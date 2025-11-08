package ui

import (
	"errors"
	"log"
	"net/http"
	"strings"

	"github.com/a-h/templ"

	custommw "finitefield.org/hanko-admin/internal/admin/httpserver/middleware"
	adminsystem "finitefield.org/hanko-admin/internal/admin/system"
	"finitefield.org/hanko-admin/internal/admin/templates/helpers"
	systemtpl "finitefield.org/hanko-admin/internal/admin/templates/system"
)

// FeedbackModal renders the feedback form modal.
func (h *Handlers) FeedbackModal(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	contextInfo := deriveFeedbackContext(r)
	form := systemtpl.FeedbackFormState{
		Contact:     strings.TrimSpace(user.Email),
		FieldErrors: make(map[string]string),
	}

	csrfToken := custommw.CSRFTokenFromContext(ctx)
	basePath := custommw.BasePathFromContext(ctx)
	data := systemtpl.BuildFeedbackModalData(ctx, basePath, csrfToken, contextInfo, form, nil)

	templ.Handler(systemtpl.FeedbackModal(data)).ServeHTTP(w, r)
}

// FeedbackSubmit handles submissions from the feedback modal.
func (h *Handlers) FeedbackSubmit(w http.ResponseWriter, r *http.Request) {
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

	contextInfo := deriveFeedbackContext(r)
	formatter := helpers.NewFormatter(ctx)

	form := systemtpl.FeedbackFormState{
		Summary:     strings.TrimSpace(r.PostFormValue("summary")),
		Details:     strings.TrimSpace(r.PostFormValue("details")),
		Expectation: strings.TrimSpace(r.PostFormValue("expectation")),
		ConsoleLog:  strings.TrimSpace(r.PostFormValue("console")),
		Contact:     strings.TrimSpace(firstNonEmptyString(r.PostFormValue("contact"), user.Email)),
		FieldErrors: make(map[string]string),
	}

	if form.Summary == "" {
		form.FieldErrors["summary"] = formatter.T("admin.feedback.modal.error.summary_required")
	}
	if form.Details == "" {
		form.FieldErrors["details"] = formatter.T("admin.feedback.modal.error.details_required")
	}
	if form.Contact == "" {
		form.FieldErrors["contact"] = formatter.T("admin.feedback.modal.error.contact_required")
	}

	if len(form.FieldErrors) > 0 {
		form.Error = formatter.T("admin.feedback.modal.error.fix_fields")
		renderFeedbackForm(r, w, custommw.BasePathFromContext(ctx), custommw.CSRFTokenFromContext(ctx), contextInfo, form, nil)
		return
	}

	submission := adminsystem.FeedbackSubmission{
		Subject:       form.Summary,
		Description:   form.Details,
		Expectation:   form.Expectation,
		ConsoleLog:    form.ConsoleLog,
		CurrentURL:    contextInfo.CurrentURL,
		Browser:       contextInfo.Browser,
		Contact:       form.Contact,
		ReporterEmail: strings.TrimSpace(user.Email),
		ReporterName:  strings.TrimSpace(user.UID),
	}

	receipt, err := h.system.SubmitFeedback(ctx, user.Token, submission)
	if err != nil {
		log.Printf("feedback: submit failed: %v", err)
		if errors.Is(err, adminsystem.ErrFeedbackInvalid) {
			form.Error = formatter.T("admin.feedback.modal.error.fix_fields")
		} else {
			form.Error = formatter.T("admin.feedback.modal.error.submit_failed")
		}
		renderFeedbackForm(r, w, custommw.BasePathFromContext(ctx), custommw.CSRFTokenFromContext(ctx), contextInfo, form, nil)
		return
	}

	renderFeedbackForm(r, w, custommw.BasePathFromContext(ctx), custommw.CSRFTokenFromContext(ctx), contextInfo, systemtpl.FeedbackFormState{}, &receipt)
}

func renderFeedbackForm(r *http.Request, w http.ResponseWriter, basePath, csrfToken string, contextInfo systemtpl.FeedbackContextData, form systemtpl.FeedbackFormState, receipt *adminsystem.FeedbackReceipt) {
	data := systemtpl.BuildFeedbackModalData(r.Context(), basePath, csrfToken, contextInfo, form, receipt)
	templ.Handler(systemtpl.FeedbackModal(data)).ServeHTTP(w, r)
}

func deriveFeedbackContext(r *http.Request) systemtpl.FeedbackContextData {
	ctxURL := strings.TrimSpace(r.FormValue("context_url"))
	if ctxURL == "" {
		ctxURL = strings.TrimSpace(r.Header.Get("HX-Current-URL"))
	}
	if ctxURL == "" {
		ctxURL = strings.TrimSpace(r.Referer())
	}
	if ctxURL == "" {
		ctxURL = strings.TrimSpace(custommw.RequestPathFromContext(r.Context()))
	}
	if ctxURL == "" {
		ctxURL = "/"
	}

	browser := strings.TrimSpace(r.FormValue("client_browser"))
	if browser == "" {
		browser = strings.TrimSpace(r.UserAgent())
	}
	if browser == "" {
		browser = "unknown"
	}

	return systemtpl.FeedbackContextData{
		CurrentURL: ctxURL,
		Browser:    browser,
	}
}

func firstNonEmptyString(values ...string) string {
	for _, value := range values {
		if strings.TrimSpace(value) != "" {
			return value
		}
	}
	return ""
}
