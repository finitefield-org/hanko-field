package productionqueues

import (
	"fmt"
	"net/url"
	"sort"
	"strings"

	adminproduction "finitefield.org/hanko-admin/internal/admin/production"
	"finitefield.org/hanko-admin/internal/admin/templates/helpers"
	"finitefield.org/hanko-admin/internal/admin/templates/partials"
)

const (
	tableContainerID  = "production-queues-table"
	drawerContainerID = "production-queues-drawer"
)

// PageData encapsulates the SSR payload for the production queue settings page.
type PageData struct {
	Title       string
	Description string
	Breadcrumbs []partials.Breadcrumb
	Filters     FilterBarData
	Analytics   []AnalyticsCard
	Table       QueueTableData
	Drawer      DrawerData
	Query       QueryState
	Actions     PageActions
	Error       string
}

// PageActions groups primary page-level actions.
type PageActions struct {
	NewQueueURL string
}

// QueryState mirrors the active query string parameters.
type QueryState struct {
	Workshop    string
	Status      string
	ProductLine string
	Search      string
	SelectedID  string
	RawQuery    string
}

// Encode serialises the query state into a URL encoded string.
func (q QueryState) Encode() string {
	values := url.Values{}
	if q.Workshop != "" {
		values.Set("workshop", q.Workshop)
	}
	if q.Status != "" {
		values.Set("status", q.Status)
	}
	if q.ProductLine != "" {
		values.Set("product_line", q.ProductLine)
	}
	if q.Search != "" {
		values.Set("search", q.Search)
	}
	if q.SelectedID != "" {
		values.Set("selected", q.SelectedID)
	}
	return values.Encode()
}

// FilterBarData powers the filter toolbar on the settings page.
type FilterBarData struct {
	Endpoint     string
	ResetURL     string
	Workshops    []FilterOption
	Statuses     []FilterOption
	ProductLines []FilterOption
	Query        QueryState
}

// FilterOption represents a selectable filter choice with counts.
type FilterOption struct {
	Label  string
	Value  string
	Count  int
	Active bool
}

// AnalyticsCard renders headline analytics for the queue list.
type AnalyticsCard struct {
	Label    string
	Value    string
	SubLabel string
	Tone     string
	Icon     string
}

// QueueTableData describes the queue list table fragment.
type QueueTableData struct {
	Rows         []QueueRow
	FragmentPath string
	RawQuery     string
	EmptyMessage string
	Error        string
	SelectedID   string
	HxTarget     string
	HxSwap       string
	DrawerTarget string
}

// QueueRow represents a single queue in the table.
type QueueRow struct {
	ID               string
	Name             string
	PriorityLabel    string
	PriorityTone     string
	Workshop         string
	ProductLine      string
	CapacityLabel    string
	SLALabel         string
	ThroughputLabel  string
	UtilisationLabel string
	UtilisationTone  string
	Active           bool
	ActiveLabel      string
	ToggleURL        string
	EditURL          string
	DeleteURL        string
	DrawerURL        string
	Selected         bool
}

// DrawerData powers the right-hand drawer panel.
type DrawerData struct {
	Empty   bool
	Queue   DrawerQueue
	Actions DrawerActions
}

// DrawerActions exposes contextual links for the drawer.
type DrawerActions struct {
	EditURL   string
	DeleteURL string
}

// DrawerQueue summarises the selected queue for the detail panel.
type DrawerQueue struct {
	ID                 string
	Name               string
	Active             bool
	ActiveLabel        string
	ActiveTone         string
	UpdatedAt          string
	UpdatedRelative    string
	Description        string
	Workshop           string
	ProductLine        string
	CapacityLabel      string
	TargetSLALabel     string
	ThroughputLabel    string
	UtilisationLabel   string
	SLAComplianceLabel string
	Notes              []string
	Stages             []StageView
	Roles              []RoleView
	WorkCenters        []WorkCenterView
}

// StageView renders a single stage definition.
type StageView struct {
	Code           string
	Label          string
	WIPLabel       string
	TargetSLALabel string
	Description    string
}

// RoleView renders staffing assignments.
type RoleView struct {
	Label          string
	HeadcountLabel string
}

// WorkCenterView renders work center assignments.
type WorkCenterView struct {
	Name       string
	Location   string
	Capability string
	Primary    bool
	Active     bool
}

// UpsertModalData powers the create/edit queue modal.
type UpsertModalData struct {
	Title       string
	Description string
	ActionURL   string
	Method      string
	SubmitLabel string
	CSRFToken   string
	Error       string
	Form        QueueFormModel
	Options     QueueFormOptions
	ReturnQuery string
}

// QueueFormModel captures the current queue values for the modal form.
type QueueFormModel struct {
	ID                  string
	Name                string
	Workshop            string
	ProductLine         string
	Priority            int
	Capacity            int
	TargetSLAHours      int
	Active              bool
	Description         string
	Notes               string
	SelectedWorkCenters []string
	PrimaryWorkCenter   string
	RoleHeadcounts      map[string]int
	Stages              []StageForm
}

// QueueFormOptions enumerates selectable options for the queue form.
type QueueFormOptions struct {
	WorkCenters            []WorkCenterOption
	RoleOptions            []RoleOption
	StageTemplates         []StageForm
	PriorityOptions        []PriorityOption
	WorkshopSuggestions    []string
	ProductLineSuggestions []string
}

// WorkCenterOption represents a selectable work center in the form.
type WorkCenterOption struct {
	ID       string
	Label    string
	Subtitle string
	Active   bool
}

// RoleOption represents a role row with suggested headcount.
type RoleOption struct {
	Key                string
	Label              string
	SuggestedHeadcount int
}

// PriorityOption renders the priority select input.
type PriorityOption struct {
	Value int
	Label string
}

// StageForm binds stage fields inside the modal.
type StageForm struct {
	Code           string
	Label          string
	Description    string
	WIPLimit       int
	TargetSLAHours int
	Sequence       int
}

// DeleteModalData powers the queue delete confirmation modal.
type DeleteModalData struct {
	Title       string
	Description string
	ActionURL   string
	Method      string
	CSRFToken   string
	QueueName   string
	Error       string
	ReturnQuery string
}

// BuildPageData assembles the SSR payload for the queue settings page.
func BuildPageData(basePath string, state QueryState, result adminproduction.QueueSettingsResult, detail *adminproduction.QueueDefinition, errMsg string) PageData {
	state.RawQuery = state.Encode()
	return PageData{
		Title:       "制作キュー設定",
		Description: "制作チームのキュー容量、SLA、担当アサインを管理します。",
		Breadcrumbs: []partials.Breadcrumb{
			{Label: "制作", Href: joinBase(basePath, "/production/queues")},
			{Label: "キュー設定"},
		},
		Filters:   buildFilterBar(basePath, state, result.Filters, result.Summary),
		Analytics: buildAnalyticsCards(result.Analytics, result.Summary),
		Table:     buildTableData(basePath, state, result.Queues),
		Drawer:    buildDrawerData(basePath, state.SelectedID, detail),
		Query:     state,
		Actions: PageActions{
			NewQueueURL: joinBase(basePath, "/production-queues/modal/new"),
		},
		Error: errMsg,
	}
}

// BuildUpsertModalData assembles the modal payload for queue creation/updating.
func BuildUpsertModalData(basePath string, csrfToken string, queue *adminproduction.QueueDefinition, options adminproduction.QueueSettingsOptions, existing []adminproduction.QueueDefinition, returnQuery string, errMsg string) UpsertModalData {
	isEdit := queue != nil && strings.TrimSpace(queue.ID) != ""
	formOptions := buildFormOptions(options, existing)

	var form QueueFormModel
	if isEdit {
		form = buildFormModelFromQueue(queue)
		form.Stages = ensureStages(form.Stages, formOptions.StageTemplates)
	} else {
		form = buildDefaultFormModel(formOptions.StageTemplates, options)
	}
	form.RoleHeadcounts = mergeRoleHeadcounts(form.RoleHeadcounts, formOptions.RoleOptions)

	title := "制作キューを追加"
	submit := "追加する"
	action := joinBase(basePath, "/production-queues")
	method := "POST"
	if isEdit {
		title = "制作キューを編集"
		submit = "更新する"
		action = joinBase(basePath, fmt.Sprintf("/production-queues/%s", queue.ID))
		method = "PUT"
		form.ID = queue.ID
	}

	return UpsertModalData{
		Title:       title,
		Description: "容量とSLA、割り当て先ワークセンターを更新します。",
		ActionURL:   action,
		Method:      method,
		SubmitLabel: submit,
		CSRFToken:   csrfToken,
		Error:       errMsg,
		Form:        form,
		Options:     formOptions,
		ReturnQuery: returnQuery,
	}
}

// BuildDeleteModalData assembles the modal payload for queue deletion.
func BuildDeleteModalData(basePath string, queue adminproduction.QueueDefinition, csrfToken string, returnQuery string, errMsg string) DeleteModalData {
	return DeleteModalData{
		Title:       "制作キューを削除",
		Description: fmt.Sprintf("%s を削除すると、関連する割り当て設定は失われます。", strings.TrimSpace(queue.Name)),
		ActionURL:   joinBase(basePath, fmt.Sprintf("/production-queues/%s", queue.ID)),
		Method:      "DELETE",
		CSRFToken:   csrfToken,
		QueueName:   queue.Name,
		Error:       errMsg,
		ReturnQuery: returnQuery,
	}
}

func buildFilterBar(basePath string, state QueryState, filters adminproduction.QueueSettingsFilters, summary adminproduction.QueueSettingsSummary) FilterBarData {
	total := summary.TotalQueues

	workshops := make([]FilterOption, 0, len(filters.Workshops)+1)
	workshops = append(workshops, FilterOption{
		Label:  "すべての工房",
		Value:  "",
		Count:  total,
		Active: state.Workshop == "",
	})
	for _, option := range filters.Workshops {
		workshops = append(workshops, FilterOption{
			Label:  option.Label,
			Value:  option.Value,
			Count:  option.Count,
			Active: strings.EqualFold(option.Value, state.Workshop),
		})
	}

	statuses := make([]FilterOption, 0, len(filters.Statuses)+1)
	statuses = append(statuses, FilterOption{
		Label:  "すべてのステータス",
		Value:  "",
		Count:  total,
		Active: state.Status == "",
	})
	for _, option := range filters.Statuses {
		statuses = append(statuses, FilterOption{
			Label:  option.Label,
			Value:  option.Value,
			Count:  option.Count,
			Active: strings.EqualFold(option.Value, state.Status),
		})
	}

	productLines := make([]FilterOption, 0, len(filters.ProductLines)+1)
	productLines = append(productLines, FilterOption{
		Label:  "すべてのライン",
		Value:  "",
		Count:  total,
		Active: state.ProductLine == "",
	})
	for _, option := range filters.ProductLines {
		productLines = append(productLines, FilterOption{
			Label:  option.Label,
			Value:  option.Value,
			Count:  option.Count,
			Active: strings.EqualFold(option.Value, state.ProductLine),
		})
	}

	return FilterBarData{
		Endpoint:     joinBase(basePath, "/production-queues/table"),
		ResetURL:     joinBase(basePath, "/production-queues"),
		Workshops:    workshops,
		Statuses:     statuses,
		ProductLines: productLines,
		Query:        state,
	}
}

func buildAnalyticsCards(analytics adminproduction.QueueAnalytics, summary adminproduction.QueueSettingsSummary) []AnalyticsCard {
	throughput := AnalyticsCard{
		Label:    "平均スループット",
		Value:    fmt.Sprintf("%.0f 件/シフト", analytics.AverageThroughputPerShift),
		SubLabel: fmt.Sprintf("対象キュー %d 件", summary.TotalQueues),
		Tone:     "info",
		Icon:     "⚙️",
	}
	utilPercent := analytics.AverageWIPUtilisation * 100
	utilTone := "success"
	switch {
	case utilPercent >= 90:
		utilTone = "danger"
	case utilPercent >= 75:
		utilTone = "warning"
	}
	utilisation := AnalyticsCard{
		Label:    "平均WIP利用率",
		Value:    fmt.Sprintf("%.0f%%", utilPercent),
		SubLabel: fmt.Sprintf("SLA平均 %.0f 時間", summary.AverageSLAHours),
		Tone:     utilTone,
		Icon:     "📊",
	}
	return []AnalyticsCard{throughput, utilisation}
}

func buildTableData(basePath string, state QueryState, queues []adminproduction.QueueDefinition) QueueTableData {
	rows := make([]QueueRow, 0, len(queues))
	for _, queue := range queues {
		rows = append(rows, buildTableRow(basePath, queue, state.SelectedID))
	}
	return QueueTableData{
		Rows:         rows,
		FragmentPath: joinBase(basePath, "/production-queues/table"),
		RawQuery:     state.RawQuery,
		EmptyMessage: "条件に一致するキューがありません。フィルタを調整してください。",
		HxTarget:     "#" + tableContainerID,
		HxSwap:       "outerHTML",
		DrawerTarget: "#" + drawerContainerID,
		SelectedID:   state.SelectedID,
	}
}

func buildTableRow(basePath string, queue adminproduction.QueueDefinition, selectedID string) QueueRow {
	utilPercent := queue.Metrics.WIPUtilisation * 100
	utilTone := "success"
	switch {
	case utilPercent >= 90:
		utilTone = "danger"
	case utilPercent >= 75:
		utilTone = "warning"
	}

	activeLabel := "停止中"
	if queue.Active {
		activeLabel = "稼働中"
	}

	return QueueRow{
		ID:               queue.ID,
		Name:             queue.Name,
		PriorityLabel:    queue.PriorityLabel,
		PriorityTone:     priorityTone(queue.Priority),
		Workshop:         queue.Workshop,
		ProductLine:      queue.ProductLine,
		CapacityLabel:    fmt.Sprintf("%d 件", queue.Capacity),
		SLALabel:         fmt.Sprintf("%d 時間", queue.TargetSLAHours),
		ThroughputLabel:  fmt.Sprintf("%.0f 件/シフト", queue.Metrics.ThroughputPerShift),
		UtilisationLabel: fmt.Sprintf("%.0f%%", utilPercent),
		UtilisationTone:  utilTone,
		Active:           queue.Active,
		ActiveLabel:      activeLabel,
		ToggleURL:        joinBase(basePath, fmt.Sprintf("/production-queues/%s/toggle", queue.ID)),
		EditURL:          joinBase(basePath, fmt.Sprintf("/production-queues/%s/modal/edit", queue.ID)),
		DeleteURL:        joinBase(basePath, fmt.Sprintf("/production-queues/%s/modal/delete", queue.ID)),
		DrawerURL:        joinBase(basePath, fmt.Sprintf("/production-queues/%s/drawer", queue.ID)),
		Selected:         selectedID != "" && strings.EqualFold(queue.ID, selectedID),
	}
}

func buildDrawerData(basePath, selectedID string, detail *adminproduction.QueueDefinition) DrawerData {
	if detail == nil || strings.TrimSpace(selectedID) == "" || !strings.EqualFold(detail.ID, selectedID) {
		return DrawerData{
			Empty: true,
			Queue: DrawerQueue{},
			Actions: DrawerActions{
				EditURL:   "",
				DeleteURL: "",
			},
		}
	}

	queueView := DrawerQueue{
		ID:                 detail.ID,
		Name:               detail.Name,
		Active:             detail.Active,
		ActiveLabel:        activeLabel(detail.Active),
		ActiveTone:         activeTone(detail.Active),
		UpdatedAt:          helpers.Date(detail.UpdatedAt, "2006-01-02 15:04"),
		UpdatedRelative:    helpers.Relative(detail.UpdatedAt),
		Description:        strings.TrimSpace(detail.Description),
		Workshop:           detail.Workshop,
		ProductLine:        detail.ProductLine,
		CapacityLabel:      fmt.Sprintf("%d 件", detail.Capacity),
		TargetSLALabel:     fmt.Sprintf("%d 時間以内", detail.TargetSLAHours),
		ThroughputLabel:    fmt.Sprintf("平均 %.0f 件/シフト", detail.Metrics.ThroughputPerShift),
		UtilisationLabel:   fmt.Sprintf("平均 %.0f%% WIP", detail.Metrics.WIPUtilisation*100),
		SLAComplianceLabel: fmt.Sprintf("SLA達成率 %.0f%%", detail.Metrics.SLACompliance*100),
		Notes:              copyStrings(detail.Notes),
		Stages:             buildStageViews(detail.Stages),
		Roles:              buildRoleViews(detail.Roles),
		WorkCenters:        buildWorkCenterViews(detail.WorkCenters),
	}

	return DrawerData{
		Empty: false,
		Queue: queueView,
		Actions: DrawerActions{
			EditURL:   joinBase(basePath, fmt.Sprintf("/production-queues/%s/modal/edit", detail.ID)),
			DeleteURL: joinBase(basePath, fmt.Sprintf("/production-queues/%s/modal/delete", detail.ID)),
		},
	}
}

func buildStageViews(stages []adminproduction.QueueStage) []StageView {
	if len(stages) == 0 {
		return nil
	}
	out := make([]StageView, 0, len(stages))
	for _, stage := range stages {
		out = append(out, StageView{
			Code:           string(stage.Code),
			Label:          stage.Label,
			WIPLabel:       fmt.Sprintf("WIP上限 %d 件", stage.WIPLimit),
			TargetSLALabel: fmt.Sprintf("目標 %d 時間", stage.TargetSLAHours),
			Description:    stage.Description,
		})
	}
	return out
}

func buildRoleViews(roles []adminproduction.QueueRoleAssignment) []RoleView {
	if len(roles) == 0 {
		return nil
	}
	out := make([]RoleView, 0, len(roles))
	for _, role := range roles {
		out = append(out, RoleView{
			Label:          role.Label,
			HeadcountLabel: fmt.Sprintf("%d 名", role.Headcount),
		})
	}
	return out
}

func buildWorkCenterViews(centers []adminproduction.QueueWorkCenterAssignment) []WorkCenterView {
	if len(centers) == 0 {
		return nil
	}
	out := make([]WorkCenterView, 0, len(centers))
	for _, assignment := range centers {
		center := assignment.WorkCenter
		out = append(out, WorkCenterView{
			Name:       center.Name,
			Location:   center.Location,
			Capability: center.Capability,
			Primary:    assignment.Primary,
			Active:     center.Active,
		})
	}
	return out
}

func buildFormModelFromQueue(queue *adminproduction.QueueDefinition) QueueFormModel {
	form := QueueFormModel{
		ID:             queue.ID,
		Name:           queue.Name,
		Workshop:       queue.Workshop,
		ProductLine:    queue.ProductLine,
		Priority:       queue.Priority,
		Capacity:       queue.Capacity,
		TargetSLAHours: queue.TargetSLAHours,
		Active:         queue.Active,
		Description:    queue.Description,
		Notes:          strings.Join(copyStrings(queue.Notes), "\n"),
		RoleHeadcounts: make(map[string]int),
	}
	if len(queue.Stages) > 0 {
		form.Stages = make([]StageForm, 0, len(queue.Stages))
		for _, stage := range queue.Stages {
			form.Stages = append(form.Stages, StageForm{
				Code:           string(stage.Code),
				Label:          stage.Label,
				Description:    stage.Description,
				WIPLimit:       stage.WIPLimit,
				TargetSLAHours: stage.TargetSLAHours,
				Sequence:       stage.Sequence,
			})
		}
	}
	selectedCenters := make([]string, 0, len(queue.WorkCenters))
	for _, assignment := range queue.WorkCenters {
		selectedCenters = append(selectedCenters, assignment.WorkCenter.ID)
		if assignment.Primary {
			form.PrimaryWorkCenter = assignment.WorkCenter.ID
		}
	}
	form.SelectedWorkCenters = selectedCenters
	for _, role := range queue.Roles {
		form.RoleHeadcounts[strings.TrimSpace(role.Key)] = role.Headcount
	}
	return form
}

func buildDefaultFormModel(stageTemplates []StageForm, options adminproduction.QueueSettingsOptions) QueueFormModel {
	form := QueueFormModel{
		Priority:       2,
		Capacity:       12,
		TargetSLAHours: 36,
		Active:         true,
		RoleHeadcounts: make(map[string]int),
		Stages:         stageTemplates,
	}
	if len(options.WorkCenters) > 0 {
		form.SelectedWorkCenters = []string{options.WorkCenters[0].ID}
		form.PrimaryWorkCenter = options.WorkCenters[0].ID
	}
	for _, role := range options.RoleOptions {
		form.RoleHeadcounts[strings.TrimSpace(role.Key)] = role.SuggestedHeadcount
	}
	return form
}

func ensureStages(current []StageForm, templates []StageForm) []StageForm {
	if len(current) > 0 {
		return current
	}
	if len(templates) == 0 {
		return nil
	}
	out := make([]StageForm, len(templates))
	copy(out, templates)
	return out
}

func mergeRoleHeadcounts(existing map[string]int, options []RoleOption) map[string]int {
	if existing == nil {
		existing = make(map[string]int)
	}
	for _, option := range options {
		key := strings.TrimSpace(option.Key)
		if key == "" {
			continue
		}
		if _, ok := existing[key]; !ok {
			existing[key] = option.SuggestedHeadcount
		}
	}
	return existing
}

func buildFormOptions(options adminproduction.QueueSettingsOptions, queues []adminproduction.QueueDefinition) QueueFormOptions {
	workCenters := make([]WorkCenterOption, 0, len(options.WorkCenters))
	for _, center := range options.WorkCenters {
		label := center.Name
		subtitle := strings.TrimSpace(center.Location)
		if center.Capability != "" {
			if subtitle != "" {
				subtitle = subtitle + " · " + center.Capability
			} else {
				subtitle = center.Capability
			}
		}
		workCenters = append(workCenters, WorkCenterOption{
			ID:       center.ID,
			Label:    label,
			Subtitle: subtitle,
			Active:   center.Active,
		})
	}

	roleOptions := make([]RoleOption, 0, len(options.RoleOptions))
	for _, role := range options.RoleOptions {
		roleOptions = append(roleOptions, RoleOption{
			Key:                role.Key,
			Label:              role.Label,
			SuggestedHeadcount: role.SuggestedHeadcount,
		})
	}

	stageTemplates := make([]StageForm, 0, len(options.StageTemplates))
	for _, stage := range options.StageTemplates {
		stageTemplates = append(stageTemplates, StageForm{
			Code:           string(stage.Code),
			Label:          stage.Label,
			Description:    stage.Description,
			WIPLimit:       stage.WIPLimit,
			TargetSLAHours: stage.TargetSLAHours,
			Sequence:       stage.Sequence,
		})
	}
	if len(stageTemplates) == 0 {
		for _, queue := range queues {
			if len(queue.Stages) == 0 {
				continue
			}
			stageTemplates = make([]StageForm, 0, len(queue.Stages))
			for _, stage := range queue.Stages {
				stageTemplates = append(stageTemplates, StageForm{
					Code:           string(stage.Code),
					Label:          stage.Label,
					Description:    stage.Description,
					WIPLimit:       stage.WIPLimit,
					TargetSLAHours: stage.TargetSLAHours,
					Sequence:       stage.Sequence,
				})
			}
			break
		}
	}

	priorityOptions := []PriorityOption{
		{Value: 1, Label: "P1 - 最優先"},
		{Value: 2, Label: "P2 - 高優先"},
		{Value: 3, Label: "P3 - 通常"},
		{Value: 4, Label: "P4 - 低優先"},
		{Value: 5, Label: "P5 - 保留"},
	}

	workshopSuggestions := make([]string, 0)
	productLineSuggestions := make([]string, 0)
	workshopSet := make(map[string]bool)
	productSet := make(map[string]bool)
	for _, queue := range queues {
		if w := strings.TrimSpace(queue.Workshop); w != "" && !workshopSet[strings.ToLower(w)] {
			workshopSet[strings.ToLower(w)] = true
			workshopSuggestions = append(workshopSuggestions, w)
		}
		if p := strings.TrimSpace(queue.ProductLine); p != "" && !productSet[strings.ToLower(p)] {
			productSet[strings.ToLower(p)] = true
			productLineSuggestions = append(productLineSuggestions, p)
		}
	}
	sort.Strings(workshopSuggestions)
	sort.Strings(productLineSuggestions)

	return QueueFormOptions{
		WorkCenters:            workCenters,
		RoleOptions:            roleOptions,
		StageTemplates:         stageTemplates,
		PriorityOptions:        priorityOptions,
		WorkshopSuggestions:    workshopSuggestions,
		ProductLineSuggestions: productLineSuggestions,
	}
}

func activeLabel(active bool) string {
	if active {
		return "稼働中"
	}
	return "停止中"
}

func activeTone(active bool) string {
	if active {
		return "success"
	}
	return "warning"
}

func priorityTone(priority int) string {
	switch {
	case priority <= 1:
		return "danger"
	case priority == 2:
		return "warning"
	case priority >= 4:
		return "muted"
	default:
		return "info"
	}
}

func copyStrings(values []string) []string {
	if len(values) == 0 {
		return nil
	}
	out := make([]string, 0, len(values))
	for _, value := range values {
		if trimmed := strings.TrimSpace(value); trimmed != "" {
			out = append(out, trimmed)
		}
	}
	if len(out) == 0 {
		return nil
	}
	return out
}

func joinBase(base, suffix string) string {
	b := strings.TrimRight(base, "/")
	if !strings.HasPrefix(suffix, "/") {
		suffix = "/" + suffix
	}
	return b + suffix
}
