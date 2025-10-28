package main

import (
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"

	mw "finitefield.org/hanko-web/internal/middleware"
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

	session := mw.GetSession(r)
	if session == nil {
		http.Error(w, "session unavailable", http.StatusInternalServerError)
		return
	}
	session.MarkNotificationRead(id)

	view := buildNotificationBellView(r, lang, true)
	renderTemplate(w, r, "component_notifications_shell", view)
}
