package customers

import (
	"context"
	"encoding/json"
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
	ImpactsJSON        string
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
func DeactivateModalPayload(ctx context.Context, basePath string, modal admincustomers.DeactivateModal, csrfToken string, form DeactivateFormState) DeactivateModalData {
	meta := DeactivateModalMetaFromModal(ctx, basePath, modal)
	return meta.ToData(csrfToken, form)
}

// DeactivateModalMeta captures immutable modal fields passed between form submits.
type DeactivateModalMeta struct {
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
	Impacts            []DeactivateImpactItem
}

// DeactivateModalMetaFromModal builds persistent modal metadata from service output.
func DeactivateModalMetaFromModal(ctx context.Context, basePath string, modal admincustomers.DeactivateModal) DeactivateModalMeta {
	formatter := helpers.NewFormatter(ctx)
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
	statusLabel := statusLabel(formatter, modal.Status)
	statusTone := statusTone(modal.Status)

	actionURL := joinBase(basePath, fmt.Sprintf("/customers/%s:deactivate-and-mask", url.PathEscape(strings.TrimSpace(modal.CustomerID))))

	impacts := make([]DeactivateImpactItem, 0, len(modal.Impacts))
	for _, impact := range modal.Impacts {
		impacts = append(impacts, DeactivateImpactItem{
			Title:       impact.Title,
			Description: impact.Description,
			Icon:        impact.Icon,
			Tone:        impact.Tone,
		})
	}

	return DeactivateModalMeta{
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
		Impacts:            impacts,
	}
}

// ToData converts modal metadata into template data with form state.
func (m DeactivateModalMeta) ToData(csrfToken string, form DeactivateFormState) DeactivateModalData {
	if form.FieldErrors == nil {
		form.FieldErrors = make(map[string]string)
	}
	impacts := m.Impacts
	if len(impacts) == 0 {
		impacts = defaultDeactivateImpacts()
	}
	payload, err := json.Marshal(impacts)
	if err != nil {
		payload = nil
	}
	return DeactivateModalData{
		CustomerID:         m.CustomerID,
		CustomerName:       m.CustomerName,
		Email:              m.Email,
		StatusLabel:        m.StatusLabel,
		StatusTone:         m.StatusTone,
		TotalOrdersLabel:   m.TotalOrdersLabel,
		LifetimeValueLabel: m.LifetimeValueLabel,
		LastOrderLabel:     m.LastOrderLabel,
		ConfirmationPhrase: m.ConfirmationPhrase,
		ActionURL:          m.ActionURL,
		CSRFToken:          csrfToken,
		Impacts:            impacts,
		ImpactsJSON:        string(payload),
		Form:               form,
	}
}

func defaultDeactivateImpacts() []DeactivateImpactItem {
	return []DeactivateImpactItem{
		{
			Title:       "サインイン権限を即時停止",
			Description: "顧客は以後、アプリやウェブからログインできなくなります。",
			Icon:        "🚫",
			Tone:        "danger",
		},
		{
			Title:       "個人情報を匿名化",
			Description: "氏名・メール・電話番号などのPIIをマスクし、通知も停止します。",
			Icon:        "🛡️",
			Tone:        "warning",
		},
		{
			Title:       "注文・請求データは保持",
			Description: "会計・レポート用途のため、注文履歴と請求記録は削除されません。",
			Icon:        "📦",
			Tone:        "info",
		},
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
