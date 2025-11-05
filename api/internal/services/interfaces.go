package services

import (
	"context"
	"time"

	domain "github.com/hanko-field/api/internal/domain"
	"github.com/hanko-field/api/internal/repositories"
)

// Type aliases expose domain models to the services package without reversing dependency direction.
type (
	Pagination                = domain.Pagination
	SortOrder                 = domain.SortOrder
	Design                    = domain.Design
	DesignType                = domain.DesignType
	DesignStatus              = domain.DesignStatus
	DesignSource              = domain.DesignSource
	DesignAssets              = domain.DesignAssets
	DesignAssetReference      = domain.DesignAssetReference
	DesignVersion             = domain.DesignVersion
	AISuggestion              = domain.AISuggestion
	Cart                      = domain.Cart
	CartPromotion             = domain.CartPromotion
	CartItem                  = domain.CartItem
	CartEstimate              = domain.CartEstimate
	PricingBreakdown          = domain.PricingBreakdown
	ItemPricingBreakdown      = domain.ItemPricingBreakdown
	DiscountBreakdown         = domain.DiscountBreakdown
	TaxBreakdown              = domain.TaxBreakdown
	ShippingBreakdown         = domain.ShippingBreakdown
	CheckoutSession           = domain.CheckoutSession
	Order                     = domain.Order
	OrderTotals               = domain.OrderTotals
	OrderLineItem             = domain.OrderLineItem
	OrderProductionEvent      = domain.OrderProductionEvent
	OrderProductionQC         = domain.OrderProductionQC
	OrderSort                 = repositories.OrderSort
	OrderStatus               = domain.OrderStatus
	OrderContact              = domain.OrderContact
	OrderFulfillment          = domain.OrderFulfillment
	OrderProduction           = domain.OrderProduction
	OrderFlags                = domain.OrderFlags
	OrderAudit                = domain.OrderAudit
	Payment                   = domain.Payment
	Shipment                  = domain.Shipment
	ShipmentEvent             = domain.ShipmentEvent
	ShipmentItem              = domain.ShipmentItem
	Review                    = domain.Review
	ReviewReply               = domain.ReviewReply
	ReviewStatus              = domain.ReviewStatus
	ReviewListFilter          = repositories.ReviewListFilter
	Promotion                 = domain.Promotion
	PromotionStacking         = domain.PromotionStacking
	PromotionConditions       = domain.PromotionConditions
	PromotionSizeRange        = domain.PromotionSizeRange
	PromotionValidationResult = domain.PromotionValidationResult
	PromotionPublic           = domain.PromotionPublic
	PromotionPage             = domain.CursorPage[Promotion]
	RegistrabilityCheckResult = domain.RegistrabilityCheckResult
	Address                   = domain.Address
	UserProfile               = domain.UserProfile
	InventoryReservationLine  = domain.InventoryReservationLine
	InventoryReservation      = domain.InventoryReservation
	InventorySnapshot         = domain.InventorySnapshot
	InventoryStock            = domain.InventoryStock
	InventoryStockEvent       = domain.InventoryStockEvent
	ContentPage               = domain.ContentPage
	ContentGuide              = domain.ContentGuide
	TemplateSummary           = domain.TemplateSummary
	Template                  = domain.Template
	TemplateDraft             = domain.TemplateDraft
	TemplateVersion           = domain.TemplateVersion
	TemplateSort              = domain.TemplateSort
	Font                      = domain.Font
	FontSummary               = domain.FontSummary
	FontLicense               = domain.FontLicense
	Material                  = domain.Material
	MaterialSummary           = domain.MaterialSummary
	MaterialTranslation       = domain.MaterialTranslation
	MaterialSustainability    = domain.MaterialSustainability
	MaterialProcurement       = domain.MaterialProcurement
	MaterialInventory         = domain.MaterialInventory
	Product                   = domain.Product
	ProductSummary            = domain.ProductSummary
	ProductPriceTier          = domain.ProductPriceTier
	ProductVariant            = domain.ProductVariant
	ProductVariantOption      = domain.ProductVariantOption
	ProductInventorySettings  = domain.ProductInventorySettings
	SystemHealthReport        = domain.SystemHealthReport
	SystemTask                = domain.SystemTask
	SystemTaskStatus          = domain.SystemTaskStatus
	SystemError               = domain.SystemError
	AuditLogEntry             = domain.AuditLogEntry
	SignedAssetResponse       = domain.SignedAssetResponse
	PromotionUsage            = domain.PromotionUsage
	PaymentMethod             = domain.PaymentMethod
	NameMapping               = domain.NameMapping
	NameMappingInput          = domain.NameMappingInput
	NameMappingCandidate      = domain.NameMappingCandidate
	NameMappingStatus         = domain.NameMappingStatus
	ProductionQueue           = domain.ProductionQueue
	ProductionQueueWIPSummary = domain.ProductionQueueWIPSummary
	Invoice                   = domain.Invoice
	InvoiceStatus             = domain.InvoiceStatus
	InvoiceLineItem           = domain.InvoiceLineItem
	InvoiceBatchSummary       = domain.InvoiceBatchSummary
	InvoiceBatchJob           = domain.InvoiceBatchJob
	InvoiceBatchJobStatus     = domain.InvoiceBatchJobStatus
)

// PromotionConstraint identifies a validation group evaluated for promotion definitions.
type PromotionConstraint string

const (
	PromotionConstraintStructure  PromotionConstraint = "structure"
	PromotionConstraintSchedule   PromotionConstraint = "schedule"
	PromotionConstraintLimits     PromotionConstraint = "usage_limits"
	PromotionConstraintConditions PromotionConstraint = "conditions"
	PromotionConstraintAudience   PromotionConstraint = "audience"
	PromotionConstraintStacking   PromotionConstraint = "stacking"
)

// PromotionValidationCheck captures the outcome of a single validation group.
type PromotionValidationCheck struct {
	Constraint PromotionConstraint
	Passed     bool
	Issues     []string
}

// PromotionDefinitionValidationResult stores dry-run validation details for a promotion definition.
type PromotionDefinitionValidationResult struct {
	Valid      bool
	Checks     []PromotionValidationCheck
	Normalized Promotion
}

// PromotionUsageUser captures the minimal user metadata surfaced alongside usage aggregates.
type PromotionUsageUser struct {
	ID          string
	Email       string
	DisplayName string
}

// PromotionUsageRecord joins per-user usage aggregates with user metadata.
type PromotionUsageRecord struct {
	Usage PromotionUsage
	User  PromotionUsageUser
}

// PromotionUsagePage provides pagination metadata for promotion usage listings.
type PromotionUsagePage = domain.CursorPage[PromotionUsageRecord]

// PromotionUsageSort enumerates supported sort fields for usage listings.
type PromotionUsageSort string

const (
	// PromotionUsageSortLastUsed sorts usage records by last-used timestamp (newest first by default).
	PromotionUsageSortLastUsed PromotionUsageSort = "lastUsedAt"
	// PromotionUsageSortTimes sorts usage records by usage count (highest first by default).
	PromotionUsageSortTimes PromotionUsageSort = "times"
)

const (
	SortAsc  = domain.SortAsc
	SortDesc = domain.SortDesc

	OrderSortCreatedAt = repositories.OrderSortCreatedAt
	OrderSortUpdatedAt = repositories.OrderSortUpdatedAt
	OrderSortPlacedAt  = repositories.OrderSortPlacedAt

	DesignTypeTyped    = domain.DesignTypeTyped
	DesignTypeUploaded = domain.DesignTypeUploaded
	DesignTypeLogo     = domain.DesignTypeLogo

	DesignStatusDraft   = domain.DesignStatusDraft
	DesignStatusReady   = domain.DesignStatusReady
	DesignStatusOrdered = domain.DesignStatusOrdered
	DesignStatusLocked  = domain.DesignStatusLocked
	DesignStatusDeleted = domain.DesignStatusDeleted

	NameMappingStatusPending  = domain.NameMappingStatusPending
	NameMappingStatusReady    = domain.NameMappingStatusReady
	NameMappingStatusSelected = domain.NameMappingStatusSelected
	NameMappingStatusExpired  = domain.NameMappingStatusExpired

	ProductionQueueStatusActive   = domain.ProductionQueueStatusActive
	ProductionQueueStatusPaused   = domain.ProductionQueueStatusPaused
	ProductionQueueStatusArchived = domain.ProductionQueueStatusArchived

	ProductionQueuePriorityNormal = domain.ProductionQueuePriorityNormal
	ProductionQueuePriorityRush   = domain.ProductionQueuePriorityRush

	InvoiceBatchJobStatusQueued     = domain.InvoiceBatchJobStatusQueued
	InvoiceBatchJobStatusProcessing = domain.InvoiceBatchJobStatusProcessing
	InvoiceBatchJobStatusSucceeded  = domain.InvoiceBatchJobStatusSucceeded
	InvoiceBatchJobStatusFailed     = domain.InvoiceBatchJobStatusFailed
	SystemTaskStatusPending         = domain.SystemTaskStatusPending
	SystemTaskStatusRunning         = domain.SystemTaskStatusRunning
	SystemTaskStatusCompleted       = domain.SystemTaskStatusCompleted
	SystemTaskStatusFailed          = domain.SystemTaskStatusFailed
)

// DesignService orchestrates design lifecycle operations, coordinating repositories,
// validation, and asynchronous AI suggestion workflows.
type DesignService interface {
	CreateDesign(ctx context.Context, cmd CreateDesignCommand) (Design, error)
	GetDesign(ctx context.Context, designID string, opts DesignReadOptions) (Design, error)
	ListDesigns(ctx context.Context, filter DesignListFilter) (domain.CursorPage[Design], error)
	ListDesignVersions(ctx context.Context, designID string, filter DesignVersionListFilter) (domain.CursorPage[DesignVersion], error)
	GetDesignVersion(ctx context.Context, designID string, versionID string, opts DesignVersionReadOptions) (DesignVersion, error)
	UpdateDesign(ctx context.Context, cmd UpdateDesignCommand) (Design, error)
	DeleteDesign(ctx context.Context, cmd DeleteDesignCommand) error
	DuplicateDesign(ctx context.Context, cmd DuplicateDesignCommand) (Design, error)
	RequestAISuggestion(ctx context.Context, cmd AISuggestionRequest) (AISuggestion, error)
	ListAISuggestions(ctx context.Context, designID string, filter AISuggestionFilter) (domain.CursorPage[AISuggestion], error)
	GetAISuggestion(ctx context.Context, designID string, suggestionID string) (AISuggestion, error)
	UpdateAISuggestionStatus(ctx context.Context, cmd AISuggestionStatusCommand) (AISuggestion, error)
	RequestRegistrabilityCheck(ctx context.Context, cmd RegistrabilityCheckCommand) (RegistrabilityCheckResult, error)
}

// CartService manages mutable cart state and estimates while enforcing inventory rules.
type CartService interface {
	GetOrCreateCart(ctx context.Context, userID string) (Cart, error)
	UpdateCart(ctx context.Context, cmd UpdateCartCommand) (Cart, error)
	AddOrUpdateItem(ctx context.Context, cmd UpsertCartItemCommand) (Cart, error)
	RemoveItem(ctx context.Context, cmd RemoveCartItemCommand) (Cart, error)
	Estimate(ctx context.Context, cmd CartEstimateCommand) (CartEstimateResult, error)
	ApplyPromotion(ctx context.Context, cmd CartPromotionCommand) (Cart, error)
	RemovePromotion(ctx context.Context, userID string) (Cart, error)
	ClearCart(ctx context.Context, userID string) error
}

// CheckoutService coordinates PSP session creation and client confirmations.
type CheckoutService interface {
	CreateCheckoutSession(ctx context.Context, cmd CreateCheckoutSessionCommand) (CheckoutSession, error)
	ConfirmClientCompletion(ctx context.Context, cmd ConfirmCheckoutCommand) (ConfirmCheckoutResult, error)
}

// FavoriteDesign enriches favorite records with resolved design metadata.
type FavoriteDesign struct {
	DesignID string
	AddedAt  time.Time
	Design   *Design
}

// OrderService encapsulates order read/write flows including cancellation and reorders.
type OrderService interface {
	CreateFromCart(ctx context.Context, cmd CreateOrderFromCartCommand) (Order, error)
	ListOrders(ctx context.Context, filter OrderListFilter) (domain.CursorPage[Order], error)
	GetOrder(ctx context.Context, orderID string, opts OrderReadOptions) (Order, error)
	TransitionStatus(ctx context.Context, cmd OrderStatusTransitionCommand) (Order, error)
	Cancel(ctx context.Context, cmd CancelOrderCommand) (Order, error)
	AppendProductionEvent(ctx context.Context, cmd AppendProductionEventCommand) (OrderProductionEvent, error)
	AssignOrderToQueue(ctx context.Context, cmd AssignOrderToQueueCommand) (Order, error)
	RequestInvoice(ctx context.Context, cmd RequestInvoiceCommand) (Order, error)
	CloneForReorder(ctx context.Context, cmd CloneForReorderCommand) (Order, error)
}

// InvoiceService coordinates bulk invoice generation and storage workflows.
type InvoiceService interface {
	IssueInvoices(ctx context.Context, cmd IssueInvoicesCommand) (IssueInvoicesResult, error)
}

// PaymentService handles idempotent PSP webhook processing and admin adjustments.
type PaymentService interface {
	RecordWebhookEvent(ctx context.Context, cmd PaymentWebhookCommand) error
	ManualCapture(ctx context.Context, cmd PaymentManualCaptureCommand) (Payment, error)
	ManualRefund(ctx context.Context, cmd PaymentManualRefundCommand) (Payment, error)
	ListPayments(ctx context.Context, orderID string) ([]Payment, error)
}

// ShipmentService orchestrates shipment creation, updates, and webhook ingestion.
type ShipmentService interface {
	CreateShipment(ctx context.Context, cmd CreateShipmentCommand) (Shipment, error)
	UpdateShipmentStatus(ctx context.Context, cmd UpdateShipmentCommand) (Shipment, error)
	ListShipments(ctx context.Context, orderID string) ([]Shipment, error)
	RecordCarrierEvent(ctx context.Context, cmd ShipmentEventCommand) error
}

// ReviewService coordinates review lifecycle and moderation workflows.
type ReviewService interface {
	Create(ctx context.Context, cmd CreateReviewCommand) (Review, error)
	GetByOrder(ctx context.Context, cmd GetReviewByOrderCommand) (Review, error)
	ListByUser(ctx context.Context, cmd ListUserReviewsCommand) (domain.CursorPage[Review], error)
	ListReviews(ctx context.Context, filter ReviewListFilter) (domain.CursorPage[Review], error)
	Moderate(ctx context.Context, cmd ModerateReviewCommand) (Review, error)
	StoreReply(ctx context.Context, cmd StoreReviewReplyCommand) (Review, error)
}

// CounterService coordinates sequence generation for formatted identifiers.
type CounterService interface {
	Next(ctx context.Context, scope, name string, opts CounterGenerationOptions) (CounterValue, error)
	NextOrderNumber(ctx context.Context) (string, error)
	NextInvoiceNumber(ctx context.Context) (string, error)
}

// PromotionService exposes promotion lifecycle and validation operations.
type PromotionService interface {
	GetPublicPromotion(ctx context.Context, code string) (PromotionPublic, error)
	ValidatePromotion(ctx context.Context, cmd ValidatePromotionCommand) (PromotionValidationResult, error)
	ValidatePromotionDefinition(ctx context.Context, promotion Promotion) (PromotionDefinitionValidationResult, error)
	ListPromotions(ctx context.Context, filter PromotionListFilter) (domain.CursorPage[Promotion], error)
	CreatePromotion(ctx context.Context, cmd UpsertPromotionCommand) (Promotion, error)
	UpdatePromotion(ctx context.Context, cmd UpsertPromotionCommand) (Promotion, error)
	DeletePromotion(ctx context.Context, promoID string, actorID string) error
	ListPromotionUsage(ctx context.Context, filter PromotionUsageFilter) (PromotionUsagePage, error)
}

// UserService manages profile, address, payment method, and favorite surfaces.
type UserService interface {
	GetProfile(ctx context.Context, userID string) (UserProfile, error)
	GetByUID(ctx context.Context, userID string) (UserProfile, error)
	UpdateProfile(ctx context.Context, cmd UpdateProfileCommand) (UserProfile, error)
	MaskProfile(ctx context.Context, cmd MaskProfileCommand) (UserProfile, error)
	DeactivateAndMask(ctx context.Context, cmd DeactivateAndMaskCommand) (UserProfile, error)
	SetUserActive(ctx context.Context, cmd SetUserActiveCommand) (UserProfile, error)
	ListAddresses(ctx context.Context, userID string) ([]Address, error)
	UpsertAddress(ctx context.Context, cmd UpsertAddressCommand) (Address, error)
	DeleteAddress(ctx context.Context, cmd DeleteAddressCommand) error
	ListPaymentMethods(ctx context.Context, userID string) ([]PaymentMethod, error)
	AddPaymentMethod(ctx context.Context, cmd AddPaymentMethodCommand) (PaymentMethod, error)
	RemovePaymentMethod(ctx context.Context, cmd RemovePaymentMethodCommand) error
	ListFavorites(ctx context.Context, userID string, pager Pagination) (domain.CursorPage[FavoriteDesign], error)
	ToggleFavorite(ctx context.Context, cmd ToggleFavoriteCommand) error
	SearchProfiles(ctx context.Context, filter UserSearchFilter) (domain.CursorPage[UserAdminSummary], error)
	GetAdminDetail(ctx context.Context, userID string) (UserAdminDetail, error)
}

// UserSearchFilter configures user lookup requests for admin/staff tooling.
type UserSearchFilter struct {
	Query           string
	PageSize        int
	PageToken       string
	IncludeInactive bool
}

// UserAdminSummary represents high-level metadata about a user for listings.
type UserAdminSummary struct {
	Profile     UserProfile
	Flags       []string
	LastLoginAt *time.Time
}

// UserAdminDetail enriches user metadata with authentication state for detail views.
type UserAdminDetail struct {
	Profile       UserProfile
	Flags         []string
	LastLoginAt   *time.Time
	LastRefreshAt *time.Time
	EmailVerified bool
	AuthDisabled  bool
	TokensValidAt *time.Time
}

// UserLifecycleNotifier dispatches user lifecycle events to downstream systems.
type UserLifecycleNotifier interface {
	NotifyUserDeactivated(ctx context.Context, notification UserDeactivatedNotification) error
}

// UserDeactivatedNotification captures context needed by integrations to process deactivation requests.
type UserDeactivatedNotification struct {
	UserID        string
	ActorID       string
	Reason        string
	OccurredAt    time.Time
	OriginalEmail string
	OriginalPhone string
	OriginalName  string
	MaskedEmail   string
	MaskedName    string
}

// NameMappingService orchestrates transliteration requests and caching logic for kanji candidate mappings.
type NameMappingService interface {
	ConvertName(ctx context.Context, cmd NameConversionCommand) (NameMapping, error)
	SelectCandidate(ctx context.Context, cmd NameMappingSelectCommand) (NameMapping, error)
}

// InventoryEventPublisher accepts inventory stock change notifications for downstream processing.
type InventoryEventPublisher interface {
	PublishInventoryEvent(ctx context.Context, event InventoryStockEvent) error
}

// InventoryService centralizes stock reservation, commit, and release workflows.
type InventoryService interface {
	ReserveStocks(ctx context.Context, cmd InventoryReserveCommand) (InventoryReservation, error)
	CommitReservation(ctx context.Context, cmd InventoryCommitCommand) (InventoryReservation, error)
	ReleaseReservation(ctx context.Context, cmd InventoryReleaseCommand) (InventoryReservation, error)
	ReleaseExpiredReservations(ctx context.Context, cmd ReleaseExpiredReservationsCommand) (InventoryReleaseExpiredResult, error)
	ListLowStock(ctx context.Context, filter InventoryLowStockFilter) (domain.CursorPage[InventorySnapshot], error)
	ConfigureSafetyStock(ctx context.Context, cmd ConfigureSafetyStockCommand) (InventoryStock, error)
}

// ContentService provides read/write access to CMS content for public and admin usage.
type ContentService interface {
	ListGuides(ctx context.Context, filter ContentGuideFilter) (domain.CursorPage[ContentGuide], error)
	GetGuideBySlug(ctx context.Context, slug string, locale string) (ContentGuide, error)
	GetGuide(ctx context.Context, guideID string) (ContentGuide, error)
	UpsertGuide(ctx context.Context, cmd UpsertContentGuideCommand) (ContentGuide, error)
	DeleteGuide(ctx context.Context, guideID string) error
	GetPage(ctx context.Context, slug string, locale string) (ContentPage, error)
	UpsertPage(ctx context.Context, cmd UpsertContentPageCommand) (ContentPage, error)
	DeletePage(ctx context.Context, cmd DeleteContentPageCommand) error
}

// ProductionQueueService manages configuration lifecycle for production queues used by operations staff.
type ProductionQueueService interface {
	ListQueues(ctx context.Context, filter ProductionQueueListFilter) (domain.CursorPage[ProductionQueue], error)
	GetQueue(ctx context.Context, queueID string) (ProductionQueue, error)
	CreateQueue(ctx context.Context, cmd UpsertProductionQueueCommand) (ProductionQueue, error)
	UpdateQueue(ctx context.Context, cmd UpsertProductionQueueCommand) (ProductionQueue, error)
	DeleteQueue(ctx context.Context, cmd DeleteProductionQueueCommand) error
	QueueWIPSummary(ctx context.Context, queueID string) (ProductionQueueWIPSummary, error)
}

// CatalogService manages templates, fonts, materials, and products for admin-facing operations.
type CatalogService interface {
	ListTemplates(ctx context.Context, filter TemplateFilter) (domain.CursorPage[TemplateSummary], error)
	GetTemplate(ctx context.Context, templateID string) (Template, error)
	UpsertTemplate(ctx context.Context, cmd UpsertTemplateCommand) (Template, error)
	DeleteTemplate(ctx context.Context, cmd DeleteTemplateCommand) error
	ListFonts(ctx context.Context, filter FontFilter) (domain.CursorPage[FontSummary], error)
	GetFont(ctx context.Context, fontID string) (Font, error)
	UpsertFont(ctx context.Context, cmd UpsertFontCommand) (FontSummary, error)
	DeleteFont(ctx context.Context, fontID string) error
	ListMaterials(ctx context.Context, filter MaterialFilter) (domain.CursorPage[MaterialSummary], error)
	GetMaterial(ctx context.Context, materialID string) (Material, error)
	UpsertMaterial(ctx context.Context, cmd UpsertMaterialCommand) (MaterialSummary, error)
	DeleteMaterial(ctx context.Context, cmd DeleteMaterialCommand) error
	ListProducts(ctx context.Context, filter ProductFilter) (domain.CursorPage[ProductSummary], error)
	GetProduct(ctx context.Context, productID string) (Product, error)
	UpsertProduct(ctx context.Context, cmd UpsertProductCommand) (Product, error)
	DeleteProduct(ctx context.Context, cmd DeleteProductCommand) error
}

// AssetService issues signed URLs and coordinates storage metadata syncing.
type AssetService interface {
	IssueSignedUpload(ctx context.Context, cmd SignedUploadCommand) (SignedAssetResponse, error)
	IssueSignedDownload(ctx context.Context, cmd SignedDownloadCommand) (SignedAssetResponse, error)
}

// SystemService aggregates utility endpoints (health checks, audit logs, counters).
type SystemService interface {
	HealthReport(ctx context.Context) (SystemHealthReport, error)
	ListAuditLogs(ctx context.Context, filter AuditLogFilter) (domain.CursorPage[AuditLogEntry], error)
	ListSystemErrors(ctx context.Context, filter SystemErrorFilter) (domain.CursorPage[SystemError], error)
	ListSystemTasks(ctx context.Context, filter SystemTaskFilter) (domain.CursorPage[SystemTask], error)
	NextCounterValue(ctx context.Context, cmd CounterCommand) (int64, error)
}

// SystemErrorStore exposes access to aggregated failure records used by system monitoring endpoints.
type SystemErrorStore interface {
	ListSystemErrors(ctx context.Context, filter SystemErrorFilter) (domain.CursorPage[SystemError], error)
}

// SystemTaskStore surfaces background task records for operational dashboards.
type SystemTaskStore interface {
	ListSystemTasks(ctx context.Context, filter SystemTaskFilter) (domain.CursorPage[SystemTask], error)
}

// ExportService coordinates data export tasks to downstream analytics systems.
type ExportService interface {
	StartBigQuerySync(ctx context.Context, cmd BigQueryExportCommand) (SystemTask, error)
}

// AuditLogService centralizes immutable audit log persistence and retrieval.
type AuditLogService interface {
	Record(ctx context.Context, record AuditLogRecord)
	List(ctx context.Context, filter AuditLogFilter) (domain.CursorPage[AuditLogEntry], error)
}

// AssetCopier copies storage objects between buckets or paths.
type AssetCopier interface {
	CopyObject(ctx context.Context, sourceBucket, sourceObject, destBucket, destObject string) error
}

// BackgroundJobDispatcher schedules asynchronous processing such as AI jobs, cleanup tasks, and notifications.
type BackgroundJobDispatcher interface {
	QueueAISuggestion(ctx context.Context, cmd QueueAISuggestionCommand) (QueueAISuggestionResult, error)
	GetAIJob(ctx context.Context, jobID string) (domain.AIJob, error)
	CompleteAISuggestion(ctx context.Context, cmd CompleteAISuggestionCommand) (CompleteAISuggestionResult, error)
	GetSuggestion(ctx context.Context, designID string, suggestionID string) (AISuggestion, error)
	EnqueueRegistrabilityCheck(ctx context.Context, payload RegistrabilityJobPayload) (string, error)
	EnqueueStockCleanup(ctx context.Context, payload StockCleanupPayload) error
}

// AISuggestionNotifier dispatches notifications when AI suggestions finish processing.
type AISuggestionNotifier interface {
	NotifySuggestionReady(ctx context.Context, notification AISuggestionNotification) error
}

// AISuggestionNotification encapsulates metadata delivered to notification channels when an AI
// suggestion is ready for review by the requesting user.
type AISuggestionNotification struct {
	JobID        string
	DesignID     string
	SuggestionID string
	UserID       string
	Method       string
	Model        string
	ReadyAt      time.Time
	Suggestion   AISuggestion
	Outputs      map[string]any
	Metadata     map[string]any
}

// ErrorTranslator converts repository or platform errors into domain-aware sentinel errors.
type ErrorTranslator interface {
	Translate(err error) error
}

// DomainError represents a structured error with stable codes for transport across layers.
type DomainError interface {
	error
	Code() string
	SafeMessage() string
}

// Command and DTO definitions ------------------------------------------------

type CreateDesignCommand struct {
	OwnerID         string
	ActorID         string
	Label           string
	Type            DesignType
	TextLines       []string
	FontID          string
	MaterialID      string
	TemplateID      string
	Locale          string
	Shape           string
	SizeMM          float64
	RawName         string
	KanjiValue      *string
	KanjiMappingRef *string
	Upload          *DesignAssetInput
	Logo            *DesignAssetInput
	Snapshot        map[string]any
	Metadata        map[string]any
	IdempotencyKey  string
}

// DesignAssetInput captures metadata for a user-provided asset referenced during design creation.
type DesignAssetInput struct {
	AssetID     string
	Bucket      string
	ObjectPath  string
	FileName    string
	ContentType string
	SizeBytes   int64
	Checksum    string
}

type DesignReadOptions struct {
	IncludeVersions    bool
	IncludeSuggestions bool
}

type DesignVersionListFilter struct {
	Pagination    Pagination
	IncludeAssets bool
}

type DesignVersionReadOptions struct {
	IncludeAssets bool
}

type DesignListFilter struct {
	OwnerID      string
	Status       []string
	Types        []string
	UpdatedAfter *time.Time
	Pagination
}

type UpdateDesignCommand struct {
	DesignID          string
	UpdatedBy         string
	Label             *string
	Status            *string
	ThumbnailURL      *string
	Snapshot          map[string]any
	ExpectedUpdatedAt *time.Time
}

type DeleteDesignCommand struct {
	DesignID          string
	RequestedBy       string
	SoftDelete        bool
	ExpectedUpdatedAt *time.Time
}

type DuplicateDesignCommand struct {
	SourceDesignID string
	RequestedBy    string
	OverrideName   *string
}

type AISuggestionRequest struct {
	DesignID       string
	Method         string
	Model          string
	Prompt         string
	Parameters     map[string]any
	Metadata       map[string]any
	IdempotencyKey string
	Priority       int
	ActorID        string
}

type AISuggestionFilter struct {
	Status     []string
	Pagination Pagination
}

type AISuggestionStatusCommand struct {
	DesignID     string
	SuggestionID string
	Action       string
	ActorID      string
	Reason       *string
}

type RegistrabilityCheckCommand struct {
	DesignID string
	UserID   string
	Locale   string
}

// RegistrabilityCheckPayload captures the design attributes sent to the external
// registrability service for evaluation.
type RegistrabilityCheckPayload struct {
	DesignID   string
	Name       string
	TextLines  []string
	Type       DesignType
	Locale     string
	MaterialID string
	TemplateID string
	Metadata   map[string]any
}

// RegistrabilityAssessment represents the outcome returned by the external registrability service.
type RegistrabilityAssessment struct {
	Status    string
	Passed    bool
	Score     *float64
	Reasons   []string
	ExpiresAt *time.Time
	Metadata  map[string]any
}

// RegistrabilityEvaluator defines the contract for external registrability checks.
type RegistrabilityEvaluator interface {
	Check(ctx context.Context, payload RegistrabilityCheckPayload) (RegistrabilityAssessment, error)
}

type UpsertCartItemCommand struct {
	UserID        string
	ItemID        *string
	ProductID     string
	SKU           string
	Quantity      int
	UnitPrice     int64
	Currency      string
	Customization map[string]any
	DesignID      *string
}

type UpdateCartCommand struct {
	UserID             string
	Currency           *string
	ShippingAddressID  *string
	BillingAddressID   *string
	Notes              *string
	PromotionHint      *string
	ExpectedUpdatedAt  *time.Time
	ExpectedFromHeader bool
}

type RemoveCartItemCommand struct {
	UserID string
	ItemID string
}

type CartEstimateCommand struct {
	UserID              string
	ShippingAddressID   *string
	BillingAddressID    *string
	PromotionCode       *string
	BypassShippingCache bool
}

type CartEstimateResult struct {
	Currency  string
	Estimate  CartEstimate
	Breakdown PricingBreakdown
	Promotion *CartPromotion
	Warnings  []CartEstimateWarning
}

type CartEstimateWarning string

const (
	CartEstimateWarningMissingShippingAddress CartEstimateWarning = "missing_shipping_address"
	CartEstimateWarningPromotionNotApplied    CartEstimateWarning = "promotion_not_applied"
)

type CartPromotionCommand struct {
	UserID         string
	Code           string
	Source         string
	IdempotencyKey string
}

type CreateCheckoutSessionCommand struct {
	UserID     string
	CartID     string
	SuccessURL string
	CancelURL  string
	PSP        string
	Metadata   map[string]string
}

type ConfirmCheckoutCommand struct {
	UserID          string
	OrderID         string
	SessionID       string
	PaymentIntentID string
}

type ConfirmCheckoutResult struct {
	Status  string
	OrderID string
}

type OrderListFilter = repositories.OrderListFilter

type OrderReadOptions struct {
	IncludePayments         bool
	IncludeShipments        bool
	IncludeProductionEvents bool
}

type CreateOrderFromCartCommand struct {
	Cart           Cart
	ActorID        string
	ReservationID  string
	OrderNumber    *string
	Metadata       map[string]any
	ExpectedStatus *OrderStatus
}

type OrderStatusTransitionCommand struct {
	OrderID        string
	TargetStatus   OrderStatus
	ActorID        string
	Reason         string
	ExpectedStatus *OrderStatus
	Metadata       map[string]any
}

type CancelOrderCommand struct {
	OrderID        string
	ActorID        string
	Reason         string
	ReservationID  string
	ExpectedStatus *OrderStatus
	Metadata       map[string]any
}

type RequestInvoiceCommand struct {
	OrderID        string
	ActorID        string
	Notes          string
	ExpectedStatus *OrderStatus
}

// InvoiceBatchFilter narrows invoice issuance scope when order IDs are not supplied.
type InvoiceBatchFilter struct {
	Statuses    []string
	PlacedRange domain.RangeQuery[time.Time]
}

// IssueInvoicesCommand requests batch invoice generation for selected orders.
type IssueInvoicesCommand struct {
	OrderIDs []string
	Filter   InvoiceBatchFilter
	ActorID  string
	Limit    int
	Notes    string
}

// IssuedInvoice summarises invoice metadata for each processed order.
type IssuedInvoice struct {
	OrderID       string
	InvoiceNumber string
	PDFAssetRef   string
}

// InvoiceFailure captures an order that failed during invoice issuance.
type InvoiceFailure struct {
	OrderID string
	Error   string
}

// IssueInvoicesResult reports batch job details and issued invoice metadata.
type IssueInvoicesResult struct {
	JobID   string
	Issued  []IssuedInvoice
	Summary InvoiceBatchSummary
	Failed  []InvoiceFailure
}

// ExportTimeWindow constrains export scope to a specific time range.
type ExportTimeWindow struct {
	From *time.Time
	To   *time.Time
}

// BigQueryExportCommand requests a background sync of selected entities to BigQuery.
type BigQueryExportCommand struct {
	ActorID        string
	Entities       []string
	Window         *ExportTimeWindow
	IdempotencyKey string
	Metadata       map[string]any
}

type AppendProductionEventCommand struct {
	OrderID string
	Event   OrderProductionEvent
	ActorID string
}

type AssignOrderToQueueCommand struct {
	OrderID           string
	QueueID           string
	ActorID           string
	ExpectedStatus    *OrderStatus
	ExpectedQueueID   *string
	IfUnmodifiedSince *time.Time
}

type CloneForReorderCommand struct {
	OrderID  string
	ActorID  string
	Metadata map[string]any
}

type PaymentWebhookCommand struct {
	Provider string
	Payload  []byte
	Headers  map[string]string
}

type PaymentManualCaptureCommand struct {
	OrderID        string
	PaymentID      string
	ActorID        string
	Amount         *int64
	Reason         string
	IdempotencyKey string
	Metadata       map[string]string
}

type PaymentManualRefundCommand struct {
	OrderID        string
	PaymentID      string
	ActorID        string
	Amount         *int64
	Reason         string
	IdempotencyKey string
	Metadata       map[string]string
}

type CreateShipmentCommand struct {
	OrderID            string
	Carrier            string
	ServiceLevel       string
	TrackingPreference string
	Package            *ShipmentPackage
	Items              []ShipmentItem
	CreatedBy          string
	ManualTrackingCode *string
}

type ShipmentPackage struct {
	Length float64
	Width  float64
	Height float64
	Weight float64
	Unit   string
}

type UpdateShipmentCommand struct {
	OrderID               string
	ShipmentID            string
	Status                string
	TrackingCode          *string
	ExpectedDelivery      *time.Time
	ClearExpectedDelivery bool
	Notes                 *string
	IfUnmodifiedSince     *time.Time
	ActorID               string
}

type ShipmentEventCommand struct {
	OrderID      string
	ShipmentID   string
	Carrier      string
	TrackingCode string
	Event        ShipmentEvent
}

type CreateReviewCommand struct {
	OrderID string
	UserID  string
	Rating  int
	Comment string
	ActorID string
}

type ListUserReviewsCommand struct {
	UserID     string
	Pagination Pagination
}

type GetReviewByOrderCommand struct {
	OrderID    string
	ActorID    string
	AllowStaff bool
}

type ModerateReviewCommand struct {
	ReviewID string
	ActorID  string
	Status   ReviewStatus
}

type StoreReviewReplyCommand struct {
	ReviewID string
	ActorID  string
	Message  string
	Visible  bool
}

type ValidatePromotionCommand struct {
	Code    string
	UserID  *string
	CartID  *string
	OrderID *string
}

type PromotionListFilter struct {
	Status     []string
	Kinds      []string
	ActiveOn   *time.Time
	Pagination Pagination
}

type UpsertPromotionCommand struct {
	Promotion             Promotion
	ActorID               string
	AllowImmutableUpdates bool
	UsageLimitSet         bool
}

type PromotionUsageFilter struct {
	PromotionID string
	Pagination  Pagination
	MinTimes    int
	SortBy      PromotionUsageSort
	SortOrder   SortOrder
}

type UpdateProfileCommand struct {
	UserID               string
	ActorID              string
	DisplayName          *string
	PreferredLanguage    *string
	Locale               *string
	NotificationPrefs    map[string]bool
	NotificationPrefsSet bool
	AvatarAssetID        *string
	AvatarAssetIDSet     bool
	ExpectedSyncTime     *time.Time
}

type MaskProfileCommand struct {
	UserID   string
	ActorID  string
	Reason   string
	Occurred time.Time
}

type DeactivateAndMaskCommand struct {
	UserID  string
	ActorID string
	Reason  string
}

type SetUserActiveCommand struct {
	UserID           string
	ActorID          string
	IsActive         bool
	Reason           string
	ExpectedSyncTime *time.Time
}

type UpsertAddressCommand struct {
	UserID          string
	AddressID       *string
	Address         Address
	DefaultShipping *bool
	DefaultBilling  *bool
}

type DeleteAddressCommand struct {
	UserID        string
	AddressID     string
	ReplacementID *string
}

type AddPaymentMethodCommand struct {
	UserID      string
	Provider    string
	Token       string
	MakeDefault bool
}

type RemovePaymentMethodCommand struct {
	UserID          string
	PaymentMethodID string
}

// PaymentMethodMetadata contains PSP-sourced attributes describing a payment instrument.
type PaymentMethodMetadata struct {
	Token    string
	Brand    string
	Last4    string
	ExpMonth int
	ExpYear  int
}

// PaymentMethodVerifier resolves PSP tokens into metadata prior to persistence.
type PaymentMethodVerifier interface {
	VerifyPaymentMethod(ctx context.Context, provider string, token string) (PaymentMethodMetadata, error)
}

// OutstandingInvoiceChecker reports whether a user has unpaid invoices blocking payment method removal.
type OutstandingInvoiceChecker interface {
	HasOutstandingInvoices(ctx context.Context, userID string) (bool, error)
}

// DesignFinder exposes the read operations required for user favorites validation.
type DesignFinder interface {
	FindByID(ctx context.Context, designID string) (Design, error)
}

type ToggleFavoriteCommand struct {
	UserID   string
	DesignID string
	Mark     bool
}

// NameConversionCommand describes an authenticated request to generate kanji candidates.
type NameConversionCommand struct {
	UserID       string
	Latin        string
	Locale       string
	Gender       string
	Context      map[string]string
	ForceRefresh bool
}

// NameMappingSelectCommand finalises a candidate selection for a mapping.
type NameMappingSelectCommand struct {
	UserID        string
	MappingID     string
	CandidateID   string
	AllowOverride bool
}

type InventoryReserveCommand struct {
	OrderID        string
	UserID         string
	Lines          []InventoryLine
	TTL            time.Duration
	Reason         string
	IdempotencyKey string
}

type InventoryCommitCommand struct {
	ReservationID string
	OrderID       string
	ActorID       string
}

type InventoryReleaseCommand struct {
	ReservationID string
	Reason        string
	ActorID       string
}

type ReleaseExpiredReservationsCommand struct {
	Limit   int
	Reason  string
	ActorID string
}

type InventoryReleaseExpiredResult struct {
	CheckedCount         int
	ReleasedCount        int
	AlreadyReleasedCount int
	NotFoundCount        int
	ReservationIDs       []string
	AlreadyReleasedIDs   []string
	SKUs                 []string
	SkippedCount         int
	SkippedIDs           []string
}

type InventoryLine struct {
	ProductID string
	SKU       string
	Quantity  int
}

type InventoryLowStockFilter struct {
	Threshold  int
	Pagination Pagination
}

type ProductionQueueListFilter struct {
	Status     []string
	Priorities []string
	Pagination Pagination
}

type ConfigureSafetyStockCommand struct {
	SKU           string
	ProductRef    string
	SafetyStock   int
	InitialOnHand *int
}

type ContentGuideFilter struct {
	Category       *string
	Slug           *string
	Locale         *string
	FallbackLocale string
	Status         []string
	PublishedOnly  bool
	Pagination     Pagination
}

type UpsertContentGuideCommand struct {
	Guide   ContentGuide
	ActorID string
}

type UpsertContentPageCommand struct {
	Page                   ContentPage
	ActorID                string
	RegeneratePreviewToken bool
}

type DeleteContentPageCommand struct {
	PageID  string
	ActorID string
}

type UpsertProductionQueueCommand struct {
	QueueID string
	Queue   ProductionQueue
	ActorID string
}

type DeleteProductionQueueCommand struct {
	QueueID string
	ActorID string
}

type TemplateFilter struct {
	Category      *string
	Style         *string
	Tags          []string
	SortBy        domain.TemplateSort
	SortOrder     SortOrder
	PublishedOnly bool
	Pagination    Pagination
}

type UpsertTemplateCommand struct {
	Template Template
	ActorID  string
}

type DeleteTemplateCommand struct {
	TemplateID string
	ActorID    string
}

type DeleteProductCommand struct {
	ProductID string
	ActorID   string
}

type FontFilter struct {
	Script        *string
	IsPremium     *bool
	PublishedOnly bool
	Pagination    Pagination
}

type UpsertFontCommand struct {
	Font    FontSummary
	ActorID string
}

type MaterialFilter struct {
	Category      *string
	OnlyAvailable bool
	Locale        string
	Pagination    Pagination
}

type UpsertMaterialCommand struct {
	Material MaterialSummary
	ActorID  string
}

type DeleteMaterialCommand struct {
	MaterialID string
	ActorID    string
}

type ProductFilter struct {
	Shape          *string
	SizeMm         *int
	MaterialID     *string
	IsCustomizable *bool
	PublishedOnly  bool
	Pagination     Pagination
}

type UpsertProductCommand struct {
	Product Product
	ActorID string
}

type SignedUploadCommand struct {
	ActorID     string
	DesignID    *string
	Kind        string
	Purpose     string
	FileName    string
	ContentType string
	SizeBytes   int64
}

type SignedDownloadCommand struct {
	ActorID string
	AssetID string
}

// SystemErrorFilter controls the retrieval of failure records exposed via system error endpoints.
type SystemErrorFilter struct {
	Sources    []string
	JobTypes   []string
	Statuses   []string
	Severities []string
	Search     string
	DateRange  domain.RangeQuery[time.Time]
	Pagination Pagination
}

// SystemTaskFilter applies pagination and attribute filters to system task listings.
type SystemTaskFilter struct {
	Statuses    []SystemTaskStatus
	Kinds       []string
	RequestedBy string
	DateRange   domain.RangeQuery[time.Time]
	Pagination  Pagination
}

// AuditLogRecord defines the payload accepted by the audit writer service.
type AuditLogRecord struct {
	Actor                 string
	ActorType             string
	Action                string
	TargetRef             string
	Severity              string
	RequestID             string
	OccurredAt            time.Time
	Metadata              map[string]any
	Diff                  map[string]AuditLogDiff
	SensitiveMetadataKeys []string
	SensitiveDiffKeys     []string
	IPAddress             string
	UserAgent             string
}

// AuditLogDiff captures before/after values for tracked fields.
type AuditLogDiff struct {
	Before any
	After  any
}

type AuditLogFilter struct {
	TargetRef  string
	Actor      string
	ActorType  string
	Action     string
	DateRange  domain.RangeQuery[time.Time]
	Pagination Pagination
}

type CounterCommand struct {
	CounterID string
	Step      int64
}

type CounterGenerationOptions struct {
	Step         int64
	MaxValue     *int64
	InitialValue *int64
	Prefix       string
	Suffix       string
	PadLength    int
	Formatter    func(time.Time, int64) string
}

type CounterValue struct {
	Value     int64
	Formatted string
}

// QueueAISuggestionCommand packages inputs for an AI suggestion job request.
type QueueAISuggestionCommand struct {
	DesignID       string
	Method         string
	Model          string
	Prompt         string
	SuggestionID   string
	Snapshot       map[string]any
	Parameters     map[string]any
	Metadata       map[string]any
	IdempotencyKey string
	Priority       int
	RequestedBy    string
}

// QueueAISuggestionResult reports identifiers generated for a queued AI job.
type QueueAISuggestionResult struct {
	JobID        string
	SuggestionID string
	Status       domain.AIJobStatus
	QueuedAt     time.Time
}

// CompleteAISuggestionCommand encapsulates AI worker outputs for persisting suggestion results.
type CompleteAISuggestionCommand struct {
	JobID      string
	Suggestion AISuggestion
	Error      *domain.AIJobError
	Outputs    map[string]any
	Metadata   map[string]any
}

// CompleteAISuggestionResult returns the persisted job and optional suggestion outputs.
type CompleteAISuggestionResult struct {
	Job        domain.AIJob
	Suggestion *AISuggestion
}

type RegistrabilityJobPayload struct {
	RequestID string
	DesignID  string
	Locale    string
}

type StockCleanupPayload struct {
	ReservationIDs []string
}
