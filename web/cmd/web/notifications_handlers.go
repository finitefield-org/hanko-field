package main

import (
	"fmt"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"

	handlersPkg "finitefield.org/hanko-web/internal/handlers"
	mw "finitefield.org/hanko-web/internal/middleware"
	"finitefield.org/hanko-web/internal/nav"
)

// NotificationsShellFrag renders the notification bell and dropdown component (htmx friendly).
func NotificationsShellFrag(w http.ResponseWriter, r *http.Request) {
	lang := mw.Lang(r)
	open := strings.TrimSpace(r.URL.Query().Get("open"))
	openState := open == "1" || strings.EqualFold(open, "true")
	view := buildNotificationBellView(r, lang, openState)
	renderTemplate(w, r, "component_notifications_shell", view)
}

// NotificationMarkReadHandler marks a notification as read and refreshes the component.
func NotificationMarkReadHandler(w http.ResponseWriter, r *http.Request) {
	lang := mw.Lang(r)
	id := strings.TrimSpace(chi.URLParam(r, "notificationID"))
	if id == "" || !notificationExists(id) {
		http.Error(w, "invalid notification id", http.StatusBadRequest)
		return
	}

	_ = r.ParseForm()
	context := strings.ToLower(strings.TrimSpace(r.FormValue("context")))

	session := mw.GetSession(r)
	if session == nil {
		http.Error(w, "session unavailable", http.StatusInternalServerError)
		return
	}
	session.MarkNotificationRead(id)

	if context == "page" {
		NotificationsPageHandler(w, r)
		return
	}

	view := buildNotificationBellView(r, lang, true)
	renderTemplate(w, r, "component_notifications_shell", view)
}

// NotificationsPageHandler renders the notifications archive page.
func NotificationsPageHandler(w http.ResponseWriter, r *http.Request) {
	lang := mw.Lang(r)
	pageView := buildNotificationPageView(r, lang)
	vm := handlersPkg.PageData{
		Title:       pageView.Heading,
		Lang:        lang,
		Path:        r.URL.Path,
		Nav:         nav.Build(r.URL.Path),
		Breadcrumbs: nav.Breadcrumbs(r.URL.Path),
		Analytics:   handlersPkg.LoadAnalyticsFromEnv(),
	}
	vm.NotificationsPage = pageView

	brand := i18nOrDefault(lang, "brand.name", "Hanko Field")
	vm.SEO.Title = fmt.Sprintf("%s | %s", pageView.Heading, brand)
	vm.SEO.Description = pageView.Summary
	vm.SEO.Canonical = absoluteURL(r)
	vm.SEO.OG.URL = vm.SEO.Canonical
	vm.SEO.OG.SiteName = brand
	vm.SEO.OG.Title = vm.SEO.Title
	vm.SEO.OG.Description = vm.SEO.Description
	vm.SEO.Twitter.Card = "summary_large_image"
	vm.SEO.Alternates = buildAlternates(r)

	renderPage(w, r, "notifications", vm)
}
