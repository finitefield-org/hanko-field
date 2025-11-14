package system

import (
	"context"
	"strings"

	adminsystem "finitefield.org/hanko-admin/internal/admin/system"
	"finitefield.org/hanko-admin/internal/admin/templates/helpers"
)

const defaultFeedbackTracker = "https://github.com/finitefield/hanko-field/issues/new?labels=admin-bug&template=bug_report.md"

// FeedbackModalData powers the feedback modal template.
type FeedbackModalData struct {
	ActionURL       string
	CSRFToken       string
	TrackerURL      string
	Context         FeedbackContextData
	Form            FeedbackFormState
	Receipt         *FeedbackReceiptData
	SupportingLinks []LinkView
}

// FeedbackContextData captures automatically detected metadata.
type FeedbackContextData struct {
	CurrentURL string
	Browser    string
}

// FeedbackFormState holds user-provided values and validation state.
type FeedbackFormState struct {
	Summary     string
	Details     string
	Expectation string
	ConsoleLog  string
	Contact     string
	Error       string
	FieldErrors map[string]string
}

// FieldError returns the error message for the provided field key.
func (f FeedbackFormState) FieldError(key string) string {
	if len(f.FieldErrors) == 0 {
		return ""
	}
	return strings.TrimSpace(f.FieldErrors[key])
}

// FeedbackReceiptData shows submission metadata after success.
type FeedbackReceiptData struct {
	ID                string
	ReferenceURL      string
	SubmittedAt       string
	SubmittedRelative string
	Message           string
	Context           FeedbackContextData
}

var defaultFeedbackLinks = []LinkView{
	{
		Label: "不具合対応 Runbook",
		URL:   "https://runbooks.hanko.local/ops/admin-bug-triage",
		Icon:  "📘",
	},
	{
		Label: "プロダクト Slack #ops-bugs",
		URL:   "https://slack.com/app_redirect?channel=ops-bugs",
		Icon:  "💬",
	},
}

// BuildFeedbackModalData assembles template data for the modal.
func BuildFeedbackModalData(ctx context.Context, basePath, csrfToken string, contextInfo FeedbackContextData, form FeedbackFormState, receipt *adminsystem.FeedbackReceipt) FeedbackModalData {
	formatter := helpers.NewFormatter(ctx)
	normalizedContext := FeedbackContextData{
		CurrentURL: strings.TrimSpace(contextInfo.CurrentURL),
		Browser:    strings.TrimSpace(contextInfo.Browser),
	}
	data := FeedbackModalData{
		ActionURL:       joinBasePath(basePath, "/feedback"),
		CSRFToken:       csrfToken,
		TrackerURL:      defaultFeedbackTracker,
		Context:         normalizedContext,
		Form:            normalizeFeedbackForm(form),
		SupportingLinks: append([]LinkView(nil), defaultFeedbackLinks...),
	}
	if receipt != nil {
		submitted := receipt.SubmittedAt
		data.Receipt = &FeedbackReceiptData{
			ID:                strings.TrimSpace(receipt.ID),
			ReferenceURL:      firstNonEmpty(strings.TrimSpace(receipt.ReferenceURL), defaultFeedbackTracker),
			SubmittedAt:       formatter.Date(submitted, "2006-01-02 15:04"),
			SubmittedRelative: formatter.Relative(submitted),
			Message:           strings.TrimSpace(receipt.Message),
			Context:           normalizedContext,
		}
	}
	return data
}

func normalizeFeedbackForm(form FeedbackFormState) FeedbackFormState {
	form.Summary = strings.TrimSpace(form.Summary)
	form.Details = strings.TrimSpace(form.Details)
	form.Expectation = strings.TrimSpace(form.Expectation)
	form.ConsoleLog = strings.TrimSpace(form.ConsoleLog)
	form.Contact = strings.TrimSpace(form.Contact)
	form.Error = strings.TrimSpace(form.Error)
	if len(form.FieldErrors) == 0 {
		form.FieldErrors = make(map[string]string)
	} else {
		for key, value := range form.FieldErrors {
			form.FieldErrors[key] = strings.TrimSpace(value)
		}
	}
	return form
}

func firstNonEmpty(values ...string) string {
	for _, value := range values {
		if strings.TrimSpace(value) != "" {
			return value
		}
	}
	return ""
}

func pickClass(condition bool, whenTrue, whenFalse string) string {
	if condition {
		return whenTrue
	}
	return whenFalse
}
