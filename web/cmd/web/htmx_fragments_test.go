package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"

	"github.com/go-chi/chi/v5"
	"golang.org/x/net/html"
)

func primeCSRFCookies(t *testing.T, handler http.Handler, path string) ([]*http.Cookie, string) {
	t.Helper()
	req := httptest.NewRequest(http.MethodGet, path, nil)
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

func requireAttr(t *testing.T, markup, attr, want string) {
	t.Helper()
	doc, err := html.Parse(strings.NewReader(markup))
	if err != nil {
		t.Fatalf("parse html: %v", err)
	}
	if !nodeContainsAttr(doc, attr, want) {
		t.Fatalf("expected attribute %s=%q in markup", attr, want)
	}
}

func nodeContainsAttr(n *html.Node, attr, want string) bool {
	for _, a := range n.Attr {
		if a.Key == attr && a.Val == want {
			return true
		}
	}
	for c := n.FirstChild; c != nil; c = c.NextSibling {
		if nodeContainsAttr(c, attr, want) {
			return true
		}
	}
	return false
}

func requireAttrContains(t *testing.T, markup, attr, want string) {
	t.Helper()
	doc, err := html.Parse(strings.NewReader(markup))
	if err != nil {
		t.Fatalf("parse html: %v", err)
	}
	if !nodeAttrContains(doc, attr, want) {
		t.Fatalf("expected attribute %s to contain %q", attr, want)
	}
}

func nodeAttrContains(n *html.Node, attr, want string) bool {
	for _, a := range n.Attr {
		if a.Key == attr && strings.Contains(a.Val, want) {
			return true
		}
	}
	for c := n.FirstChild; c != nil; c = c.NextSibling {
		if nodeAttrContains(c, attr, want) {
			return true
		}
	}
	return false
}

func TestDesignEditorFormFragHXHeaders(t *testing.T) {
	handler := newTestRouter(t, func(r chi.Router) {
		r.MethodFunc(http.MethodGet, "/design/editor/form", DesignEditorFormFrag)
		r.MethodFunc(http.MethodPost, "/design/editor/form", DesignEditorFormFrag)
	})

	cookies, csrfToken := primeCSRFCookies(t, handler, "/design/editor/form")

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
	if push == "" {
		t.Fatalf("expected HX-Push-Url header")
	}
	pushURL, err := url.Parse(push)
	if err != nil {
		t.Fatalf("parse HX-Push-Url: %v", err)
	}
	if pushURL.Path != "/design/editor" {
		t.Fatalf("expected HX-Push-Url path /design/editor, got %s", pushURL.Path)
	}
	pushQuery := pushURL.Query()
	if got := pushQuery.Get("mode"); got != "text" {
		t.Fatalf("expected mode=text in push query, got %q", got)
	}
	if got := pushQuery.Get("name"); got != "Kaito Studio" {
		t.Fatalf("expected name preserved in push query, got %q", got)
	}
	if got := pushQuery.Get("template"); got != "tpl-ring-corporate" {
		t.Fatalf("expected template id in push query, got %q", got)
	}
	if got := pushQuery.Get("font"); got != "jp-mincho" {
		t.Fatalf("expected font id in push query, got %q", got)
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
	q, err := url.ParseQuery(event["query"])
	if err != nil {
		t.Fatalf("parse event query: %v", err)
	}
	if q.Get("mode") != "text" {
		t.Fatalf("expected event query mode=text, got %q", q.Get("mode"))
	}
	if q.Get("template") != "tpl-ring-corporate" {
		t.Fatalf("expected event query template=tpl-ring-corporate, got %q", q.Get("template"))
	}
	if q.Get("font") != "jp-mincho" {
		t.Fatalf("expected event query font=jp-mincho, got %q", q.Get("font"))
	}
	if event["query"] != pushURL.RawQuery {
		t.Fatalf("expected HX-Trigger query to match HX-Push-Url, got %q vs %q", event["query"], pushURL.RawQuery)
	}

	body := rec.Body.String()
	requireAttr(t, body, "id", "design-editor-form")
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
	requireAttr(t, body, "id", "cart-promo-modal_title")
	requireAttr(t, body, "hx-post", "/cart:apply-promo")
	requireAttr(t, body, "hx-target", "#modal-root")
}

func TestCartPromoApplyHandlerValidPromoTriggersEvent(t *testing.T) {
	handler := newTestRouter(t, func(r chi.Router) {
		r.Get("/modal/cart/promo", CartPromoModal)
		r.MethodFunc(http.MethodPost, "/cart:apply-promo", CartPromoApplyHandler)
	})

	cookies, csrfToken := primeCSRFCookies(t, handler, "/modal/cart/promo")

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
	requireAttrContains(t, body, "class", "border-emerald-200")
	requireAttrContains(t, body, "class", "bg-emerald-50")
}

func TestCartPromoApplyHandlerInvalidPromoShowsError(t *testing.T) {
	handler := newTestRouter(t, func(r chi.Router) {
		r.Get("/modal/cart/promo", CartPromoModal)
		r.MethodFunc(http.MethodPost, "/cart:apply-promo", CartPromoApplyHandler)
	})

	cookies, csrfToken := primeCSRFCookies(t, handler, "/modal/cart/promo")

	form := url.Values{
		"promo_code": {"INVALID"},
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
	if trigger := rec.Header().Get("HX-Trigger"); trigger != "" {
		t.Fatalf("expected no HX-Trigger on invalid promo, got %s", trigger)
	}
	body := rec.Body.String()
	requireAttrContains(t, body, "class", "border-red-200")
	requireAttrContains(t, body, "class", "bg-red-50")
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
	requireAttr(t, body, "id", "template-picker-modal_title")
	requireAttr(t, body, "hx-vals", `{"template":"tpl-ring-corporate"}`)
	requireAttrContains(t, body, "class", "border-indigo-400")
	requireAttrContains(t, body, "class", "bg-indigo-50")
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
