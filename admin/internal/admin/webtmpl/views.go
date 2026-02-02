package webtmpl

import (
	"html/template"

	"finitefield.org/hanko-admin/internal/admin/httpserver/middleware"
	"finitefield.org/hanko-admin/internal/admin/navigation"
	auditlogstpl "finitefield.org/hanko-admin/internal/admin/templates/auditlogs"
	catalogtpl "finitefield.org/hanko-admin/internal/admin/templates/catalog"
	customerstpl "finitefield.org/hanko-admin/internal/admin/templates/customers"
	dashboardtpl "finitefield.org/hanko-admin/internal/admin/templates/dashboard"
	financetpl "finitefield.org/hanko-admin/internal/admin/templates/finance"
	guidestpl "finitefield.org/hanko-admin/internal/admin/templates/guides"
	notificationstpl "finitefield.org/hanko-admin/internal/admin/templates/notifications"
	orderstpl "finitefield.org/hanko-admin/internal/admin/templates/orders"
	orgtpl "finitefield.org/hanko-admin/internal/admin/templates/org"
	pagestpl "finitefield.org/hanko-admin/internal/admin/templates/pages"
	paymentstpl "finitefield.org/hanko-admin/internal/admin/templates/payments"
	productiontpl "finitefield.org/hanko-admin/internal/admin/templates/production"
	productionqueuestpl "finitefield.org/hanko-admin/internal/admin/templates/productionqueues"
	profiletpl "finitefield.org/hanko-admin/internal/admin/templates/profile"
	promotionstpl "finitefield.org/hanko-admin/internal/admin/templates/promotions"
	promotionusagetpl "finitefield.org/hanko-admin/internal/admin/templates/promotionusage"
	reviewstpl "finitefield.org/hanko-admin/internal/admin/templates/reviews"
	searchtpl "finitefield.org/hanko-admin/internal/admin/templates/search"
	shipmentstpl "finitefield.org/hanko-admin/internal/admin/templates/shipments"
	systemtpl "finitefield.org/hanko-admin/internal/admin/templates/system"
)

// Breadcrumb represents a simple breadcrumb item.
type Breadcrumb struct {
	Label string
	Href  string
}

// BreadcrumbsView wraps breadcrumb items for templates.
type BreadcrumbsView struct {
	Items []Breadcrumb
}

// SidebarView provides sidebar menu data.
type SidebarView struct {
	Locale       string
	RequestPath  string
	Groups       []navigation.MenuGroup
	Capabilities map[string]bool
}

// TopbarView provides topbar action data.
type TopbarView struct {
	Locale           string
	BasePath         string
	Environment      string
	SupportedLocales []string
	User             *middleware.User
	CSRFToken        string
	Capabilities     map[string]bool
}

// BaseView is the layout wrapper for admin pages.
type BaseView struct {
	Title              string
	Locale             string
	CSRFToken          string
	BasePath           string
	ContentClass       string
	ContentTemplate    string
	ContentHTML        template.HTML
	FeedbackTrackerURL string
	Breadcrumbs        BreadcrumbsView
	Sidebar            SidebarView
	Topbar             TopbarView
}

// DashboardView wraps the layout and dashboard page data.
type DashboardView struct {
	BaseView
	Page           dashboardtpl.PageData
	KPIFragment    DashboardKPIView
	AlertsFragment DashboardAlertsView
	ActivityFeed   DashboardActivityView
}

// DashboardKPIView wraps KPI fragment data with locale.
type DashboardKPIView struct {
	Locale string
	Data   dashboardtpl.KPIFragmentData
}

// DashboardAlertsView wraps alerts fragment data with locale.
type DashboardAlertsView struct {
	Locale string
	Data   dashboardtpl.AlertsFragmentData
}

// DashboardActivityView wraps activity feed data with locale.
type DashboardActivityView struct {
	Locale string
	Items  []dashboardtpl.ActivityItem
}

// PreviewPageView wraps the layout and preview page data.
type PreviewPageView struct {
	BaseView
	Header  pagestpl.PreviewHeaderData
	Content PreviewContentView
}

// PreviewContentView renders the preview HTML safely.
type PreviewContentView struct {
	HeroHTML template.HTML
	BodyHTML template.HTML
	Notes    []string
	Locales  []pagestpl.LocaleOption
}

// PagesIndexView wraps the layout and page management data.
type PagesIndexView struct {
	BaseView
	Data pagestpl.PageManagementData
}

// PagesPreviewFragmentView renders the preview panel fragment.
type PagesPreviewFragmentView struct {
	Preview pagestpl.PreviewViewData
}

// SearchPageView wraps the layout and search page data.
type SearchPageView struct {
	BaseView
	Page searchtpl.PageData
}

// SearchTableView renders the search results fragment.
type SearchTableView struct {
	Table searchtpl.TableData
}

// PaymentsPageView wraps the layout and payments page data.
type PaymentsPageView struct {
	BaseView
	Page  paymentstpl.PageData
	Table PaymentsTableView
}

// PaymentsTableView wraps payments table data with pagination props.
type PaymentsTableView struct {
	Table      paymentstpl.TableData
	Pagination PaginationProps
}

// PaymentsDrawerView wraps the payments drawer data.
type PaymentsDrawerView struct {
	Drawer paymentstpl.DrawerData
}

// SystemConfigPageView wraps the layout and system configuration data.
type SystemConfigPageView struct {
	BaseView
	Page systemtpl.EnvironmentSettingsPageData
}

// SystemTasksPageView wraps the layout and system tasks data.
type SystemTasksPageView struct {
	BaseView
	Page systemtpl.TasksPageData
}

// SystemTasksTableView renders the tasks table fragment with base path.
type SystemTasksTableView struct {
	systemtpl.TasksTableData
	BasePath string
}

// SystemTasksDrawerView renders the task drawer fragment.
type SystemTasksDrawerView struct {
	Drawer systemtpl.TasksDrawerData
}

// SystemCountersPageView wraps the layout and counters data.
type SystemCountersPageView struct {
	BaseView
	Page systemtpl.CountersPageData
}

// SystemCountersTableView renders the counters table fragment.
type SystemCountersTableView struct {
	Table    systemtpl.CountersTableData
	BasePath string
	Query    systemtpl.CountersQueryState
}

// SystemCountersDrawerView renders the counter drawer fragment.
type SystemCountersDrawerView struct {
	Drawer systemtpl.CountersDrawerData
	Query  systemtpl.CountersQueryState
}

// SystemErrorsPageView wraps the layout and system errors data.
type SystemErrorsPageView struct {
	BaseView
	Page systemtpl.PageData
}

// SystemErrorsTableView renders the system errors table fragment.
type SystemErrorsTableView struct {
	Table    systemtpl.TableData
	BasePath string
}

// SystemErrorsDrawerView renders the system errors drawer fragment.
type SystemErrorsDrawerView struct {
	Drawer   systemtpl.DrawerData
	BasePath string
}

// FeedbackModalView renders the feedback modal.
type FeedbackModalView struct {
	Locale string
	Data   systemtpl.FeedbackModalData
}

// GuidesTableView wraps table payload with CSRF token.
type GuidesTableView struct {
	Table     guidestpl.TableData
	CSRFToken string
}

// GuidesPageView wraps the layout and guides index data.
type GuidesPageView struct {
	BaseView
	Page  guidestpl.PageData
	Table GuidesTableView
}

// GuidesFragmentView renders the table fragment payload.
type GuidesFragmentView struct {
	Table     guidestpl.TableData
	Summary   guidestpl.SummaryData
	Bulk      guidestpl.BulkData
	Drawer    guidestpl.DrawerData
	CSRFToken string
}

// GuidesPreviewPageView wraps the layout and preview page data.
type GuidesPreviewPageView struct {
	BaseView
	Page guidestpl.PreviewPageData
}

// GuidesEditorPageView wraps the layout and editor page data.
type GuidesEditorPageView struct {
	BaseView
	Page guidestpl.EditorPageData
}

// CatalogPageView wraps the layout and catalog page data.
type CatalogPageView struct {
	BaseView
	Page catalogtpl.PageData
}

// CatalogTableView wraps the catalog table fragment data.
type CatalogTableView struct {
	Page     catalogtpl.PageData
	BasePath string
}

// CatalogCardsView wraps the catalog cards fragment data.
type CatalogCardsView struct {
	Page     catalogtpl.PageData
	BasePath string
}

// CatalogModalView renders catalog modals with base path.
type CatalogModalView struct {
	BasePath string
	Data     catalogtpl.ModalFormData
}

// CatalogDeleteModalView renders catalog delete modal.
type CatalogDeleteModalView struct {
	BasePath string
	Data     catalogtpl.DeleteModalData
}

// ProfilePageView wraps the layout and profile data.
type ProfilePageView struct {
	BaseView
	Page profiletpl.PageData
}

// ProfileTabsView renders the profile tabs fragment.
type ProfileTabsView struct {
	Page     profiletpl.PageData
	BasePath string
}

// ProfileSessionUpdateView renders the sessions update fragment.
type ProfileSessionUpdateView struct {
	BasePath string
	Data     profiletpl.SessionUpdateData
}

// HistoryModalView renders the history modal.
type HistoryModalView struct {
	Title string
	Data  pagestpl.HistoryViewData
}

// ButtonOptions configures shared button styling.
type ButtonOptions struct {
	Variant   string
	Size      string
	Type      string
	Href      string
	Leading   string
	Trailing  string
	FullWidth bool
	Disabled  bool
	Loading   bool
	Attrs     map[string]string
}

// ButtonView wraps button content and options.
type ButtonView struct {
	Label   string
	Options ButtonOptions
}

// TextInputProps configures a text input.
type TextInputProps struct {
	ID          string
	Name        string
	Type        string
	Value       string
	Label       string
	Placeholder string
	Hint        string
	Error       string
	Required    bool
	Disabled    bool
	AutoFocus   bool
	Attrs       map[string]string
}

// TextAreaProps configures a textarea.
type TextAreaProps struct {
	ID          string
	Name        string
	Value       string
	Label       string
	Placeholder string
	Hint        string
	Error       string
	Required    bool
	Disabled    bool
	Rows        int
	Attrs       map[string]string
}

// SelectOption represents a select option.
type SelectOption struct {
	Value    string
	Label    string
	Selected bool
	Disabled bool
}

// SelectProps configures a select input.
type SelectProps struct {
	ID       string
	Name     string
	Label    string
	Hint     string
	Error    string
	Required bool
	Disabled bool
	Attrs    map[string]string
	Options  []SelectOption
}

// BadgeProps configures a badge display.
type BadgeProps struct {
	Label string
	Tone  string
}

// PageInfo captures pagination state.
type PageInfo struct {
	PageSize   int
	Current    int
	Count      int
	TotalItems *int
	Next       *int
	Prev       *int
}

// PaginationProps configures a pagination control.
type PaginationProps struct {
	Info          PageInfo
	BasePath      string
	RawQuery      string
	FragmentPath  string
	FragmentQuery string
	Param         string
	SizeParam     string
	HxTarget      string
	HxSwap        string
	HxPushURL     bool
	Attrs         map[string]string
	Label         string
}

// PaginationView wraps pagination props for templates.
type PaginationView struct {
	Props PaginationProps
}

// ModalView renders a modal shell with provided body HTML.
type ModalView struct {
	ID           string
	Title        string
	BodyHTML     template.HTML
	OverlayAttrs map[string]string
	PanelAttrs   map[string]string
	BodyAttrs    map[string]string
}

// TableView renders a basic table.
type TableView struct {
	Headers      []string
	Rows         [][]string
	EmptyMessage string
}

// NotificationsPageView wraps the notifications page data.
type NotificationsPageView struct {
	BaseView
	Title         string
	Description   string
	Legend        []notificationstpl.LegendItem
	Filters       notificationstpl.Filters
	Query         notificationstpl.QueryState
	TableEndpoint string
	Table         NotificationsTableView
	Drawer        NotificationsDrawerView
}

// NotificationRowView renders a notification table row.
type NotificationRowView struct {
	ID                string
	CategoryLabel     string
	CategoryTone      string
	CategoryIcon      string
	SeverityLabel     string
	SeverityTone      string
	Title             string
	Summary           string
	StatusLabel       string
	StatusTone        string
	ResourceLabel     string
	ResourceURL       string
	ResourceKind      string
	Owner             string
	CreatedAtRelative string
	CreatedAtTooltip  string
	Actions           []notificationstpl.RowAction
	Attributes        map[string]string
}

// NotificationsTableView wraps the notifications table payload.
type NotificationsTableView struct {
	Total        int
	NextCursor   string
	Error        string
	EmptyMessage string
	SelectedID   string
	Items        []NotificationRowView
}

// NotificationsDrawerView wraps the notifications drawer payload.
type NotificationsDrawerView struct {
	Empty             bool
	ID                string
	Title             string
	Summary           string
	CategoryLabel     string
	CategoryTone      string
	SeverityLabel     string
	SeverityTone      string
	StatusLabel       string
	StatusTone        string
	Owner             string
	Resource          notificationstpl.ResourceView
	CreatedRelative   string
	CreatedTooltip    string
	AcknowledgedLabel string
	ResolvedLabel     string
	Metadata          []notificationstpl.MetadataView
	Timeline          []notificationstpl.TimelineEventView
	Links             []notificationstpl.RowAction
}

// NotificationsBadgeView wraps the badge payload.
type NotificationsBadgeView struct {
	Total          int
	Critical       int
	Warning        int
	ReviewsPending int
	TasksPending   int
	Endpoint       string
	Href           string
}

// OrdersPageView wraps the layout and orders page data.
type OrdersPageView struct {
	BaseView
	Page  orderstpl.PageData
	Table OrdersTableView
}

// OrdersTableView wraps the orders table fragment data.
type OrdersTableView struct {
	Table      orderstpl.TableData
	Pagination PaginationView
}

// ShipmentsPageView wraps the layout and shipments batch page data.
type ShipmentsPageView struct {
	BaseView
	Page shipmentstpl.PageData
}

// ShipmentsTrackingPageView wraps the layout and tracking page data.
type ShipmentsTrackingPageView struct {
	BaseView
	Page shipmentstpl.TrackingPageData
}

// ShipmentsDrawerView wraps drawer data with base path for links.
type ShipmentsDrawerView struct {
	BasePath string
	Drawer   shipmentstpl.DrawerData
}

// FinanceReconciliationView wraps the layout and reconciliation data.
type FinanceReconciliationView struct {
	BaseView
	Page financetpl.ReconciliationPageData
}

// FinanceTaxSettingsView wraps the layout and tax settings data.
type FinanceTaxSettingsView struct {
	BaseView
	Page financetpl.PageData
}

// FinanceTaxGridView renders the tax settings grid fragment.
type FinanceTaxGridView struct {
	Content  financetpl.ContentData
	Snackbar *financetpl.SnackbarView
}

// ProductionPageView wraps the layout and production board data.
type ProductionPageView struct {
	BaseView
	Page productiontpl.PageData
}

// ProductionSummaryView wraps the layout and WIP summary data.
type ProductionSummaryView struct {
	BaseView
	Page productiontpl.WIPSummaryPageData
}

// ProductionWorkOrderView wraps the layout and work order data.
type ProductionWorkOrderView struct {
	BaseView
	Page productiontpl.WorkOrderPageData
}

// ProductionQCView wraps the layout and QC page data.
type ProductionQCView struct {
	BaseView
	Page productiontpl.QCPageData
}

// ProductionQueuesView wraps the layout and queue settings data.
type ProductionQueuesView struct {
	BaseView
	Page productionqueuestpl.PageData
}

// ProductionQueuesTableView renders the table fragment with base path.
type ProductionQueuesTableView struct {
	BasePath string
	Table    productionqueuestpl.QueueTableData
}

// ProductionQueuesTableDrawerView renders table + drawer.
type ProductionQueuesTableDrawerView struct {
	BasePath string
	Table    productionqueuestpl.QueueTableData
	Drawer   productionqueuestpl.DrawerData
}

// AuditLogsTableView wraps the table payload with pagination view.
type AuditLogsTableView struct {
	Table      auditlogstpl.TableData
	Pagination PaginationView
}

// AuditLogsPageView wraps the layout and audit log page data.
type AuditLogsPageView struct {
	BaseView
	Page  auditlogstpl.PageData
	Table AuditLogsTableView
}

// PromotionsTableView wraps the table payload with pagination view.
type PromotionsTableView struct {
	Table      promotionstpl.TableData
	Pagination PaginationView
}

// PromotionsPageView wraps the layout and promotions page data.
type PromotionsPageView struct {
	BaseView
	Page   promotionstpl.PageData
	Table  PromotionsTableView
	Drawer promotionstpl.DrawerData
}

// PromotionUsageTableView wraps the usage table payload with pagination view.
type PromotionUsageTableView struct {
	Table      promotionusagetpl.TableData
	Pagination PaginationView
}

// PromotionUsagePageView wraps the layout and promotion usage data.
type PromotionUsagePageView struct {
	BaseView
	Page  promotionusagetpl.PageData
	Table PromotionUsageTableView
}

// OrgPageView wraps the layout and organisation management data.
type OrgPageView struct {
	BaseView
	Page orgtpl.PageData
}

// CustomersTableView wraps the table payload with pagination view.
type CustomersTableView struct {
	Locale     string
	Table      customerstpl.TableData
	Pagination PaginationView
}

// CustomersPageView wraps the layout and customers page data.
type CustomersPageView struct {
	BaseView
	Page  customerstpl.PageData
	Table CustomersTableView
}

// CustomerDetailView wraps the layout and customer detail data.
type CustomerDetailView struct {
	BaseView
	Page customerstpl.DetailPageData
}

// ReviewsTableView wraps the table payload with pagination view.
type ReviewsTableView struct {
	Table      reviewstpl.TableData
	Pagination PaginationView
}

// ReviewsPageView wraps the layout and reviews page data.
type ReviewsPageView struct {
	BaseView
	Page   reviewstpl.PageData
	Table  ReviewsTableView
	Detail reviewstpl.DetailData
}

// ReviewsTableFragmentView renders table and detail fragments.
type ReviewsTableFragmentView struct {
	Table  ReviewsTableView
	Detail reviewstpl.DetailData
}

// ReviewsRefreshView refreshes table and detail after actions.
type ReviewsRefreshView struct {
	Table  ReviewsTableView
	Detail reviewstpl.DetailData
}
