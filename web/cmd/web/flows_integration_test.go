package main

import (
	"encoding/json"
	"io"
	"net/http"
	"net/http/cookiejar"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"

	"github.com/go-chi/chi/v5"
)

func newFlowTestServer(t *testing.T, add func(r chi.Router)) *httptest.Server {
	t.Helper()
	handler := newTestRouter(t, add)
	server := httptest.NewServer(handler)
	t.Cleanup(server.Close)
	return server
}

func csrfTokenFromJar(t *testing.T, jar http.CookieJar, rawURL string) string {
	t.Helper()
	u, err := url.Parse(rawURL)
	if err != nil {
		t.Fatalf("parse url: %v", err)
	}
	for _, c := range jar.Cookies(u) {
		if c.Name == "csrf_token" {
			return c.Value
		}
	}
	t.Fatalf("csrf token missing for %s", rawURL)
	return ""
}

func TestCheckoutHTMXFlowAdvancesBetweenSteps(t *testing.T) {
	server := newFlowTestServer(t, func(r chi.Router) {
		r.Get("/checkout/address", CheckoutAddressHandler)
		r.Get("/checkout/address/list", CheckoutAddressListFrag)
		r.MethodFunc(http.MethodPost, "/checkout/address/submit", CheckoutAddressSubmitHandler)
		r.Get("/checkout/shipping", CheckoutShippingHandler)
		r.MethodFunc(http.MethodPost, "/checkout/shipping/table", CheckoutShippingTableFrag)
		r.MethodFunc(http.MethodPost, "/checkout/shipping/submit", CheckoutShippingSubmitHandler)
		r.Get("/checkout/payment", CheckoutPaymentHandler)
		r.MethodFunc(http.MethodPost, "/checkout/payment/confirm", CheckoutPaymentConfirmHandler)
		r.Get("/checkout/review", CheckoutReviewHandler)
	})

	jar, err := cookiejar.New(nil)
	if err != nil {
		t.Fatalf("failed to build cookie jar: %v", err)
	}
	client := server.Client()
	client.Jar = jar

	// Step 1: address page
	req, err := http.NewRequest(http.MethodGet, server.URL+"/checkout/address", nil)
	if err != nil {
		t.Fatalf("new request: %v", err)
	}
	req.Header.Set("Accept-Language", "en")
	resp, err := client.Do(req)
	if err != nil {
		t.Fatalf("request failed: %v", err)
	}
	bodyBytes, _ := io.ReadAll(resp.Body)
	resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200 OK, got %d body=%s", resp.StatusCode, string(bodyBytes))
	}
	if !strings.Contains(string(bodyBytes), "checkout-address-root") {
		t.Fatalf("expected checkout address markup in response")
	}

	csrfToken := csrfTokenFromJar(t, jar, server.URL+"/")

	// Step 2: submit selections via HTMX
	form := url.Values{
		"shipping_id": {"addr_tokyo"},
		"billing_id":  {"addr_osaka"},
	}
	req, err = http.NewRequest(http.MethodPost, server.URL+"/checkout/address/submit", strings.NewReader(form.Encode()))
	if err != nil {
		t.Fatalf("new request: %v", err)
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	req.Header.Set("HX-Request", "true")
	req.Header.Set("Accept-Language", "en")
	req.Header.Set("X-CSRF-Token", csrfToken)
	resp, err = client.Do(req)
	if err != nil {
		t.Fatalf("request failed: %v", err)
	}
	io.Copy(io.Discard, resp.Body)
	resp.Body.Close()
	if resp.StatusCode != http.StatusNoContent {
		t.Fatalf("expected 204 No Content, got %d", resp.StatusCode)
	}
	if redir := resp.Header.Get("HX-Redirect"); redir != "/checkout/shipping" {
		t.Fatalf("expected HX-Redirect /checkout/shipping, got %q", redir)
	}

	// Step 3: shipping page render
	req, err = http.NewRequest(http.MethodGet, server.URL+"/checkout/shipping", nil)
	if err != nil {
		t.Fatalf("new request: %v", err)
	}
	req.Header.Set("Accept-Language", "en")
	resp, err = client.Do(req)
	if err != nil {
		t.Fatalf("request failed: %v", err)
	}
	bodyBytes, _ = io.ReadAll(resp.Body)
	resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200 OK, got %d body=%s", resp.StatusCode, string(bodyBytes))
	}
	if !strings.Contains(string(bodyBytes), "checkout-shipping-root") {
		t.Fatalf("expected shipping markup in response")
	}

	// Step 4: HTMX submit shipping method
	form = url.Values{
		"shipping_method": {"express"},
	}
	req, err = http.NewRequest(http.MethodPost, server.URL+"/checkout/shipping/submit", strings.NewReader(form.Encode()))
	if err != nil {
		t.Fatalf("new request: %v", err)
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	req.Header.Set("HX-Request", "true")
	req.Header.Set("Accept-Language", "en")
	req.Header.Set("X-CSRF-Token", csrfToken)
	resp, err = client.Do(req)
	if err != nil {
		t.Fatalf("request failed: %v", err)
	}
	io.Copy(io.Discard, resp.Body)
	resp.Body.Close()
	if resp.StatusCode != http.StatusNoContent {
		t.Fatalf("expected 204 No Content, got %d", resp.StatusCode)
	}
	if redir := resp.Header.Get("HX-Redirect"); redir != "/checkout/payment" {
		t.Fatalf("expected HX-Redirect /checkout/payment, got %q", redir)
	}

	// Step 5: payment page render
	req, err = http.NewRequest(http.MethodGet, server.URL+"/checkout/payment", nil)
	if err != nil {
		t.Fatalf("new request: %v", err)
	}
	req.Header.Set("Accept-Language", "en")
	resp, err = client.Do(req)
	if err != nil {
		t.Fatalf("request failed: %v", err)
	}
	bodyBytes, _ = io.ReadAll(resp.Body)
	resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200 OK, got %d body=%s", resp.StatusCode, string(bodyBytes))
	}
	if !strings.Contains(string(bodyBytes), "checkout-payment-root") {
		t.Fatalf("expected payment markup in response")
	}

	// Step 6: confirm payment and capture HX trigger
	form = url.Values{
		"session_id": {"sess_demo"},
		"provider":   {"stripe"},
	}
	req, err = http.NewRequest(http.MethodPost, server.URL+"/checkout/payment/confirm", strings.NewReader(form.Encode()))
	if err != nil {
		t.Fatalf("new request: %v", err)
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	req.Header.Set("HX-Request", "true")
	req.Header.Set("Accept-Language", "en")
	req.Header.Set("X-CSRF-Token", csrfToken)
	resp, err = client.Do(req)
	if err != nil {
		t.Fatalf("request failed: %v", err)
	}
	bodyBytes, _ = io.ReadAll(resp.Body)
	resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200 OK, got %d body=%s", resp.StatusCode, string(bodyBytes))
	}
	if !strings.Contains(string(bodyBytes), "Payment confirmed") {
		t.Fatalf("expected success copy in response body: %s", string(bodyBytes))
	}
	trigger := resp.Header.Get("HX-Trigger")
	if trigger == "" {
		t.Fatalf("expected HX-Trigger header from payment confirm")
	}
	var payload map[string]map[string]string
	if err := json.Unmarshal([]byte(trigger), &payload); err != nil {
		t.Fatalf("unmarshal HX-Trigger: %v", err)
	}
	success, ok := payload["checkout:payment:success"]
	if !ok {
		t.Fatalf("expected checkout:payment:success event, got %v", payload)
	}
	nextURL := success["nextUrl"]
	if nextURL == "" || !strings.HasPrefix(nextURL, "/checkout/review") {
		t.Fatalf("expected nextUrl to point to review, got %q", nextURL)
	}

	// Step 7: follow to review page
	req, err = http.NewRequest(http.MethodGet, server.URL+nextURL, nil)
	if err != nil {
		t.Fatalf("new request: %v", err)
	}
	req.Header.Set("Accept-Language", "en")
	resp, err = client.Do(req)
	if err != nil {
		t.Fatalf("request failed: %v", err)
	}
	bodyBytes, _ = io.ReadAll(resp.Body)
	resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200 OK, got %d body=%s", resp.StatusCode, string(bodyBytes))
	}
	if !strings.Contains(string(bodyBytes), "checkout-review-root") {
		t.Fatalf("expected checkout review markup in response")
	}
}

func TestAccountProfileFormHTMXFlowPersistsSession(t *testing.T) {
	server := newFlowTestServer(t, func(r chi.Router) {
		r.Get("/account", AccountHandler)
		r.MethodFunc(http.MethodGet, "/account/profile/form", AccountProfileFormHandler)
		r.MethodFunc(http.MethodPost, "/account/profile/form", AccountProfileFormHandler)
	})

	jar, err := cookiejar.New(nil)
	if err != nil {
		t.Fatalf("failed to build cookie jar: %v", err)
	}
	client := server.Client()
	client.Jar = jar

	// Initial fetch
	req, err := http.NewRequest(http.MethodGet, server.URL+"/account/profile/form", nil)
	if err != nil {
		t.Fatalf("new request: %v", err)
	}
	req.Header.Set("Accept-Language", "en")
	resp, err := client.Do(req)
	if err != nil {
		t.Fatalf("request failed: %v", err)
	}
	bodyBytes, _ := io.ReadAll(resp.Body)
	resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200 OK, got %d body=%s", resp.StatusCode, string(bodyBytes))
	}
	if !strings.Contains(string(bodyBytes), `name="display_name"`) {
		t.Fatalf("expected profile form input in response")
	}

	csrfToken := csrfTokenFromJar(t, jar, server.URL+"/")

	// Submit updated profile via HTMX
	form := url.Values{
		"display_name":  {"Kaito Ito"},
		"email":         {"kaito.ito@example.com"},
		"phone":         {"09012345678"},
		"phone_country": {"JP"},
		"lang":          {"en"},
		"country":       {"JP"},
	}
	req, err = http.NewRequest(http.MethodPost, server.URL+"/account/profile/form", strings.NewReader(form.Encode()))
	if err != nil {
		t.Fatalf("new request: %v", err)
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	req.Header.Set("HX-Request", "true")
	req.Header.Set("Accept-Language", "en")
	req.Header.Set("X-CSRF-Token", csrfToken)
	resp, err = client.Do(req)
	if err != nil {
		t.Fatalf("request failed: %v", err)
	}
	bodyBytes, _ = io.ReadAll(resp.Body)
	resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200 OK, got %d body=%s", resp.StatusCode, string(bodyBytes))
	}
	trigger := resp.Header.Get("HX-Trigger")
	if trigger == "" {
		t.Fatalf("expected HX-Trigger header after saving profile")
	}
	var payload map[string]map[string]string
	if err := json.Unmarshal([]byte(trigger), &payload); err != nil {
		t.Fatalf("unmarshal HX-Trigger: %v", err)
	}
	event, ok := payload["account:profile:saved"]
	if !ok {
		t.Fatalf("expected account:profile:saved event, got %v", payload)
	}
	if msg := event["message"]; msg != "Profile updated" {
		t.Fatalf("expected localized message 'Profile updated', got %q", msg)
	}

	// Refetch form to confirm persisted values
	req, err = http.NewRequest(http.MethodGet, server.URL+"/account/profile/form", nil)
	if err != nil {
		t.Fatalf("new request: %v", err)
	}
	req.Header.Set("Accept-Language", "en")
	resp, err = client.Do(req)
	if err != nil {
		t.Fatalf("request failed: %v", err)
	}
	bodyBytes, _ = io.ReadAll(resp.Body)
	resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200 OK, got %d body=%s", resp.StatusCode, string(bodyBytes))
	}
	if !strings.Contains(string(bodyBytes), `value="Kaito Ito"`) {
		t.Fatalf("expected updated display name in refetched form")
	}
	if !strings.Contains(string(bodyBytes), `value="kaito.ito@example.com"`) {
		t.Fatalf("expected updated email in refetched form")
	}
}
