package httpserver_test

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/http/cookiejar"
	"net/url"
	"regexp"
	"strings"
	"testing"
	"time"

	"github.com/stretchr/testify/require"

	admindashboard "finitefield.org/hanko-admin/internal/admin/dashboard"
	"finitefield.org/hanko-admin/internal/admin/httpserver/middleware"
	"finitefield.org/hanko-admin/internal/admin/i18n"
	adminproduction "finitefield.org/hanko-admin/internal/admin/production"
	"finitefield.org/hanko-admin/internal/admin/profile"
	"finitefield.org/hanko-admin/internal/admin/templates/helpers"
	"finitefield.org/hanko-admin/internal/admin/testutil"
)

func TestDashboardRedirectsWithoutAuth(t *testing.T) {
	t.Parallel()

	ts := testutil.NewServer(t)

	client := noRedirectClient(t)

	resp, err := client.Get(ts.URL + "/admin")
	require.NoError(t, err)
	t.Cleanup(func() { resp.Body.Close() })

	require.Equal(t, http.StatusFound, resp.StatusCode)
	location := resp.Header.Get("Location")
	require.NotEmpty(t, location)
	loc, err := url.Parse(location)
	require.NoError(t, err)
	require.Equal(t, "/admin/login", loc.Path)
	q := loc.Query()
	require.Equal(t, middleware.ReasonMissingToken, q.Get("reason"))
	require.Equal(t, "/admin", q.Get("next"))
}

func TestDashboardRendersForAuthenticatedUser(t *testing.T) {
	t.Parallel()

	auth := &tokenAuthenticator{Token: "test-token"}
	now := time.Now()
	stub := &dashboardStub{
		kpis: []admindashboard.KPI{
			{ID: "revenue", Label: "日次売上", Value: "¥123,000", DeltaText: "+12%", Trend: admindashboard.TrendUp, Sparkline: []float64{120, 135, 140}, UpdatedAt: now},
		},
		alerts: []admindashboard.Alert{
			{ID: "inventory", Severity: "warning", Title: "在庫警告", Message: "SKU在庫が閾値を下回りました", ActionURL: "/admin/catalog/products", Action: "確認", CreatedAt: now.Add(-30 * time.Minute)},
		},
		activity: []admindashboard.ActivityItem{
			{ID: "order", Icon: "📦", Title: "注文 #1001 を出荷しました", Detail: "山田様", Occurred: now.Add(-10 * time.Minute)},
		},
	}

	ts := testutil.NewServer(t, testutil.WithAuthenticator(auth), testutil.WithDashboardService(stub))

	req, err := http.NewRequest(http.MethodGet, ts.URL+"/admin", nil)
	require.NoError(t, err)
	req.Header.Set("Authorization", "Bearer "+auth.Token)

	resp, err := http.DefaultClient.Do(req)
	require.NoError(t, err)
	defer resp.Body.Close()

	require.Equal(t, http.StatusOK, resp.StatusCode)

	body, err := io.ReadAll(resp.Body)
	require.NoError(t, err)

	doc := testutil.ParseHTML(t, body)

	pageLocale, _ := doc.Find("html").Attr("lang")
	localeCtx := i18n.ContextWithLocale(context.Background(), pageLocale)
	wantHeading := helpers.I18N(localeCtx, "admin.dashboard.title")
	wantTitle := wantHeading + " | Hanko Admin"
	require.Equal(t, wantTitle, doc.Find("title").First().Text())
	require.Equal(t, wantHeading, doc.Find("h1").First().Text())
	require.Greater(t, doc.Find("#dashboard-kpi article").Length(), 0, "dashboard should render KPI cards")
	require.Greater(t, doc.Find("#dashboard-alerts li").Length(), 0, "dashboard should render alerts list")
	require.Equal(t, 1, doc.Find("[data-dashboard-refresh]").Length(), "refresh control should be present")
	require.Contains(t, doc.Find("aside").Text(), "注文 #1001")
}

func TestDashboardKPIFragmentProvidesCards(t *testing.T) {
	t.Parallel()

	auth := &tokenAuthenticator{Token: "kpi-token"}
	now := time.Now()
	stub := &dashboardStub{
		kpis: []admindashboard.KPI{
			{ID: "orders", Label: "注文数", Value: "128", DeltaText: "+8件", Trend: admindashboard.TrendUp, Sparkline: []float64{10, 12, 15}, UpdatedAt: now},
		},
	}

	ts := testutil.NewServer(t, testutil.WithAuthenticator(auth), testutil.WithDashboardService(stub))

	req, err := http.NewRequest(http.MethodGet, ts.URL+"/admin/fragments/kpi?limit=1", nil)
	require.NoError(t, err)
	req.Header.Set("Authorization", "Bearer "+auth.Token)

	resp, err := http.DefaultClient.Do(req)
	require.NoError(t, err)
	defer resp.Body.Close()

	require.Equal(t, http.StatusOK, resp.StatusCode)
	body, err := io.ReadAll(resp.Body)
	require.NoError(t, err)

	doc := testutil.ParseHTML(t, body)
	require.Equal(t, 1, doc.Find("article").Length())
	require.Contains(t, doc.Text(), "注文数")
}

func TestDashboardKPIsHandlesServiceError(t *testing.T) {
	t.Parallel()

	auth := &tokenAuthenticator{Token: "kpi-error"}
	stub := &dashboardStub{kpiErr: errors.New("backend down")}

	ts := testutil.NewServer(t, testutil.WithAuthenticator(auth), testutil.WithDashboardService(stub))

	req, err := http.NewRequest(http.MethodGet, ts.URL+"/admin/fragments/kpi", nil)
	require.NoError(t, err)
	req.Header.Set("Authorization", "Bearer "+auth.Token)

	resp, err := http.DefaultClient.Do(req)
	require.NoError(t, err)
	defer resp.Body.Close()

	require.Equal(t, http.StatusOK, resp.StatusCode)
	body, err := io.ReadAll(resp.Body)
	require.NoError(t, err)

	require.Contains(t, string(body), "KPIの取得に失敗しました")
}

func TestDashboardAlertsFragmentProvidesList(t *testing.T) {
	t.Parallel()

	auth := &tokenAuthenticator{Token: "alert-token"}
	now := time.Now()
	stub := &dashboardStub{
		alerts: []admindashboard.Alert{
			{ID: "delay", Severity: "danger", Title: "配送遅延", Message: "2件が遅延中", ActionURL: "/admin/shipments/tracking", Action: "確認", CreatedAt: now},
		},
	}

	ts := testutil.NewServer(t, testutil.WithAuthenticator(auth), testutil.WithDashboardService(stub))

	req, err := http.NewRequest(http.MethodGet, ts.URL+"/admin/fragments/alerts", nil)
	require.NoError(t, err)
	req.Header.Set("Authorization", "Bearer "+auth.Token)

	resp, err := http.DefaultClient.Do(req)
	require.NoError(t, err)
	defer resp.Body.Close()
	require.Equal(t, http.StatusOK, resp.StatusCode)

	body, err := io.ReadAll(resp.Body)
	require.NoError(t, err)
	doc := testutil.ParseHTML(t, body)
	require.GreaterOrEqual(t, doc.Find("li").Length(), 1)
	require.Contains(t, doc.Text(), "配送遅延")
}

func TestDashboardAlertsHandlesServiceError(t *testing.T) {
	t.Parallel()

	auth := &tokenAuthenticator{Token: "alert-error"}
	stub := &dashboardStub{alertsErr: errors.New("timeout")}

	ts := testutil.NewServer(t, testutil.WithAuthenticator(auth), testutil.WithDashboardService(stub))

	req, err := http.NewRequest(http.MethodGet, ts.URL+"/admin/fragments/alerts", nil)
	require.NoError(t, err)
	req.Header.Set("Authorization", "Bearer "+auth.Token)

	resp, err := http.DefaultClient.Do(req)
	require.NoError(t, err)
	defer resp.Body.Close()
	require.Equal(t, http.StatusOK, resp.StatusCode)

	body, err := io.ReadAll(resp.Body)
	require.NoError(t, err)
	require.Contains(t, string(body), "アラートの取得に失敗しました")
}

func TestProfilePageRenders(t *testing.T) {
	t.Parallel()

	auth := &tokenAuthenticator{Token: "secure-token"}
	service := &profileStub{
		state: &profile.SecurityState{
			UserEmail: "staff@example.com",
			MFA:       profile.MFAState{Enabled: true},
			APIKeys: []profile.APIKey{
				{ID: "key-1", Label: "Automation", Status: profile.APIKeyStatusActive, CreatedAt: time.Now()},
			},
			Sessions: []profile.Session{
				{ID: "sess-1", UserAgent: "Chrome", IPAddress: "127.0.0.1", CreatedAt: time.Now(), LastSeenAt: time.Now(), Current: true},
			},
		},
	}

	ts := testutil.NewServer(t, testutil.WithAuthenticator(auth), testutil.WithProfileService(service))

	req, err := http.NewRequest(http.MethodGet, ts.URL+"/admin/profile", nil)
	require.NoError(t, err)
	req.Header.Set("Authorization", "Bearer "+auth.Token)

	resp, err := http.DefaultClient.Do(req)
	require.NoError(t, err)
	defer resp.Body.Close()

	require.Equal(t, http.StatusOK, resp.StatusCode)
	body, err := io.ReadAll(resp.Body)
	require.NoError(t, err)

	doc := testutil.ParseHTML(t, body)
	require.Contains(t, doc.Find("title").First().Text(), "admin.profile.title")
	require.Contains(t, doc.Find("body").Text(), "API キー")
}

func TestProfileTabsFragmentHTMX(t *testing.T) {
	t.Parallel()

	auth := &tokenAuthenticator{Token: "tab-token"}
	service := &profileStub{
		state: &profile.SecurityState{
			UserEmail: "staff@example.com",
			Sessions: []profile.Session{
				{ID: "sess-2", UserAgent: "Safari", IPAddress: "203.0.113.10", CreatedAt: time.Now(), LastSeenAt: time.Now(), Current: false},
			},
		},
	}

	ts := testutil.NewServer(t, testutil.WithAuthenticator(auth), testutil.WithProfileService(service))

	req, err := http.NewRequest(http.MethodGet, ts.URL+"/admin/profile?tab=sessions", nil)
	require.NoError(t, err)
	req.Header.Set("Authorization", "Bearer "+auth.Token)
	req.Header.Set("HX-Request", "true")
	req.Header.Set("HX-Target", "profile-tabs")

	resp, err := http.DefaultClient.Do(req)
	require.NoError(t, err)
	defer resp.Body.Close()

	require.Equal(t, http.StatusOK, resp.StatusCode)

	body, err := io.ReadAll(resp.Body)
	require.NoError(t, err)
	html := string(body)

	require.NotContains(t, html, "<html")
	require.Contains(t, html, `id="profile-tabs"`)
	require.Contains(t, html, "アクティブセッション")
}

func TestLoginSuccessFlow(t *testing.T) {
	t.Parallel()

	auth := &tokenAuthenticator{Token: "valid-token"}
	ts := testutil.NewServer(t, testutil.WithAuthenticator(auth))

	client := noRedirectClient(t)

	seedLoginCSRF(t, client, ts.URL+"/admin/login")
	csrf := findCSRFCookie(t, client.Jar, ts.URL+"/admin/login")
	require.NotEmpty(t, csrf)

	form := url.Values{}
	form.Set("email", "tester@example.com")
	form.Set("id_token", auth.Token)
	form.Set("remember", "1")
	form.Set("csrf_token", csrf)

	resp, err := client.PostForm(ts.URL+"/admin/login", form)
	require.NoError(t, err)
	resp.Body.Close()
	require.Equal(t, http.StatusSeeOther, resp.StatusCode)
	require.Equal(t, "/admin", resp.Header.Get("Location"))

	cookies := client.Jar.Cookies(mustParseURL(t, ts.URL+"/admin"))
	var authCookie *http.Cookie
	for _, c := range cookies {
		if c.Name == "Authorization" {
			authCookie = c
			break
		}
	}
	require.NotNil(t, authCookie)
	require.Equal(t, "Bearer "+auth.Token, authCookie.Value)

	resp, err = client.Get(ts.URL + "/admin")
	require.NoError(t, err)
	defer resp.Body.Close()
	require.Equal(t, http.StatusOK, resp.StatusCode)
}

func TestLoginHandlesInvalidToken(t *testing.T) {
	t.Parallel()

	auth := &tokenAuthenticator{Token: "expected-token"}
	ts := testutil.NewServer(t, testutil.WithAuthenticator(auth))

	client := noRedirectClient(t)
	seedLoginCSRF(t, client, ts.URL+"/admin/login")
	csrf := findCSRFCookie(t, client.Jar, ts.URL+"/admin/login")
	require.NotEmpty(t, csrf)

	form := url.Values{}
	form.Set("email", "tester@example.com")
	form.Set("id_token", "wrong-token")
	form.Set("csrf_token", csrf)

	resp, err := client.PostForm(ts.URL+"/admin/login", form)
	require.NoError(t, err)
	defer resp.Body.Close()
	require.Equal(t, http.StatusUnauthorized, resp.StatusCode)

	body, err := io.ReadAll(resp.Body)
	require.NoError(t, err)
	require.Contains(t, string(body), "認証に失敗しました")
}

func TestLogoutClearsSession(t *testing.T) {
	t.Parallel()

	auth := &tokenAuthenticator{Token: "logout-token"}
	ts := testutil.NewServer(t, testutil.WithAuthenticator(auth))

	client := noRedirectClient(t)
	seedLoginCSRF(t, client, ts.URL+"/admin/login")
	csrf := findCSRFCookie(t, client.Jar, ts.URL+"/admin/login")
	require.NotEmpty(t, csrf)

	form := url.Values{}
	form.Set("id_token", auth.Token)
	form.Set("csrf_token", csrf)

	resp, err := client.PostForm(ts.URL+"/admin/login", form)
	require.NoError(t, err)
	resp.Body.Close()
	require.Equal(t, http.StatusSeeOther, resp.StatusCode)

	resp, err = client.Get(ts.URL + "/admin/logout")
	require.NoError(t, err)
	resp.Body.Close()
	require.Equal(t, http.StatusSeeOther, resp.StatusCode)
	loc := resp.Header.Get("Location")
	require.NotEmpty(t, loc)
	mapped, err := url.Parse(loc)
	require.NoError(t, err)
	require.Equal(t, "/admin/login", mapped.Path)
	require.Equal(t, "logged_out", mapped.Query().Get("status"))

	resp, err = client.Get(ts.URL + "/admin")
	require.NoError(t, err)
	resp.Body.Close()
	require.Equal(t, http.StatusFound, resp.StatusCode)

	reloc, err := url.Parse(resp.Header.Get("Location"))
	require.NoError(t, err)
	require.Equal(t, "/admin/login", reloc.Path)
	require.Equal(t, middleware.ReasonMissingToken, reloc.Query().Get("reason"))
}

func TestLoginRejectsExternalNextParameter(t *testing.T) {
	t.Parallel()

	auth := &tokenAuthenticator{Token: "safe-token"}
	ts := testutil.NewServer(t, testutil.WithAuthenticator(auth))

	client := noRedirectClient(t)
	seedLoginCSRF(t, client, ts.URL+"/admin/login")
	csrf := findCSRFCookie(t, client.Jar, ts.URL+"/admin/login")
	require.NotEmpty(t, csrf)

	form := url.Values{}
	form.Set("id_token", auth.Token)
	form.Set("csrf_token", csrf)
	form.Set("next", "http://evil.example/phish")

	resp, err := client.PostForm(ts.URL+"/admin/login", form)
	require.NoError(t, err)
	resp.Body.Close()
	require.Equal(t, http.StatusSeeOther, resp.StatusCode)
	require.Equal(t, "/admin", resp.Header.Get("Location"))

	// Ensure encoded double slash is also rejected.
	form.Set("next", "%2f%2fevil.example/another")
	resp, err = client.PostForm(ts.URL+"/admin/login", form)
	require.NoError(t, err)
	resp.Body.Close()
	require.Equal(t, http.StatusSeeOther, resp.StatusCode)
	require.Equal(t, "/admin", resp.Header.Get("Location"))
}

func TestOrdersStatusUpdateFlow(t *testing.T) {
	t.Parallel()

	auth := &tokenAuthenticator{Token: "orders-token"}
	ts := testutil.NewServer(t, testutil.WithAuthenticator(auth))
	client := noRedirectClient(t)

	// Seed CSRF cookie by loading the orders page.
	req, err := http.NewRequest(http.MethodGet, ts.URL+"/admin/orders", nil)
	require.NoError(t, err)
	req.Header.Set("Authorization", "Bearer "+auth.Token)
	resp, err := client.Do(req)
	require.NoError(t, err)
	resp.Body.Close()
	require.Equal(t, http.StatusOK, resp.StatusCode)

	csrf := findCSRFCookie(t, client.Jar, ts.URL+"/admin")
	require.NotEmpty(t, csrf)

	// Fetch the status modal via htmx request.
	modalReq, err := http.NewRequest(http.MethodGet, ts.URL+"/admin/orders/order-1052/modal/status", nil)
	require.NoError(t, err)
	modalReq.Header.Set("Authorization", "Bearer "+auth.Token)
	modalReq.Header.Set("HX-Request", "true")
	modalReq.Header.Set("HX-Target", "modal")
	modalResp, err := client.Do(modalReq)
	require.NoError(t, err)
	body, err := io.ReadAll(modalResp.Body)
	modalResp.Body.Close()
	require.NoError(t, err)
	require.Equal(t, http.StatusOK, modalResp.StatusCode)
	modalHTML := string(body)
	require.Contains(t, modalHTML, `hx-put="/admin/orders/order-1052:status"`)

	// Submit the status update.
	form := url.Values{}
	form.Set("status", "ready_to_ship")
	form.Set("note", "包装確認済み")
	form.Set("notifyCustomer", "true")
	updateReq, err := http.NewRequest(http.MethodPut, ts.URL+"/admin/orders/order-1052:status", strings.NewReader(form.Encode()))
	require.NoError(t, err)
	updateReq.Header.Set("Authorization", "Bearer "+auth.Token)
	updateReq.Header.Set("HX-Request", "true")
	updateReq.Header.Set("HX-Target", "modal")
	updateReq.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	updateReq.Header.Set("X-CSRF-Token", csrf)
	updateResp, err := client.Do(updateReq)
	require.NoError(t, err)
	updateBody, err := io.ReadAll(updateResp.Body)
	updateResp.Body.Close()
	require.NoError(t, err)
	require.Equal(t, http.StatusOK, updateResp.StatusCode)
	require.Equal(t, `{"toast":{"message":"ステータスを更新しました。","tone":"success"},"modal:close":true}`, updateResp.Header.Get("HX-Trigger"))

	updateHTML := string(updateBody)
	require.Contains(t, updateHTML, "hx-swap-oob")
	require.Contains(t, updateHTML, "出荷待ち")
	require.Contains(t, updateHTML, "包装確認済み")
}

func TestOrdersManualCaptureFlow(t *testing.T) {
	t.Parallel()

	auth := &tokenAuthenticator{Token: "capture-token"}
	ts := testutil.NewServer(t, testutil.WithAuthenticator(auth))
	client := noRedirectClient(t)

	req, err := http.NewRequest(http.MethodGet, ts.URL+"/admin/orders", nil)
	require.NoError(t, err)
	req.Header.Set("Authorization", "Bearer "+auth.Token)
	resp, err := client.Do(req)
	require.NoError(t, err)
	resp.Body.Close()
	require.Equal(t, http.StatusOK, resp.StatusCode)

	csrf := findCSRFCookie(t, client.Jar, ts.URL+"/admin")
	require.NotEmpty(t, csrf)

	modalReq, err := http.NewRequest(http.MethodGet, ts.URL+"/admin/orders/order-1048/modal/manual-capture", nil)
	require.NoError(t, err)
	modalReq.Header.Set("Authorization", "Bearer "+auth.Token)
	modalReq.Header.Set("HX-Request", "true")
	modalReq.Header.Set("HX-Target", "modal")
	modalResp, err := client.Do(modalReq)
	require.NoError(t, err)
	modalBody, err := io.ReadAll(modalResp.Body)
	modalResp.Body.Close()
	require.NoError(t, err)
	require.Equal(t, http.StatusOK, modalResp.StatusCode)
	require.Contains(t, string(modalBody), `hx-post="/admin/orders/order-1048/payments:manual-capture"`)

	form := url.Values{}
	form.Set("paymentID", "pay-1048")
	form.Set("amount", "999999")
	form.Set("reason", "テスト売上確定")

	invalidReq, err := http.NewRequest(http.MethodPost, ts.URL+"/admin/orders/order-1048/payments:manual-capture", strings.NewReader(form.Encode()))
	require.NoError(t, err)
	invalidReq.Header.Set("Authorization", "Bearer "+auth.Token)
	invalidReq.Header.Set("HX-Request", "true")
	invalidReq.Header.Set("HX-Target", "modal")
	invalidReq.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	invalidReq.Header.Set("X-CSRF-Token", csrf)
	invalidResp, err := client.Do(invalidReq)
	require.NoError(t, err)
	invalidBody, err := io.ReadAll(invalidResp.Body)
	invalidResp.Body.Close()
	require.NoError(t, err)
	require.Equal(t, http.StatusUnprocessableEntity, invalidResp.StatusCode)
	require.Contains(t, string(invalidBody), "確定可能額を超えています。")

	form.Set("amount", "1000")

	validReq, err := http.NewRequest(http.MethodPost, ts.URL+"/admin/orders/order-1048/payments:manual-capture", strings.NewReader(form.Encode()))
	require.NoError(t, err)
	validReq.Header.Set("Authorization", "Bearer "+auth.Token)
	validReq.Header.Set("HX-Request", "true")
	validReq.Header.Set("HX-Target", "modal")
	validReq.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	validReq.Header.Set("X-CSRF-Token", csrf)
	validResp, err := client.Do(validReq)
	require.NoError(t, err)
	validBody, err := io.ReadAll(validResp.Body)
	validResp.Body.Close()
	require.NoError(t, err)
	require.Equal(t, http.StatusOK, validResp.StatusCode)
	require.Contains(t, string(validBody), "売上を確定しました")
	require.Contains(t, string(validBody), "PSP Raw Payload")
	require.Equal(t, `{"toast":{"message":"売上を確定しました。","tone":"success"},"refresh:fragment":{"targets":["[data-order-payments]","[data-order-summary]"]}}`, validResp.Header.Get("HX-Trigger"))
}

func TestOrdersRefundFlow(t *testing.T) {
	t.Parallel()

	auth := &tokenAuthenticator{Token: "refund-token"}
	ts := testutil.NewServer(t, testutil.WithAuthenticator(auth))
	client := noRedirectClient(t)

	// Seed CSRF cookie by loading the orders page.
	req, err := http.NewRequest(http.MethodGet, ts.URL+"/admin/orders", nil)
	require.NoError(t, err)
	req.Header.Set("Authorization", "Bearer "+auth.Token)
	resp, err := client.Do(req)
	require.NoError(t, err)
	resp.Body.Close()
	require.Equal(t, http.StatusOK, resp.StatusCode)

	csrf := findCSRFCookie(t, client.Jar, ts.URL+"/admin")
	require.NotEmpty(t, csrf)

	// Load the refund modal.
	modalReq, err := http.NewRequest(http.MethodGet, ts.URL+"/admin/orders/order-1052/modal/refund", nil)
	require.NoError(t, err)
	modalReq.Header.Set("Authorization", "Bearer "+auth.Token)
	modalReq.Header.Set("HX-Request", "true")
	modalReq.Header.Set("HX-Target", "modal")
	modalResp, err := client.Do(modalReq)
	require.NoError(t, err)
	modalBody, err := io.ReadAll(modalResp.Body)
	modalResp.Body.Close()
	require.NoError(t, err)
	require.Equal(t, http.StatusOK, modalResp.StatusCode)
	modalHTML := string(modalBody)
	require.Contains(t, modalHTML, `hx-post="/admin/orders/order-1052/payments:refund"`)

	// Submit an invalid refund that exceeds the available amount.
	form := url.Values{}
	form.Set("paymentID", "pay-1052")
	form.Set("amount", "4000000") // ¥4,000,000 > ¥3,200,000 available
	form.Set("reason", "テスト返金")
	form.Set("notifyCustomer", "true")

	invalidReq, err := http.NewRequest(http.MethodPost, ts.URL+"/admin/orders/order-1052/payments:refund", strings.NewReader(form.Encode()))
	require.NoError(t, err)
	invalidReq.Header.Set("Authorization", "Bearer "+auth.Token)
	invalidReq.Header.Set("HX-Request", "true")
	invalidReq.Header.Set("HX-Target", "modal")
	invalidReq.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	invalidReq.Header.Set("X-CSRF-Token", csrf)
	invalidResp, err := client.Do(invalidReq)
	require.NoError(t, err)
	invalidBody, err := io.ReadAll(invalidResp.Body)
	invalidResp.Body.Close()
	require.NoError(t, err)
	require.Equal(t, http.StatusUnprocessableEntity, invalidResp.StatusCode)
	require.Contains(t, string(invalidBody), "返金可能額を超えています。")

	// Submit a valid refund.
	form.Set("amount", "5000")
	validReq, err := http.NewRequest(http.MethodPost, ts.URL+"/admin/orders/order-1052/payments:refund", strings.NewReader(form.Encode()))
	require.NoError(t, err)
	validReq.Header.Set("Authorization", "Bearer "+auth.Token)
	validReq.Header.Set("HX-Request", "true")
	validReq.Header.Set("HX-Target", "modal")
	validReq.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	validReq.Header.Set("X-CSRF-Token", csrf)
	validResp, err := client.Do(validReq)
	require.NoError(t, err)
	validBody, err := io.ReadAll(validResp.Body)
	validResp.Body.Close()
	require.NoError(t, err)
	require.Equal(t, http.StatusNoContent, validResp.StatusCode)
	require.Empty(t, validBody)
	require.Equal(t, `{"toast":{"message":"返金を登録しました。","tone":"success"},"modal:close":true,"refresh:fragment":{"targets":["[data-order-payments]","[data-order-summary]"]}}`, validResp.Header.Get("HX-Trigger"))
}

func TestOrdersInvoiceIssueFlow(t *testing.T) {
	t.Parallel()

	auth := &tokenAuthenticator{Token: "invoice-token"}
	ts := testutil.NewServer(t, testutil.WithAuthenticator(auth))
	client := noRedirectClient(t)

	// Seed CSRF cookie.
	seedReq, err := http.NewRequest(http.MethodGet, ts.URL+"/admin/orders", nil)
	require.NoError(t, err)
	seedReq.Header.Set("Authorization", "Bearer "+auth.Token)
	seedResp, err := client.Do(seedReq)
	require.NoError(t, err)
	seedResp.Body.Close()
	require.Equal(t, http.StatusOK, seedResp.StatusCode)

	csrf := findCSRFCookie(t, client.Jar, ts.URL+"/admin")
	require.NotEmpty(t, csrf)

	// Load the invoice modal.
	modalReq, err := http.NewRequest(http.MethodGet, ts.URL+"/admin/orders/order-1052/modal/invoice", nil)
	require.NoError(t, err)
	modalReq.Header.Set("Authorization", "Bearer "+auth.Token)
	modalReq.Header.Set("HX-Request", "true")
	modalReq.Header.Set("HX-Target", "modal")
	modalResp, err := client.Do(modalReq)
	require.NoError(t, err)
	defer modalResp.Body.Close()
	require.Equal(t, http.StatusOK, modalResp.StatusCode)
	modalBody, err := io.ReadAll(modalResp.Body)
	require.NoError(t, err)
	require.Contains(t, string(modalBody), `hx-post="/admin/invoices:issue"`)

	// Submit invalid invoice request (invalid email).
	form := url.Values{}
	form.Set("orderID", "order-1052")
	form.Set("templateID", "invoice-standard")
	form.Set("language", "ja-JP")
	form.Set("email", "invalid-email")
	form.Set("note", "テスト領収書")

	invalidReq, err := http.NewRequest(http.MethodPost, ts.URL+"/admin/invoices:issue", strings.NewReader(form.Encode()))
	require.NoError(t, err)
	invalidReq.Header.Set("Authorization", "Bearer "+auth.Token)
	invalidReq.Header.Set("HX-Request", "true")
	invalidReq.Header.Set("HX-Target", "modal")
	invalidReq.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	invalidReq.Header.Set("X-CSRF-Token", csrf)
	invalidResp, err := client.Do(invalidReq)
	require.NoError(t, err)
	defer invalidResp.Body.Close()
	require.Equal(t, http.StatusUnprocessableEntity, invalidResp.StatusCode)
	invalidBody, err := io.ReadAll(invalidResp.Body)
	require.NoError(t, err)
	require.Contains(t, string(invalidBody), "メールアドレスの形式が正しくありません")

	// Submit valid invoice request (synchronous template).
	form.Set("email", "jun.hasegawa+new@example.com")
	validReq, err := http.NewRequest(http.MethodPost, ts.URL+"/admin/invoices:issue", strings.NewReader(form.Encode()))
	require.NoError(t, err)
	validReq.Header.Set("Authorization", "Bearer "+auth.Token)
	validReq.Header.Set("HX-Request", "true")
	validReq.Header.Set("HX-Target", "modal")
	validReq.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	validReq.Header.Set("X-CSRF-Token", csrf)
	validResp, err := client.Do(validReq)
	require.NoError(t, err)
	validResp.Body.Close()
	require.Equal(t, http.StatusNoContent, validResp.StatusCode)
	require.Equal(t, `{"toast":{"message":"領収書を発行しました。","tone":"success"},"modal:close":true,"refresh:fragment":{"targets":["[data-order-invoice]"]}}`, validResp.Header.Get("HX-Trigger"))

	// Load modal for asynchronous template.
	asyncModalReq, err := http.NewRequest(http.MethodGet, ts.URL+"/admin/orders/order-1050/modal/invoice", nil)
	require.NoError(t, err)
	asyncModalReq.Header.Set("Authorization", "Bearer "+auth.Token)
	asyncModalReq.Header.Set("HX-Request", "true")
	asyncModalReq.Header.Set("HX-Target", "modal")
	asyncModalResp, err := client.Do(asyncModalReq)
	require.NoError(t, err)
	defer asyncModalResp.Body.Close()
	require.Equal(t, http.StatusOK, asyncModalResp.StatusCode)

	// Submit asynchronous invoice request.
	asyncForm := url.Values{}
	asyncForm.Set("orderID", "order-1050")
	asyncForm.Set("templateID", "invoice-batch")
	asyncForm.Set("language", "ja-JP")
	asyncForm.Set("email", "maho.sato@example.com")
	asyncForm.Set("note", "バッチ請求書")

	asyncReq, err := http.NewRequest(http.MethodPost, ts.URL+"/admin/invoices:issue", strings.NewReader(asyncForm.Encode()))
	require.NoError(t, err)
	asyncReq.Header.Set("Authorization", "Bearer "+auth.Token)
	asyncReq.Header.Set("HX-Request", "true")
	asyncReq.Header.Set("HX-Target", "modal")
	asyncReq.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	asyncReq.Header.Set("X-CSRF-Token", csrf)
	asyncResp, err := client.Do(asyncReq)
	require.NoError(t, err)
	defer asyncResp.Body.Close()
	require.Equal(t, http.StatusOK, asyncResp.StatusCode)
	require.Equal(t, `{"toast":{"message":"領収書の生成を開始しました。","tone":"info"},"refresh:fragment":{"targets":["[data-order-invoice]"]}}`, asyncResp.Header.Get("HX-Trigger"))
	asyncBody, err := io.ReadAll(asyncResp.Body)
	require.NoError(t, err)
	require.Contains(t, string(asyncBody), "ジョブID")
	require.Contains(t, string(asyncBody), `data-invoice-job-status`)

	jobID := extractJobID(t, string(asyncBody))
	require.NotEmpty(t, jobID)

	// First poll should keep the job running.
	pollReq, err := http.NewRequest(http.MethodGet, ts.URL+"/admin/invoices/jobs/"+jobID, nil)
	require.NoError(t, err)
	pollReq.Header.Set("Authorization", "Bearer "+auth.Token)
	pollReq.Header.Set("HX-Request", "true")
	pollReq.Header.Set("HX-Target", "modal")
	pollResp, err := client.Do(pollReq)
	require.NoError(t, err)
	defer pollResp.Body.Close()
	require.Equal(t, http.StatusOK, pollResp.StatusCode)
	require.Empty(t, pollResp.Header.Get("HX-Trigger"))
	pollBody, err := io.ReadAll(pollResp.Body)
	require.NoError(t, err)
	require.Contains(t, string(pollBody), "現在のステータス")

	// Second poll should complete the job and close the modal.
	finalPollReq, err := http.NewRequest(http.MethodGet, ts.URL+"/admin/invoices/jobs/"+jobID, nil)
	require.NoError(t, err)
	finalPollReq.Header.Set("Authorization", "Bearer "+auth.Token)
	finalPollReq.Header.Set("HX-Request", "true")
	finalPollReq.Header.Set("HX-Target", "modal")
	finalPollResp, err := client.Do(finalPollReq)
	require.NoError(t, err)
	defer finalPollResp.Body.Close()
	require.Equal(t, http.StatusOK, finalPollResp.StatusCode)
	require.Equal(t, `{"toast":{"message":"領収書を発行しました。","tone":"success"},"modal:close":true,"refresh:fragment":{"targets":["[data-order-invoice]"]}}`, finalPollResp.Header.Get("HX-Trigger"))
}

func TestProductionQueuesPageRenders(t *testing.T) {
	t.Parallel()

	auth := &tokenAuthenticator{Token: "prod-board"}
	stub := &productionStub{boardResult: sampleBoardResult()}
	ts := testutil.NewServer(t, testutil.WithAuthenticator(auth), testutil.WithProductionService(stub))

	req, err := http.NewRequest(http.MethodGet, ts.URL+"/admin/production/queues", nil)
	require.NoError(t, err)
	req.Header.Set("Authorization", "Bearer "+auth.Token)

	resp, err := http.DefaultClient.Do(req)
	require.NoError(t, err)
	defer resp.Body.Close()

	require.Equal(t, http.StatusOK, resp.StatusCode)
	body, err := io.ReadAll(resp.Body)
	require.NoError(t, err)
	require.Contains(t, string(body), "青山アトリエ")
	require.Contains(t, string(body), "待機")
}

func TestProductionQueuesSummaryRenders(t *testing.T) {
	t.Parallel()

	auth := &tokenAuthenticator{Token: "prod-summary"}
	stub := &productionStub{summaryResult: sampleSummaryResult()}
	ts := testutil.NewServer(t, testutil.WithAuthenticator(auth), testutil.WithProductionService(stub))

	req, err := http.NewRequest(http.MethodGet, ts.URL+"/admin/production/queues/summary", nil)
	require.NoError(t, err)
	req.Header.Set("Authorization", "Bearer "+auth.Token)

	resp, err := http.DefaultClient.Do(req)
	require.NoError(t, err)
	defer resp.Body.Close()

	require.Equal(t, http.StatusOK, resp.StatusCode)
	body, err := io.ReadAll(resp.Body)
	require.NoError(t, err)
	require.Contains(t, string(body), "制作WIPサマリー")
	require.Contains(t, string(body), "ステージ別WIP")
}

func TestOrdersProductionEventSuccess(t *testing.T) {
	t.Parallel()

	auth := &tokenAuthenticator{Token: "prod-events"}
	stub := &productionStub{boardResult: sampleBoardResult()}
	ts := testutil.NewServer(t, testutil.WithAuthenticator(auth), testutil.WithProductionService(stub))
	client := noRedirectClient(t)

	seedReq, err := http.NewRequest(http.MethodGet, ts.URL+"/admin/production/queues", nil)
	require.NoError(t, err)
	seedReq.Header.Set("Authorization", "Bearer "+auth.Token)
	seedResp, err := client.Do(seedReq)
	require.NoError(t, err)
	seedResp.Body.Close()
	require.Equal(t, http.StatusOK, seedResp.StatusCode)

	csrf := findCSRFCookie(t, client.Jar, ts.URL+"/admin")
	require.NotEmpty(t, csrf)

	form := url.Values{}
	form.Set("type", "engraving")
	postReq, err := http.NewRequest(http.MethodPost, ts.URL+"/admin/orders/order-5000/production-events", strings.NewReader(form.Encode()))
	require.NoError(t, err)
	postReq.Header.Set("Authorization", "Bearer "+auth.Token)
	postReq.Header.Set("HX-Request", "true")
	postReq.Header.Set("HX-Target", "production-board")
	postReq.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	postReq.Header.Set("X-CSRF-Token", csrf)

	resp, err := client.Do(postReq)
	require.NoError(t, err)
	defer resp.Body.Close()
	require.Equal(t, http.StatusNoContent, resp.StatusCode)
	require.Contains(t, resp.Header.Get("HX-Trigger"), "制作ステージを更新しました。")

	require.Equal(t, "order-5000", stub.lastOrderID)
	require.Len(t, stub.appendCalls, 1)
	require.Equal(t, adminproduction.Stage("engraving"), stub.appendCalls[0].Stage)
}

func TestOrdersProductionEventHandlesErrors(t *testing.T) {
	t.Parallel()

	auth := &tokenAuthenticator{Token: "prod-events-error"}
	stub := &productionStub{boardResult: sampleBoardResult(), appendErr: adminproduction.ErrStageInvalid}
	ts := testutil.NewServer(t, testutil.WithAuthenticator(auth), testutil.WithProductionService(stub))
	client := noRedirectClient(t)

	seedReq, err := http.NewRequest(http.MethodGet, ts.URL+"/admin/production/queues", nil)
	require.NoError(t, err)
	seedReq.Header.Set("Authorization", "Bearer "+auth.Token)
	seedResp, err := client.Do(seedReq)
	require.NoError(t, err)
	seedResp.Body.Close()
	require.Equal(t, http.StatusOK, seedResp.StatusCode)
	csrf := findCSRFCookie(t, client.Jar, ts.URL+"/admin")
	require.NotEmpty(t, csrf)

	form := url.Values{}
	form.Set("type", "invalid-stage")
	postReq, err := http.NewRequest(http.MethodPost, ts.URL+"/admin/orders/order-5000/production-events", strings.NewReader(form.Encode()))
	require.NoError(t, err)
	postReq.Header.Set("Authorization", "Bearer "+auth.Token)
	postReq.Header.Set("HX-Request", "true")
	postReq.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	postReq.Header.Set("X-CSRF-Token", csrf)

	resp, err := client.Do(postReq)
	require.NoError(t, err)
	defer resp.Body.Close()
	require.Equal(t, http.StatusBadRequest, resp.StatusCode)
	body, err := io.ReadAll(resp.Body)
	require.NoError(t, err)
	require.Contains(t, string(body), "指定されたステージに移動できません")
}

func TestShipmentsLabelGenerationFlow(t *testing.T) {
	t.Parallel()

	auth := &tokenAuthenticator{Token: "shipments-token"}
	ts := testutil.NewServer(t, testutil.WithAuthenticator(auth))
	client := noRedirectClient(t)

	seedReq, err := http.NewRequest(http.MethodGet, ts.URL+"/admin/shipments/batches", nil)
	require.NoError(t, err)
	seedReq.Header.Set("Authorization", "Bearer "+auth.Token)
	seedResp, err := client.Do(seedReq)
	require.NoError(t, err)
	seedResp.Body.Close()
	require.Equal(t, http.StatusOK, seedResp.StatusCode)

	csrf := findCSRFCookie(t, client.Jar, ts.URL+"/admin")
	require.NotEmpty(t, csrf)

	regenForm := url.Values{}
	regenForm.Set("batchID", "batch-2304")
	regenReq, err := http.NewRequest(http.MethodPost, ts.URL+"/admin/shipments/batches/regenerate", strings.NewReader(regenForm.Encode()))
	require.NoError(t, err)
	regenReq.Header.Set("Authorization", "Bearer "+auth.Token)
	regenReq.Header.Set("HX-Request", "true")
	regenReq.Header.Set("HX-Target", "shipments-batches")
	regenReq.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	regenReq.Header.Set("X-CSRF-Token", csrf)

	regenResp, err := client.Do(regenReq)
	require.NoError(t, err)
	regenResp.Body.Close()
	require.Equal(t, http.StatusNoContent, regenResp.StatusCode)
	require.Equal(t, `{"toast":{"message":"バッチ batch-2304 のラベル再生成を開始しました。","tone":"success"}}`, regenResp.Header.Get("HX-Trigger"))
	require.Equal(t, `{"shipments:select":{"id":"batch-2304"}}`, regenResp.Header.Get("HX-Trigger-After-Swap"))

	orderReq, err := http.NewRequest(http.MethodPost, ts.URL+"/admin/orders/order-1052/shipments", strings.NewReader(""))
	require.NoError(t, err)
	orderReq.Header.Set("Authorization", "Bearer "+auth.Token)
	orderReq.Header.Set("HX-Request", "true")
	orderReq.Header.Set("HX-Target", "orders-table")
	orderReq.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	orderReq.Header.Set("X-CSRF-Token", csrf)

	orderResp, err := client.Do(orderReq)
	require.NoError(t, err)
	orderResp.Body.Close()
	require.Equal(t, http.StatusNoContent, orderResp.StatusCode)
	require.Equal(t, `{"toast":{"message":"注文 order-1052 の出荷ラベル生成をキューに投入しました。","tone":"info"}}`, orderResp.Header.Get("HX-Trigger"))
}

func TestPromotionsCreationFlow(t *testing.T) {
	t.Parallel()

	auth := &tokenAuthenticator{Token: "promotions-token"}
	ts := testutil.NewServer(t, testutil.WithAuthenticator(auth))
	client := noRedirectClient(t)

	pageReq, err := http.NewRequest(http.MethodGet, ts.URL+"/admin/promotions", nil)
	require.NoError(t, err)
	pageReq.Header.Set("Authorization", "Bearer "+auth.Token)
	pageResp, err := client.Do(pageReq)
	require.NoError(t, err)
	pageResp.Body.Close()
	require.Equal(t, http.StatusOK, pageResp.StatusCode)

	csrf := findCSRFCookie(t, client.Jar, ts.URL+"/admin")
	require.NotEmpty(t, csrf)

	now := time.Now().In(time.Local)
	startDate := now.Format("2006-01-02")
	startTime := now.Format("15:04")

	form := url.Values{}
	form.Set("name", "深夜フラッシュセール")
	form.Set("description", "短時間の高コンバージョン施策")
	form.Set("code", "NIGHTFLASH25")
	form.Set("status", "active")
	form.Set("type", "percentage")
	form.Add("channels", "online_store")
	form.Add("channels", "app")
	form.Set("segment", "vip_retention")
	form.Set("percentage", "25")
	form.Set("startDate", startDate)
	form.Set("startTime", startTime)
	form.Set("usageLimit", "500")
	form.Set("perCustomerLimit", "1")

	createReq, err := http.NewRequest(http.MethodPost, ts.URL+"/admin/promotions", strings.NewReader(form.Encode()))
	require.NoError(t, err)
	createReq.Header.Set("Authorization", "Bearer "+auth.Token)
	createReq.Header.Set("HX-Request", "true")
	createReq.Header.Set("HX-Target", "modal")
	createReq.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	createReq.Header.Set("X-CSRF-Token", csrf)

	createResp, err := client.Do(createReq)
	require.NoError(t, err)
	createResp.Body.Close()
	require.Equal(t, http.StatusNoContent, createResp.StatusCode)

	triggerRaw := createResp.Header.Get("HX-Trigger")
	require.NotEmpty(t, triggerRaw)

	var triggerPayload map[string]any
	require.NoError(t, json.Unmarshal([]byte(triggerRaw), &triggerPayload))

	toast, ok := triggerPayload["toast"].(map[string]any)
	require.True(t, ok)
	require.Equal(t, "プロモーション「深夜フラッシュセール」を作成しました。", toast["message"])
	require.Equal(t, "success", toast["tone"])

	modalClose, ok := triggerPayload["modal:close"].(bool)
	require.True(t, ok)
	require.True(t, modalClose)

	selectPayload, ok := triggerPayload["promotions:select"].(map[string]any)
	require.True(t, ok)
	selectedID, _ := selectPayload["id"].(string)
	require.NotEmpty(t, selectedID)
	require.True(t, strings.HasPrefix(selectedID, "promo-generated-"))

	tableReq, err := http.NewRequest(http.MethodGet, ts.URL+"/admin/promotions/table?selected="+url.QueryEscape(selectedID), nil)
	require.NoError(t, err)
	tableReq.Header.Set("Authorization", "Bearer "+auth.Token)
	tableReq.Header.Set("HX-Request", "true")
	tableReq.Header.Set("HX-Target", "promotions-table")
	tableResp, err := client.Do(tableReq)
	require.NoError(t, err)
	defer tableResp.Body.Close()
	require.Equal(t, http.StatusOK, tableResp.StatusCode)

	tableBody, err := io.ReadAll(tableResp.Body)
	require.NoError(t, err)
	doc := testutil.ParseHTML(t, tableBody)
	row := doc.Find(`tr[data-promotion-id="` + selectedID + `"]`)
	require.Equal(t, 1, row.Length())
	require.Contains(t, row.Text(), "深夜フラッシュセール")
	require.Contains(t, row.Text(), "NIGHTFLASH25")
}

func TestReviewsModerationFlow(t *testing.T) {
	t.Parallel()

	auth := &tokenAuthenticator{Token: "reviews-token"}
	ts := testutil.NewServer(t, testutil.WithAuthenticator(auth))
	client := noRedirectClient(t)

	pageURL := ts.URL + "/admin/reviews?moderation=pending"
	pageReq, err := http.NewRequest(http.MethodGet, pageURL, nil)
	require.NoError(t, err)
	pageReq.Header.Set("Authorization", "Bearer "+auth.Token)
	pageResp, err := client.Do(pageReq)
	require.NoError(t, err)
	pageResp.Body.Close()
	require.Equal(t, http.StatusOK, pageResp.StatusCode)

	csrf := findCSRFCookie(t, client.Jar, ts.URL+"/admin")
	require.NotEmpty(t, csrf)

	reviewID := "rvw-pending-1043"
	form := url.Values{}
	form.Set("decision", "approve")
	form.Set("notes", "ブランドトーンを満たしているため公開します。")
	form.Set("notifyCustomer", "true")
	form.Set("selected", reviewID)

	moderateReq, err := http.NewRequest(http.MethodPut, ts.URL+"/admin/reviews/"+reviewID+":moderate", strings.NewReader(form.Encode()))
	require.NoError(t, err)
	moderateReq.Header.Set("Authorization", "Bearer "+auth.Token)
	moderateReq.Header.Set("HX-Request", "true")
	moderateReq.Header.Set("HX-Target", "modal")
	moderateReq.Header.Set("HX-Current-URL", pageURL)
	moderateReq.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	moderateReq.Header.Set("X-CSRF-Token", csrf)

	moderateResp, err := client.Do(moderateReq)
	require.NoError(t, err)
	defer moderateResp.Body.Close()
	require.Equal(t, http.StatusOK, moderateResp.StatusCode)
	require.Equal(t, `{"toast":{"message":"レビューを承認しました。","tone":"success"},"modal:close":true}`, moderateResp.Header.Get("HX-Trigger"))

	body, err := io.ReadAll(moderateResp.Body)
	require.NoError(t, err)
	doc := testutil.ParseHTML(t, body)

	table := doc.Find("#reviews-table")
	require.Equal(t, 1, table.Length())
	swapAttr, exists := table.Attr("hx-swap-oob")
	require.True(t, exists)
	require.Equal(t, "true", swapAttr)

	approvedReq, err := http.NewRequest(http.MethodGet, ts.URL+"/admin/reviews?moderation=approved", nil)
	require.NoError(t, err)
	approvedReq.Header.Set("Authorization", "Bearer "+auth.Token)
	approvedResp, err := client.Do(approvedReq)
	require.NoError(t, err)
	defer approvedResp.Body.Close()
	require.Equal(t, http.StatusOK, approvedResp.StatusCode)

	approvedBody, err := io.ReadAll(approvedResp.Body)
	require.NoError(t, err)
	require.Contains(t, string(approvedBody), "最高の仕上がりでした")
	require.Contains(t, string(approvedBody), "公開済み")
}

func sampleBoardResult() adminproduction.BoardResult {
	now := time.Now()
	return adminproduction.BoardResult{
		Queue: adminproduction.Queue{
			ID:            "atelier-aoyama",
			Name:          "青山アトリエ",
			Capacity:      10,
			Load:          5,
			LeadTimeHours: 24,
		},
		Queues: []adminproduction.QueueOption{{ID: "atelier-aoyama", Label: "青山アトリエ", Active: true}},
		Summary: adminproduction.Summary{
			TotalWIP:     1,
			DueSoon:      1,
			Blocked:      0,
			AvgLeadHours: 24,
			Utilisation:  50,
			UpdatedAt:    now,
		},
		Filters: adminproduction.FilterSummary{},
		Lanes: []adminproduction.Lane{
			{
				Stage:    adminproduction.StageQueued,
				Label:    "待機",
				Capacity: adminproduction.LaneCapacity{Used: 1, Limit: 6},
				SLA:      adminproduction.SLAMeta{Label: "平均6h", Tone: "info"},
				Cards: []adminproduction.Card{
					{
						ID:            "order-5000",
						OrderNumber:   "5000",
						Stage:         adminproduction.StageQueued,
						Priority:      adminproduction.PriorityRush,
						PriorityLabel: "特急",
						PriorityTone:  "warning",
						Customer:      "テスト 顧客",
						ProductLine:   "Classic",
						Design:        "テストリング",
						PreviewURL:    "/public/static/previews/ring-classic.png",
						QueueID:       "atelier-aoyama",
						QueueName:     "青山アトリエ",
						DueAt:         now.Add(6 * time.Hour),
						DueLabel:      "残り6時間",
					},
				},
			},
		},
		Drawer:          adminproduction.Drawer{Empty: true},
		SelectedCardID:  "order-5000",
		GeneratedAt:     now,
		RefreshInterval: 30 * time.Second,
	}
}

func sampleSummaryResult() adminproduction.QueueWIPSummaryResult {
	now := time.Now()
	totals := adminproduction.QueueWIPSummaryTotals{
		TotalWIP:      6,
		TotalCapacity: 46,
		Utilisation:   13,
		SLABreaches:   1,
		DueSoon:       2,
	}

	cards := []adminproduction.QueueWIPSummaryCard{
		{
			QueueID:     "atelier-aoyama",
			QueueName:   "青山アトリエ",
			Facility:    "青山工房",
			Shift:       "08:00-22:00",
			QueueType:   "Classic / Brilliant",
			WIPCount:    4,
			Capacity:    28,
			Utilisation: 14,
			SLABreaches: 1,
			DueSoon:     1,
		},
		{
			QueueID:     "atelier-kyoto",
			QueueName:   "京都スタジオ",
			Facility:    "京都工房",
			Shift:       "09:00-19:00",
			QueueType:   "Heritage / Monogram",
			WIPCount:    2,
			Capacity:    18,
			Utilisation: 11,
			SLABreaches: 0,
			DueSoon:     1,
		},
	}

	trend := adminproduction.QueueWIPSummaryTrend{
		Caption: "対象キュー: 2",
		Bars: []adminproduction.QueueWIPTrendBar{
			{Stage: adminproduction.StageQueued, Label: "待機", Count: 2, Capacity: 20, SLALabel: "平均6h", SLATone: "info"},
			{Stage: adminproduction.StageEngraving, Label: "刻印", Count: 1, Capacity: 16, SLALabel: "平均9h", SLATone: "info"},
			{Stage: adminproduction.StagePolishing, Label: "研磨", Count: 2, Capacity: 14, SLALabel: "平均5h", SLATone: "warning"},
			{Stage: adminproduction.StageQC, Label: "QC", Count: 1, Capacity: 10, SLALabel: "平均3h", SLATone: "success"},
		},
	}

	stageColumns := []adminproduction.QueueWIPStageColumn{
		{Stage: adminproduction.StageQueued, Label: "待機"},
		{Stage: adminproduction.StageEngraving, Label: "刻印"},
		{Stage: adminproduction.StagePolishing, Label: "研磨"},
		{Stage: adminproduction.StageQC, Label: "QC"},
		{Stage: adminproduction.StagePacked, Label: "梱包"},
	}

	table := adminproduction.QueueWIPSummaryTable{
		StageColumns: stageColumns,
		Rows: []adminproduction.QueueWIPSummaryRow{
			{
				QueueID:         "atelier-aoyama",
				QueueName:       "青山アトリエ",
				Facility:        "青山工房",
				Shift:           "08:00-22:00",
				QueueType:       "Classic / Brilliant",
				WIPCount:        4,
				Capacity:        28,
				Utilisation:     14,
				SLABreaches:     1,
				AverageAgeHours: 26,
				StageBreakdown: []adminproduction.QueueWIPStageBreakdown{
					{Stage: adminproduction.StageQueued, Label: "待機", Count: 2, Capacity: 10},
					{Stage: adminproduction.StageEngraving, Label: "刻印", Count: 1, Capacity: 8},
					{Stage: adminproduction.StagePolishing, Label: "研磨", Count: 1, Capacity: 6},
					{Stage: adminproduction.StageQC, Label: "QC", Count: 0, Capacity: 4},
					{Stage: adminproduction.StagePacked, Label: "梱包", Count: 0, Capacity: 4},
				},
				LinkPath: "/production/queues?queue=atelier-aoyama",
			},
			{
				QueueID:         "atelier-kyoto",
				QueueName:       "京都スタジオ",
				Facility:        "京都工房",
				Shift:           "09:00-19:00",
				QueueType:       "Heritage / Monogram",
				WIPCount:        2,
				Capacity:        18,
				Utilisation:     11,
				SLABreaches:     0,
				AverageAgeHours: 18,
				StageBreakdown: []adminproduction.QueueWIPStageBreakdown{
					{Stage: adminproduction.StageQueued, Label: "待機", Count: 0, Capacity: 8},
					{Stage: adminproduction.StageEngraving, Label: "刻印", Count: 0, Capacity: 6},
					{Stage: adminproduction.StagePolishing, Label: "研磨", Count: 1, Capacity: 4},
					{Stage: adminproduction.StageQC, Label: "QC", Count: 1, Capacity: 3},
					{Stage: adminproduction.StagePacked, Label: "梱包", Count: 0, Capacity: 3},
				},
				LinkPath: "/production/queues?queue=atelier-kyoto",
			},
		},
		Totals:       totals,
		EmptyMessage: "該当するキューがありません。",
	}

	filters := adminproduction.QueueWIPSummaryFilters{
		Facilities: []adminproduction.FilterOption{
			{Value: "青山工房", Label: "青山工房", Count: 4},
			{Value: "京都工房", Label: "京都工房", Count: 2},
		},
		Shifts: []adminproduction.FilterOption{
			{Value: "08:00-22:00", Label: "08:00-22:00", Count: 4},
			{Value: "09:00-19:00", Label: "09:00-19:00", Count: 2},
		},
		QueueTypes: []adminproduction.FilterOption{
			{Value: "Classic / Brilliant", Label: "Classic / Brilliant", Count: 4},
			{Value: "Heritage / Monogram", Label: "Heritage / Monogram", Count: 2},
		},
		DateRanges: []adminproduction.FilterOption{
			{Value: "", Label: "全期間", Active: true},
			{Value: "7d", Label: "過去7日間"},
		},
	}

	alerts := []adminproduction.QueueWIPSummaryAlert{
		{
			Tone:        "warning",
			Title:       "青山アトリエ の稼働状況",
			Message:     "使用率 14% / SLA逸脱 1件 / 締切迫る 1件",
			ActionLabel: "キューを確認",
			ActionPath:  "/production/queues?queue=atelier-aoyama",
		},
	}

	return adminproduction.QueueWIPSummaryResult{
		GeneratedAt:     now,
		RefreshInterval: 45 * time.Second,
		Totals:          totals,
		Cards:           cards,
		Trend:           trend,
		Table:           table,
		Filters:         filters,
		Alerts:          alerts,
	}
}

type productionStub struct {
	boardResult      adminproduction.BoardResult
	boardErr         error
	summaryResult    adminproduction.QueueWIPSummaryResult
	summaryErr       error
	appendResult     adminproduction.AppendEventResult
	appendErr        error
	lastOrderID      string
	appendCalls      []adminproduction.AppendEventRequest
	workOrder        adminproduction.WorkOrder
	workErr          error
	qcResult         adminproduction.QCResult
	qcErr            error
	qcDecision       adminproduction.QCDecisionResult
	qcDecisionErr    error
	qcRework         adminproduction.QCReworkResult
	qcReworkErr      error
	queueSettings    adminproduction.QueueSettingsResult
	queueSettingsErr error
	queueDetail      adminproduction.QueueDefinition
	queueDetailErr   error
	queueOptions     adminproduction.QueueSettingsOptions
	queueOptionsErr  error
	createdQueue     adminproduction.QueueDefinition
	createQueueErr   error
	updatedQueue     adminproduction.QueueDefinition
	updateQueueErr   error
	deleteQueueErr   error
}

func (s *productionStub) Board(ctx context.Context, token string, query adminproduction.BoardQuery) (adminproduction.BoardResult, error) {
	if s.boardErr != nil {
		return adminproduction.BoardResult{}, s.boardErr
	}
	return s.boardResult, nil
}

func (s *productionStub) QueueWIPSummary(ctx context.Context, token string, query adminproduction.QueueWIPSummaryQuery) (adminproduction.QueueWIPSummaryResult, error) {
	if s.summaryErr != nil {
		return adminproduction.QueueWIPSummaryResult{}, s.summaryErr
	}
	return s.summaryResult, nil
}

func (s *productionStub) AppendEvent(ctx context.Context, token, orderID string, req adminproduction.AppendEventRequest) (adminproduction.AppendEventResult, error) {
	s.lastOrderID = orderID
	s.appendCalls = append(s.appendCalls, req)
	if s.appendErr != nil {
		return adminproduction.AppendEventResult{}, s.appendErr
	}
	res := s.appendResult
	if res.Card.ID == "" {
		res.Card.ID = orderID
	}
	return res, nil
}

func (s *productionStub) WorkOrder(ctx context.Context, token, orderID string) (adminproduction.WorkOrder, error) {
	if s.workErr != nil {
		return adminproduction.WorkOrder{}, s.workErr
	}
	if s.workOrder.Card.ID != "" {
		work := s.workOrder
		if work.Card.ID == "" {
			work.Card.ID = orderID
		}
		return work, nil
	}
	if len(s.boardResult.Lanes) > 0 {
		for _, lane := range s.boardResult.Lanes {
			if len(lane.Cards) > 0 {
				return adminproduction.WorkOrder{
					Card: lane.Cards[0],
				}, nil
			}
		}
	}
	return adminproduction.WorkOrder{
		Card: adminproduction.Card{
			ID:          orderID,
			OrderNumber: orderID,
			Customer:    "テスト顧客",
		},
	}, nil
}

func (s *productionStub) QCOverview(ctx context.Context, token string, query adminproduction.QCQuery) (adminproduction.QCResult, error) {
	if s.qcErr != nil {
		return adminproduction.QCResult{}, s.qcErr
	}
	return s.qcResult, nil
}

func (s *productionStub) RecordQCDecision(ctx context.Context, token, orderID string, req adminproduction.QCDecisionRequest) (adminproduction.QCDecisionResult, error) {
	if s.qcDecisionErr != nil {
		return adminproduction.QCDecisionResult{}, s.qcDecisionErr
	}
	result := s.qcDecision
	if result.Item.ID == "" {
		result.Item.ID = orderID
	}
	return result, nil
}

func (s *productionStub) TriggerRework(ctx context.Context, token, orderID string, req adminproduction.QCReworkRequest) (adminproduction.QCReworkResult, error) {
	if s.qcReworkErr != nil {
		return adminproduction.QCReworkResult{}, s.qcReworkErr
	}
	result := s.qcRework
	if result.Item.ID == "" {
		result.Item.ID = orderID
	}
	return result, nil
}

func (s *productionStub) QueueSettings(ctx context.Context, token string, query adminproduction.QueueSettingsQuery) (adminproduction.QueueSettingsResult, error) {
	if s.queueSettingsErr != nil {
		return adminproduction.QueueSettingsResult{}, s.queueSettingsErr
	}
	return s.queueSettings, nil
}

func (s *productionStub) QueueSettingsDetail(ctx context.Context, token, queueID string) (adminproduction.QueueDefinition, error) {
	if s.queueDetailErr != nil {
		return adminproduction.QueueDefinition{}, s.queueDetailErr
	}
	if s.queueDetail.ID == "" {
		return adminproduction.QueueDefinition{ID: queueID, Name: "Stub Queue"}, nil
	}
	return s.queueDetail, nil
}

func (s *productionStub) QueueSettingsOptions(ctx context.Context, token string) (adminproduction.QueueSettingsOptions, error) {
	if s.queueOptionsErr != nil {
		return adminproduction.QueueSettingsOptions{}, s.queueOptionsErr
	}
	return s.queueOptions, nil
}

func (s *productionStub) CreateQueueDefinition(ctx context.Context, token string, input adminproduction.QueueDefinitionInput) (adminproduction.QueueDefinition, error) {
	if s.createQueueErr != nil {
		return adminproduction.QueueDefinition{}, s.createQueueErr
	}
	if s.createdQueue.ID == "" {
		return adminproduction.QueueDefinition{ID: "new-queue", Name: input.Name}, nil
	}
	return s.createdQueue, nil
}

func (s *productionStub) UpdateQueueDefinition(ctx context.Context, token, queueID string, input adminproduction.QueueDefinitionInput) (adminproduction.QueueDefinition, error) {
	if s.updateQueueErr != nil {
		return adminproduction.QueueDefinition{}, s.updateQueueErr
	}
	if s.updatedQueue.ID == "" {
		return adminproduction.QueueDefinition{ID: queueID, Name: input.Name}, nil
	}
	return s.updatedQueue, nil
}

func (s *productionStub) DeleteQueueDefinition(ctx context.Context, token, queueID string) error {
	return s.deleteQueueErr
}

type dashboardStub struct {
	kpis        []admindashboard.KPI
	alerts      []admindashboard.Alert
	activity    []admindashboard.ActivityItem
	kpiErr      error
	alertsErr   error
	activityErr error
}

func (s *dashboardStub) FetchKPIs(ctx context.Context, token string, since *time.Time) ([]admindashboard.KPI, error) {
	if s.kpiErr != nil {
		return nil, s.kpiErr
	}
	if since != nil {
		filtered := make([]admindashboard.KPI, 0, len(s.kpis))
		for _, k := range s.kpis {
			if k.UpdatedAt.After(*since) || k.UpdatedAt.Equal(*since) {
				filtered = append(filtered, k)
			}
		}
		return append([]admindashboard.KPI(nil), filtered...), nil
	}
	return append([]admindashboard.KPI(nil), s.kpis...), nil
}

func (s *dashboardStub) FetchAlerts(ctx context.Context, token string, limit int) ([]admindashboard.Alert, error) {
	if s.alertsErr != nil {
		return nil, s.alertsErr
	}
	alerts := append([]admindashboard.Alert(nil), s.alerts...)
	if limit > 0 && len(alerts) > limit {
		alerts = alerts[:limit]
	}
	return alerts, nil
}

func (s *dashboardStub) FetchActivity(ctx context.Context, token string, limit int) ([]admindashboard.ActivityItem, error) {
	if s.activityErr != nil {
		return nil, s.activityErr
	}
	items := append([]admindashboard.ActivityItem(nil), s.activity...)
	if limit > 0 && len(items) > limit {
		items = items[:limit]
	}
	return items, nil
}

type profileStub struct {
	state      *profile.SecurityState
	enrollment *profile.TOTPEnrollment
	secret     *profile.APIKeySecret
}

func (s *profileStub) SecurityOverview(ctx context.Context, token string) (*profile.SecurityState, error) {
	return s.state, nil
}

func (s *profileStub) StartTOTPEnrollment(ctx context.Context, token string) (*profile.TOTPEnrollment, error) {
	if s.enrollment != nil {
		return s.enrollment, nil
	}
	return &profile.TOTPEnrollment{Secret: "SECRET"}, nil
}

func (s *profileStub) ConfirmTOTPEnrollment(ctx context.Context, token, code string) (*profile.SecurityState, error) {
	return s.state, nil
}

func (s *profileStub) EnableEmailMFA(ctx context.Context, token string) (*profile.SecurityState, error) {
	return s.state, nil
}

func (s *profileStub) DisableMFA(ctx context.Context, token string) (*profile.SecurityState, error) {
	return s.state, nil
}

func (s *profileStub) CreateAPIKey(ctx context.Context, token string, req profile.CreateAPIKeyRequest) (*profile.APIKeySecret, error) {
	if s.secret != nil {
		return s.secret, nil
	}
	return &profile.APIKeySecret{ID: "key-2", Label: req.Label, Secret: "secret"}, nil
}

func (s *profileStub) RevokeAPIKey(ctx context.Context, token, keyID string) (*profile.SecurityState, error) {
	return s.state, nil
}

func (s *profileStub) RevokeSession(ctx context.Context, token, sessionID string) (*profile.SecurityState, error) {
	return s.state, nil
}

type tokenAuthenticator struct {
	Token string
}

func (t *tokenAuthenticator) Authenticate(_ *http.Request, token string) (*middleware.User, error) {
	if token != t.Token {
		return nil, middleware.ErrUnauthorized
	}
	return &middleware.User{
		UID:   "tester",
		Email: "tester@example.com",
		Token: token,
		Roles: []string{"admin"},
	}, nil
}

func noRedirectClient(t testing.TB) *http.Client {
	jar, err := cookiejar.New(nil)
	require.NoError(t, err)
	client := &http.Client{
		Jar: jar,
		CheckRedirect: func(req *http.Request, via []*http.Request) error {
			return http.ErrUseLastResponse
		},
	}
	t.Cleanup(func() {
		client.CloseIdleConnections()
	})
	return client
}

func seedLoginCSRF(t testing.TB, client *http.Client, loginURL string) {
	resp, err := client.Get(loginURL)
	require.NoError(t, err)
	defer resp.Body.Close()
	require.Equal(t, http.StatusOK, resp.StatusCode)
	_, err = io.ReadAll(resp.Body)
	require.NoError(t, err)
}

func findCSRFCookie(t testing.TB, jar http.CookieJar, rawURL string) string {
	u := mustParseURL(t, rawURL)
	cookies := jar.Cookies(u)
	for _, c := range cookies {
		if c.Name == "csrf_token" {
			return c.Value
		}
	}
	return ""
}

func extractJobID(t testing.TB, body string) string {
	t.Helper()
	re := regexp.MustCompile(`job-[A-Za-z0-9\-]+`)
	match := re.FindString(body)
	return strings.TrimSpace(match)
}

func mustParseURL(t testing.TB, raw string) *url.URL {
	u, err := url.Parse(raw)
	require.NoError(t, err)
	return u
}
