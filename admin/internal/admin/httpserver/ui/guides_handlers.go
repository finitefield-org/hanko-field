package ui

import (
	"context"
	"errors"
	"log"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/a-h/templ"
	"github.com/go-chi/chi/v5"

	admincontent "finitefield.org/hanko-admin/internal/admin/content"
	custommw "finitefield.org/hanko-admin/internal/admin/httpserver/middleware"
	guidestpl "finitefield.org/hanko-admin/internal/admin/templates/guides"
)

// GuidesPage renders the guides management page.
func (h *Handlers) GuidesPage(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	params := buildGuidesRequest(r)

	feed, err := h.content.ListGuides(ctx, user.Token, params.query)
	if err != nil {
		log.Printf("guides: list failed: %v", err)
		feed = admincontent.GuideFeed{}
	}

	csrfToken := custommw.CSRFTokenFromContext(ctx)
	page := guidestpl.BuildPageData(custommw.BasePathFromContext(ctx), params.state, feed, params.state.Selected, csrfToken)

	templ.Handler(guidestpl.Index(page)).ServeHTTP(w, r)
}

// GuidesPreview renders the localized preview page for a guide.
func (h *Handlers) GuidesPreview(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	guideID := strings.TrimSpace(chi.URLParam(r, "guideID"))
	if guideID == "" {
		http.Error(w, http.StatusText(http.StatusBadRequest), http.StatusBadRequest)
		return
	}

	locale := strings.TrimSpace(r.URL.Query().Get("lang"))

	preview, err := h.content.PreviewGuide(ctx, user.Token, guideID, locale)
	if err != nil {
		if errors.Is(err, admincontent.ErrGuideNotFound) {
			http.NotFound(w, r)
			return
		}
		log.Printf("guides: preview failed: %v", err)
		http.Error(w, http.StatusText(http.StatusInternalServerError), http.StatusInternalServerError)
		return
	}

	data := guidestpl.BuildPreviewPageData(custommw.BasePathFromContext(ctx), preview)
	templ.Handler(guidestpl.PreviewPage(data)).ServeHTTP(w, r)
}

// GuidesEdit renders the two-pane editor for a guide.
func (h *Handlers) GuidesEdit(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	guideID := strings.TrimSpace(chi.URLParam(r, "guideID"))
	if guideID == "" {
		http.Error(w, http.StatusText(http.StatusBadRequest), http.StatusBadRequest)
		return
	}

	editor, err := h.content.EditorGuide(ctx, user.Token, guideID)
	if err != nil {
		if errors.Is(err, admincontent.ErrGuideNotFound) {
			http.NotFound(w, r)
			return
		}
		log.Printf("guides: editor payload failed: %v", err)
		http.Error(w, http.StatusText(http.StatusInternalServerError), http.StatusInternalServerError)
		return
	}

	draftInput := admincontent.GuideDraftInput{
		Locale:       editor.Draft.Locale,
		Title:        editor.Draft.Title,
		Summary:      editor.Draft.Summary,
		HeroImageURL: editor.Draft.HeroImageURL,
		BodyHTML:     editor.Draft.BodyHTML,
		Persona:      editor.Draft.Persona,
		Category:     editor.Draft.Category,
		Tags:         cloneStrings(editor.Draft.Tags),
	}

	preview, err := h.content.PreviewDraft(ctx, user.Token, guideID, draftInput)
	if err != nil {
		log.Printf("guides: editor preview bootstrap failed: %v", err)
		http.Error(w, http.StatusText(http.StatusInternalServerError), http.StatusInternalServerError)
		return
	}

	csrfToken := custommw.CSRFTokenFromContext(ctx)
	payload := guidestpl.BuildEditorPageData(custommw.BasePathFromContext(ctx), editor, preview, csrfToken)

	templ.Handler(guidestpl.EditorPage(payload)).ServeHTTP(w, r)
}

// GuidesEditPreview handles live preview refreshes from the editor form.
func (h *Handlers) GuidesEditPreview(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	guideID := strings.TrimSpace(chi.URLParam(r, "guideID"))
	if guideID == "" {
		http.Error(w, http.StatusText(http.StatusBadRequest), http.StatusBadRequest)
		return
	}

	if err := r.ParseForm(); err != nil {
		http.Error(w, http.StatusText(http.StatusBadRequest), http.StatusBadRequest)
		return
	}

	input := admincontent.GuideDraftInput{
		Locale:       strings.TrimSpace(r.FormValue("locale")),
		Title:        strings.TrimSpace(r.FormValue("title")),
		Summary:      strings.TrimSpace(r.FormValue("summary")),
		HeroImageURL: strings.TrimSpace(r.FormValue("hero_image")),
		BodyHTML:     strings.TrimSpace(r.FormValue("body")),
		Persona:      strings.TrimSpace(r.FormValue("persona")),
		Category:     strings.TrimSpace(r.FormValue("category")),
		Tags:         splitTags(r.FormValue("tags")),
	}

	preview, err := h.content.PreviewDraft(ctx, user.Token, guideID, input)
	if err != nil {
		if errors.Is(err, admincontent.ErrGuideNotFound) {
			http.NotFound(w, r)
			return
		}
		log.Printf("guides: live preview failed: %v", err)
		http.Error(w, http.StatusText(http.StatusInternalServerError), http.StatusInternalServerError)
		return
	}

	data := guidestpl.BuildEditorPreviewData(custommw.BasePathFromContext(ctx), preview)

	templ.Handler(guidestpl.EditorPreview(data)).ServeHTTP(w, r)
}

// GuidesTable renders the table fragment for htmx updates.
func (h *Handlers) GuidesTable(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	params := buildGuidesRequest(r)
	h.renderGuidesFragment(w, r, user.Token, params)
}

// GuidesPublish toggles a guide into the published state.
func (h *Handlers) GuidesPublish(w http.ResponseWriter, r *http.Request) {
	h.handlePublishToggle(w, r, true)
}

// GuidesUnpublish toggles a guide back to draft.
func (h *Handlers) GuidesUnpublish(w http.ResponseWriter, r *http.Request) {
	h.handlePublishToggle(w, r, false)
}

// GuidesSchedule updates a guide's scheduled publish date.
func (h *Handlers) GuidesSchedule(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	if err := r.ParseForm(); err != nil {
		http.Error(w, http.StatusText(http.StatusBadRequest), http.StatusBadRequest)
		return
	}

	params := buildGuidesRequest(r)
	guideID := strings.TrimSpace(chi.URLParam(r, "guideID"))
	rawScheduled := strings.TrimSpace(r.PostFormValue("scheduledAt"))

	var scheduled *time.Time
	if rawScheduled != "" {
		if ts, err := time.Parse("2006-01-02T15:04", rawScheduled); err == nil {
			scheduled = &ts
		}
	}

	if _, err := h.content.Schedule(ctx, user.Token, guideID, scheduled); err != nil {
		log.Printf("guides: schedule failed: %v", err)
	}

	h.renderGuidesFragment(w, r, user.Token, params)
}

// GuidesUnschedule clears the scheduled publish date.
func (h *Handlers) GuidesUnschedule(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	params := buildGuidesRequest(r)
	guideID := strings.TrimSpace(chi.URLParam(r, "guideID"))
	if _, err := h.content.Schedule(ctx, user.Token, guideID, nil); err != nil {
		log.Printf("guides: unschedule failed: %v", err)
	}
	h.renderGuidesFragment(w, r, user.Token, params)
}

// GuidesBulkPublish publishes selected guides.
func (h *Handlers) GuidesBulkPublish(w http.ResponseWriter, r *http.Request) {
	h.handleBulkAction(w, r, func(ctx customContext, ids []string) error {
		_, err := h.content.BulkPublish(ctx.context, ctx.token, ids)
		return err
	})
}

// GuidesBulkUnschedule clears scheduled dates for selected guides.
func (h *Handlers) GuidesBulkUnschedule(w http.ResponseWriter, r *http.Request) {
	h.handleBulkAction(w, r, func(ctx customContext, ids []string) error {
		_, err := h.content.BulkUnschedule(ctx.context, ctx.token, ids)
		return err
	})
}

// GuidesBulkArchive archives selected guides.
func (h *Handlers) GuidesBulkArchive(w http.ResponseWriter, r *http.Request) {
	h.handleBulkAction(w, r, func(ctx customContext, ids []string) error {
		_, err := h.content.BulkArchive(ctx.context, ctx.token, ids)
		return err
	})
}

func (h *Handlers) handlePublishToggle(w http.ResponseWriter, r *http.Request, publish bool) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	params := buildGuidesRequest(r)
	guideID := strings.TrimSpace(chi.URLParam(r, "guideID"))
	if guideID == "" {
		http.Error(w, http.StatusText(http.StatusBadRequest), http.StatusBadRequest)
		return
	}

	if _, err := h.content.TogglePublish(ctx, user.Token, guideID, publish); err != nil {
		log.Printf("guides: toggle publish failed: %v", err)
	}

	h.renderGuidesFragment(w, r, user.Token, params)
}

func (h *Handlers) handleBulkAction(w http.ResponseWriter, r *http.Request, action func(customContext, []string) error) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	if err := r.ParseForm(); err != nil {
		http.Error(w, http.StatusText(http.StatusBadRequest), http.StatusBadRequest)
		return
	}

	params := buildGuidesRequest(r)
	ids := parseIDs(r.PostFormValue("ids"))
	if len(ids) > 0 {
		if err := action(customContext{context: ctx, token: user.Token}, ids); err != nil {
			log.Printf("guides: bulk action failed: %v", err)
		}
	}

	h.renderGuidesFragment(w, r, user.Token, params)
}

type customContext struct {
	context context.Context
	token   string
}

func (h *Handlers) renderGuidesFragment(w http.ResponseWriter, r *http.Request, token string, params guidesRequest) {
	ctx := r.Context()

	feed, err := h.content.ListGuides(ctx, token, params.query)
	errMsg := ""
	if err != nil {
		log.Printf("guides: list failed: %v", err)
		feed = admincontent.GuideFeed{}
		errMsg = "ガイド一覧の取得に失敗しました。時間をおいて再度お試しください。"
	}

	csrfToken := custommw.CSRFTokenFromContext(ctx)
	basePath := custommw.BasePathFromContext(ctx)

	table := guidestpl.TablePayload(basePath, params.state, feed, params.state.Selected)
	if errMsg != "" {
		table.Error = errMsg
	}
	summary := guidestpl.SummaryPayload(basePath, params.state, feed)
	bulk := guidestpl.BulkPayload(basePath, params.state, table)
	drawer := guidestpl.DrawerPayload(feed, table.SelectedID)

	fragment := guidestpl.FragmentPayload(table, summary, bulk, drawer, csrfToken)

	if canonical := canonicalGuidesURL(basePath, params, table); canonical != "" {
		w.Header().Set("HX-Push-Url", canonical)
	}

	templ.Handler(guidestpl.TableFragment(fragment)).ServeHTTP(w, r)
}

func splitTags(raw string) []string {
	if strings.TrimSpace(raw) == "" {
		return []string{}
	}
	values := strings.Split(raw, ",")
	results := make([]string, 0, len(values))
	for _, value := range values {
		if trimmed := strings.TrimSpace(value); trimmed != "" {
			results = append(results, trimmed)
		}
	}
	return results
}

func cloneStrings(values []string) []string {
	if len(values) == 0 {
		return nil
	}
	dup := make([]string, len(values))
	copy(dup, values)
	return dup
}

type guidesRequest struct {
	query admincontent.GuideQuery
	state guidestpl.QueryState
}

func buildGuidesRequest(r *http.Request) guidesRequest {
	values := r.URL.Query()
	rawSearch := strings.TrimSpace(values.Get("q"))
	rawStatus := strings.TrimSpace(values.Get("status"))
	rawPersona := strings.TrimSpace(values.Get("persona"))
	rawCategory := strings.TrimSpace(values.Get("category"))
	rawLocale := strings.TrimSpace(values.Get("locale"))
	rawSchedule := strings.TrimSpace(values.Get("schedule"))

	var schedulePtr *time.Time
	if rawSchedule != "" {
		if ts, err := time.Parse("2006-01-02", rawSchedule); err == nil {
			schedulePtr = &ts
		}
	}

	selectedValues := parseMulti(values["selected"])

	state := guidestpl.QueryState{
		Search:       rawSearch,
		Status:       rawStatus,
		Persona:      rawPersona,
		Category:     rawCategory,
		Locale:       rawLocale,
		ScheduleDate: rawSchedule,
		Selected:     selectedValues,
		RawQuery:     r.URL.RawQuery,
	}

	query := admincontent.GuideQuery{
		Search:       rawSearch,
		Persona:      rawPersona,
		Category:     rawCategory,
		Locale:       rawLocale,
		ScheduleDate: schedulePtr,
		SelectedIDs:  selectedValues,
	}
	if rawStatus != "" {
		query.Status = admincontent.GuideStatus(rawStatus)
	}

	return guidesRequest{
		query: query,
		state: state,
	}
}

func canonicalGuidesURL(basePath string, req guidesRequest, table guidestpl.TableData) string {
	params := url.Values{}
	if strings.TrimSpace(req.state.Search) != "" {
		params.Set("q", req.state.Search)
	}
	if strings.TrimSpace(req.state.Status) != "" {
		params.Set("status", req.state.Status)
	}
	if strings.TrimSpace(req.state.Persona) != "" {
		params.Set("persona", req.state.Persona)
	}
	if strings.TrimSpace(req.state.Category) != "" {
		params.Set("category", req.state.Category)
	}
	if strings.TrimSpace(req.state.Locale) != "" {
		params.Set("locale", req.state.Locale)
	}
	if strings.TrimSpace(req.state.ScheduleDate) != "" {
		params.Set("schedule", req.state.ScheduleDate)
	}
	if table.SelectedID != "" {
		params.Set("selected", table.SelectedID)
	}

	path := strings.TrimSpace(basePath)
	if path == "" || path == "/" {
		path = ""
	}
	path += "/content/guides"
	for strings.Contains(path, "//") {
		path = strings.ReplaceAll(path, "//", "/")
	}
	if !strings.HasPrefix(path, "/") {
		path = "/" + path
	}
	if encoded := params.Encode(); encoded != "" {
		return path + "?" + encoded
	}
	return path
}

func parseMulti(values []string) []string {
	set := make(map[string]struct{})
	for _, value := range values {
		if strings.TrimSpace(value) == "" {
			continue
		}
		parts := strings.Split(value, ",")
		for _, part := range parts {
			part = strings.TrimSpace(part)
			if part == "" {
				continue
			}
			set[part] = struct{}{}
		}
	}
	result := make([]string, 0, len(set))
	for id := range set {
		result = append(result, id)
	}
	return result
}

func parseIDs(raw string) []string {
	return parseMulti([]string{raw})
}
