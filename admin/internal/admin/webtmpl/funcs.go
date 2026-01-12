package webtmpl

import (
	"context"
	"fmt"
	"html/template"
	"path"
	"reflect"
	"strconv"
	"strings"
	"time"
	"unicode"

	"finitefield.org/hanko-admin/internal/admin/httpserver/middleware"
	"finitefield.org/hanko-admin/internal/admin/i18n"
	"finitefield.org/hanko-admin/internal/admin/navigation"
	"finitefield.org/hanko-admin/internal/admin/profile"
	"finitefield.org/hanko-admin/internal/admin/rbac"
	catalogtpl "finitefield.org/hanko-admin/internal/admin/templates/catalog"
	"finitefield.org/hanko-admin/internal/admin/templates/components"
	financetpl "finitefield.org/hanko-admin/internal/admin/templates/finance"
	guidestpl "finitefield.org/hanko-admin/internal/admin/templates/guides"
	"finitefield.org/hanko-admin/internal/admin/templates/helpers"
	productiontpl "finitefield.org/hanko-admin/internal/admin/templates/production"
	profiletpl "finitefield.org/hanko-admin/internal/admin/templates/profile"
	promotionstpl "finitefield.org/hanko-admin/internal/admin/templates/promotions"
	systemtpl "finitefield.org/hanko-admin/internal/admin/templates/system"
)

var templateFuncs = template.FuncMap{
	"badgeClass":                         helpers.BadgeClass,
	"navClass":                           helpers.NavClass,
	"localize":                           localize,
	"localeDisplayName":                  localeDisplayName,
	"trimSpace":                          strings.TrimSpace,
	"equalFold":                          strings.EqualFold,
	"isLast":                             isLast,
	"hasCap":                             hasCapability,
	"visibleMenuGroups":                  visibleMenuGroups,
	"navActive":                          navActive,
	"environmentTone":                    environmentTone,
	"environmentLabel":                   environmentLabel,
	"environmentDisplay":                 environmentDisplay,
	"topbarRoute":                        topbarRoute,
	"userDisplayName":                    userDisplayName,
	"userSecondaryLabel":                 userSecondaryLabel,
	"userInitials":                       userInitials,
	"formatNotificationCount":            formatNotificationCount,
	"formatDate":                         formatDate,
	"joinBaseFooter":                     joinBaseFooter,
	"joinBase":                           joinBase,
	"buttonClass":                        helpers.ButtonClass,
	"classList":                          helpers.ClassList,
	"inlineNoticeClass":                  inlineNoticeClass,
	"kpiTrendClass":                      kpiTrendClass,
	"trendBadgeClass":                    trendBadgeClass,
	"kpiTrendGlyph":                      kpiTrendGlyph,
	"sparklinePoints":                    sparklinePoints,
	"relativeTime":                       relativeTime,
	"mul":                                mul,
	"dict":                               dict,
	"buttonType":                         buttonType,
	"fieldType":                          fieldType,
	"textareaRows":                       textareaRows,
	"inputClass":                         inputClass,
	"textareaClass":                      textareaClass,
	"selectClass":                        selectClass,
	"previewLocaleClass":                 previewLocaleClass,
	"summaryChipClass":                   summaryChipClass,
	"treeLinkClass":                      treeLinkClass,
	"localeChipClass":                    localeChipClass,
	"boolAttr":                           boolAttr,
	"rawHTML":                            rawHTML,
	"paginationLabel":                    paginationLabel,
	"paginationPageSize":                 paginationPageSize,
	"paginationCurrentPage":              paginationCurrentPage,
	"paginationPageCount":                paginationPageCount,
	"paginationParam":                    paginationParam,
	"paginationSizeParam":                paginationSizeParam,
	"paginationBasePath":                 paginationBasePath,
	"paginationFragmentPath":             paginationFragmentPath,
	"paginationBaseQuery":                paginationBaseQuery,
	"paginationFragmentQuery":            paginationFragmentQuery,
	"paginationHasHTMX":                  paginationHasHTMX,
	"paginationPrevURL":                  paginationPrevURL,
	"paginationPrevHxURL":                paginationPrevHxURL,
	"paginationNextURL":                  paginationNextURL,
	"paginationNextHxURL":                paginationNextHxURL,
	"paginationStartIndex":               paginationStartIndex,
	"paginationEndIndex":                 paginationEndIndex,
	"paginationHasTotalItems":            paginationHasTotalItems,
	"paginationTotalItems":               paginationTotalItems,
	"maxInt":                             maxInt,
	"clampPercentage":                    clampPercentage,
	"badgeDisplay":                       badgeDisplay,
	"categoryOptionClass":                categoryOptionClass,
	"severityOptionClass":                severityOptionClass,
	"tableRowClass":                      tableRowClass,
	"reviewsSummaryChipClass":            reviewsSummaryChipClass,
	"reviewsProductivityCardClass":       reviewsProductivityCardClass,
	"reviewsFilterChipClass":             reviewsFilterChipClass,
	"reviewsRatingChipClass":             reviewsRatingChipClass,
	"reviewsFlagChipClass":               reviewsFlagChipClass,
	"reviewsTableRowClass":               reviewsTableRowClass,
	"reviewsChannelBadgeClass":           reviewsChannelBadgeClass,
	"reviewsFlagBadgeClass":              reviewsFlagBadgeClass,
	"reviewsModerationBadgeClass":        reviewsModerationBadgeClass,
	"reviewsDetailFlagClass":             reviewsDetailFlagClass,
	"reviewsFirstNonEmpty":               reviewsFirstNonEmpty,
	"reviewsReplyVisibilityClass":        reviewsReplyVisibilityClass,
	"reviewsReplyVisibilityLabel":        reviewsReplyVisibilityLabel,
	"reviewsDecisionTone":                reviewsDecisionTone,
	"inlineAlertClass":                   inlineAlertClass,
	"actionChipClass":                    actionChipClass,
	"firstValue":                         firstValue,
	"exportButtonClass":                  exportButtonClass,
	"exportTabIndex":                     exportTabIndex,
	"bulkToolbarMessage":                 bulkToolbarMessage,
	"bulkSelectionLabel":                 bulkSelectionLabel,
	"bulkActionVariant":                  bulkActionVariant,
	"bulkActionSize":                     bulkActionSize,
	"customersSegmentChipClass":          customersSegmentChipClass,
	"customersStatusChipClass":           customersStatusChipClass,
	"customersInitials":                  customersInitials,
	"customersTrendToneClass":            customersTrendToneClass,
	"customersNoteCardClass":             customersNoteCardClass,
	"customersFieldInputClass":           customersFieldInputClass,
	"customersConfirmationHelpClass":     customersConfirmationHelpClass,
	"customersUnderlineTabClass":         customersUnderlineTabClass,
	"customersUnderlineTabHref":          customersUnderlineTabHref,
	"underlineTabClass":                  underlineTabClass,
	"underlineTabHref":                   underlineTabHref,
	"underlineSwapValue":                 underlineSwapValue,
	"promotionsStatusChipClass":          promotionsStatusChipClass,
	"promotionsInputType":                promotionsInputType,
	"promotionsModalTone":                promotionsModalTone,
	"promotionsSectionHidden":            promotionsSectionHidden,
	"promotionsFieldHidden":              promotionsFieldHidden,
	"promotionsValidationFieldError":     promotionsValidationFieldError,
	"promotionsValidationItemFieldError": promotionsValidationItemFieldError,
	"promotionsValidationValueAt":        promotionsValidationValueAt,
	"promotionsValidationResultTone":     promotionsValidationResultTone,
	"promotionsValidationResultLabel":    promotionsValidationResultLabel,
	"promotionsValidationRuleTone":       promotionsValidationRuleTone,
	"promotionsValidationRuleBadge":      promotionsValidationRuleBadge,
	"starIndices":                        starIndices,
	"intValue":                           intValue,
	"statusChipClass":                    statusChipClass,
	"statusChipTone":                     statusChipTone,
	"trackingSummaryClass":               trackingSummaryClass,
	"trackingAlertClass":                 trackingAlertClass,
	"trackingStatusChipClass":            trackingStatusChipClass,
	"trackingStatusTone":                 trackingStatusTone,
	"trackingRefreshTrigger":             trackingRefreshTrigger,
	"trackingFragmentURL":                trackingFragmentURL,
	"totalPages":                         totalPages,
	"paginationURL":                      paginationURL,
	"trackingTotalPages":                 trackingTotalPages,
	"trackingPaginationURL":              trackingPaginationURL,
	"presetButtonClasses":                presetButtonClasses,
	"exportSectionClasses":               exportSectionClasses,
	"slaToneClass":                       slaToneClass,
	"sortCurrentDirection":               sortCurrentDirection,
	"sortNextDirection":                  sortNextDirection,
	"sortAria":                           sortAriaValue,
	"sortHeaderClass":                    sortHeaderClass,
	"sortIconClass":                      sortIconClass,
	"sortHref":                           sortHref,
	"sortHxHref":                         sortHxHref,
	"sortNextDirectionAttr":              sortNextDirectionAttr,
	"sortSrLabel":                        sortSrLabel,
	"toastClass":                         toastClass,
	"modalPanelClass":                    modalPanelClass,
	"financeMetricCardClass":             financeMetricCardClass,
	"financeAlertClass":                  financeAlertClass,
	"financeHeaderMetricClass":           financeHeaderMetricClass,
	"financeNavigationItemClass":         financeNavigationItemClass,
	"financeTaxTableRowClass":            financeTaxTableRowClass,
	"financeInputClass":                  financeInputClass,
	"financeGridContainerID":             financeGridContainerID,
	"financeContentContainerID":          financeContentContainerID,
	"financeDetailContainerID":           financeDetailContainerID,
	"financeHistoryContainerID":          financeHistoryContainerID,
	"financeReconciliationRootID":        financeReconciliationRootID,
	"minInt":                             minInt,
	"fallback":                           fallback,
	"productionQueueSelectDomID":         productionQueueSelectDomID,
	"productionBoardInstructionsDomID":   productionBoardInstructionsDomID,
	"productionBoardAriaLabel":           productionBoardAriaLabel,
	"productionLaneHeadingDomID":         productionLaneHeadingDomID,
	"productionLaneMetaDomID":            productionLaneMetaDomID,
	"productionLaneAssistiveDescription": productionLaneAssistiveDescription,
	"productionKanbanCardClass":          productionKanbanCardClass,
	"productionDueToneClass":             productionDueToneClass,
	"productionCardAriaLabel":            productionCardAriaLabel,
	"productionCardAssistiveMeta":        productionCardAssistiveMeta,
	"productionCardMetaDomID":            productionCardMetaDomID,
	"productionUnderlineTabClass":        productionUnderlineTabClass,
	"productionUnderlineTabHref":         productionUnderlineTabHref,
	"productionSummaryAlertClass":        productionSummaryAlertClass,
	"productionSummaryCardClass":         productionSummaryCardClass,
	"productionSummaryMetricTone":        productionSummaryMetricTone,
	"productionSummaryBarClass":          productionSummaryBarClass,
	"productionSummaryRowClass":          productionSummaryRowClass,
	"productionDeadlineToneClass":        productionDeadlineToneClass,
	"productionChecklistBadgeClass":      productionChecklistBadgeClass,
	"productionNoticeToneClass":          productionNoticeToneClass,
	"productionQCRowClass":               productionQCRowClass,
	"catalogViewToggleClass":             catalogViewToggleClass,
	"catalogStatusFilterClass":           catalogStatusFilterClass,
	"catalogRowClass":                    catalogRowClass,
	"catalogCardClass":                   catalogCardClass,
	"catalogFilterEndpoint":              catalogFilterEndpoint,
	"catalogPaginationProps":             catalogPaginationProps,
	"catalogModalTone":                   catalogModalTone,
	"catalogFieldContainerClass":         catalogFieldContainerClass,
	"catalogInputType":                   catalogInputType,
	"catalogAssetHasValue":               catalogAssetHasValue,
	"catalogBoolString":                  catalogBoolString,
	"catalogAssetPreviewClass":           catalogAssetPreviewClass,
	"catalogCoalesceLabel":               catalogCoalesceLabel,
	"catalogAssetFileLabel":              catalogAssetFileLabel,
	"catalogAssetTriggerLabel":           catalogAssetTriggerLabel,
	"catalogFormatFileSize":              catalogFormatFileSize,
	"catalogCoalesceWarning":             catalogCoalesceWarning,
	"profileAvatarInitial":               profileAvatarInitial,
	"profileFormatTimestamp":             profileFormatTimestamp,
	"profileFormatOptionalTime":          profileFormatOptionalTime,
	"hasMFAMethod":                       hasMFAMethod,
	"productionQueuesTableContainerID":   productionQueuesTableContainerID,
	"productionQueuesDrawerContainerID":  productionQueuesDrawerContainerID,
	"productionQueuesQueueRowClass":      productionQueuesQueueRowClass,
	"productionQueuesActiveTone":         productionQueuesActiveTone,
	"buildURL":                           buildURL,
	"setRawQuery":                        setRawQuery,
	"fmtInt":                             fmtInt,
	"containsString":                     containsString,
	"guidesLocaleChipClass":              guidesLocaleChipClass,
	"guidesSegmentedClass":               guidesSegmentedClass,
	"guidesBulkStepClass":                guidesBulkStepClass,
	"guidesPreviewLocaleClass":           guidesPreviewLocaleClass,
	"guidesPreviewModeClass":             guidesPreviewModeClass,
	"guidesTableRowClass":                guidesTableRowClass,
	"searchScopeOptionClass":             searchScopeOptionClass,
	"searchNoticeClass":                  searchNoticeClass,
	"searchFormatScore":                  searchFormatScore,
	"searchHighlightSegments":            searchHighlightSegments,
	"paymentsSummaryDeltaClass":          paymentsSummaryDeltaClass,
	"paymentsStatusChipClass":            paymentsStatusChipClass,
	"paymentsFallback":                   paymentsFallback,
	"paymentsRowClass":                   paymentsRowClass,
	"paymentsRiskBadgeClass":             paymentsRiskBadgeClass,
	"paymentsBreakdownClass":             paymentsBreakdownClass,
	"systemSummaryDeltaClass":            systemSummaryDeltaClass,
	"systemSourceOptionClass":            systemSourceOptionClass,
	"systemSeverityOptionClass":          systemSeverityOptionClass,
	"systemStatusOptionClass":            systemStatusOptionClass,
	"systemErrorsToneClass":              systemErrorsToneClass,
	"systemErrorsTableRowClass":          systemErrorsTableRowClass,
	"systemErrorsTableActionClass":       systemErrorsTableActionClass,
	"systemInlineAlertClass":             systemInlineAlertClass,
	"systemFallbackLockReason":           systemFallbackLockReason,
	"systemTasksToggleClass":             systemTasksToggleClass,
	"systemTasksToneClass":               systemTasksToneClass,
	"systemTasksRowClass":                systemTasksRowClass,
	"systemTasksInsightClass":            systemTasksInsightClass,
	"systemTasksPickActionVariant":       systemTasksPickActionVariant,
	"systemTaskHistoryPoints":            systemTaskHistoryPoints,
	"pickClass":                          pickClass,
	"addInt":                             addInt,
}

func localize(locale string, key string, args ...any) string {
	return i18n.Default().Translate(locale, key, args...)
}

func localeDisplayName(locale string, code string) string {
	normalized := strings.ToLower(strings.TrimSpace(code))
	if normalized == "" {
		return ""
	}
	key := "admin.locale.name." + strings.ReplaceAll(normalized, "-", "_")
	if label := i18n.Default().Translate(locale, key); label != "" && label != key {
		return label
	}
	return strings.ToUpper(code)
}

func formatDate(ts time.Time, layout string) string {
	if ts.IsZero() {
		return ""
	}
	return helpers.Date(ts, layout)
}

func hasCapability(caps map[string]bool, capability any) bool {
	if caps == nil {
		return false
	}
	switch val := capability.(type) {
	case rbac.Capability:
		return caps[string(val)]
	case string:
		return caps[val]
	default:
		return false
	}
}

func visibleMenuGroups(groups []navigation.MenuGroup, caps map[string]bool) []navigation.MenuGroup {
	if len(groups) == 0 {
		return nil
	}
	result := make([]navigation.MenuGroup, 0, len(groups))
	for _, group := range groups {
		if group.Capability != "" && !hasCapability(caps, group.Capability) {
			continue
		}
		items := make([]navigation.MenuItem, 0, len(group.Items))
		for _, item := range group.Items {
			if hasCapability(caps, item.Capability) {
				items = append(items, item)
			}
		}
		if len(items) == 0 {
			continue
		}
		group.Items = items
		result = append(result, group)
	}
	return result
}

func navActive(currentPath, pattern string, prefix bool) bool {
	current := normalizeRoute(currentPath)
	target := normalizeRoute(pattern)
	if target == "" {
		return false
	}
	if prefix {
		if target == "/" {
			return current == "/"
		}
		if current == target {
			return true
		}
		return strings.HasPrefix(current, target+"/")
	}
	return current == target
}

func normalizeRoute(path string) string {
	path = strings.TrimSpace(path)
	if path == "" {
		return "/"
	}
	if !strings.HasPrefix(path, "/") {
		path = "/" + path
	}
	for strings.Contains(path, "//") {
		path = strings.ReplaceAll(path, "//", "/")
	}
	if len(path) > 1 {
		path = strings.TrimRight(path, "/")
		if path == "" {
			return "/"
		}
	}
	return path
}

func isLast(index int, items any) bool {
	value := reflect.ValueOf(items)
	if !value.IsValid() {
		return false
	}
	if value.Kind() == reflect.Pointer {
		if value.IsNil() {
			return false
		}
		value = value.Elem()
	}
	if value.Kind() != reflect.Slice && value.Kind() != reflect.Array {
		return false
	}
	if value.Len() == 0 {
		return false
	}
	return index == value.Len()-1
}

func environmentTone(env string) string {
	switch strings.ToLower(strings.TrimSpace(env)) {
	case "production", "prod", "live":
		return "success"
	case "staging", "stage", "stg":
		return "warning"
	case "development", "dev", "local":
		return "info"
	default:
		return ""
	}
}

func environmentLabel(env string) string {
	trimmed := strings.TrimSpace(env)
	if trimmed == "" {
		return "DEV"
	}
	switch strings.ToLower(trimmed) {
	case "production", "prod", "live":
		return "PROD"
	case "staging", "stage", "stg":
		return "STG"
	case "development", "dev", "local":
		return "DEV"
	default:
		return strings.ToUpper(trimmed)
	}
}

func environmentDisplay(env string) string {
	trimmed := strings.TrimSpace(env)
	if trimmed == "" {
		return "Development"
	}
	return trimmed
}

func topbarRoute(basePath, suffix string) string {
	base := strings.TrimSpace(basePath)
	if base == "" {
		base = "/"
	}
	if !strings.HasPrefix(base, "/") {
		base = "/" + base
	}
	if len(base) > 1 {
		base = strings.TrimRight(base, "/")
	}

	raw := strings.TrimSpace(suffix)
	if raw == "" {
		return base
	}

	query := ""
	if idx := strings.Index(raw, "?"); idx >= 0 {
		query = raw[idx:]
		raw = raw[:idx]
	}

	path := strings.TrimSpace(raw)
	if path == "" || path == "/" {
		if query != "" {
			return base + query
		}
		return base
	}

	if !strings.HasPrefix(path, "/") {
		path = "/" + path
	}

	if base == "/" {
		return normalizeSlashes(path) + query
	}

	return normalizeSlashes(base+path) + query
}

func normalizeSlashes(path string) string {
	if path == "" {
		return "/"
	}
	result := strings.ReplaceAll(path, "//", "/")
	if len(result) > 1 {
		result = strings.TrimRight(result, "/")
		if result == "" {
			return "/"
		}
	}
	return result
}

func userDisplayName(user *middleware.User) string {
	if user == nil {
		return "スタッフ"
	}
	if strings.TrimSpace(user.UID) != "" {
		return user.UID
	}
	if strings.TrimSpace(user.Email) != "" {
		return user.Email
	}
	return "スタッフ"
}

func userSecondaryLabel(user *middleware.User) string {
	if user == nil {
		return ""
	}
	return strings.TrimSpace(user.Email)
}

func userInitials(user *middleware.User) string {
	display := userDisplayName(user)
	if display == "" {
		return "?"
	}
	fields := strings.Fields(display)
	if len(fields) == 0 {
		return "?"
	}
	if len(fields) == 1 {
		runes := []rune(fields[0])
		if len(runes) == 0 {
			return "?"
		}
		return strings.ToUpper(string(runes[0]))
	}
	first := []rune(fields[0])
	last := []rune(fields[len(fields)-1])
	initials := []rune{}
	if len(first) > 0 {
		initials = append(initials, first[0])
	}
	if len(last) > 0 {
		initials = append(initials, last[0])
	}
	return strings.ToUpper(string(initials))
}

func formatNotificationCount(value int) string {
	if value > 99 {
		return "99+"
	}
	if value < 0 {
		value = 0
	}
	return fmt.Sprintf("%d", value)
}

func inlineNoticeClass(tone string) string {
	base := "flex items-center gap-2 rounded-md border px-4 py-3 text-sm"
	switch tone {
	case "success":
		return base + " border-emerald-200 bg-emerald-50 text-emerald-700"
	case "danger":
		return base + " border-rose-200 bg-rose-50 text-rose-700"
	case "warning":
		return base + " border-amber-200 bg-amber-50 text-amber-700"
	default:
		return base + " border-slate-200 bg-slate-50 text-slate-600"
	}
}

func kpiTrendClass(trend string) string {
	switch trend {
	case "up":
		return "text-emerald-600"
	case "down":
		return "text-rose-600"
	default:
		return "text-slate-500"
	}
}

func trendBadgeClass(trend string) string {
	switch trend {
	case "up":
		return "bg-emerald-100 text-emerald-600"
	case "down":
		return "bg-rose-100 text-rose-600"
	default:
		return "bg-slate-100 text-slate-500"
	}
}

func kpiTrendGlyph(trend string) string {
	switch trend {
	case "up":
		return "↑"
	case "down":
		return "↓"
	default:
		return "→"
	}
}

func sparklinePoints(values []float64) string {
	if len(values) == 0 {
		return ""
	}
	if len(values) == 1 {
		return "0,50 100,50"
	}

	min := values[0]
	max := values[0]
	for _, v := range values[1:] {
		if v < min {
			min = v
		}
		if v > max {
			max = v
		}
	}

	rangeVal := max - min
	if rangeVal == 0 {
		rangeVal = 1
	}

	points := make([]string, 0, len(values))
	lastIndex := len(values) - 1
	for i, v := range values {
		x := 0.0
		if lastIndex > 0 {
			x = float64(i) / float64(lastIndex) * 100
		}
		y := 100 - ((v - min) / rangeVal * 100)
		points = append(points, fmt.Sprintf("%.1f,%.1f", x, y))
	}
	return strings.Join(points, " ")
}

func relativeTime(locale string, ts time.Time) string {
	if ts.IsZero() {
		return ""
	}
	ctx := i18n.ContextWithLocale(context.Background(), locale)
	return helpers.RelativeLocalized(ctx, ts)
}

func mul(a, b int) int {
	return a * b
}

func dict(values ...any) map[string]any {
	result := make(map[string]any, len(values)/2)
	for i := 0; i+1 < len(values); i += 2 {
		key, ok := values[i].(string)
		if !ok {
			continue
		}
		result[key] = values[i+1]
	}
	return result
}

func buttonType(value string) string {
	if strings.TrimSpace(value) == "" {
		return "button"
	}
	return value
}

func fieldType(value string) string {
	if strings.TrimSpace(value) == "" {
		return "text"
	}
	return value
}

func textareaRows(rows int) int {
	if rows <= 0 {
		return 4
	}
	return rows
}

func inputClass(err string) string {
	if strings.TrimSpace(err) != "" {
		return helpers.ClassList("form-control", "is-error")
	}
	return "form-control"
}

func textareaClass(err string) string {
	return inputClass(err)
}

func selectClass(err string) string {
	return inputClass(err)
}

func previewLocaleClass(active bool) string {
	base := []string{"rounded-full", "px-3", "py-1"}
	if active {
		base = append(base, "bg-brand-500", "text-white")
	} else {
		base = append(base, "bg-slate-200", "text-slate-600")
	}
	return helpers.ClassList(base...)
}

func summaryChipClass(tone string) string {
	switch tone {
	case "success":
		return "inline-flex items-center rounded-full bg-success-50 px-3 py-1 text-xs font-semibold text-success-700"
	case "warning":
		return "inline-flex items-center rounded-full bg-warning-50 px-3 py-1 text-xs font-semibold text-warning-700"
	default:
		return "inline-flex items-center rounded-full bg-slate-100 px-3 py-1 text-xs font-semibold text-slate-600"
	}
}

func treeLinkClass(selected bool) string {
	base := []string{"flex", "items-center", "justify-between", "gap-3", "rounded-lg", "border", "px-3", "py-2", "transition-colors"}
	if selected {
		base = append(base, "border-brand-400", "bg-brand-50", "text-brand-700")
	} else {
		base = append(base, "border-transparent", "hover:border-slate-200", "hover:bg-slate-50")
	}
	return helpers.ClassList(base...)
}

func localeChipClass(active bool) string {
	base := []string{"rounded-full", "px-3", "py-1"}
	if active {
		base = append(base, "bg-brand-600", "text-white")
	} else {
		base = append(base, "bg-white", "text-slate-600", "hover:bg-slate-100")
	}
	return helpers.ClassList(base...)
}

func boolAttr(value bool) string {
	if value {
		return "true"
	}
	return "false"
}

func rawHTML(value string) template.HTML {
	return template.HTML(value)
}

func paginationLabel(props PaginationProps) string {
	if strings.TrimSpace(props.Label) != "" {
		return props.Label
	}
	return "Pagination"
}

func paginationPageSize(props PaginationProps) int {
	return props.Info.PageSize
}

func paginationCurrentPage(props PaginationProps) int {
	page := props.Info.Current
	if page <= 0 {
		return 1
	}
	return page
}

func paginationPageCount(props PaginationProps) int {
	count := props.Info.Count
	size := paginationPageSize(props)
	if count <= 0 || (size > 0 && count > size) {
		return size
	}
	return count
}

func paginationParam(props PaginationProps) string {
	if strings.TrimSpace(props.Param) != "" {
		return props.Param
	}
	return "page"
}

func paginationSizeParam(props PaginationProps) string {
	if strings.TrimSpace(props.SizeParam) != "" {
		return props.SizeParam
	}
	return "pageSize"
}

func paginationBasePath(props PaginationProps) string {
	if strings.TrimSpace(props.BasePath) != "" {
		return props.BasePath
	}
	return "."
}

func paginationFragmentPath(props PaginationProps) string {
	if strings.TrimSpace(props.FragmentPath) != "" {
		return props.FragmentPath
	}
	return paginationBasePath(props)
}

func paginationBaseQuery(props PaginationProps) string {
	query := props.RawQuery
	size := paginationPageSize(props)
	if size > 0 {
		query = helpers.SetRawQuery(query, paginationSizeParam(props), strconv.Itoa(size))
	}
	return query
}

func paginationFragmentQuery(props PaginationProps) string {
	query := props.FragmentQuery
	if query == "" {
		query = props.RawQuery
	}
	size := paginationPageSize(props)
	if size > 0 {
		query = helpers.SetRawQuery(query, paginationSizeParam(props), strconv.Itoa(size))
	}
	return query
}

func paginationHasHTMX(props PaginationProps) bool {
	return props.HxTarget != "" || props.HxSwap != "" || props.HxPushURL
}

func paginationPrevURL(props PaginationProps) string {
	if props.Info.Prev == nil {
		return ""
	}
	query := helpers.SetRawQuery(paginationBaseQuery(props), paginationParam(props), strconv.Itoa(*props.Info.Prev))
	return helpers.BuildURL(paginationBasePath(props), query)
}

func paginationPrevHxURL(props PaginationProps) string {
	if props.Info.Prev == nil {
		return ""
	}
	query := helpers.SetRawQuery(paginationFragmentQuery(props), paginationParam(props), strconv.Itoa(*props.Info.Prev))
	return helpers.BuildURL(paginationFragmentPath(props), query)
}

func paginationNextURL(props PaginationProps) string {
	if props.Info.Next == nil {
		return ""
	}
	query := helpers.SetRawQuery(paginationBaseQuery(props), paginationParam(props), strconv.Itoa(*props.Info.Next))
	return helpers.BuildURL(paginationBasePath(props), query)
}

func paginationNextHxURL(props PaginationProps) string {
	if props.Info.Next == nil {
		return ""
	}
	query := helpers.SetRawQuery(paginationFragmentQuery(props), paginationParam(props), strconv.Itoa(*props.Info.Next))
	return helpers.BuildURL(paginationFragmentPath(props), query)
}

func paginationStartIndex(props PaginationProps) int {
	page := paginationCurrentPage(props)
	size := paginationPageSize(props)
	if size <= 0 {
		return 1
	}
	start := ((page - 1) * size) + 1
	if start < 1 {
		start = 1
	}
	if props.Info.TotalItems != nil && *props.Info.TotalItems > 0 && start > *props.Info.TotalItems {
		return *props.Info.TotalItems
	}
	return start
}

func paginationEndIndex(props PaginationProps) int {
	start := paginationStartIndex(props)
	count := paginationPageCount(props)
	if count <= 0 {
		return start
	}
	end := start + count - 1
	if end < start {
		end = start
	}
	if props.Info.TotalItems != nil && *props.Info.TotalItems > 0 && end > *props.Info.TotalItems {
		end = *props.Info.TotalItems
	}
	return end
}

func paginationHasTotalItems(props PaginationProps) bool {
	return props.Info.TotalItems != nil && *props.Info.TotalItems >= 0
}

func paginationTotalItems(props PaginationProps) int {
	if props.Info.TotalItems == nil {
		return 0
	}
	return *props.Info.TotalItems
}

func maxInt(a, b int) int {
	if a > b {
		return a
	}
	return b
}

func clampPercentage(value int) int {
	if value < 0 {
		return 0
	}
	if value > 100 {
		return 100
	}
	return value
}

func badgeDisplay(total int) string {
	switch {
	case total <= 0:
		return "0"
	case total > 99:
		return "99+"
	default:
		return fmt.Sprintf("%d", total)
	}
}

func categoryOptionClass(active bool) string {
	base := "inline-flex items-center gap-2 rounded-full border px-3 py-1.5 text-sm font-medium transition focus-within:ring-2 focus-within:ring-brand-500"
	if active {
		return base + " border-brand-500 bg-brand-50 text-brand-600"
	}
	return base + " border-slate-200 text-slate-600 hover:border-slate-300 hover:text-slate-900"
}

func severityOptionClass(active bool, tone string) string {
	base := "inline-flex items-center gap-2 rounded-full border px-3 py-1.5 text-sm font-medium transition focus-within:ring-2 focus-within:ring-brand-500"
	if active {
		return base + " border-brand-500 bg-brand-50 text-brand-600"
	}
	switch tone {
	case "danger":
		return base + " border-danger-200 text-danger-600 hover:border-danger-300 hover:text-danger-700"
	case "warning":
		return base + " border-warning-200 text-warning-600 hover:border-warning-300 hover:text-warning-700"
	default:
		return base + " border-slate-200 text-slate-600 hover:border-slate-300 hover:text-slate-900"
	}
}

func tableRowClass(selected bool) string {
	base := "hover:bg-slate-50 transition cursor-pointer"
	if selected {
		return base + " bg-brand-50"
	}
	return base
}

func reviewsSummaryChipClass(tone string) string {
	base := []string{"rounded-xl border px-4 py-3 shadow-sm"}
	switch tone {
	case "success":
		base = append(base, "border-emerald-100 bg-emerald-50 text-emerald-700")
	case "warning":
		base = append(base, "border-amber-100 bg-amber-50 text-amber-700")
	case "danger":
		base = append(base, "border-rose-100 bg-rose-50 text-rose-700")
	default:
		base = append(base, "border-sky-100 bg-sky-50 text-sky-700")
	}
	return helpers.ClassList(base...)
}

func reviewsProductivityCardClass(tone string) string {
	base := []string{"rounded-xl border px-4 py-3 shadow-sm text-slate-900"}
	switch tone {
	case "success":
		base = append(base, "border-emerald-200 bg-emerald-100/70")
	case "warning":
		base = append(base, "border-amber-200 bg-amber-100/70")
	case "danger":
		base = append(base, "border-rose-200 bg-rose-100/70")
	default:
		base = append(base, "border-slate-200 bg-slate-100/70")
	}
	return helpers.ClassList(base...)
}

func reviewsFilterChipClass(selected bool) string {
	base := []string{"inline-flex items-center rounded-full border px-3 py-1.5 text-sm font-medium transition"}
	if selected {
		base = append(base, "border-brand-500 bg-brand-50 text-brand-700 shadow-sm")
	} else {
		base = append(base, "border-slate-200 text-slate-600 hover:border-brand-200 hover:text-brand-600")
	}
	return helpers.ClassList(base...)
}

func reviewsRatingChipClass(selected bool) string {
	base := []string{"inline-flex items-center rounded-full border px-3 py-1.5 text-sm font-medium transition"}
	if selected {
		base = append(base, "border-amber-400 bg-amber-50 text-amber-700 shadow-sm")
	} else {
		base = append(base, "border-slate-200 text-slate-600 hover:border-amber-200 hover:text-amber-700")
	}
	return helpers.ClassList(base...)
}

func reviewsFlagChipClass(tone string, selected bool) string {
	base := []string{"inline-flex items-center rounded-full border px-3 py-1.5 text-sm font-medium transition"}
	switch tone {
	case "danger":
		if selected {
			base = append(base, "border-rose-500 bg-rose-50 text-rose-700 shadow-sm")
		} else {
			base = append(base, "border-rose-200 text-rose-600 hover:border-rose-400 hover:text-rose-700")
		}
	case "warning":
		if selected {
			base = append(base, "border-amber-500 bg-amber-50 text-amber-700 shadow-sm")
		} else {
			base = append(base, "border-amber-200 text-amber-600 hover:border-amber-400 hover:text-amber-700")
		}
	default:
		if selected {
			base = append(base, "border-sky-500 bg-sky-50 text-sky-700 shadow-sm")
		} else {
			base = append(base, "border-slate-200 text-slate-600 hover:border-sky-200 hover:text-sky-700")
		}
	}
	return helpers.ClassList(base...)
}

func reviewsTableRowClass(selected bool) string {
	base := []string{"transition hover:bg-slate-50 cursor-pointer"}
	if selected {
		base = append(base, "bg-brand-50/70 hover:bg-brand-50")
	}
	return helpers.ClassList(base...)
}

func reviewsChannelBadgeClass(tone string) string {
	switch tone {
	case "success":
		return "inline-flex items-center rounded-full bg-emerald-100 px-3 py-1 text-xs font-medium text-emerald-700"
	case "info":
		return "inline-flex items-center rounded-full bg-sky-100 px-3 py-1 text-xs font-medium text-sky-700"
	case "danger":
		return "inline-flex items-center rounded-full bg-rose-100 px-3 py-1 text-xs font-medium text-rose-700"
	default:
		return "inline-flex items-center rounded-full bg-slate-200 px-3 py-1 text-xs font-medium text-slate-700"
	}
}

func reviewsFlagBadgeClass(tone string) string {
	switch tone {
	case "danger":
		return "inline-flex items-center rounded-full bg-rose-100 px-2.5 py-1 text-xs font-medium text-rose-700"
	case "warning":
		return "inline-flex items-center rounded-full bg-amber-100 px-2.5 py-1 text-xs font-medium text-amber-700"
	case "info":
		return "inline-flex items-center rounded-full bg-sky-100 px-2.5 py-1 text-xs font-medium text-sky-700"
	default:
		return "inline-flex items-center rounded-full bg-slate-200 px-2.5 py-1 text-xs font-medium text-slate-700"
	}
}

func reviewsModerationBadgeClass(tone string) string {
	switch tone {
	case "success":
		return "inline-flex items-center rounded-full bg-emerald-100 px-2.5 py-1 text-xs font-medium text-emerald-700"
	case "warning":
		return "inline-flex items-center rounded-full bg-amber-100 px-2.5 py-1 text-xs font-medium text-amber-700"
	case "danger":
		return "inline-flex items-center rounded-full bg-rose-100 px-2.5 py-1 text-xs font-medium text-rose-700"
	default:
		return "inline-flex items-center rounded-full bg-slate-200 px-2.5 py-1 text-xs font-medium text-slate-700"
	}
}

func reviewsDetailFlagClass(tone string) string {
	switch tone {
	case "danger":
		return "rounded-lg border border-rose-200 bg-rose-50 px-3 py-2"
	case "warning":
		return "rounded-lg border border-amber-200 bg-amber-50 px-3 py-2"
	case "info":
		return "rounded-lg border border-sky-200 bg-sky-50 px-3 py-2"
	default:
		return "rounded-lg border border-slate-200 bg-white px-3 py-2"
	}
}

func reviewsFirstNonEmpty(values ...string) string {
	for _, v := range values {
		if strings.TrimSpace(v) != "" {
			return v
		}
	}
	return ""
}

func reviewsReplyVisibilityClass(public bool) string {
	if public {
		return "inline-flex items-center rounded-full bg-emerald-100 px-2 py-1 font-medium text-emerald-700"
	}
	return "inline-flex items-center rounded-full bg-slate-200 px-2 py-1 font-medium text-slate-700"
}

func reviewsReplyVisibilityLabel(public bool) string {
	if public {
		return "公開"
	}
	return "内部メモ"
}

func reviewsDecisionTone(decision string) string {
	switch strings.ToLower(strings.TrimSpace(decision)) {
	case "reject":
		return "secondary"
	default:
		return "primary"
	}
}

func starIndices() []int {
	return []int{0, 1, 2, 3, 4}
}

func intValue(value *int) int {
	if value == nil {
		return 0
	}
	return *value
}

func statusChipClass(active bool) string {
	return statusChipTone("info", active)
}

func statusChipTone(tone string, active bool) string {
	base := []string{
		"inline-flex items-center gap-1 rounded-full border px-3 py-1 text-xs font-semibold transition focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-500 focus-visible:ring-offset-2",
	}
	if active {
		base = append(base, "border-brand-400 bg-brand-50 text-brand-600")
	} else {
		base = append(base, "border-slate-300 bg-white text-slate-600 hover:border-slate-400")
	}
	switch tone {
	case "success":
		base = append(base, "data-[tone]:border-emerald-400 data-[tone]:bg-emerald-50 data-[tone]:text-emerald-600")
	case "warning":
		base = append(base, "data-[tone]:border-amber-400 data-[tone]:bg-amber-50 data-[tone]:text-amber-600")
	case "danger":
		base = append(base, "data-[tone]:border-red-400 data-[tone]:bg-red-50 data-[tone]:text-red-600")
	}
	return helpers.ClassList(base...)
}

func inlineAlertClass(tone string) string {
	base := []string{"flex items-center gap-2 rounded-md border px-4 py-3 text-sm"}
	switch tone {
	case "danger":
		base = append(base, "border-rose-200 bg-rose-50 text-rose-700")
	case "warning":
		base = append(base, "border-amber-200 bg-amber-50 text-amber-700")
	case "success":
		base = append(base, "border-emerald-200 bg-emerald-50 text-emerald-700")
	default:
		base = append(base, "border-slate-200 bg-slate-50 text-slate-600")
	}
	return helpers.ClassList(base...)
}

func actionChipClass(active bool, tone string) string {
	base := []string{"rounded-full border px-3 py-1 text-xs font-medium transition"}
	if active {
		base = append(base, "border-transparent bg-brand-600 text-white shadow-sm")
	} else {
		switch tone {
		case "danger":
			base = append(base, "border-rose-200 bg-rose-50 text-rose-700 hover:bg-rose-100")
		case "warning":
			base = append(base, "border-amber-200 bg-amber-50 text-amber-700 hover:bg-amber-100")
		case "success":
			base = append(base, "border-emerald-200 bg-emerald-50 text-emerald-700 hover:bg-emerald-100")
		default:
			base = append(base, "border-slate-200 bg-slate-50 text-slate-600 hover:bg-slate-100")
		}
	}
	return helpers.ClassList(base...)
}

func firstValue(values []string) string {
	if len(values) == 0 {
		return ""
	}
	return values[0]
}

func exportButtonClass(enabled bool) string {
	base := helpers.ButtonClass("secondary", "sm", false, false)
	if enabled {
		return base
	}
	return base + " opacity-60 pointer-events-none"
}

func exportTabIndex(enabled bool) string {
	if enabled {
		return "0"
	}
	return "-1"
}

func bulkSelectionLabel(selected, total int) string {
	if total > 0 {
		return fmt.Sprintf("%d selected of %d", selected, total)
	}
	return fmt.Sprintf("%d selected", selected)
}

func bulkToolbarMessage(props components.BulkToolbarProps) string {
	if strings.TrimSpace(props.Message) != "" {
		return props.Message
	}
	return bulkSelectionLabel(props.SelectedCount, props.TotalCount)
}

func bulkActionVariant(variant string, isClear bool) string {
	if strings.TrimSpace(variant) != "" {
		return variant
	}
	if isClear {
		return "ghost"
	}
	return "secondary"
}

func bulkActionSize(size string) string {
	if strings.TrimSpace(size) != "" {
		return size
	}
	return "sm"
}

func customersSegmentChipClass(active bool) string {
	base := []string{
		"inline-flex items-center gap-1 rounded-full border px-3 py-1 text-xs font-medium transition focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-500 focus-visible:ring-offset-1",
	}
	if active {
		base = append(base, "border-brand-500 bg-brand-50 text-brand-600")
	} else {
		base = append(base, "border-slate-200 bg-white text-slate-600 hover:border-slate-300 hover:text-slate-900")
	}
	return helpers.ClassList(base...)
}

func customersStatusChipClass(active bool, tone string) string {
	base := []string{
		"inline-flex items-center gap-1 rounded-full border px-3 py-1 text-xs font-medium transition focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-500 focus-visible:ring-offset-1",
	}
	if active {
		base = append(base, "border-brand-500 bg-brand-50 text-brand-600")
	} else {
		switch tone {
		case "success":
			base = append(base, "border-emerald-200 bg-emerald-50 text-emerald-700 hover:border-emerald-300")
		case "warning":
			base = append(base, "border-amber-200 bg-amber-50 text-amber-700 hover:border-amber-300")
		case "danger":
			base = append(base, "border-rose-200 bg-rose-50 text-rose-700 hover:border-rose-300")
		default:
			base = append(base, "border-slate-200 bg-white text-slate-600 hover:border-slate-300 hover:text-slate-900")
		}
	}
	return helpers.ClassList(base...)
}

func customersInitials(value string, fallback string) string {
	value = strings.TrimSpace(value)
	if value == "" {
		return fallback
	}
	parts := strings.Fields(value)
	if len(parts) == 0 {
		return fallback
	}
	if len(parts) == 1 {
		runes := []rune(parts[0])
		if len(runes) >= 2 {
			return strings.ToUpper(string(runes[:2]))
		}
		return strings.ToUpper(string(runes[:1]))
	}
	var builder strings.Builder
	added := 0
	for _, segment := range parts {
		runes := []rune(segment)
		if len(runes) == 0 {
			continue
		}
		builder.WriteRune(unicode.ToUpper(runes[0]))
		added++
		if added == 3 {
			break
		}
	}
	if builder.Len() == 0 {
		return fallback
	}
	return builder.String()
}

func customersTrendToneClass(tone string) string {
	switch strings.ToLower(strings.TrimSpace(tone)) {
	case "success":
		return "mt-2 text-xs font-medium text-emerald-600"
	case "danger":
		return "mt-2 text-xs font-medium text-rose-600"
	case "warning":
		return "mt-2 text-xs font-medium text-amber-600"
	default:
		return "mt-2 text-xs font-medium text-slate-500"
	}
}

func customersNoteCardClass(tone string) string {
	switch strings.ToLower(strings.TrimSpace(tone)) {
	case "danger":
		return "rounded-2xl border border-rose-200 bg-rose-50 px-5 py-5 shadow-sm"
	case "warning":
		return "rounded-2xl border border-amber-200 bg-amber-50 px-5 py-5 shadow-sm"
	case "success":
		return "rounded-2xl border border-emerald-200 bg-emerald-50 px-5 py-5 shadow-sm"
	default:
		return "rounded-2xl border border-slate-200 bg-slate-50 px-5 py-5 shadow-sm"
	}
}

func customersFieldInputClass(err string) string {
	base := []string{"w-full", "rounded-lg", "border", "px-3", "py-2", "text-sm", "shadow-sm", "focus:outline-none", "focus:ring-2", "focus:ring-brand-200"}
	if strings.TrimSpace(err) != "" {
		base = append(base, "border-rose-300", "focus:border-rose-400", "focus:ring-rose-100")
	} else {
		base = append(base, "border-slate-300", "text-slate-800", "focus:border-brand-500")
	}
	return helpers.ClassList(base...)
}

func customersConfirmationHelpClass(err string) string {
	if strings.TrimSpace(err) != "" {
		return "text-xs text-rose-600"
	}
	return "text-xs text-slate-500"
}

func customersUnderlineTabClass(active bool) string {
	base := []string{
		"inline-flex", "items-center", "gap-2", "rounded-md", "border-b-2", "px-3", "py-2", "text-sm", "font-semibold", "transition-colors", "focus-visible:outline-none", "focus-visible:ring-2", "focus-visible:ring-brand-500", "focus-visible:ring-offset-2",
	}
	if active {
		base = append(base, "border-brand-500", "text-brand-600")
	} else {
		base = append(base, "border-transparent", "text-slate-500", "hover:border-slate-300", "hover:text-slate-900")
	}
	return helpers.ClassList(base...)
}

func customersUnderlineTabHref(href string, id string) string {
	if strings.TrimSpace(href) != "" {
		return href
	}
	if strings.TrimSpace(id) != "" {
		return "#" + id
	}
	return "#"
}

func promotionsStatusChipClass(active bool, tone string) string {
	base := []string{
		"inline-flex items-center rounded-full border px-3 py-1 text-sm font-medium transition focus:outline-none focus:ring-2 focus:ring-brand-400",
	}
	if active {
		base = append(base, "border-brand-500 bg-brand-50 text-brand-700")
	} else {
		base = append(base, "border-slate-200 bg-white text-slate-600 hover:border-brand-200 hover:text-brand-600")
	}
	return helpers.ClassList(base...)
}

func promotionsInputType(value string) string {
	switch strings.ToLower(strings.TrimSpace(value)) {
	case "textarea":
		return "textarea"
	case "select":
		return "select"
	case "multiselect":
		return "multiselect"
	case "checkbox-group":
		return "checkbox-group"
	case "radio":
		return "radio"
	case "number":
		return "number"
	case "date":
		return "date"
	case "time":
		return "time"
	case "datetime", "datetime-local":
		return "datetime-local"
	case "email":
		return "email"
	case "url":
		return "url"
	default:
		return "text"
	}
}

func promotionsModalTone(value string) string {
	if strings.TrimSpace(value) == "" {
		return "primary"
	}
	return strings.TrimSpace(value)
}

func promotionsSectionHidden(section promotionstpl.ModalSection, active map[string]string) bool {
	return promotionsSectionHiddenInternal(section.ConditionKey, section.ConditionValue, section.HideWhenMissing, active)
}

func promotionsSectionHiddenInternal(key, value string, hideWhenMissing bool, active map[string]string) bool {
	if strings.TrimSpace(key) == "" || strings.TrimSpace(value) == "" {
		return false
	}
	current := strings.TrimSpace(activeValue(active, key))
	if current == "" {
		return hideWhenMissing
	}
	return !conditionMatches(current, value)
}

func promotionsFieldHidden(field promotionstpl.ModalField, active map[string]string) bool {
	return promotionsFieldHiddenInternal(field.ConditionKey, field.ConditionValue, active)
}

func promotionsFieldHiddenInternal(key, value string, active map[string]string) bool {
	if strings.TrimSpace(key) == "" || strings.TrimSpace(value) == "" {
		return false
	}
	current := strings.TrimSpace(activeValue(active, key))
	if current == "" {
		return false
	}
	return !conditionMatches(current, value)
}

func activeValue(active map[string]string, key string) string {
	if active == nil {
		return ""
	}
	return active[strings.TrimSpace(key)]
}

func conditionMatches(current string, raw string) bool {
	values := strings.Split(raw, ",")
	for _, value := range values {
		if strings.TrimSpace(value) == current {
			return true
		}
	}
	return false
}

func promotionsValidationFieldError(errors map[string]string, key string) string {
	if errors == nil {
		return ""
	}
	return errors[key]
}

func promotionsValidationItemFieldError(errors map[string]string, kind string, idx int) string {
	if errors == nil {
		return ""
	}
	return errors[fmt.Sprintf("item_%s_%d", kind, idx)]
}

func promotionsValidationValueAt(values []string, idx int) string {
	if idx < 0 || idx >= len(values) {
		return ""
	}
	return values[idx]
}

func promotionsValidationResultTone(eligible bool) string {
	if eligible {
		return "success"
	}
	return "danger"
}

func promotionsValidationResultLabel(eligible bool) string {
	if eligible {
		return "適用可能"
	}
	return "適用不可"
}

func promotionsValidationRuleTone(rule promotionstpl.ValidationRuleView) string {
	if rule.Passed {
		return "success"
	}
	if rule.Blocking {
		return "danger"
	}
	return "warning"
}

func promotionsValidationRuleBadge(rule promotionstpl.ValidationRuleView) string {
	if rule.Passed {
		return "PASS"
	}
	if rule.Blocking {
		return "BLOCK"
	}
	return "WARN"
}

func trackingSummaryClass(tone string) string {
	switch tone {
	case "warning":
		return "rounded-xl border border-amber-200 bg-amber-500 px-4 py-3 text-white shadow-sm"
	case "danger":
		return "rounded-xl border border-rose-200 bg-rose-500 px-4 py-3 text-white shadow-sm"
	default:
		return "rounded-xl border border-sky-200 bg-sky-500 px-4 py-3 text-white shadow-sm"
	}
}

func trackingAlertClass(tone string) string {
	switch tone {
	case "danger":
		return "flex flex-col gap-2 rounded-2xl bg-rose-600/90 px-4 py-4 text-white shadow"
	case "warning":
		return "flex flex-col gap-2 rounded-2xl bg-amber-500/90 px-4 py-4 text-white shadow"
	default:
		return "flex flex-col gap-2 rounded-2xl bg-sky-500/90 px-4 py-4 text-white shadow"
	}
}

func trackingStatusChipClass(active bool) string {
	base := []string{"inline-flex items-center rounded-full border px-4 py-2 text-sm font-medium transition"}
	if active {
		base = append(base, "border-brand-500 bg-brand-50 text-brand-700")
	} else {
		base = append(base, "border-slate-200 text-slate-500 hover:border-brand-200 hover:text-brand-600")
	}
	return helpers.ClassList(base...)
}

func trackingStatusTone(tone string, active bool) string {
	base := []string{"inline-flex items-center rounded-full border px-4 py-2 text-sm font-medium transition"}
	switch tone {
	case "warning":
		base = append(base, "border-amber-200 text-amber-800")
	case "danger":
		base = append(base, "border-rose-200 text-rose-800")
	case "success":
		base = append(base, "border-emerald-200 text-emerald-700")
	case "slate":
		base = append(base, "border-slate-200 text-slate-600")
	default:
		base = append(base, "border-sky-200 text-sky-800")
	}
	if active {
		base = append(base, "bg-white shadow")
	} else {
		base = append(base, "bg-slate-50")
	}
	return helpers.ClassList(base...)
}

func trackingRefreshTrigger(enabled bool, seconds int) string {
	if !enabled {
		return ""
	}
	if seconds <= 0 {
		seconds = 30
	}
	return fmt.Sprintf("every %ds", seconds)
}

func trackingFragmentURL(path, raw string) string {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return path
	}
	if strings.Contains(path, "?") {
		return path + "&" + raw
	}
	return path + "?" + raw
}

func totalPages(total, size int) int {
	if size <= 0 {
		return 1
	}
	if total <= 0 {
		return 1
	}
	pages := total / size
	if total%size != 0 {
		pages++
	}
	if pages == 0 {
		pages = 1
	}
	return pages
}

func paginationURL(_ string, fragment, raw string, page any) string {
	value := intFromAny(page)
	if value < 1 {
		value = 1
	}
	query := helpers.SetRawQuery(raw, "page", fmt.Sprintf("%d", value))
	return trackingFragmentURL(fragment, query)
}

func trackingTotalPages(total, size int) int {
	return totalPages(total, size)
}

func trackingPaginationURL(fragment, raw string, page any) string {
	value := intFromAny(page)
	if value < 1 {
		value = 1
	}
	query := helpers.SetRawQuery(raw, "page", fmt.Sprintf("%d", value))
	return trackingFragmentURL(fragment, query)
}

func presetButtonClasses(active bool) string {
	if active {
		return "bg-brand-100 text-brand-700 ring-1 ring-brand-200"
	}
	return "bg-slate-100 text-slate-600 hover:bg-slate-200"
}

func exportSectionClasses(empty bool) string {
	if empty {
		return "hidden"
	}
	return ""
}

func slaToneClass(tone string) string {
	switch strings.ToLower(strings.TrimSpace(tone)) {
	case "danger":
		return "text-danger-600"
	case "warning":
		return "text-warning-600"
	case "success":
		return "text-success-600"
	default:
		return "text-slate-500"
	}
}

func sortCurrentDirection(active, key string) string {
	if active == key {
		return "asc"
	}
	if active == "-"+key {
		return "desc"
	}
	return ""
}

func sortNextDirection(current, defaultDir string) string {
	switch current {
	case "asc":
		return "desc"
	case "desc":
		return ""
	default:
		if strings.TrimSpace(defaultDir) == "" {
			return "asc"
		}
		return defaultDir
	}
}

func sortAriaValue(direction string) string {
	switch direction {
	case "asc":
		return "ascending"
	case "desc":
		return "descending"
	default:
		return "none"
	}
}

func sortHeaderClass(direction string) string {
	base := []string{
		"group inline-flex items-center gap-1 rounded-md px-1 py-0.5 text-xs font-semibold uppercase tracking-wide text-slate-600 transition focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-500 focus-visible:ring-offset-1 hover:text-slate-900",
	}
	if direction != "" {
		base = append(base, "text-slate-900")
	}
	return helpers.ClassList(base...)
}

func sortIconClass(direction string) string {
	if direction == "" {
		return "inline-flex h-5 w-5 items-center justify-center text-slate-500 transition group-hover:text-slate-700"
	}
	return "inline-flex h-5 w-5 items-center justify-center text-brand-600"
}

func sortHref(basePath, rawQuery, param, pageParam, active, key, defaultDir string, resetPage bool) string {
	query := rawQuery
	if resetPage {
		query = helpers.DelRawQuery(query, sortPageParamKey(pageParam))
	}
	nextDir := sortNextDirection(sortCurrentDirection(active, key), defaultDir)
	query = buildSortQuery(query, sortParamKey(param), key, nextDir)
	return helpers.BuildURL(sortBasePath(basePath), query)
}

func sortHxHref(fragmentPath, rawQuery, param, pageParam, active, key, defaultDir string, resetPage bool) string {
	query := rawQuery
	if resetPage {
		query = helpers.DelRawQuery(query, sortPageParamKey(pageParam))
	}
	nextDir := sortNextDirection(sortCurrentDirection(active, key), defaultDir)
	query = buildSortQuery(query, sortParamKey(param), key, nextDir)
	return helpers.BuildURL(sortBasePath(fragmentPath), query)
}

func sortNextDirectionAttr(active, key, defaultDir string) string {
	nextDir := sortNextDirection(sortCurrentDirection(active, key), defaultDir)
	if nextDir == "" {
		return "none"
	}
	return nextDir
}

func sortSrLabel(label, active, key, defaultDir string) string {
	current := sortCurrentDirection(active, key)
	next := sortNextDirection(current, defaultDir)
	return sortSrLabelFromDirections(label, current, next)
}

func sortSrLabelFromDirections(label, current, next string) string {
	currentState := "no sort applied"
	switch current {
	case "asc":
		currentState = "sorted ascending"
	case "desc":
		currentState = "sorted descending"
	}

	nextState := "will clear sorting"
	switch next {
	case "asc":
		nextState = "will sort ascending"
	case "desc":
		nextState = "will sort descending"
	}

	return fmt.Sprintf("%s (%s, activating %s)", label, currentState, nextState)
}

func buildSortQuery(rawQuery, param, key, direction string) string {
	switch direction {
	case "asc":
		return helpers.SetRawQuery(rawQuery, param, key)
	case "desc":
		return helpers.SetRawQuery(rawQuery, param, "-"+key)
	default:
		return helpers.DelRawQuery(rawQuery, param)
	}
}

func sortParamKey(param string) string {
	if strings.TrimSpace(param) != "" {
		return param
	}
	return "sort"
}

func sortPageParamKey(param string) string {
	if strings.TrimSpace(param) != "" {
		return param
	}
	return "page"
}

func sortBasePath(path string) string {
	if strings.TrimSpace(path) != "" {
		return path
	}
	return "."
}

func joinBaseFooter(base, suffix string) string {
	base = strings.TrimSpace(base)
	if base == "" || base == "/" {
		return "/" + strings.TrimPrefix(suffix, "/")
	}
	return strings.TrimRight(base, "/") + "/" + strings.TrimPrefix(suffix, "/")
}

func joinBase(base, suffix string) string {
	base = strings.TrimSpace(base)
	if base == "" {
		base = "/admin"
	}
	suffix = strings.TrimSpace(suffix)
	if !strings.HasPrefix(suffix, "/") {
		suffix = "/" + suffix
	}
	return strings.TrimRight(base, "/") + suffix
}

func intFromAny(value any) int {
	switch v := value.(type) {
	case int:
		return v
	case int64:
		return int(v)
	case float64:
		return int(v)
	case *int:
		if v == nil {
			return 0
		}
		return *v
	default:
		return 0
	}
}

func toastClass(tone string) string {
	return helpers.ToastClass(tone)
}

func modalPanelClass(size string) string {
	return helpers.ModalPanelClass(size)
}

func financeMetricCardClass(tone string) string {
	classes := []string{"flex", "min-w-[180px]", "flex-col", "gap-1", "rounded-xl", "border", "px-4", "py-3", "shadow-sm"}
	switch tone {
	case "success":
		classes = append(classes, "border-emerald-200", "bg-emerald-50")
	case "warning":
		classes = append(classes, "border-amber-200", "bg-amber-50")
	case "danger":
		classes = append(classes, "border-rose-200", "bg-rose-50")
	default:
		classes = append(classes, "border-slate-200", "bg-slate-50")
	}
	return helpers.ClassList(classes...)
}

func financeAlertClass(tone string) string {
	switch tone {
	case "warning":
		return "flex items-start gap-3 rounded-xl border border-amber-200 bg-amber-50 px-4 py-3 text-amber-800"
	case "danger":
		return "flex items-start gap-3 rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-red-800"
	default:
		return "flex items-start gap-3 rounded-xl border border-slate-200 bg-slate-50 px-4 py-3 text-slate-700"
	}
}

func financeHeaderMetricClass(tone string) string {
	base := []string{"flex", "flex-col", "gap-1", "rounded-xl", "border", "px-4", "py-3", "shadow-sm"}
	switch tone {
	case "success":
		base = append(base, "border-emerald-200", "bg-emerald-50", "text-emerald-700")
	case "warning":
		base = append(base, "border-amber-200", "bg-amber-50", "text-amber-700")
	case "info":
		base = append(base, "border-blue-200", "bg-blue-50", "text-blue-700")
	default:
		base = append(base, "border-slate-200", "bg-slate-50", "text-slate-700")
	}
	return helpers.ClassList(base...)
}

func financeNavigationItemClass(selected bool) string {
	base := []string{
		"flex items-center justify-between gap-3 rounded-lg border px-3 py-2 transition-colors",
	}
	if selected {
		base = append(base, "border-brand-500 bg-brand-50 text-brand-700")
	} else {
		base = append(base, "border-transparent hover:border-slate-200 hover:bg-slate-50")
	}
	return helpers.ClassList(base...)
}

func financeTaxTableRowClass(selected bool) string {
	if selected {
		return "bg-brand-50"
	}
	return ""
}

func financeInputClass(err any) string {
	errText := ""
	switch val := err.(type) {
	case nil:
		errText = ""
	case string:
		errText = strings.TrimSpace(val)
	default:
		errText = strings.TrimSpace(fmt.Sprint(val))
		if errText == "<nil>" {
			errText = ""
		}
	}
	base := []string{"w-full", "rounded-lg", "border", "px-3", "py-2", "text-sm", "shadow-sm", "focus:outline-none", "focus:ring-2"}
	if errText != "" {
		base = append(base, "border-red-300", "focus:border-red-500", "focus:ring-red-200")
	} else {
		base = append(base, "border-slate-300", "text-slate-700", "focus:border-brand-500", "focus:ring-brand-200")
	}
	return helpers.ClassList(base...)
}

func financeGridContainerID() string {
	return financetpl.GridContainerID
}

func financeContentContainerID() string {
	return financetpl.ContentContainerID
}

func financeDetailContainerID() string {
	return financetpl.DetailContainerID
}

func financeHistoryContainerID() string {
	return financetpl.HistoryContainerID
}

func financeReconciliationRootID() string {
	return financetpl.ReconciliationRootID
}

func minInt(a, b int) int {
	if a < b {
		return a
	}
	return b
}

func fallback(value, alt string) string {
	value = strings.TrimSpace(value)
	if value != "" {
		return value
	}
	return alt
}

func productionQueueSelectDomID(containerID string) string {
	slug := productionDomSlug(containerID)
	if slug == "" || slug == "id" {
		return "queue-select"
	}
	return slug + "-queue-select"
}

func productionBoardInstructionsDomID(boardID string) string {
	slug := productionDomSlug(boardID)
	if slug == "" || slug == "id" {
		return "instructions"
	}
	return slug + "-instructions"
}

func productionBoardAriaLabel(queue productiontpl.QueueMeta) string {
	name := strings.TrimSpace(queue.Name)
	if name == "" {
		return "制作ステージ"
	}
	return fmt.Sprintf("%sのステージ", name)
}

func productionLaneHeadingDomID(boardID string, stage string, label string) string {
	boardSlug := productionDomSlug(boardID)
	laneSlug := productionDomSlug(stage, label)
	if boardSlug == "" || boardSlug == "id" {
		boardSlug = "board"
	}
	if laneSlug == "" || laneSlug == "id" {
		laneSlug = "lane"
	}
	return boardSlug + "-" + laneSlug + "-heading"
}

func productionLaneMetaDomID(boardID string, stage string) string {
	boardSlug := productionDomSlug(boardID)
	laneSlug := productionDomSlug(stage, "meta")
	if boardSlug == "" || boardSlug == "id" {
		boardSlug = "board"
	}
	if laneSlug == "" || laneSlug == "id" {
		laneSlug = "lane-meta"
	}
	return boardSlug + "-" + laneSlug + "-meta"
}

func productionLaneAssistiveDescription(lane productiontpl.LaneData) string {
	label := strings.TrimSpace(lane.Label)
	if label == "" {
		label = "ステージ"
	}
	capacity := strings.TrimSpace(lane.CapacityLabel)
	if capacity == "" {
		capacity = "未設定"
	}
	return fmt.Sprintf("%s: 容量 %s、カード %d 件", label, capacity, len(lane.Cards))
}

func productionKanbanCardClass(selected bool, blocked bool) string {
	classes := []string{"rounded-2xl", "border", "border-slate-200", "bg-white", "p-4", "shadow-sm", "transition", "hover:shadow-md", "focus:outline-none", "focus:ring-2", "focus:ring-brand-500"}
	if selected {
		classes = append(classes, "ring-2", "ring-brand-500")
	}
	if blocked {
		classes = append(classes, "border-rose-200")
	}
	return helpers.ClassList(classes...)
}

func productionDueToneClass(tone string) string {
	switch tone {
	case "danger":
		return "text-rose-600"
	case "warning":
		return "text-amber-600"
	default:
		return "text-slate-500"
	}
}

func productionCardAriaLabel(card productiontpl.CardData) string {
	sections := []string{}
	if number := strings.TrimSpace(card.OrderNumber); number != "" {
		sections = append(sections, fmt.Sprintf("注文 %s", number))
	}
	if customer := strings.TrimSpace(card.Customer); customer != "" {
		sections = append(sections, fmt.Sprintf("顧客 %s", customer))
	}
	if combo := productionCompactJoin(" / ", card.ProductLine, card.Design); combo != "" {
		sections = append(sections, combo)
	}
	if stage := strings.TrimSpace(card.StageLabel); stage != "" {
		sections = append(sections, fmt.Sprintf("ステージ %s", stage))
	}
	if due := strings.TrimSpace(card.DueLabel); due != "" {
		sections = append(sections, fmt.Sprintf("期限 %s", due))
	}
	if len(sections) == 0 {
		return "生産カード"
	}
	return strings.Join(sections, "、")
}

func productionCardAssistiveMeta(card productiontpl.CardData) string {
	meta := []string{}
	if blocked := strings.TrimSpace(card.BlockedReason); card.Blocked && blocked != "" {
		meta = append(meta, fmt.Sprintf("ブロック理由: %s", blocked))
	} else if card.Blocked {
		meta = append(meta, "現在ブロック中")
	}
	if priority := strings.TrimSpace(card.PriorityLabel); priority != "" {
		meta = append(meta, fmt.Sprintf("優先度 %s", priority))
	}
	if workstation := strings.TrimSpace(card.Workstation); workstation != "" {
		meta = append(meta, fmt.Sprintf("作業場所 %s", workstation))
	}
	if len(card.Assignees) > 0 {
		meta = append(meta, fmt.Sprintf("担当者 %d 名", len(card.Assignees)))
	}
	if len(card.Flags) > 0 {
		meta = append(meta, fmt.Sprintf("フラグ %d 件", len(card.Flags)))
	}
	if len(meta) == 0 {
		return "カードの詳細は開いて確認できます。"
	}
	return strings.Join(meta, "、")
}

func productionCardMetaDomID(card productiontpl.CardData) string {
	slug := productionDomSlug("card", card.ID, card.OrderNumber)
	if slug == "" || slug == "id" {
		slug = "card"
	}
	return slug + "-meta"
}

func productionUnderlineTabClass(active bool) string {
	base := []string{
		"inline-flex", "items-center", "gap-2", "rounded-md", "border-b-2", "px-3", "py-2", "text-sm", "font-semibold", "transition-colors", "focus-visible:outline-none", "focus-visible:ring-2", "focus-visible:ring-brand-500", "focus-visible:ring-offset-2",
	}
	if active {
		base = append(base, "border-brand-500", "text-brand-600")
	} else {
		base = append(base, "border-transparent", "text-slate-500", "hover:border-slate-300", "hover:text-slate-900")
	}
	return helpers.ClassList(base...)
}

func productionUnderlineTabHref(href string, id string) string {
	if strings.TrimSpace(href) != "" {
		return href
	}
	if strings.TrimSpace(id) != "" {
		return "#" + id
	}
	return "#"
}

func productionSummaryAlertClass(tone string) string {
	switch tone {
	case "danger":
		return "flex flex-col gap-2 rounded-2xl bg-rose-600/90 px-5 py-4 text-white shadow"
	case "warning":
		return "flex flex-col gap-2 rounded-2xl bg-amber-500/90 px-5 py-4 text-white shadow"
	default:
		return "flex flex-col gap-2 rounded-2xl bg-sky-500/90 px-5 py-4 text-white shadow"
	}
}

func productionSummaryCardClass(tone string) string {
	base := []string{"flex", "flex-col", "justify-between", "rounded-2xl", "border", "px-5", "py-5", "shadow-sm", "transition"}
	switch tone {
	case "danger":
		base = append(base, "border-rose-200", "bg-rose-50")
	case "warning":
		base = append(base, "border-amber-200", "bg-amber-50")
	default:
		base = append(base, "border-slate-200", "bg-slate-50")
	}
	return helpers.ClassList(base...)
}

func productionSummaryMetricTone(tone string) string {
	switch tone {
	case "danger":
		return "font-semibold text-rose-600"
	case "warning":
		return "font-semibold text-amber-600"
	case "success":
		return "font-semibold text-emerald-600"
	default:
		return "font-semibold text-slate-900"
	}
}

func productionSummaryBarClass(percent int) string {
	class := []string{"h-full", "rounded-full", "bg-brand-500"}
	if percent >= 90 {
		class = append(class, "bg-rose-500")
	} else if percent >= 75 {
		class = append(class, "bg-amber-500")
	}
	return helpers.ClassList(class...)
}

func productionSummaryRowClass(tone string) string {
	switch tone {
	case "danger":
		return "bg-rose-50"
	case "warning":
		return "bg-amber-50"
	default:
		return ""
	}
}

func productionDeadlineToneClass(tone string) string {
	switch tone {
	case "danger":
		return "mt-1 font-semibold text-rose-600"
	case "warning":
		return "mt-1 font-semibold text-amber-600"
	default:
		return "mt-1 font-semibold text-slate-900"
	}
}

func productionChecklistBadgeClass(done bool) string {
	if done {
		return "inline-flex h-4 w-4 items-center justify-center rounded-full bg-emerald-500 text-white"
	}
	return "inline-flex h-4 w-4 items-center justify-center rounded-full border border-slate-300"
}

func productionNoticeToneClass(tone string) string {
	switch tone {
	case "warning":
		return "rounded-xl border-l-4 border-amber-400 bg-amber-50 px-4 py-3 text-sm text-amber-900"
	case "danger":
		return "rounded-xl border-l-4 border-rose-400 bg-rose-50 px-4 py-3 text-sm text-rose-900"
	default:
		return "rounded-xl border-l-4 border-sky-400 bg-sky-50 px-4 py-3 text-sm text-sky-900"
	}
}

func productionQCRowClass(selected bool) string {
	base := []string{"cursor-pointer", "transition-colors"}
	if selected {
		base = append(base, "bg-brand-50")
	} else {
		base = append(base, "hover:bg-slate-50")
	}
	return helpers.ClassList(base...)
}

func productionCompactJoin(sep string, values ...string) string {
	cleaned := make([]string, 0, len(values))
	for _, value := range values {
		if trimmed := strings.TrimSpace(value); trimmed != "" {
			cleaned = append(cleaned, trimmed)
		}
	}
	return strings.Join(cleaned, sep)
}

func productionDomSlug(values ...string) string {
	builder := strings.Builder{}
	for _, value := range values {
		segment := strings.ToLower(strings.TrimSpace(value))
		if segment == "" {
			continue
		}
		if builder.Len() > 0 {
			builder.WriteString("-")
		}
		for _, r := range segment {
			switch {
			case r >= 'a' && r <= 'z':
				builder.WriteRune(r)
			case r >= '0' && r <= '9':
				builder.WriteRune(r)
			default:
				builder.WriteRune('-')
			}
		}
	}
	result := strings.Trim(builder.String(), "-")
	if result == "" {
		return "id"
	}
	return result
}

func productionQueuesTableContainerID() string {
	return "production-queues-table"
}

func productionQueuesDrawerContainerID() string {
	return "production-queues-drawer"
}

func productionQueuesQueueRowClass(selected bool) string {
	base := []string{"cursor-pointer", "transition-colors"}
	if selected {
		base = append(base, "bg-brand-50")
	} else {
		base = append(base, "hover:bg-slate-50")
	}
	return helpers.ClassList(base...)
}

func productionQueuesActiveTone(active bool) string {
	if active {
		return "success"
	}
	return "warning"
}

func guidesLocaleChipClass(active bool) string {
	base := []string{"inline-flex", "items-center", "gap-1", "rounded-full", "border", "px-3", "py-1", "text-sm", "transition"}
	if active {
		base = append(base, "border-brand-500", "bg-brand-50", "text-brand-600")
	} else {
		base = append(base, "border-slate-200", "text-slate-600", "hover:border-brand-300", "hover:text-brand-600")
	}
	return helpers.ClassList(base...)
}

func guidesSegmentedClass(active bool) string {
	base := []string{"inline-flex", "items-center", "gap-2", "rounded-full", "border", "px-3", "py-1.5", "text-sm", "font-medium", "transition"}
	if active {
		base = append(base, "border-brand-500", "bg-brand-50", "text-brand-600")
	} else {
		base = append(base, "border-slate-200", "text-slate-600", "hover:border-brand-300", "hover:text-brand-600")
	}
	return helpers.ClassList(base...)
}

func guidesBulkStepClass(step guidestpl.BulkProgressStep, idx, active int) string {
	base := []string{"rounded-full", "px-3", "py-1"}
	switch {
	case step.Completed:
		base = append(base, "bg-brand-600", "text-white")
	case step.Current || idx == active:
		base = append(base, "bg-brand-100", "text-brand-700")
	default:
		base = append(base, "bg-slate-100", "text-slate-500")
	}
	return helpers.ClassList(base...)
}

func guidesPreviewLocaleClass(active bool) string {
	base := []string{"rounded-full", "px-4", "py-1", "transition-colors"}
	if active {
		base = append(base, "bg-white", "text-slate-900", "shadow-sm")
	} else {
		base = append(base, "text-slate-500", "hover:text-slate-900")
	}
	return helpers.ClassList(base...)
}

func guidesPreviewModeClass(active bool) string {
	classes := []string{"rounded-full", "px-3", "py-1"}
	if active {
		classes = append(classes, "bg-white", "text-slate-900", "shadow-sm")
	} else {
		classes = append(classes, "text-slate-500")
	}
	return helpers.ClassList(classes...)
}

func guidesTableRowClass(selected bool) string {
	base := []string{"cursor-pointer", "transition", "hover:bg-slate-50", "align-top"}
	if selected {
		base = append(base, "bg-brand-50")
	}
	return helpers.ClassList(base...)
}

func searchScopeOptionClass(active bool) string {
	base := "inline-flex items-center rounded-full border px-3 py-1.5 text-sm font-medium shadow-sm transition"
	if active {
		return base + " border-brand-500 bg-brand-50 text-brand-600"
	}
	return base + " border-slate-200 bg-slate-50 text-slate-600 hover:border-slate-300"
}

func searchFormatScore(score float64) string {
	if score <= 0 {
		return "0.00"
	}
	return fmt.Sprintf("%.2f", score)
}

func searchNoticeClass(tone string) string {
	base := "flex items-center gap-2 rounded-lg border px-4 py-3 text-sm shadow-sm"
	switch tone {
	case "danger", "error":
		return base + " border-rose-200 bg-rose-50 text-rose-700"
	case "info":
		return base + " border-sky-200 bg-sky-50 text-sky-700"
	default:
		return base + " border-slate-200 bg-slate-50 text-slate-600"
	}
}

func searchHighlightSegments(value, term string) []helpers.HighlightSegment {
	return helpers.HighlightSegments(value, term)
}

func paymentsSummaryDeltaClass(tone string) string {
	switch tone {
	case "warning":
		return "text-xs text-amber-600"
	case "success":
		return "text-xs text-emerald-600"
	case "danger":
		return "text-xs text-rose-600"
	default:
		return "text-xs text-slate-500"
	}
}

func paymentsStatusChipClass(active bool, tone string) string {
	base := []string{
		"inline-flex items-center rounded-full border px-3 py-1 text-xs font-medium transition focus:outline-none focus:ring-2 focus:ring-brand-500",
	}
	if active {
		base = append(base, "border-brand-500 bg-brand-50 text-brand-700")
	} else {
		switch tone {
		case "success":
			base = append(base, "border-emerald-200 bg-emerald-50 text-emerald-700 hover:border-emerald-300")
		case "warning":
			base = append(base, "border-amber-200 bg-amber-50 text-amber-700 hover:border-amber-300")
		case "danger":
			base = append(base, "border-rose-200 bg-rose-50 text-rose-700 hover:border-rose-300")
		default:
			base = append(base, "border-slate-200 bg-white text-slate-600 hover:border-slate-300")
		}
	}
	return helpers.ClassList(base...)
}

func paymentsFallback(value, fallback string) string {
	if strings.TrimSpace(value) != "" {
		return value
	}
	return fallback
}

func paymentsRowClass(selected bool) string {
	base := []string{"cursor-pointer", "transition", "hover:bg-slate-50"}
	if selected {
		base = append(base, "bg-brand-50/60")
	}
	return helpers.ClassList(base...)
}

func paymentsRiskBadgeClass(tone string) string {
	switch tone {
	case "danger":
		return "inline-flex w-fit items-center rounded-md bg-rose-100 px-2 py-1 text-xs font-semibold text-rose-700"
	case "warning":
		return "inline-flex w-fit items-center rounded-md bg-amber-100 px-2 py-1 text-xs font-semibold text-amber-700"
	default:
		return "inline-flex w-fit items-center rounded-md bg-slate-100 px-2 py-1 text-xs font-semibold text-slate-600"
	}
}

func paymentsBreakdownClass(tone string) string {
	switch tone {
	case "success":
		return "text-sm font-semibold text-emerald-700"
	case "danger":
		return "text-sm font-semibold text-rose-700"
	default:
		return "text-sm font-semibold text-slate-700"
	}
}

func systemSummaryDeltaClass(tone string) string {
	switch tone {
	case "danger":
		return "text-xs font-medium text-rose-600"
	case "success":
		return "text-xs font-medium text-emerald-600"
	default:
		return "text-xs font-medium text-slate-500"
	}
}

func systemSourceOptionClass(active bool, tone string) string {
	base := []string{"inline-flex", "items-center", "rounded-full", "border", "px-3", "py-1.5", "text-xs", "font-medium", "transition"}
	if active {
		base = append(base, "border-brand-500", "bg-brand-50", "text-brand-700")
	} else {
		base = append(base, "border-slate-200", "text-slate-500", "hover:border-brand-200", "hover:text-brand-600")
	}
	return helpers.ClassList(base...)
}

func systemSeverityOptionClass(active bool, tone string) string {
	base := []string{"inline-flex", "items-center", "rounded-full", "border", "px-3", "py-1.5", "text-xs", "font-medium", "transition"}
	if active {
		base = append(base, systemErrorsToneClass(tone, true))
	} else {
		base = append(base, systemErrorsToneClass(tone, false))
	}
	return helpers.ClassList(base...)
}

func systemStatusOptionClass(active bool, tone string) string {
	base := []string{"inline-flex", "items-center", "rounded-full", "border", "px-3", "py-1.5", "text-xs", "font-medium", "transition"}
	if active {
		base = append(base, systemErrorsToneClass(tone, true))
	} else {
		base = append(base, systemErrorsToneClass(tone, false))
	}
	return helpers.ClassList(base...)
}

func systemErrorsToneClass(tone string, active bool) string {
	switch tone {
	case "danger":
		if active {
			return "border-rose-500 bg-rose-50 text-rose-700"
		}
		return "border-slate-200 text-rose-500 hover:border-rose-200 hover:text-rose-600"
	case "warning":
		if active {
			return "border-amber-500 bg-amber-50 text-amber-700"
		}
		return "border-slate-200 text-amber-500 hover:border-amber-200 hover:text-amber-600"
	case "success":
		if active {
			return "border-emerald-500 bg-emerald-50 text-emerald-700"
		}
		return "border-slate-200 text-emerald-500 hover:border-emerald-200 hover:text-emerald-600"
	case "info":
		if active {
			return "border-sky-500 bg-sky-50 text-sky-700"
		}
		return "border-slate-200 text-sky-500 hover:border-sky-200 hover:text-sky-600"
	default:
		if active {
			return "border-brand-500 bg-brand-50 text-brand-700"
		}
		return "border-slate-200 text-slate-500 hover:border-brand-200 hover:text-brand-600"
	}
}

func systemErrorsTableRowClass(selected bool) string {
	base := []string{"cursor-pointer", "transition", "hover:bg-slate-50"}
	if selected {
		base = append(base, "bg-brand-50")
	}
	return helpers.ClassList(base...)
}

func systemErrorsTableActionClass(variant string) string {
	switch variant {
	case "primary":
		return helpers.ButtonClass("primary", "xs", false, false)
	case "secondary":
		return helpers.ButtonClass("secondary", "xs", false, false)
	default:
		return helpers.ButtonClass("ghost", "xs", false, false)
	}
}

func systemInlineAlertClass(tone string) string {
	switch tone {
	case "info":
		return "flex flex-col gap-2 rounded-2xl border border-sky-200 bg-sky-50 px-4 py-4 shadow-sm"
	case "warning":
		return "flex flex-col gap-2 rounded-2xl border border-amber-200 bg-amber-50 px-4 py-4 shadow-sm"
	case "danger":
		return "flex flex-col gap-2 rounded-2xl border border-rose-200 bg-rose-50 px-4 py-4 shadow-sm"
	default:
		return "flex flex-col gap-2 rounded-2xl border border-slate-200 bg-slate-50 px-4 py-4 shadow-sm"
	}
}

func systemFallbackLockReason(reason string) string {
	if strings.TrimSpace(reason) == "" {
		return "権限不足のため編集できません。"
	}
	return reason
}

func systemTasksToggleClass(active bool, tone string) string {
	base := []string{"inline-flex", "items-center", "rounded-full", "border", "px-3", "py-1.5", "text-xs", "font-medium", "transition"}
	if active {
		base = append(base, systemTasksToneClass(tone, true))
	} else {
		base = append(base, systemTasksToneClass(tone, false))
	}
	return helpers.ClassList(base...)
}

func systemTasksToneClass(tone string, active bool) string {
	switch tone {
	case "danger":
		if active {
			return "border-rose-500 bg-rose-50 text-rose-700"
		}
		return "border-slate-200 text-rose-500 hover:border-rose-200 hover:text-rose-600"
	case "warning":
		if active {
			return "border-amber-500 bg-amber-50 text-amber-700"
		}
		return "border-slate-200 text-amber-500 hover:border-amber-200 hover:text-amber-600"
	case "success":
		if active {
			return "border-emerald-500 bg-emerald-50 text-emerald-700"
		}
		return "border-slate-200 text-emerald-500 hover:border-emerald-200 hover:text-emerald-600"
	case "info":
		if active {
			return "border-sky-500 bg-sky-50 text-sky-700"
		}
		return "border-slate-200 text-sky-500 hover:border-sky-200 hover:text-sky-600"
	case "secondary":
		if active {
			return "border-slate-400 bg-slate-100 text-slate-700"
		}
		return "border-slate-200 text-slate-500 hover:border-slate-300 hover:text-slate-700"
	default:
		if active {
			return "border-brand-500 bg-brand-50 text-brand-700"
		}
		return "border-slate-200 text-slate-500 hover:border-brand-200 hover:text-brand-600"
	}
}

func systemTasksRowClass(selected bool) string {
	base := []string{"transition", "hover:bg-slate-50"}
	if selected {
		base = append(base, "bg-brand-50")
	} else {
		base = append(base, "bg-white")
	}
	return helpers.ClassList(base...)
}

func systemTasksInsightClass(tone string) string {
	switch tone {
	case "success":
		return "rounded-lg border border-emerald-200 bg-emerald-50 px-3 py-2 text-emerald-700"
	case "warning":
		return "rounded-lg border border-amber-200 bg-amber-50 px-3 py-2 text-amber-700"
	case "danger":
		return "rounded-lg border border-rose-200 bg-rose-50 px-3 py-2 text-rose-700"
	case "info":
		return "rounded-lg border border-sky-200 bg-sky-50 px-3 py-2 text-sky-700"
	default:
		return "rounded-lg border border-slate-200 bg-slate-50 px-3 py-2 text-slate-600"
	}
}

func systemTasksPickActionVariant(dangerous bool) string {
	if dangerous {
		return "danger"
	}
	return "primary"
}

func systemTaskHistoryPoints(chart systemtpl.TaskHistoryChart) string {
	if len(chart.Points) == 0 {
		return ""
	}
	if len(chart.Points) == 1 {
		return "0,50 100,50"
	}
	min := chart.Points[0].DurationSeconds
	max := chart.Points[0].DurationSeconds
	for _, point := range chart.Points[1:] {
		if point.DurationSeconds < min {
			min = point.DurationSeconds
		}
		if point.DurationSeconds > max {
			max = point.DurationSeconds
		}
	}
	rangeVal := max - min
	if rangeVal == 0 {
		rangeVal = 1
	}
	points := make([]string, 0, len(chart.Points))
	lastIndex := len(chart.Points) - 1
	for idx, point := range chart.Points {
		x := 0.0
		if lastIndex > 0 {
			x = float64(idx) / float64(lastIndex) * 100
		}
		y := 100 - ((point.DurationSeconds - min) / rangeVal * 100)
		points = append(points, fmt.Sprintf("%.1f,%.1f", x, y))
	}
	return strings.Join(points, " ")
}

func pickClass(condition bool, whenTrue, whenFalse string) string {
	if condition {
		return whenTrue
	}
	return whenFalse
}

func addInt(a, b int) int {
	return a + b
}

func buildURL(base string, rawQuery string) string {
	return helpers.BuildURL(base, rawQuery)
}

func setRawQuery(rawQuery string, key string, value string) string {
	return helpers.SetRawQuery(rawQuery, key, value)
}

func fmtInt(value int) string {
	return fmt.Sprintf("%d", value)
}

func containsString(values []string, target string) bool {
	for _, value := range values {
		if strings.EqualFold(value, target) {
			return true
		}
	}
	return false
}

func underlineTabClass(active bool) string {
	base := []string{
		"inline-flex",
		"items-center",
		"gap-2",
		"rounded-md",
		"border-b-2",
		"px-3",
		"py-2",
		"text-sm",
		"font-semibold",
		"transition-colors",
		"focus-visible:outline-none",
		"focus-visible:ring-2",
		"focus-visible:ring-brand-500",
		"focus-visible:ring-offset-2",
	}
	if active {
		base = append(base, "border-brand-500", "text-brand-600")
	} else {
		base = append(base, "border-transparent", "text-slate-500", "hover:border-slate-300", "hover:text-slate-900")
	}
	return helpers.ClassList(base...)
}

func underlineTabHref(tab components.UnderlineTab) string {
	if strings.TrimSpace(tab.Href) != "" {
		return tab.Href
	}
	if strings.TrimSpace(tab.ID) != "" {
		return "#" + tab.ID
	}
	return "#"
}

func underlineSwapValue(value string) string {
	if strings.TrimSpace(value) == "" {
		return "outerHTML"
	}
	return value
}

func catalogViewToggleClass(active bool) string {
	base := "inline-flex items-center gap-1 rounded-full px-3 py-1.5 text-sm font-medium shadow-sm transition"
	if active {
		return base + " bg-slate-900 text-white"
	}
	return base + " bg-slate-100 text-slate-600 hover:bg-slate-200"
}

func catalogStatusFilterClass(active bool, tone string) string {
	class := "inline-flex items-center rounded-full border px-3 py-1 text-xs font-semibold transition"
	if active {
		return class + " border-brand-500 bg-brand-50 text-brand-700"
	}
	return class + " border-slate-200 bg-slate-50 text-slate-500 hover:border-slate-300"
}

func catalogRowClass(selected bool) string {
	base := "cursor-pointer transition hover:bg-slate-50 focus-within:bg-slate-50"
	if selected {
		return base + " bg-brand-50"
	}
	return base
}

func catalogCardClass(selected bool) string {
	base := "rounded-2xl border px-4 py-4 shadow-sm transition hover:-translate-y-0.5 hover:shadow-md"
	if selected {
		return base + " border-brand-400 bg-brand-50"
	}
	return base + " border-slate-200 bg-white"
}

func catalogFilterEndpoint(data catalogtpl.PageData) string {
	if strings.TrimSpace(data.ViewToggle.Active) == "cards" {
		return helpers.BuildURL(data.CardsEndpoint, data.Cards.FilterQuery)
	}
	return helpers.BuildURL(data.TableEndpoint, data.Table.FilterQuery)
}

func catalogPaginationProps(table catalogtpl.TableData) PaginationProps {
	pageInfo := PageInfo{
		PageSize:   table.Pagination.PageSize,
		Current:    table.Pagination.Page,
		Count:      table.Pagination.Total,
		TotalItems: table.Pagination.TotalPtr,
		Next:       table.Pagination.Next,
		Prev:       table.Pagination.Prev,
	}
	return PaginationProps{
		Info:          pageInfo,
		BasePath:      table.PagePath,
		RawQuery:      table.FilterQuery,
		FragmentPath:  table.FragmentPath,
		FragmentQuery: table.RawQuery,
		Param:         "page",
		SizeParam:     "pageSize",
		HxTarget:      "#catalog-view",
		HxSwap:        "outerHTML",
		HxPushURL:     true,
	}
}

func catalogModalTone(value string) string {
	if strings.TrimSpace(value) == "" {
		return "primary"
	}
	return strings.TrimSpace(value)
}

func catalogFieldContainerClass(full bool) string {
	if full {
		return "md:col-span-2"
	}
	return ""
}

func catalogInputType(value string) string {
	switch strings.ToLower(strings.TrimSpace(value)) {
	case "number":
		return "number"
	case "email":
		return "email"
	case "url":
		return "url"
	case "datetime", "datetime-local":
		return "datetime-local"
	default:
		return "text"
	}
}

func catalogAssetHasValue(asset *catalogtpl.ModalAssetField) bool {
	if asset == nil {
		return false
	}
	if strings.TrimSpace(asset.AssetID) != "" {
		return true
	}
	if strings.TrimSpace(asset.URLFieldValue) != "" {
		return true
	}
	if strings.TrimSpace(asset.AssetURL) != "" {
		return true
	}
	return false
}

func catalogBoolString(value bool) string {
	if value {
		return "true"
	}
	return "false"
}

func catalogAssetPreviewClass(displayPreview bool, hasAsset bool) string {
	classes := []string{"relative", "flex", "h-20", "w-20", "items-center", "justify-center", "overflow-hidden", "rounded-lg", "border", "border-slate-200", "bg-slate-50", "text-slate-400"}
	if !hasAsset {
		classes = append(classes, "border-dashed")
	} else {
		classes = append(classes, "border-solid")
	}
	if displayPreview {
		classes = append(classes, "bg-white")
	}
	return helpers.ClassList(classes...)
}

func catalogCoalesceLabel(values ...string) string {
	for _, value := range values {
		if trimmed := strings.TrimSpace(value); trimmed != "" {
			return trimmed
		}
	}
	return ""
}

func catalogAssetFileLabel(asset *catalogtpl.ModalAssetField, hasAsset bool) string {
	if asset == nil {
		return ""
	}
	if hasAsset {
		if name := strings.TrimSpace(asset.FileName); name != "" {
			return name
		}
		if url := strings.TrimSpace(asset.AssetURL); url != "" {
			return path.Base(url)
		}
		if id := strings.TrimSpace(asset.AssetID); id != "" {
			return id
		}
	}
	return catalogCoalesceLabel(asset.EmptyLabel, "未設定")
}

func catalogAssetTriggerLabel(asset *catalogtpl.ModalAssetField, hasAsset bool) string {
	if asset == nil {
		return "アップロード"
	}
	if hasAsset {
		return catalogCoalesceLabel(asset.ReplaceLabel, asset.UploadLabel, "ファイルを変更")
	}
	return catalogCoalesceLabel(asset.UploadLabel, "ファイルをアップロード")
}

func catalogFormatFileSize(size int64) string {
	if size <= 0 {
		return ""
	}
	const (
		kilobyte = 1024
		megabyte = 1024 * kilobyte
	)
	if size >= megabyte {
		return fmt.Sprintf("%.1f MB", float64(size)/float64(megabyte))
	}
	if size >= kilobyte {
		return fmt.Sprintf("%.0f KB", float64(size)/float64(kilobyte))
	}
	return fmt.Sprintf("%d B", size)
}

func catalogCoalesceWarning(value string) string {
	if strings.TrimSpace(value) == "" {
		return "この操作は取り消せません。関連するテンプレートや商品に影響する可能性があります。"
	}
	return value
}

func profileAvatarInitial(name, email, fallback string) string {
	return profiletpl.AvatarInitial(name, email, fallback)
}

func profileFormatTimestamp(t time.Time) string {
	if t.IsZero() {
		return "-"
	}
	return helpers.Relative(t)
}

func profileFormatOptionalTime(t *time.Time) string {
	if t == nil {
		return "-"
	}
	return profileFormatTimestamp(*t)
}

func hasMFAMethod(state *profile.SecurityState, kind string) bool {
	if state == nil {
		return false
	}
	normalized := strings.TrimSpace(kind)
	for _, method := range state.MFA.Methods {
		if string(method.Kind) == normalized {
			return true
		}
	}
	return false
}
