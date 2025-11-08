package ui

import (
	"errors"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/a-h/templ"
	"github.com/go-chi/chi/v5"

	admincontent "finitefield.org/hanko-admin/internal/admin/content"
	custommw "finitefield.org/hanko-admin/internal/admin/httpserver/middleware"
	pagestpl "finitefield.org/hanko-admin/internal/admin/templates/pages"
)

// PagesPage renders the fixed pages management experience.
func (h *Handlers) PagesPage(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	req := buildPagesRequest(r)

	tree, err := h.content.ListPages(ctx, user.Token, req.query)
	if err != nil {
		log.Printf("pages: list failed: %v", err)
		tree = admincontent.PageTree{}
	}

	selectedID := tree.ActiveID
	if selectedID == "" {
		selectedID = req.state.PageID
	}
	if selectedID == "" {
		selectedID = firstTreeNodeID(tree.Nodes)
		req.query.SelectedID = selectedID
		req.state.PageID = selectedID
	}

	if strings.TrimSpace(selectedID) == "" {
		http.Error(w, "ページが未構成です", http.StatusNotFound)
		return
	}

	editor, err := h.content.PageEditor(ctx, user.Token, selectedID)
	if err != nil {
		if errors.Is(err, admincontent.ErrPageNotFound) {
			http.NotFound(w, r)
			return
		}
		log.Printf("pages: editor payload failed: %v", err)
		http.Error(w, http.StatusText(http.StatusInternalServerError), http.StatusInternalServerError)
		return
	}

	preview, err := h.content.PagePreview(ctx, user.Token, selectedID, req.state.Locale)
	if err != nil {
		if errors.Is(err, admincontent.ErrPageNotFound) {
			http.NotFound(w, r)
			return
		}
		log.Printf("pages: preview bootstrap failed: %v", err)
		http.Error(w, http.StatusText(http.StatusInternalServerError), http.StatusInternalServerError)
		return
	}

	csrfToken := custommw.CSRFTokenFromContext(ctx)
	basePath := custommw.BasePathFromContext(ctx)
	data := pagestpl.BuildPageManagementData(basePath, req.state, tree, editor, preview, csrfToken)

	templ.Handler(pagestpl.Index(data)).ServeHTTP(w, r)
}

// PagesPreview renders the standalone preview page.
func (h *Handlers) PagesPreview(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	pageID := strings.TrimSpace(chi.URLParam(r, "pageID"))
	if pageID == "" {
		http.Error(w, http.StatusText(http.StatusBadRequest), http.StatusBadRequest)
		return
	}

	locale := strings.TrimSpace(r.URL.Query().Get("locale"))
	preview, err := h.content.PagePreview(ctx, user.Token, pageID, locale)
	if err != nil {
		if errors.Is(err, admincontent.ErrPageNotFound) {
			http.NotFound(w, r)
			return
		}
		log.Printf("pages: preview render failed: %v", err)
		http.Error(w, http.StatusText(http.StatusInternalServerError), http.StatusInternalServerError)
		return
	}

	basePath := custommw.BasePathFromContext(ctx)
	data := pagestpl.BuildPreviewPageData(basePath, preview)
	templ.Handler(pagestpl.PreviewPage(data)).ServeHTTP(w, r)
}

// PagesEditPreview handles live preview updates via htmx.
func (h *Handlers) PagesEditPreview(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	pageID := strings.TrimSpace(chi.URLParam(r, "pageID"))
	if pageID == "" {
		http.Error(w, http.StatusText(http.StatusBadRequest), http.StatusBadRequest)
		return
	}

	if err := r.ParseForm(); err != nil {
		http.Error(w, http.StatusText(http.StatusBadRequest), http.StatusBadRequest)
		return
	}

	input := buildDraftInputFromForm(r)
	preview, err := h.content.PagePreviewDraft(ctx, user.Token, pageID, input)
	if err != nil {
		if errors.Is(err, admincontent.ErrPageNotFound) {
			http.NotFound(w, r)
			return
		}
		log.Printf("pages: live preview failed: %v", err)
		http.Error(w, http.StatusText(http.StatusInternalServerError), http.StatusInternalServerError)
		return
	}

	req := buildPagesRequest(r)
	basePath := custommw.BasePathFromContext(ctx)
	data := pagestpl.BuildPreviewFragmentData(basePath, req.state, preview)
	templ.Handler(pagestpl.PreviewFragment(data)).ServeHTTP(w, r)
}

// PagesSaveDraft persists draft changes (placeholder static implementation).
func (h *Handlers) PagesSaveDraft(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	pageID := strings.TrimSpace(chi.URLParam(r, "pageID"))
	if pageID == "" {
		http.Error(w, http.StatusText(http.StatusBadRequest), http.StatusBadRequest)
		return
	}

	if err := r.ParseForm(); err != nil {
		http.Error(w, http.StatusText(http.StatusBadRequest), http.StatusBadRequest)
		return
	}

	input := buildDraftInputFromForm(r)
	if _, err := h.content.PageSaveDraft(ctx, user.Token, pageID, input); err != nil {
		if errors.Is(err, admincontent.ErrPageNotFound) {
			http.NotFound(w, r)
			return
		}
		log.Printf("pages: save draft failed: %v", err)
		w.WriteHeader(http.StatusInternalServerError)
	}

	redirectSelf(w, r)
}

// PagesPublish publishes a page.
func (h *Handlers) PagesPublish(w http.ResponseWriter, r *http.Request) {
	if err := h.togglePagePublish(w, r, true); err != nil {
		log.Printf("pages: publish failed: %v", err)
	}
}

// PagesUnpublish reverts a page to draft.
func (h *Handlers) PagesUnpublish(w http.ResponseWriter, r *http.Request) {
	if err := h.togglePagePublish(w, r, false); err != nil {
		log.Printf("pages: unpublish failed: %v", err)
	}
}

// PagesSchedule updates a page schedule.
func (h *Handlers) PagesSchedule(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	pageID := strings.TrimSpace(chi.URLParam(r, "pageID"))
	if pageID == "" {
		http.Error(w, http.StatusText(http.StatusBadRequest), http.StatusBadRequest)
		return
	}

	if err := r.ParseForm(); err != nil {
		http.Error(w, http.StatusText(http.StatusBadRequest), http.StatusBadRequest)
		return
	}

	var scheduledAt *time.Time
	if raw := strings.TrimSpace(r.FormValue("scheduled_at")); raw != "" {
		if ts, err := time.Parse("2006-01-02T15:04", raw); err == nil {
			scheduledAt = &ts
		}
	}

	if _, err := h.content.PageSchedule(ctx, user.Token, pageID, scheduledAt); err != nil {
		if errors.Is(err, admincontent.ErrPageNotFound) {
			http.NotFound(w, r)
			return
		}
		log.Printf("pages: schedule update failed: %v", err)
		w.WriteHeader(http.StatusInternalServerError)
	}

	redirectSelf(w, r)
}

// PagesUnschedule clears a scheduled publish date.
func (h *Handlers) PagesUnschedule(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	pageID := strings.TrimSpace(chi.URLParam(r, "pageID"))
	if pageID == "" {
		http.Error(w, http.StatusText(http.StatusBadRequest), http.StatusBadRequest)
		return
	}

	if _, err := h.content.PageSchedule(ctx, user.Token, pageID, nil); err != nil {
		if errors.Is(err, admincontent.ErrPageNotFound) {
			http.NotFound(w, r)
			return
		}
		log.Printf("pages: unschedule failed: %v", err)
		w.WriteHeader(http.StatusInternalServerError)
	}

	redirectSelf(w, r)
}

// PagesHistoryModal renders the history modal fragment.
func (h *Handlers) PagesHistoryModal(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	pageID := strings.TrimSpace(chi.URLParam(r, "pageID"))
	if pageID == "" {
		http.Error(w, http.StatusText(http.StatusBadRequest), http.StatusBadRequest)
		return
	}

	editor, err := h.content.PageEditor(ctx, user.Token, pageID)
	if err != nil {
		if errors.Is(err, admincontent.ErrPageNotFound) {
			http.NotFound(w, r)
			return
		}
		log.Printf("pages: load history failed: %v", err)
		w.WriteHeader(http.StatusInternalServerError)
		return
	}

	data := pagestpl.BuildHistoryModalData(editor.History)
	templ.Handler(pagestpl.HistoryModal(data)).ServeHTTP(w, r)
}

func (h *Handlers) togglePagePublish(w http.ResponseWriter, r *http.Request, publish bool) error {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return errors.New("unauthorized")
	}

	pageID := strings.TrimSpace(chi.URLParam(r, "pageID"))
	if pageID == "" {
		http.Error(w, http.StatusText(http.StatusBadRequest), http.StatusBadRequest)
		return errors.New("missing page id")
	}

	if _, err := h.content.PageTogglePublish(ctx, user.Token, pageID, publish); err != nil {
		if errors.Is(err, admincontent.ErrPageNotFound) {
			http.NotFound(w, r)
			return err
		}
		w.WriteHeader(http.StatusInternalServerError)
		return err
	}

	redirectSelf(w, r)
	return nil
}

func buildPagesRequest(r *http.Request) pagesRequest {
	values := r.URL.Query()
	search := strings.TrimSpace(values.Get("q"))
	status := strings.TrimSpace(values.Get("status"))
	typeFilter := strings.TrimSpace(values.Get("type"))
	locale := strings.TrimSpace(values.Get("locale"))
	selected := strings.TrimSpace(values.Get("page"))

	query := admincontent.PageQuery{
		Search:     search,
		Type:       typeFilter,
		Locale:     locale,
		SelectedID: selected,
	}
	if status != "" {
		query.Status = admincontent.PageStatus(status)
	}

	state := pagestpl.QueryState{
		RawQuery: r.URL.RawQuery,
		PageID:   selected,
		Search:   search,
		Status:   status,
		Type:     typeFilter,
		Locale:   locale,
	}

	return pagesRequest{query: query, state: state}
}

type pagesRequest struct {
	query admincontent.PageQuery
	state pagestpl.QueryState
}

func firstTreeNodeID(nodes []admincontent.PageNode) string {
	for _, node := range nodes {
		if node.Leaf && node.ID != "" {
			return node.ID
		}
		if len(node.Children) > 0 {
			if id := firstTreeNodeID(node.Children); id != "" {
				return id
			}
		}
	}
	return ""
}

func redirectSelf(w http.ResponseWriter, r *http.Request) {
	if hxCurrent := strings.TrimSpace(r.Header.Get("HX-Current-URL")); hxCurrent != "" {
		w.Header().Set("HX-Redirect", hxCurrent)
		return
	}
	current := r.URL.Path
	if raw := r.URL.RawQuery; raw != "" {
		current += "?" + raw
	}
	w.Header().Set("HX-Redirect", current)
}

func buildDraftInputFromForm(r *http.Request) admincontent.PageDraftInput {
	return admincontent.PageDraftInput{
		Locale:          strings.TrimSpace(r.FormValue("locale")),
		Title:           strings.TrimSpace(r.FormValue("title")),
		Summary:         strings.TrimSpace(r.FormValue("summary")),
		Outline:         strings.TrimSpace(r.FormValue("outline")),
		Tags:            splitCSV(r.FormValue("tags")),
		MetaTitle:       strings.TrimSpace(r.FormValue("meta_title")),
		MetaDescription: strings.TrimSpace(r.FormValue("meta_description")),
		OGImageURL:      strings.TrimSpace(r.FormValue("og_image")),
		CanonicalURL:    strings.TrimSpace(r.FormValue("canonical")),
	}
}

func splitCSV(raw string) []string {
	if strings.TrimSpace(raw) == "" {
		return nil
	}
	parts := strings.Split(raw, ",")
	results := make([]string, 0, len(parts))
	for _, part := range parts {
		if trimmed := strings.TrimSpace(part); trimmed != "" {
			results = append(results, trimmed)
		}
	}
	return results
}
