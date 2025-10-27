package handlers

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"

	"github.com/hanko-field/api/internal/platform/auth"
	"github.com/hanko-field/api/internal/platform/httpx"
	"github.com/hanko-field/api/internal/services"
)

const (
	maxContentGuideRequestBody = 256 * 1024
	maxContentPageRequestBody  = 128 * 1024
)

// AdminContentHandlers exposes admin CRUD operations for localized guides.
type AdminContentHandlers struct {
	authn   *auth.Authenticator
	content services.ContentService
}

// NewAdminContentHandlers constructs the content handler set for admins.
func NewAdminContentHandlers(authn *auth.Authenticator, content services.ContentService) *AdminContentHandlers {
	return &AdminContentHandlers{authn: authn, content: content}
}

// Routes registers admin content endpoints beneath /admin.
func (h *AdminContentHandlers) Routes(r chi.Router) {
	if r == nil {
		return
	}
	if h.authn != nil {
		r.Use(h.authn.RequireFirebaseAuth(auth.RoleAdmin))
	}
	r.Route("/content", func(rt chi.Router) {
		rt.Post("/guides", h.createGuide)
		rt.Put("/guides/{guideID}", h.updateGuide)
		rt.Delete("/guides/{guideID}", h.deleteGuide)
		rt.Post("/pages", h.createPage)
		rt.Put("/pages/{pageID}", h.updatePage)
		rt.Delete("/pages/{pageID}", h.deletePage)
	})
}

func (h *AdminContentHandlers) createGuide(w http.ResponseWriter, r *http.Request) {
	h.saveGuide(w, r, "")
}

func (h *AdminContentHandlers) updateGuide(w http.ResponseWriter, r *http.Request) {
	guideID := chi.URLParam(r, "guideID")
	h.saveGuide(w, r, guideID)
}

func (h *AdminContentHandlers) saveGuide(w http.ResponseWriter, r *http.Request, guideID string) {
	ctx := r.Context()
	if h.content == nil {
		httpx.WriteError(ctx, w, httpx.NewError("service_unavailable", "content service unavailable", http.StatusServiceUnavailable))
		return
	}

	identity, ok := auth.IdentityFromContext(ctx)
	if !ok || identity == nil || strings.TrimSpace(identity.UID) == "" {
		httpx.WriteError(ctx, w, httpx.NewError("unauthenticated", "authentication required", http.StatusUnauthorized))
		return
	}

	guide, err := decodeAdminContentGuideRequest(r, guideID)
	if err != nil {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", err.Error(), http.StatusBadRequest))
		return
	}

	result, err := h.content.UpsertGuide(ctx, services.UpsertContentGuideCommand{
		Guide:   guide,
		ActorID: identity.UID,
	})
	if err != nil {
		writeContentError(ctx, w, err, "guide")
		return
	}

	response := newAdminContentGuideResponse(result)
	w.Header().Set("Content-Type", "application/json")
	if r.Method == http.MethodPost {
		w.WriteHeader(http.StatusCreated)
	} else {
		w.WriteHeader(http.StatusOK)
	}
	_ = json.NewEncoder(w).Encode(response)
}

func (h *AdminContentHandlers) deleteGuide(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	if h.content == nil {
		httpx.WriteError(ctx, w, httpx.NewError("service_unavailable", "content service unavailable", http.StatusServiceUnavailable))
		return
	}

	identity, ok := auth.IdentityFromContext(ctx)
	if !ok || identity == nil || strings.TrimSpace(identity.UID) == "" {
		httpx.WriteError(ctx, w, httpx.NewError("unauthenticated", "authentication required", http.StatusUnauthorized))
		return
	}

	guideID := strings.TrimSpace(chi.URLParam(r, "guideID"))
	if guideID == "" {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "guide id is required", http.StatusBadRequest))
		return
	}

	if err := h.content.DeleteGuide(ctx, guideID); err != nil {
		writeContentError(ctx, w, err, "guide")
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

func (h *AdminContentHandlers) createPage(w http.ResponseWriter, r *http.Request) {
	h.savePage(w, r, "")
}

func (h *AdminContentHandlers) updatePage(w http.ResponseWriter, r *http.Request) {
	pageID := chi.URLParam(r, "pageID")
	h.savePage(w, r, pageID)
}

func (h *AdminContentHandlers) savePage(w http.ResponseWriter, r *http.Request, pageID string) {
	ctx := r.Context()
	if h.content == nil {
		httpx.WriteError(ctx, w, httpx.NewError("service_unavailable", "content service unavailable", http.StatusServiceUnavailable))
		return
	}

	identity, ok := auth.IdentityFromContext(ctx)
	if !ok || identity == nil || strings.TrimSpace(identity.UID) == "" {
		httpx.WriteError(ctx, w, httpx.NewError("unauthenticated", "authentication required", http.StatusUnauthorized))
		return
	}

	page, regenerate, err := decodeAdminContentPageRequest(r, pageID)
	if err != nil {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", err.Error(), http.StatusBadRequest))
		return
	}

	result, err := h.content.UpsertPage(ctx, services.UpsertContentPageCommand{
		Page:                   page,
		ActorID:                identity.UID,
		RegeneratePreviewToken: regenerate,
	})
	if err != nil {
		writeContentError(ctx, w, err, "page")
		return
	}

	response := newAdminContentPageResponse(result)
	w.Header().Set("Content-Type", "application/json")
	if r.Method == http.MethodPost {
		w.WriteHeader(http.StatusCreated)
	} else {
		w.WriteHeader(http.StatusOK)
	}
	_ = json.NewEncoder(w).Encode(response)
}

func (h *AdminContentHandlers) deletePage(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	if h.content == nil {
		httpx.WriteError(ctx, w, httpx.NewError("service_unavailable", "content service unavailable", http.StatusServiceUnavailable))
		return
	}

	identity, ok := auth.IdentityFromContext(ctx)
	if !ok || identity == nil || strings.TrimSpace(identity.UID) == "" {
		httpx.WriteError(ctx, w, httpx.NewError("unauthenticated", "authentication required", http.StatusUnauthorized))
		return
	}

	pageID := strings.TrimSpace(chi.URLParam(r, "pageID"))
	if pageID == "" {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "page id is required", http.StatusBadRequest))
		return
	}

	if err := h.content.DeletePage(ctx, services.DeleteContentPageCommand{
		PageID:  pageID,
		ActorID: identity.UID,
	}); err != nil {
		writeContentError(ctx, w, err, "page")
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

func decodeAdminContentGuideRequest(r *http.Request, overrideID string) (services.ContentGuide, error) {
	limited := io.LimitReader(r.Body, maxContentGuideRequestBody)
	defer r.Body.Close()
	decoder := json.NewDecoder(limited)
	decoder.DisallowUnknownFields()

	var req adminContentGuideRequest
	if err := decoder.Decode(&req); err != nil {
		if errors.Is(err, io.EOF) {
			return services.ContentGuide{}, errors.New("request body required")
		}
		return services.ContentGuide{}, fmt.Errorf("invalid request body: %w", err)
	}

	guide, err := req.toModel()
	if err != nil {
		return services.ContentGuide{}, err
	}
	if trimmed := strings.TrimSpace(overrideID); trimmed != "" {
		guide.ID = trimmed
	}
	return guide, nil
}

type adminContentGuideRequest struct {
	ID          string   `json:"id"`
	Slug        string   `json:"slug"`
	Locale      string   `json:"locale"`
	Category    string   `json:"category"`
	Title       string   `json:"title"`
	Summary     string   `json:"summary"`
	BodyHTML    string   `json:"body_html"`
	HeroImage   string   `json:"hero_image"`
	Tags        []string `json:"tags"`
	Status      string   `json:"status"`
	PublishAt   *string  `json:"publish_at"`
	IsPublished *bool    `json:"is_published"`
}

func (req adminContentGuideRequest) toModel() (services.ContentGuide, error) {
	guide := services.ContentGuide{
		ID:        strings.TrimSpace(req.ID),
		Slug:      strings.TrimSpace(req.Slug),
		Locale:    normalizeLocale(req.Locale),
		Category:  strings.TrimSpace(req.Category),
		Title:     strings.TrimSpace(req.Title),
		Summary:   strings.TrimSpace(req.Summary),
		BodyHTML:  sanitizeGuideHTML(req.BodyHTML),
		HeroImage: strings.TrimSpace(req.HeroImage),
		Tags:      normalizeGuideTags(req.Tags),
		Status:    strings.TrimSpace(req.Status),
	}
	if req.IsPublished != nil {
		guide.IsPublished = *req.IsPublished
	}
	if req.PublishAt != nil {
		timestamp, err := parseTimePointer(req.PublishAt)
		if err != nil {
			return services.ContentGuide{}, err
		}
		guide.PublishedAt = timestamp
	}
	return guide, nil
}

type adminContentGuideResponse struct {
	ID          string   `json:"id"`
	Slug        string   `json:"slug"`
	Locale      string   `json:"locale"`
	Category    string   `json:"category"`
	Title       string   `json:"title"`
	Summary     string   `json:"summary"`
	BodyHTML    string   `json:"body_html"`
	HeroImage   string   `json:"hero_image"`
	Tags        []string `json:"tags,omitempty"`
	Status      string   `json:"status,omitempty"`
	IsPublished bool     `json:"is_published"`
	PublishedAt string   `json:"published_at,omitempty"`
	CreatedAt   string   `json:"created_at,omitempty"`
	UpdatedAt   string   `json:"updated_at,omitempty"`
}

func newAdminContentGuideResponse(guide services.ContentGuide) adminContentGuideResponse {
	locale := normalizeLocale(guide.Locale)
	resp := adminContentGuideResponse{
		ID:          strings.TrimSpace(guide.ID),
		Slug:        strings.TrimSpace(guide.Slug),
		Locale:      locale,
		Category:    strings.TrimSpace(guide.Category),
		Title:       strings.TrimSpace(guide.Title),
		Summary:     strings.TrimSpace(guide.Summary),
		BodyHTML:    sanitizeGuideHTML(guide.BodyHTML),
		HeroImage:   strings.TrimSpace(guide.HeroImage),
		Tags:        normalizeGuideTags(guide.Tags),
		Status:      strings.TrimSpace(guide.Status),
		IsPublished: guide.IsPublished,
		CreatedAt:   formatTimestamp(guide.CreatedAt),
		UpdatedAt:   formatTimestamp(guide.UpdatedAt),
	}
	if !guide.PublishedAt.IsZero() {
		resp.PublishedAt = formatTimestamp(guide.PublishedAt)
	}
	return resp
}

func decodeAdminContentPageRequest(r *http.Request, overrideID string) (services.ContentPage, bool, error) {
	limited := io.LimitReader(r.Body, maxContentPageRequestBody)
	defer r.Body.Close()
	decoder := json.NewDecoder(limited)
	decoder.DisallowUnknownFields()

	var req adminContentPageRequest
	if err := decoder.Decode(&req); err != nil {
		if errors.Is(err, io.EOF) {
			return services.ContentPage{}, false, errors.New("request body required")
		}
		return services.ContentPage{}, false, fmt.Errorf("invalid request body: %w", err)
	}

	page := req.toModel()
	if trimmed := strings.TrimSpace(overrideID); trimmed != "" {
		page.ID = trimmed
	}
	return page, req.RegeneratePreviewToken, nil
}

type adminContentPageRequest struct {
	ID                     string            `json:"id"`
	Slug                   string            `json:"slug"`
	Locale                 string            `json:"locale"`
	Title                  string            `json:"title"`
	BodyHTML               string            `json:"body_html"`
	SEO                    map[string]string `json:"seo"`
	Status                 string            `json:"status"`
	RegeneratePreviewToken bool              `json:"regenerate_preview_token"`
}

func (req adminContentPageRequest) toModel() services.ContentPage {
	return services.ContentPage{
		ID:       strings.TrimSpace(req.ID),
		Slug:     strings.TrimSpace(req.Slug),
		Locale:   normalizeLocale(req.Locale),
		Title:    strings.TrimSpace(req.Title),
		BodyHTML: sanitizePageHTML(req.BodyHTML),
		SEO:      req.SEO,
		Status:   strings.TrimSpace(req.Status),
	}
}

type adminContentPageResponse struct {
	ID           string            `json:"id"`
	Slug         string            `json:"slug"`
	Locale       string            `json:"locale"`
	Title        string            `json:"title"`
	BodyHTML     string            `json:"body_html,omitempty"`
	SEO          map[string]string `json:"seo,omitempty"`
	Status       string            `json:"status,omitempty"`
	IsPublished  bool              `json:"is_published"`
	PreviewToken string            `json:"preview_token,omitempty"`
	UpdatedAt    string            `json:"updated_at,omitempty"`
}

func newAdminContentPageResponse(page services.ContentPage) adminContentPageResponse {
	payload := buildContentPagePayload(page)
	return adminContentPageResponse{
		ID:           strings.TrimSpace(page.ID),
		Slug:         payload.Slug,
		Locale:       payload.Locale,
		Title:        payload.Title,
		BodyHTML:     payload.BodyHTML,
		SEO:          payload.SEO,
		Status:       strings.TrimSpace(page.Status),
		IsPublished:  payload.IsPublished,
		PreviewToken: strings.TrimSpace(page.PreviewToken),
		UpdatedAt:    payload.UpdatedAt,
	}
}
