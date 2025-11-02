package customers

import (
	"fmt"
	"net/url"
	"strings"

	admincustomers "finitefield.org/hanko-admin/internal/admin/customers"
	"finitefield.org/hanko-admin/internal/admin/templates/helpers"
)

// DeactivateModalData powers the deactivate + mask confirmation modal.
type DeactivateModalData struct {
	CustomerID         string
	CustomerName       string
	Email              string
	StatusLabel        string
	StatusTone         string
	TotalOrdersLabel   string
	LifetimeValueLabel string
	LastOrderLabel     string
	ConfirmationPhrase string
	ActionURL          string
	CSRFToken          string
	Impacts            []DeactivateImpactItem
	Form               DeactivateFormState
}

// DeactivateImpactItem renders a single consequence bullet.
type DeactivateImpactItem struct {
	Title       string
	Description string
	Icon        string
	Tone        string
}

// DeactivateFormState stores user input and validation errors.
type DeactivateFormState struct {
	Reason        string
	Confirmation  string
	Error         string
	FieldErrors   map[string]string
	DisableSubmit bool
}

// DeactivateSuccessData is shown once the deactivate + mask flow completes.
type DeactivateSuccessData struct {
	CustomerID     string
	CustomerName   string
	Message        string
	AuditID        string
	AuditURL       string
	AuditTimestamp string
	AuditRelative  string
	AuditActor     string
}

// DeactivateModalPayload normalises service data for the modal template.
func DeactivateModalPayload(basePath string, modal admincustomers.DeactivateModal, csrfToken string, form DeactivateFormState) DeactivateModalData {
	totalOrders := fmt.Sprintf("%d件", modal.TotalOrders)
	lifetime := helpers.Currency(modal.LifetimeValueMinor, modal.Currency)
	lastOrder := "-"
	if strings.TrimSpace(modal.LastOrderNumber) != "" {
		lastOrder = modal.LastOrderNumber
	}
	if !modal.LastOrderAt.IsZero() {
		lastLabel := formatDate(modal.LastOrderAt, "2006-01-02 15:04")
		if strings.TrimSpace(modal.LastOrderNumber) != "" {
			lastOrder = fmt.Sprintf("%s (#%s)", lastLabel, modal.LastOrderNumber)
		} else {
			lastOrder = lastLabel
		}
	}
	statusLabel := statusLabel(modal.Status)
	statusTone := statusTone(modal.Status)

	impacts := make([]DeactivateImpactItem, 0, len(modal.Impacts))
	for _, impact := range modal.Impacts {
		impacts = append(impacts, DeactivateImpactItem{
			Title:       impact.Title,
			Description: impact.Description,
			Icon:        impact.Icon,
			Tone:        impact.Tone,
		})
	}

	if form.FieldErrors == nil {
		form.FieldErrors = make(map[string]string)
	}

	actionURL := joinBase(basePath, fmt.Sprintf("/customers/%s:deactivate-and-mask", url.PathEscape(strings.TrimSpace(modal.CustomerID))))

	return DeactivateModalData{
		CustomerID:         modal.CustomerID,
		CustomerName:       modal.DisplayName,
		Email:              modal.Email,
		StatusLabel:        statusLabel,
		StatusTone:         statusTone,
		TotalOrdersLabel:   totalOrders,
		LifetimeValueLabel: lifetime,
		LastOrderLabel:     lastOrder,
		ConfirmationPhrase: modal.ConfirmationPhrase,
		ActionURL:          actionURL,
		CSRFToken:          csrfToken,
		Impacts:            impacts,
		Form:               form,
	}
}

// DeactivateSuccessPayload builds the success state payload after processing.
func DeactivateSuccessPayload(basePath, originalName string, result admincustomers.DeactivateAndMaskResult) DeactivateSuccessData {
	customerName := strings.TrimSpace(originalName)
	if customerName == "" {
		customerName = strings.TrimSpace(result.Detail.Profile.DisplayName)
	}
	if customerName == "" {
		customerName = strings.TrimSpace(result.Detail.Profile.ID)
	}

	targetRef := fmt.Sprintf("user:%s", strings.TrimSpace(result.Detail.Profile.ID))
	auditURL := joinBase(basePath, "/audit-logs")
	if targetRef != "" {
		values := url.Values{}
		values.Set("targetRef", targetRef)
		query := values.Encode()
		if strings.Contains(auditURL, "?") {
			auditURL = auditURL + "&" + query
		} else {
			auditURL = auditURL + "?" + query
		}
	}

	auditActor := strings.TrimSpace(result.Audit.ActorEmail)
	if auditActor == "" {
		auditActor = strings.TrimSpace(result.Audit.ActorID)
	}
	if auditActor == "" {
		auditActor = "システム"
	}

	return DeactivateSuccessData{
		CustomerID:     result.Detail.Profile.ID,
		CustomerName:   customerName,
		Message:        fmt.Sprintf("%s のアカウントを無効化し、個人情報をマスクしました。", customerName),
		AuditID:        result.Audit.ID,
		AuditURL:       auditURL,
		AuditTimestamp: helpers.Date(result.Audit.Timestamp, "2006-01-02 15:04"),
		AuditRelative:  helpers.Relative(result.Audit.Timestamp),
		AuditActor:     auditActor,
	}
}
