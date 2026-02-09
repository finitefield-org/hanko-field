package store

import (
	"context"
	"errors"
)

var (
	ErrUnsupportedLocale   = errors.New("unsupported locale")
	ErrInvalidReference    = errors.New("invalid reference")
	ErrInactiveReference   = errors.New("inactive reference")
	ErrIdempotencyConflict = errors.New("idempotency key conflict")
)

type Store interface {
	GetPublicConfig(ctx context.Context) (PublicConfig, error)
	ListActiveFonts(ctx context.Context) ([]Font, error)
	ListActiveMaterials(ctx context.Context) ([]Material, error)
	ListActiveCountries(ctx context.Context) ([]Country, error)
	CreateOrder(ctx context.Context, input CreateOrderInput) (CreateOrderResult, error)
	ProcessStripeWebhook(ctx context.Context, event StripeWebhookEvent) (ProcessStripeWebhookResult, error)
	Close() error
}

type PublicConfig struct {
	SupportedLocales []string
	DefaultLocale    string
}

type Font struct {
	Key        string
	LabelI18N  map[string]string
	FontFamily string
	Version    int
	SortOrder  int
}

type MaterialPhoto struct {
	AssetID     string
	StoragePath string
	AltI18N     map[string]string
	SortOrder   int
	IsPrimary   bool
	Width       int
	Height      int
}

type Material struct {
	Key             string
	LabelI18N       map[string]string
	DescriptionI18N map[string]string
	Photos          []MaterialPhoto
	PriceJPY        int
	Version         int
	SortOrder       int
}

type Country struct {
	Code           string
	LabelI18N      map[string]string
	ShippingFeeJPY int
	Version        int
	SortOrder      int
}

type CreateOrderInput struct {
	Channel        string
	Locale         string
	IdempotencyKey string
	TermsAgreed    bool
	Seal           SealInput
	MaterialKey    string
	Shipping       ShippingInput
	Contact        ContactInput
}

type SealInput struct {
	Line1   string
	Line2   string
	Shape   string
	FontKey string
}

type ShippingInput struct {
	CountryCode   string
	RecipientName string
	Phone         string
	PostalCode    string
	State         string
	City          string
	AddressLine1  string
	AddressLine2  string
}

type ContactInput struct {
	Email           string
	PreferredLocale string
}

type CreateOrderResult struct {
	OrderID           string
	OrderNo           string
	Status            string
	PaymentStatus     string
	FulfillmentStatus string
	TotalJPY          int
	Currency          string
	IdempotentReplay  bool
}

type StripeWebhookEvent struct {
	ProviderEventID string
	EventType       string
	PaymentIntentID string
	OrderID         string
}

type ProcessStripeWebhookResult struct {
	Processed        bool
	AlreadyProcessed bool
}
