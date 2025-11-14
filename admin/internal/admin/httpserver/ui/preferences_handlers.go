package ui

import (
	"net/http"
	"strings"

	custommw "finitefield.org/hanko-admin/internal/admin/httpserver/middleware"
	"finitefield.org/hanko-admin/internal/admin/i18n"
)

// UpdateLocalePreference persists the selected locale to the session and refreshes the UI.
func (h *Handlers) UpdateLocalePreference(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	if err := r.ParseForm(); err != nil {
		http.Error(w, http.StatusText(http.StatusBadRequest), http.StatusBadRequest)
		return
	}
	desired := strings.TrimSpace(r.FormValue("locale"))
	catalog := i18n.Default()
	canonical := catalog.Canonicalize(desired)
	allowed := make(map[string]struct{})
	for _, loc := range catalog.SupportedLocales() {
		allowed[loc] = struct{}{}
	}
	if _, ok := allowed[canonical]; !ok {
		http.Error(w, http.StatusText(http.StatusBadRequest), http.StatusBadRequest)
		return
	}
	if sess, ok := custommw.SessionFromContext(ctx); ok {
		sess.SetLocale(canonical)
	}
	w.Header().Set("HX-Refresh", "true")
	w.WriteHeader(http.StatusNoContent)
}
