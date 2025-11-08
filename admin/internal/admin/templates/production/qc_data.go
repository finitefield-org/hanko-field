package production

import (
	"fmt"
	"net/url"
	"strings"

	adminproduction "finitefield.org/hanko-admin/internal/admin/production"
	"finitefield.org/hanko-admin/internal/admin/templates/helpers"
	"finitefield.org/hanko-admin/internal/admin/templates/partials"
)

// QCPageData encapsulates the SSR payload for the QC page.
type QCPageData struct {
	Title        string
	Description  string
	Error        string
	Alert        string
	Breadcrumbs  []partials.Breadcrumb
	QueueForm    QueueSelector
	Summary      []SummaryChip
	Performance  []SummaryChip
	Filters      QCFilterBar
	Table        QCWorklist
	Drawer       QCDrawerData
	FilterErrors string
}

// QCFilterBar renders the QC filter controls.
type QCFilterBar struct {
	Endpoint     string
	Query        adminproduction.QCQuery
	ProductLines []FilterOption
	IssueTypes   []FilterOption
	Assignees    []FilterOption
	Statuses     []FilterOption
}

// QCWorklist models the QC table.
type QCWorklist struct {
	Rows         []QCRow
	EmptyMessage string
	SelectedID   string
}

// QCRow renders a single QC row.
type QCRow struct {
	ID             string
	OrderNumber    string
	Customer       string
	ProductLine    string
	ItemType       string
	PriorityLabel  string
	PriorityTone   string
	StageLabel     string
	StageTone      string
	Assigned       string
	SLA            string
	SLATone        string
	StatusLabel    string
	StatusTone     string
	IssueHint      string
	PreviewURL     string
	DrawerEndpoint string
	Selected       bool
}

// QCDrawerData powers the action drawer.
type QCDrawerData struct {
	Empty       bool
	Item        QCDrawerHeader
	Checklist   []QCChecklistRow
	Issues      []QCIssueRow
	Attachments []QCAttachmentRow
	Notes       []string
	Decision    QCDecisionForm
}

// QCDrawerHeader summarises the selected QC item.
type QCDrawerHeader struct {
	ID            string
	OrderNumber   string
	Customer      string
	ProductLine   string
	PriorityLabel string
	PriorityTone  string
	StageLabel    string
	StageTone     string
	Assigned      string
	DueLabel      string
	DueTone       string
	PreviewURL    string
}

// QCChecklistRow renders checklist items.
type QCChecklistRow struct {
	Label       string
	Description string
	Required    bool
	Status      string
}

// QCIssueRow renders historical QC issues.
type QCIssueRow struct {
	Category string
	Summary  string
	Actor    string
	Relative string
	Tone     string
}

// QCAttachmentRow renders reference assets.
type QCAttachmentRow struct {
	Label string
	URL   string
	Kind  string
}

// QCDecisionForm powers the pass/fail form.
type QCDecisionForm struct {
	Action        string
	ReasonOptions []QCReasonOption
	ReworkModal   string
	OrderID       string
}

// QCReasonOption renders fail reason select entries.
type QCReasonOption struct {
	Code     string
	Label    string
	Category string
}

// QCReworkModalData powers the rework modal.
type QCReworkModalData struct {
	Title       string
	OrderID     string
	OrderNumber string
	Action      string
	Routes      []QCReworkRouteOption
	Reasons     []QCReasonOption
	Note        string
}

// QCReworkRouteOption renders routing options.
type QCReworkRouteOption struct {
	ID          string
	Label       string
	Description string
}

// BuildQCPageData assembles the QC page payload.
func BuildQCPageData(basePath string, result adminproduction.QCResult, errMsg string) QCPageData {
	selector := buildQCQueueSelector(basePath, result.Queue.ID, result.Queues)
	data := QCPageData{
		Title:       "QCワークフロー",
		Description: "検品結果の記録と再作業の起票を行います。",
		Error:       errMsg,
		Alert:       strings.TrimSpace(result.Alert),
		Breadcrumbs: []partials.Breadcrumb{
			{Label: "受注管理", Href: joinBase(basePath, "/orders")},
			{Label: "制作カンバン", Href: joinBase(basePath, "/production/queues")},
			{Label: "QC", Href: joinBase(basePath, "/production/qc")},
		},
		QueueForm:   selector,
		Summary:     buildQCSummaryChips(result.Summary),
		Performance: buildQCSummaryChips(result.Performance),
		Filters: QCFilterBar{
			Endpoint:     joinBase(basePath, "/production/qc"),
			Query:        result.Filters.Query,
			ProductLines: convertFilterOptions(result.Filters.ProductLines, result.Filters.Query.ProductLine),
			IssueTypes:   convertFilterOptions(result.Filters.IssueTypes, result.Filters.Query.IssueType),
			Assignees:    convertFilterOptions(result.Filters.Assignees, result.Filters.Query.Assignee),
			Statuses:     convertFilterOptions(result.Filters.Statuses, result.Filters.Query.Status),
		},
		Table: QCWorklist{
			Rows:         buildQCRows(basePath, result.Items, result.Filters.Query),
			EmptyMessage: "現在QC待ちの注文はありません。",
			SelectedID:   result.SelectedID,
		},
		Drawer: buildQCDrawerData(basePath, result.Drawer, result.Filters.Query),
	}
	if data.QueueForm.Selected == "" {
		data.QueueForm.Selected = result.Queue.ID
	}
	return data
}

// BuildQCDrawer constructs the drawer fragment for HTMX swaps.
func BuildQCDrawer(basePath string, inspector adminproduction.QCInspector, query adminproduction.QCQuery) QCDrawerData {
	return buildQCDrawerData(basePath, inspector, query)
}

// BuildQCReworkModal assembles the rework modal payload.
func BuildQCReworkModal(basePath, orderID string, inspector adminproduction.QCInspector, query adminproduction.QCQuery) QCReworkModalData {
	data := QCReworkModalData{
		Title:   "再作業を割り当て",
		OrderID: orderID,
		Action:  joinBase(basePath, fmt.Sprintf("/production/qc/orders/%s/rework%s", url.PathEscape(orderID), qcQueryString(query, ""))),
		Reasons: buildReasonOptions(inspector.Reasons),
	}
	if inspector.Item.ID != "" {
		data.OrderNumber = inspector.Item.OrderNumber
	}
	data.Routes = buildRouteOptions(inspector.ReworkRoutes)
	return data
}

func buildQCSummaryChips(values []adminproduction.QCSummary) []SummaryChip {
	if len(values) == 0 {
		return nil
	}
	chips := make([]SummaryChip, 0, len(values))
	for _, value := range values {
		chips = append(chips, SummaryChip{
			Label:   value.Label,
			Value:   value.Value,
			SubText: value.SubText,
			Tone:    value.Tone,
			Icon:    value.Icon,
		})
	}
	return chips
}

func buildQCRows(basePath string, items []adminproduction.QCItem, query adminproduction.QCQuery) []QCRow {
	rows := make([]QCRow, 0, len(items))
	for _, item := range items {
		row := QCRow{
			ID:             item.ID,
			OrderNumber:    item.OrderNumber,
			Customer:       item.Customer,
			ProductLine:    item.ProductLine,
			ItemType:       item.ItemType,
			PriorityLabel:  item.PriorityLabel,
			PriorityTone:   item.PriorityTone,
			StageLabel:     item.StageLabel,
			StageTone:      item.StageTone,
			Assigned:       item.Assigned,
			SLA:            item.SLA,
			SLATone:        item.SLATone,
			StatusLabel:    item.StatusLabel,
			StatusTone:     item.StatusTone,
			IssueHint:      item.IssueHint,
			PreviewURL:     item.PreviewURL,
			DrawerEndpoint: joinBase(basePath, fmt.Sprintf("/production/qc/orders/%s/drawer%s", url.PathEscape(item.ID), qcQueryString(query, item.ID))),
			Selected:       query.Selected == item.ID,
		}
		rows = append(rows, row)
	}
	return rows
}

func buildQCDrawerData(basePath string, inspector adminproduction.QCInspector, query adminproduction.QCQuery) QCDrawerData {
	if inspector.Empty || inspector.Item.ID == "" {
		return QCDrawerData{Empty: true}
	}
	header := QCDrawerHeader{
		ID:            inspector.Item.ID,
		OrderNumber:   inspector.Item.OrderNumber,
		Customer:      inspector.Item.Customer,
		ProductLine:   inspector.Item.ProductLine,
		PriorityLabel: inspector.Item.PriorityLabel,
		PriorityTone:  inspector.Item.PriorityTone,
		StageLabel:    inspector.Item.StageLabel,
		StageTone:     inspector.Item.StageTone,
		Assigned:      inspector.Item.Assigned,
		DueLabel:      inspector.Item.DueLabel,
		DueTone:       inspector.Item.DueTone,
		PreviewURL:    inspector.Item.PreviewURL,
	}
	data := QCDrawerData{
		Item:        header,
		Checklist:   buildChecklistRows(inspector.Checklist),
		Issues:      buildIssueRows(inspector.Issues),
		Attachments: buildAttachmentRows(inspector.Attachments),
		Notes:       append([]string(nil), inspector.Notes...),
		Decision: QCDecisionForm{
			Action:        joinBase(basePath, fmt.Sprintf("/production/qc/orders/%s/decision%s", url.PathEscape(inspector.Item.ID), qcQueryString(query, inspector.Item.ID))),
			ReasonOptions: buildReasonOptions(inspector.Reasons),
			ReworkModal:   joinBase(basePath, fmt.Sprintf("/production/qc/orders/%s/modal/rework%s", url.PathEscape(inspector.Item.ID), qcQueryString(query, inspector.Item.ID))),
			OrderID:       inspector.Item.ID,
		},
	}
	return data
}

func buildChecklistRows(items []adminproduction.QCChecklistItem) []QCChecklistRow {
	rows := make([]QCChecklistRow, 0, len(items))
	for _, item := range items {
		rows = append(rows, QCChecklistRow{
			Label:       item.Label,
			Description: item.Description,
			Required:    item.Required,
			Status:      strings.TrimSpace(item.Status),
		})
	}
	return rows
}

func buildIssueRows(items []adminproduction.QCIssueRecord) []QCIssueRow {
	rows := make([]QCIssueRow, 0, len(items))
	for _, issue := range items {
		rows = append(rows, QCIssueRow{
			Category: issue.Category,
			Summary:  issue.Summary,
			Actor:    issue.Actor,
			Relative: helpers.Relative(issue.CreatedAt),
			Tone:     issue.Tone,
		})
	}
	return rows
}

func buildAttachmentRows(items []adminproduction.QCAttachment) []QCAttachmentRow {
	rows := make([]QCAttachmentRow, 0, len(items))
	for _, attachment := range items {
		rows = append(rows, QCAttachmentRow{
			Label: attachment.Label,
			URL:   attachment.URL,
			Kind:  attachment.Kind,
		})
	}
	return rows
}

func buildReasonOptions(items []adminproduction.QCReason) []QCReasonOption {
	options := make([]QCReasonOption, 0, len(items))
	for _, item := range items {
		options = append(options, QCReasonOption{
			Code:     item.Code,
			Label:    item.Label,
			Category: item.Category,
		})
	}
	return options
}

func buildRouteOptions(routes []adminproduction.QCReworkRoute) []QCReworkRouteOption {
	options := make([]QCReworkRouteOption, 0, len(routes))
	for _, route := range routes {
		options = append(options, QCReworkRouteOption{
			ID:          route.ID,
			Label:       route.Label,
			Description: route.Description,
		})
	}
	return options
}

func convertFilterOptions(options []adminproduction.FilterOption, active string) []FilterOption {
	if len(options) == 0 {
		return nil
	}
	result := make([]FilterOption, 0, len(options))
	for _, option := range options {
		result = append(result, FilterOption{
			Value:  option.Value,
			Label:  option.Label,
			Count:  option.Count,
			Active: strings.EqualFold(option.Value, active),
		})
	}
	return result
}

func qcQueryString(query adminproduction.QCQuery, selected string) string {
	values := url.Values{}
	if query.QueueID != "" {
		values.Set("queue", query.QueueID)
	}
	if query.ProductLine != "" {
		values.Set("product_line", query.ProductLine)
	}
	if query.IssueType != "" {
		values.Set("issue_type", query.IssueType)
	}
	if query.Assignee != "" {
		values.Set("assignee", query.Assignee)
	}
	if query.Status != "" {
		values.Set("status", query.Status)
	}
	if selected != "" {
		values.Set("selected", selected)
	} else if query.Selected != "" {
		values.Set("selected", query.Selected)
	}
	raw := values.Encode()
	if raw == "" {
		return ""
	}
	return "?" + raw
}

func buildQCQueueSelector(basePath, selected string, options []adminproduction.QueueOption) QueueSelector {
	selector := QueueSelector{
		Endpoint: joinBase(basePath, "/production/qc"),
		Selected: strings.TrimSpace(selected),
	}
	if len(options) == 0 {
		return selector
	}
	for _, opt := range options {
		active := opt.Active
		if !active && selector.Selected != "" {
			active = opt.ID == selector.Selected
		}
		if active {
			selector.Selected = opt.ID
		}
		selector.Options = append(selector.Options, QueueOption{
			ID:       opt.ID,
			Label:    opt.Label,
			Sublabel: opt.Sublabel,
			Load:     opt.Load,
			Active:   active,
		})
	}
	if selector.Selected == "" && len(selector.Options) > 0 {
		selector.Options[0].Active = true
		selector.Selected = selector.Options[0].ID
	}
	return selector
}
