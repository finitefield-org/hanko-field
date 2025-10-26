package ui

import (
	"log"
	"net/http"
	"strings"

	"github.com/a-h/templ"
	"github.com/go-chi/chi/v5"

	admincatalog "finitefield.org/hanko-admin/internal/admin/catalog"
	custommw "finitefield.org/hanko-admin/internal/admin/httpserver/middleware"
	catalogtpl "finitefield.org/hanko-admin/internal/admin/templates/catalog"
)

// CatalogRootRedirect sends /admin/catalog to the templates tab by default.
func (h *Handlers) CatalogRootRedirect(w http.ResponseWriter, r *http.Request) {
	base := custommw.BasePathFromContext(r.Context())
	http.Redirect(w, r, joinBasePath(base, "/catalog/templates"), http.StatusFound)
}

// CatalogPage renders the full catalog overview page for the requested kind.
func (h *Handlers) CatalogPage(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	kind, state, query := parseCatalogRequest(r)
	result, err := h.catalog.ListAssets(ctx, user.Token, query)
	if err != nil {
		log.Printf("catalog: list assets failed: %v", err)
		http.Error(w, http.StatusText(http.StatusInternalServerError), http.StatusInternalServerError)
		return
	}

	data := catalogtpl.BuildPageData(custommw.BasePathFromContext(ctx), kind, state, result)
	templ.Handler(catalogtpl.Index(data)).ServeHTTP(w, r)
}

// CatalogTable returns the table fragment for htmx requests.
func (h *Handlers) CatalogTable(w http.ResponseWriter, r *http.Request) {
	renderCatalogFragment(w, r, h, fragmentTable)
}

// CatalogCards returns the card grid fragment for htmx requests.
func (h *Handlers) CatalogCards(w http.ResponseWriter, r *http.Request) {
	renderCatalogFragment(w, r, h, fragmentCards)
}

type fragmentKind int

const (
	fragmentTable fragmentKind = iota
	fragmentCards
)

func renderCatalogFragment(w http.ResponseWriter, r *http.Request, h *Handlers, kind fragmentKind) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	assetKind, state, query := parseCatalogRequest(r)
	result, err := h.catalog.ListAssets(ctx, user.Token, query)
	if err != nil {
		log.Printf("catalog: fragment list failed: %v", err)
		http.Error(w, http.StatusText(http.StatusInternalServerError), http.StatusInternalServerError)
		return
	}

	data := catalogtpl.BuildPageData(custommw.BasePathFromContext(ctx), assetKind, state, result)
	switch kind {
	case fragmentCards:
		templ.Handler(catalogtpl.CardsSection(data.Cards)).ServeHTTP(w, r)
	default:
		templ.Handler(catalogtpl.TableSection(data.Table)).ServeHTTP(w, r)
	}
}

func parseCatalogRequest(r *http.Request) (admincatalog.Kind, catalogtpl.QueryState, admincatalog.ListQuery) {
	params := r.URL.Query()
	kind := admincatalog.NormalizeKind(chi.URLParam(r, "kind"))
	statuses := params["status"]
	tags := params["tag"]
	owner := strings.TrimSpace(params.Get("owner"))
	updated := strings.TrimSpace(params.Get("updated"))
	query := strings.TrimSpace(params.Get("q"))
	view := strings.TrimSpace(params.Get("view"))
	selected := strings.TrimSpace(params.Get("selected"))

	state := catalogtpl.QueryState{
		Status:   statuses,
		Owner:    owner,
		Tags:     tags,
		Updated:  updated,
		Search:   query,
		View:     view,
		Selected: selected,
		RawQuery: r.URL.RawQuery,
	}

	list := admincatalog.ListQuery{
		Kind:         kind,
		Statuses:     toCatalogStatuses(statuses),
		Owner:        owner,
		Tags:         tags,
		UpdatedRange: updated,
		Search:       query,
		View:         admincatalog.NormalizeViewMode(view),
		SelectedID:   selected,
	}
	state.View = string(list.View)
	return kind, state, list
}

func toCatalogStatuses(values []string) []admincatalog.Status {
	if len(values) == 0 {
		return nil
	}
	set := make([]admincatalog.Status, 0, len(values))
	for _, value := range values {
		switch strings.ToLower(strings.TrimSpace(value)) {
		case string(admincatalog.StatusDraft):
			set = append(set, admincatalog.StatusDraft)
		case string(admincatalog.StatusInReview):
			set = append(set, admincatalog.StatusInReview)
		case string(admincatalog.StatusArchived):
			set = append(set, admincatalog.StatusArchived)
		case string(admincatalog.StatusPublished):
			set = append(set, admincatalog.StatusPublished)
		}
	}
	return set
}
