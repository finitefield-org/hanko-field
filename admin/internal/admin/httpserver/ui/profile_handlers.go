package ui

import (
	"log"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"

	custommw "finitefield.org/hanko-admin/internal/admin/httpserver/middleware"
	profiletpl "finitefield.org/hanko-admin/internal/admin/templates/profile"
	"finitefield.org/hanko-admin/internal/admin/webtmpl"
)

// ProfilePage renders the main profile dashboard.
func (h *Handlers) ProfilePage(w http.ResponseWriter, r *http.Request) {
	h.renderProfilePage(w, r)
}

// RevokeSession terminates an active session.
func (h *Handlers) RevokeSession(w http.ResponseWriter, r *http.Request) {
	user, ok := custommw.UserFromContext(r.Context())
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	sessionID := strings.TrimSpace(chi.URLParam(r, "sessionID"))
	if sessionID == "" {
		http.Error(w, "セッションが指定されていません。", http.StatusBadRequest)
		return
	}

	state, err := h.profile.RevokeSession(r.Context(), user.Token, sessionID)
	if err != nil {
		log.Printf("profile: revoke session failed: %v", err)
		http.Error(w, "セッションの失効に失敗しました。", http.StatusBadGateway)
		return
	}

	payload := profiletpl.SessionUpdateData{
		Security:  state,
		CSRFToken: custommw.CSRFTokenFromContext(r.Context()),
		Message:   "セッションを失効させました。",
	}
	view := webtmpl.ProfileSessionUpdateView{
		BasePath: custommw.BasePathFromContext(r.Context()),
		Data:     payload,
	}
	if err := dashboardTemplates.Render(w, "profile/session-update", view); err != nil {
		http.Error(w, "template render error", http.StatusInternalServerError)
	}
}
