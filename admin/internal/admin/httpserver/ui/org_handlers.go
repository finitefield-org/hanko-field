package ui

import (
	"net/http"

	"github.com/a-h/templ"

	custommw "finitefield.org/hanko-admin/internal/admin/httpserver/middleware"
	orgtpl "finitefield.org/hanko-admin/internal/admin/templates/org"
)

// OrgStaffPage renders the placeholder staff management page.
func (h *Handlers) OrgStaffPage(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	basePath := custommw.BasePathFromContext(ctx)
	page := orgtpl.BuildStaffPageData(basePath)

	templ.Handler(orgtpl.Index(page)).ServeHTTP(w, r)
}

// OrgRolesPage renders the placeholder role definition page.
func (h *Handlers) OrgRolesPage(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	basePath := custommw.BasePathFromContext(ctx)
	page := orgtpl.BuildRolesPageData(basePath)

	templ.Handler(orgtpl.Index(page)).ServeHTTP(w, r)
}
