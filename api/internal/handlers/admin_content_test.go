package handlers

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"

	domain "github.com/hanko-field/api/internal/domain"
	"github.com/hanko-field/api/internal/platform/auth"
	"github.com/hanko-field/api/internal/services"
)

func TestAdminContentHandlers_CreateGuide(t *testing.T) {
	t.Helper()

	publishedAt := time.Date(2024, time.May, 10, 9, 0, 0, 0, time.UTC)
	updatedAt := publishedAt.Add(time.Hour)
	svc := &adminStubContentService{
		upsertResp: services.ContentGuide{
			ID:          "guide_123",
			Slug:        "tea-ceremony",
			Locale:      "en-us",
			Category:    "culture",
			Title:       "Tea Ceremony",
			Summary:     "Learn the basics",
			BodyHTML:    "<p>allowed</p>",
			HeroImage:   "images/hero.jpg",
			Tags:        []string{"culture"},
			Status:      "published",
			IsPublished: true,
			PublishedAt: publishedAt,
			CreatedAt:   publishedAt.Add(-time.Hour),
			UpdatedAt:   updatedAt,
		},
	}

	handler := NewAdminContentHandlers(nil, svc)
	router := chi.NewRouter()
	handler.Routes(router)

	body := map[string]any{
		"id":           "guide_temp",
		"slug":         " tea-ceremony ",
		"locale":       "EN_us",
		"category":     " Culture ",
		"title":        " Tea Ceremony ",
		"summary":      " Learn the basics ",
		"body_html":    "<script>alert(1)</script><p>allowed</p>",
		"hero_image":   "images/hero.jpg",
		"tags":         []string{"culture", "Culture"},
		"status":       " Published ",
		"publish_at":   "2024-05-10T09:00:00Z",
		"is_published": true,
	}
	payload, _ := json.Marshal(body)
	req := httptest.NewRequest(http.MethodPost, "/content/guides", bytes.NewReader(payload))
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: "admin", Roles: []string{auth.RoleAdmin}}))
	resp := httptest.NewRecorder()

	router.ServeHTTP(resp, req)

	if resp.Code != http.StatusCreated {
		t.Fatalf("expected 201 got %d", resp.Code)
	}
	if svc.upsertCmd.ActorID != "admin" {
		t.Fatalf("expected actor admin, got %s", svc.upsertCmd.ActorID)
	}
	if svc.upsertCmd.Guide.Slug != "tea-ceremony" {
		t.Fatalf("expected trimmed slug, got %q", svc.upsertCmd.Guide.Slug)
	}
	if svc.upsertCmd.Guide.Locale != "en-us" {
		t.Fatalf("expected normalized locale en-us, got %q", svc.upsertCmd.Guide.Locale)
	}
	if strings.Contains(svc.upsertCmd.Guide.BodyHTML, "script") {
		t.Fatalf("expected sanitized body html, got %q", svc.upsertCmd.Guide.BodyHTML)
	}
	if len(svc.upsertCmd.Guide.Tags) != 1 {
		t.Fatalf("expected deduped tags, got %#v", svc.upsertCmd.Guide.Tags)
	}
	if svc.upsertCmd.Guide.PublishedAt.IsZero() {
		t.Fatalf("expected published at parsed")
	}

	var parsed adminContentGuideResponse
	if err := json.NewDecoder(resp.Body).Decode(&parsed); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if parsed.Locale != "en-us" {
		t.Fatalf("expected locale en-us, got %q", parsed.Locale)
	}
	if parsed.BodyHTML != "<p>allowed</p>" {
		t.Fatalf("expected sanitized body html, got %q", parsed.BodyHTML)
	}
	if parsed.PublishedAt == "" {
		t.Fatalf("expected published_at timestamp")
	}
}

func TestAdminContentHandlers_UpdateGuideUsesPathID(t *testing.T) {
	svc := &adminStubContentService{}
	handler := NewAdminContentHandlers(nil, svc)
	router := chi.NewRouter()
	handler.Routes(router)

	body := map[string]any{
		"id":        "guide_body",
		"slug":      "tea",
		"locale":    "ja",
		"body_html": "<p>ok</p>",
	}
	payload, _ := json.Marshal(body)
	req := httptest.NewRequest(http.MethodPut, "/content/guides/guide_path", bytes.NewReader(payload))
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: "staff", Roles: []string{auth.RoleAdmin}}))
	resp := httptest.NewRecorder()

	router.ServeHTTP(resp, req)

	if resp.Code != http.StatusOK {
		t.Fatalf("expected 200 got %d", resp.Code)
	}
	if svc.upsertCmd.Guide.ID != "guide_path" {
		t.Fatalf("expected path id override, got %q", svc.upsertCmd.Guide.ID)
	}
}

func TestAdminContentHandlers_DeleteGuideRequiresIdentity(t *testing.T) {
	handler := NewAdminContentHandlers(nil, &adminStubContentService{})
	router := chi.NewRouter()
	handler.Routes(router)

	req := httptest.NewRequest(http.MethodDelete, "/content/guides/guide_x", nil)
	resp := httptest.NewRecorder()

	router.ServeHTTP(resp, req)

	if resp.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401 got %d", resp.Code)
	}
}

func TestAdminContentHandlers_DeleteGuideCallsService(t *testing.T) {
	svc := &adminStubContentService{}
	handler := NewAdminContentHandlers(nil, svc)
	router := chi.NewRouter()
	handler.Routes(router)

	req := httptest.NewRequest(http.MethodDelete, "/content/guides/guide_del", nil)
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: "admin", Roles: []string{auth.RoleAdmin}}))
	resp := httptest.NewRecorder()

	router.ServeHTTP(resp, req)

	if resp.Code != http.StatusNoContent {
		t.Fatalf("expected 204 got %d", resp.Code)
	}
	if svc.deleteID != "guide_del" {
		t.Fatalf("expected delete id guide_del, got %q", svc.deleteID)
	}
}

func TestAdminContentHandlers_ServiceUnavailable(t *testing.T) {
	handler := NewAdminContentHandlers(nil, nil)
	router := chi.NewRouter()
	handler.Routes(router)

	req := httptest.NewRequest(http.MethodPost, "/content/guides", bytes.NewBufferString(`{"slug":"missing"}`))
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: "admin", Roles: []string{auth.RoleAdmin}}))
	resp := httptest.NewRecorder()

	router.ServeHTTP(resp, req)

	if resp.Code != http.StatusServiceUnavailable {
		t.Fatalf("expected 503 got %d", resp.Code)
	}
}

func TestAdminContentHandlers_InvalidPayload(t *testing.T) {
	svc := &adminStubContentService{}
	handler := NewAdminContentHandlers(nil, svc)
	router := chi.NewRouter()
	handler.Routes(router)

	req := httptest.NewRequest(http.MethodPost, "/content/guides", bytes.NewBufferString(`{"id":`))
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: "admin", Roles: []string{auth.RoleAdmin}}))
	resp := httptest.NewRecorder()

	router.ServeHTTP(resp, req)

	if resp.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 got %d", resp.Code)
	}
}

func TestAdminContentHandlers_CreatePage(t *testing.T) {
	t.Helper()

	updatedAt := time.Date(2024, time.March, 2, 8, 0, 0, 0, time.UTC)
	svc := &adminStubContentService{
		pageUpsertResp: services.ContentPage{
			ID:           "page_001",
			Slug:         "company",
			Locale:       "ja",
			Title:        "Company",
			BodyHTML:     "<p>clean</p>",
			Status:       "draft",
			IsPublished:  false,
			PreviewToken: "token-123",
			UpdatedAt:    updatedAt,
		},
	}
	handler := NewAdminContentHandlers(nil, svc)
	router := chi.NewRouter()
	handler.Routes(router)

	payload := map[string]any{
		"id":                       "override",
		"slug":                     " company ",
		"locale":                   "JA",
		"title":                    " Company ",
		"body_html":                "<script>alert(1)</script><p>clean</p>",
		"seo":                      map[string]string{"title": " About "},
		"status":                   " Draft ",
		"regenerate_preview_token": true,
	}
	body, _ := json.Marshal(payload)

	req := httptest.NewRequest(http.MethodPost, "/content/pages", bytes.NewReader(body))
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: "admin", Roles: []string{auth.RoleAdmin}}))
	resp := httptest.NewRecorder()

	router.ServeHTTP(resp, req)

	if resp.Code != http.StatusCreated {
		t.Fatalf("expected 201 got %d", resp.Code)
	}
	if svc.pageUpsertCmd.ActorID != "admin" {
		t.Fatalf("expected actor admin, got %s", svc.pageUpsertCmd.ActorID)
	}
	if svc.pageUpsertCmd.Page.Slug != "company" {
		t.Fatalf("expected trimmed slug, got %q", svc.pageUpsertCmd.Page.Slug)
	}
	if svc.pageUpsertCmd.Page.Locale != "ja" {
		t.Fatalf("expected normalized locale ja, got %q", svc.pageUpsertCmd.Page.Locale)
	}
	if svc.pageUpsertCmd.Page.BodyHTML != "<p>clean</p>" {
		t.Fatalf("expected sanitized body html, got %q", svc.pageUpsertCmd.Page.BodyHTML)
	}
	if !svc.pageUpsertCmd.RegeneratePreviewToken {
		t.Fatalf("expected regenerate preview token flag")
	}

	var parsed adminContentPageResponse
	if err := json.NewDecoder(resp.Body).Decode(&parsed); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if parsed.ID != "page_001" {
		t.Fatalf("expected id page_001, got %s", parsed.ID)
	}
	if parsed.PreviewToken != "token-123" {
		t.Fatalf("expected preview token token-123, got %s", parsed.PreviewToken)
	}
	if parsed.UpdatedAt == "" {
		t.Fatalf("expected updated_at populated")
	}
}

func TestAdminContentHandlers_UpdatePageUsesPathID(t *testing.T) {
	svc := &adminStubContentService{}
	handler := NewAdminContentHandlers(nil, svc)
	router := chi.NewRouter()
	handler.Routes(router)

	body := map[string]any{
		"id":        "body-id",
		"slug":      "company",
		"locale":    "ja",
		"title":     "Company",
		"body_html": "<p>clean</p>",
	}
	payload, _ := json.Marshal(body)

	req := httptest.NewRequest(http.MethodPut, "/content/pages/page-param", bytes.NewReader(payload))
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: "staff", Roles: []string{auth.RoleAdmin}}))
	resp := httptest.NewRecorder()

	router.ServeHTTP(resp, req)

	if resp.Code != http.StatusOK {
		t.Fatalf("expected 200 got %d", resp.Code)
	}
	if svc.pageUpsertCmd.Page.ID != "page-param" {
		t.Fatalf("expected path id override, got %q", svc.pageUpsertCmd.Page.ID)
	}
}

func TestAdminContentHandlers_DeletePageCallsService(t *testing.T) {
	svc := &adminStubContentService{}
	handler := NewAdminContentHandlers(nil, svc)
	router := chi.NewRouter()
	handler.Routes(router)

	req := httptest.NewRequest(http.MethodDelete, "/content/pages/page-del", nil)
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{UID: "admin", Roles: []string{auth.RoleAdmin}}))
	resp := httptest.NewRecorder()

	router.ServeHTTP(resp, req)

	if resp.Code != http.StatusNoContent {
		t.Fatalf("expected 204 got %d", resp.Code)
	}
	if svc.pageDeleteCmd.PageID != "page-del" {
		t.Fatalf("expected delete page id page-del, got %q", svc.pageDeleteCmd.PageID)
	}
	if svc.pageDeleteCmd.ActorID != "admin" {
		t.Fatalf("expected actor admin, got %q", svc.pageDeleteCmd.ActorID)
	}
}

type adminStubContentService struct {
	upsertCmd      services.UpsertContentGuideCommand
	upsertResp     services.ContentGuide
	upsertErr      error
	deleteID       string
	deleteErr      error
	pageUpsertCmd  services.UpsertContentPageCommand
	pageUpsertResp services.ContentPage
	pageUpsertErr  error
	pageDeleteCmd  services.DeleteContentPageCommand
	pageDeleteErr  error
}

func (s *adminStubContentService) ListGuides(context.Context, services.ContentGuideFilter) (domain.CursorPage[services.ContentGuide], error) {
	return domain.CursorPage[services.ContentGuide]{}, nil
}

func (s *adminStubContentService) GetGuideBySlug(context.Context, string, string) (services.ContentGuide, error) {
	return services.ContentGuide{}, errors.New("not implemented")
}

func (s *adminStubContentService) GetGuide(context.Context, string) (services.ContentGuide, error) {
	return services.ContentGuide{}, errors.New("not implemented")
}

func (s *adminStubContentService) UpsertGuide(_ context.Context, cmd services.UpsertContentGuideCommand) (services.ContentGuide, error) {
	s.upsertCmd = cmd
	if s.upsertErr != nil {
		return services.ContentGuide{}, s.upsertErr
	}
	if s.upsertResp.ID == "" {
		return cmd.Guide, nil
	}
	return s.upsertResp, nil
}

func (s *adminStubContentService) DeleteGuide(_ context.Context, guideID string) error {
	s.deleteID = guideID
	return s.deleteErr
}

func (s *adminStubContentService) GetPage(context.Context, string, string) (services.ContentPage, error) {
	return services.ContentPage{}, errors.New("not implemented")
}

func (s *adminStubContentService) UpsertPage(_ context.Context, cmd services.UpsertContentPageCommand) (services.ContentPage, error) {
	s.pageUpsertCmd = cmd
	if s.pageUpsertErr != nil {
		return services.ContentPage{}, s.pageUpsertErr
	}
	if s.pageUpsertResp.ID == "" {
		return cmd.Page, nil
	}
	return s.pageUpsertResp, nil
}

func (s *adminStubContentService) DeletePage(_ context.Context, cmd services.DeleteContentPageCommand) error {
	s.pageDeleteCmd = cmd
	return s.pageDeleteErr
}
