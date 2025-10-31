package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"

	"github.com/go-chi/chi/v5"
)

func primeCSRFCookies(t *testing.T, handler http.Handler) ([]*http.Cookie, string) {
	t.Helper()
	req := httptest.NewRequest(http.MethodGet, "/", nil)
	req.Header.Set("Accept-Language", "en")
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	res := rec.Result()
	defer res.Body.Close()
	if rec.Code != http.StatusOK {
		t.Fatalf("expected priming request 200, got %d", rec.Code)
	}
	var token string
	for _, c := range res.Cookies() {
		if c.Name == "csrf_token" {
			token = c.Value
		}
	}
	if token == "" {
		t.Fatalf("missing CSRF token from priming response")
	}
	return res.Cookies(), token
}

func TestDesignEditorFormFragHXHeaders(t *testing.T) {
	handler := newTestRouter(t, func(r chi.Router) {
		r.MethodFunc(http.MethodGet, "/design/editor/form", DesignEditorFormFrag)
		r.MethodFunc(http.MethodPost, "/design/editor/form", DesignEditorFormFrag)
	})

	cookies, csrfToken := primeCSRFCookies(t, handler)

	form := url.Values{
		"name":   {"Kaito Studio"},
		"mode":   {"text"},
		"action": {"save"},
	}
	req := httptest.NewRequest(http.MethodPost, "/design/editor/form", strings.NewReader(form.Encode()))
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	req.Header.Set("HX-Request", "true")
	req.Header.Set("Accept-Language", "en")
	for _, c := range cookies {
		req.AddCookie(c)
	}
	req.Header.Set("X-CSRF-Token", csrfToken)

	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200 OK, got %d body=%s", rec.Code, rec.Body.String())
	}
	push := rec.Header().Get("HX-Push-Url")
	if push == "" || !strings.HasPrefix(push, "/design/editor") {
		t.Fatalf("expected HX-Push-Url with /design/editor*, got %q", push)
	}
	trigger := rec.Header().Get("HX-Trigger")
	if trigger == "" {
		t.Fatalf("expected HX-Trigger header")
	}
	var payload map[string]map[string]string
	if err := json.Unmarshal([]byte(trigger), &payload); err != nil {
		t.Fatalf("failed to unmarshal HX-Trigger payload: %v", err)
	}
	event, ok := payload["editor:state-updated"]
	if !ok || event["query"] == "" {
		t.Fatalf("expected editor:state-updated event with query, got %v", payload)
	}
	if !strings.Contains(event["query"], "mode=text") {
		t.Fatalf("expected query to preserve mode=text, got %q", event["query"])
	}
	body := rec.Body.String()
	if !strings.Contains(body, `id="design-editor-form"`) {
		t.Fatalf("expected form markup in fragment body")
	}
	if !strings.Contains(body, "Design saved") {
		t.Fatalf("expected success toast copy in body")
	}
}

func TestCartPromoModalHTMXAttributes(t *testing.T) {
	handler := newTestRouter(t, func(r chi.Router) {
		r.Get("/modal/cart/promo", CartPromoModal)
	})

	req := httptest.NewRequest(http.MethodGet, "/modal/cart/promo", nil)
	req.Header.Set("Accept-Language", "en")
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200 OK, got %d body=%s", rec.Code, rec.Body.String())
	}
	body := rec.Body.String()
	if !strings.Contains(body, "cart-promo-modal") {
		t.Fatalf("expected modal wrapper id in body")
	}
	if !strings.Contains(body, `hx-post="/cart:apply-promo"`) {
		t.Fatalf("expected hx-post attribute pointing to promo apply endpoint")
	}
	if !strings.Contains(body, `hx-target="#modal-root"`) {
		t.Fatalf("expected hx-target modal root attribute")
	}
}

func TestCartPromoApplyHandlerValidPromoTriggersEvent(t *testing.T) {
	handler := newTestRouter(t, func(r chi.Router) {
		r.MethodFunc(http.MethodPost, "/cart:apply-promo", CartPromoApplyHandler)
	})

	cookies, csrfToken := primeCSRFCookies(t, handler)

	form := url.Values{
		"promo_code": {"HANKO10"},
	}
	req := httptest.NewRequest(http.MethodPost, "/cart:apply-promo", strings.NewReader(form.Encode()))
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	req.Header.Set("HX-Request", "true")
	req.Header.Set("Accept-Language", "en")
	for _, c := range cookies {
		req.AddCookie(c)
	}
	req.Header.Set("X-CSRF-Token", csrfToken)

	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200 OK, got %d body=%s", rec.Code, rec.Body.String())
	}
	trigger := rec.Header().Get("HX-Trigger")
	if trigger == "" {
		t.Fatalf("expected HX-Trigger with promo event")
	}
	var payload map[string]map[string]string
	if err := json.Unmarshal([]byte(trigger), &payload); err != nil {
		t.Fatalf("failed to unmarshal HX-Trigger payload: %v", err)
	}
	event, ok := payload["cart:promo-applied"]
	if !ok {
		t.Fatalf("expected cart:promo-applied event, got %v", payload)
	}
	if code := event["code"]; code != "HANKO10" {
		t.Fatalf("expected event code HANKO10, got %q", code)
	}
	body := rec.Body.String()
	if !strings.Contains(body, "Promo applied.") {
		t.Fatalf("expected success status copy in body")
	}
}

func TestModalPickTemplateDefaultsToFirstTemplate(t *testing.T) {
	handler := newTestRouter(t, func(r chi.Router) {
		r.Get("/modal/pick/template", ModalPickTemplate)
	})

	req := httptest.NewRequest(http.MethodGet, "/modal/pick/template?template=unknown-template", nil)
	req.Header.Set("Accept-Language", "en")
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200 OK, got %d body=%s", rec.Code, rec.Body.String())
	}
	body := rec.Body.String()
	if !strings.Contains(body, "template-picker-modal") {
		t.Fatalf("expected modal id in body")
	}
	if !strings.Contains(body, "tpl-ring-corporate") {
		t.Fatalf("expected fallback template id in body")
	}
	if !strings.Contains(body, "Currently applied") {
		t.Fatalf("expected selected template hint in body")
	}
}

func TestProductGalleryModalFragDefaultsToPrimaryMedia(t *testing.T) {
	handler := newTestRouter(t, func(r chi.Router) {
		r.Get("/products/{productID}/gallery/modal", ProductGalleryModalFrag)
	})

	req := httptest.NewRequest(http.MethodGet, "/products/P-1000/gallery/modal", nil)
	req.Header.Set("Accept-Language", "en")
	req.Header.Set("HX-Request", "true")

	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200 OK, got %d body=%s", rec.Code, rec.Body.String())
	}
	body := rec.Body.String()
	if !strings.Contains(body, `data-modal-overlay`) {
		t.Fatalf("expected modal overlay markup in body")
	}
	if !strings.Contains(body, `<img src="`) && !strings.Contains(body, `<video`) {
		t.Fatalf("expected media element in modal body")
	}
	if !strings.Contains(body, "Round") {
		t.Fatalf("expected product name present in modal body")
	}
}
