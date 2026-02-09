package httpapi

import (
	"errors"
	"fmt"
	"net/mail"
	"regexp"
	"strings"
	"unicode"
	"unicode/utf8"

	"hanko-field/api/internal/store"
)

var (
	idempotencyKeyPattern = regexp.MustCompile(`^[A-Za-z0-9_-]{8,128}$`)
	localePattern         = regexp.MustCompile(`^[a-z]{2,3}(-[a-z0-9]{2,8})*$`)
)

type createOrderRequest struct {
	Channel        string                     `json:"channel"`
	Locale         string                     `json:"locale"`
	IdempotencyKey string                     `json:"idempotency_key"`
	TermsAgreed    bool                       `json:"terms_agreed"`
	Seal           createOrderSealRequest     `json:"seal"`
	MaterialKey    string                     `json:"material_key"`
	Shipping       createOrderShippingRequest `json:"shipping"`
	Contact        createOrderContactRequest  `json:"contact"`
}

type createOrderSealRequest struct {
	Line1   string `json:"line1"`
	Line2   string `json:"line2"`
	Shape   string `json:"shape"`
	FontKey string `json:"font_key"`
}

type createOrderShippingRequest struct {
	CountryCode   string `json:"country_code"`
	RecipientName string `json:"recipient_name"`
	Phone         string `json:"phone"`
	PostalCode    string `json:"postal_code"`
	State         string `json:"state"`
	City          string `json:"city"`
	AddressLine1  string `json:"address_line1"`
	AddressLine2  string `json:"address_line2"`
}

type createOrderContactRequest struct {
	Email           string `json:"email"`
	PreferredLocale string `json:"preferred_locale"`
}

func validateCreateOrderRequest(req createOrderRequest) (store.CreateOrderInput, error) {
	channel := strings.ToLower(strings.TrimSpace(req.Channel))
	if channel != "app" && channel != "web" {
		return store.CreateOrderInput{}, errors.New("channel must be one of app or web")
	}

	locale := strings.ToLower(strings.TrimSpace(req.Locale))
	if !localePattern.MatchString(locale) {
		return store.CreateOrderInput{}, errors.New("locale must be a valid BCP-47 lowercase tag")
	}

	idempotencyKey := strings.TrimSpace(req.IdempotencyKey)
	if !idempotencyKeyPattern.MatchString(idempotencyKey) {
		return store.CreateOrderInput{}, errors.New("idempotency_key must match ^[A-Za-z0-9_-]{8,128}$")
	}

	if !req.TermsAgreed {
		return store.CreateOrderInput{}, errors.New("terms_agreed must be true")
	}

	line1 := strings.TrimSpace(req.Seal.Line1)
	if err := validateSealLine("seal.line1", line1, 1, 2); err != nil {
		return store.CreateOrderInput{}, err
	}
	line2 := strings.TrimSpace(req.Seal.Line2)
	if err := validateSealLine("seal.line2", line2, 0, 2); err != nil {
		return store.CreateOrderInput{}, err
	}

	shape := strings.ToLower(strings.TrimSpace(req.Seal.Shape))
	if shape != "square" && shape != "round" {
		return store.CreateOrderInput{}, errors.New("seal.shape must be one of square or round")
	}

	fontKey := strings.TrimSpace(req.Seal.FontKey)
	if fontKey == "" {
		return store.CreateOrderInput{}, errors.New("seal.font_key is required")
	}

	materialKey := strings.TrimSpace(req.MaterialKey)
	if materialKey == "" {
		return store.CreateOrderInput{}, errors.New("material_key is required")
	}

	countryCode := strings.ToUpper(strings.TrimSpace(req.Shipping.CountryCode))
	if len(countryCode) != 2 {
		return store.CreateOrderInput{}, errors.New("shipping.country_code must be ISO alpha-2")
	}
	if err := requireNonEmpty("shipping.recipient_name", req.Shipping.RecipientName); err != nil {
		return store.CreateOrderInput{}, err
	}
	if err := requireNonEmpty("shipping.phone", req.Shipping.Phone); err != nil {
		return store.CreateOrderInput{}, err
	}
	if err := requireNonEmpty("shipping.postal_code", req.Shipping.PostalCode); err != nil {
		return store.CreateOrderInput{}, err
	}
	if err := requireNonEmpty("shipping.state", req.Shipping.State); err != nil {
		return store.CreateOrderInput{}, err
	}
	if err := requireNonEmpty("shipping.city", req.Shipping.City); err != nil {
		return store.CreateOrderInput{}, err
	}
	if err := requireNonEmpty("shipping.address_line1", req.Shipping.AddressLine1); err != nil {
		return store.CreateOrderInput{}, err
	}

	email := strings.TrimSpace(req.Contact.Email)
	if email == "" {
		return store.CreateOrderInput{}, errors.New("contact.email is required")
	}
	if _, err := mail.ParseAddress(email); err != nil {
		return store.CreateOrderInput{}, errors.New("contact.email must be valid")
	}

	preferredLocale := strings.ToLower(strings.TrimSpace(req.Contact.PreferredLocale))
	if !localePattern.MatchString(preferredLocale) {
		return store.CreateOrderInput{}, errors.New("contact.preferred_locale must be a valid BCP-47 lowercase tag")
	}

	return store.CreateOrderInput{
		Channel:        channel,
		Locale:         locale,
		IdempotencyKey: idempotencyKey,
		TermsAgreed:    req.TermsAgreed,
		Seal: store.SealInput{
			Line1:   line1,
			Line2:   line2,
			Shape:   shape,
			FontKey: fontKey,
		},
		MaterialKey: materialKey,
		Shipping: store.ShippingInput{
			CountryCode:   countryCode,
			RecipientName: strings.TrimSpace(req.Shipping.RecipientName),
			Phone:         strings.TrimSpace(req.Shipping.Phone),
			PostalCode:    strings.TrimSpace(req.Shipping.PostalCode),
			State:         strings.TrimSpace(req.Shipping.State),
			City:          strings.TrimSpace(req.Shipping.City),
			AddressLine1:  strings.TrimSpace(req.Shipping.AddressLine1),
			AddressLine2:  strings.TrimSpace(req.Shipping.AddressLine2),
		},
		Contact: store.ContactInput{
			Email:           email,
			PreferredLocale: preferredLocale,
		},
	}, nil
}

func requireNonEmpty(fieldName, raw string) error {
	if strings.TrimSpace(raw) == "" {
		return fmt.Errorf("%s is required", fieldName)
	}
	return nil
}

func validateSealLine(fieldName, value string, minLen, maxLen int) error {
	length := utf8.RuneCountInString(value)
	if length < minLen || length > maxLen {
		return fmt.Errorf("%s must be %d-%d characters", fieldName, minLen, maxLen)
	}
	for _, r := range value {
		if unicode.IsSpace(r) {
			return fmt.Errorf("%s must not contain whitespace", fieldName)
		}
	}
	return nil
}

func resolveLocalized(i18n map[string]string, requestedLocale, defaultLocale string) string {
	requested := strings.ToLower(strings.TrimSpace(requestedLocale))
	def := strings.ToLower(strings.TrimSpace(defaultLocale))

	if value := lookupI18N(i18n, requested); value != "" {
		return value
	}
	if value := lookupI18N(i18n, def); value != "" {
		return value
	}
	if value := lookupI18N(i18n, "ja"); value != "" {
		return value
	}
	for _, value := range i18n {
		trimmed := strings.TrimSpace(value)
		if trimmed != "" {
			return trimmed
		}
	}
	return ""
}

func lookupI18N(i18n map[string]string, locale string) string {
	if locale == "" {
		return ""
	}
	value, ok := i18n[locale]
	if !ok {
		return ""
	}
	return strings.TrimSpace(value)
}
