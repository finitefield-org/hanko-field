package main

import (
	"fmt"
	"net/url"
	"strings"
	"time"

	"finitefield.org/hanko-web/internal/format"
	mw "finitefield.org/hanko-web/internal/middleware"
)

// CheckoutReviewView powers the `/checkout/review` page.
type CheckoutReviewView struct {
	Steps    []CheckoutStep
	Alerts   []CheckoutInlineAlert
	Summary  CheckoutSummary
	Snapshot CheckoutReviewSnapshot
	Shipment CheckoutReviewShipment
	Billing  CheckoutReviewBilling
	Payment  CheckoutReviewPayment
	Items    []CartItem
	Loyalty  CheckoutReviewLoyalty
	Terms    CheckoutReviewTerms
	Support  CheckoutSupportCard

	BackURL     string
	SubmitURL   string
	LastUpdated time.Time
}

// CheckoutReviewSnapshot highlights the lead design or cart hero.
type CheckoutReviewSnapshot struct {
	Title      string
	Subtitle   string
	ImageURL   string
	ImageAlt   string
	Badge      CheckoutBadge
	MetaLines  []string
	PreviewURL string
}

// CheckoutReviewShipment summarizes delivery details.
type CheckoutReviewShipment struct {
	MethodLabel string
	Carrier     string
	Badge       string
	BadgeTone   string
	ETA         string
	Window      string
	Weight      string
	Highlights  []string
	Address     *CheckoutAddress
	EditURL     string
}

// CheckoutReviewBilling renders billing contact data.
type CheckoutReviewBilling struct {
	Address *CheckoutAddress
	Notes   []string
	EditURL string
}

// CheckoutReviewPayment outlines payment method metadata.
type CheckoutReviewPayment struct {
	Method     *CheckoutSavedMethod
	Amount     int64
	Currency   string
	Status     string
	StatusTone string
	Notes      []string
	EditURL    string
}

// CheckoutReviewTerms describes the policy acknowledgment block.
type CheckoutReviewTerms struct {
	Label        string
	Description  string
	PolicyURL    string
	PrivacyURL   string
	RequiredNote string
}

// CheckoutReviewLoyalty displays loyalty/credit meta.
type CheckoutReviewLoyalty struct {
	Tier     string
	Points   int
	Summary  string
	Detail   string
	CTALabel string
	CTAHref  string
}

func buildCheckoutReviewView(lang string, q url.Values, sess *mw.SessionData) CheckoutReviewView {
	addresses := mergeCheckoutAddresses(lang, sess.Checkout.Addresses)
	shippingAddr := findCheckoutAddress(addresses, sess.Checkout.ShippingAddressID)
	billingAddr := findCheckoutAddress(addresses, sess.Checkout.BillingAddressID)

	country := strings.ToUpper(strings.TrimSpace(q.Get("country")))
	if country == "" && shippingAddr != nil {
		country = strings.ToUpper(strings.TrimSpace(shippingAddr.Country))
	}
	if country == "" {
		country = "JP"
	}

	postal := strings.TrimSpace(q.Get("postal"))
	if postal == "" && shippingAddr != nil {
		postal = strings.TrimSpace(shippingAddr.PostalCode)
	}
	if postal == "" {
		postal = defaultPostalForCountry(country)
	}

	method := normalizeCartShippingMethod(q.Get("method"))
	if method == "" {
		method = normalizeCartShippingMethod(sess.Checkout.ShippingMethodID)
	}
	promo := normalizePromoCode(q.Get("promo"))

	query := url.Values{}
	query.Set("country", country)
	if postal != "" {
		query.Set("postal", postal)
	}
	if method != "" {
		query.Set("method", method)
	}
	if promo != "" {
		query.Set("promo", promo)
	}

	cartView := buildCartView(lang, query)

	summary := CheckoutSummary{
		Estimate: cartView.Estimate,
		Items: []CheckoutSummaryItem{
			{Label: i18nOrDefault(lang, "checkout.summary.items", "Items"), Value: fmt.Sprintf("%d", cartView.Estimate.ItemsCount)},
			{Label: i18nOrDefault(lang, "checkout.summary.method", "Method"), Value: cartView.Estimate.MethodLabel},
			{Label: i18nOrDefault(lang, "checkout.summary.eta", "ETA"), Value: cartView.Estimate.ETA},
		},
		Notes: []string{
			fmt.Sprintf("%s: %s", i18nOrDefault(lang, "checkout.payment.due_today", "Due today"), format.FmtCurrency(cartView.Estimate.Total, cartView.Estimate.Currency, lang)),
		},
		ShippingAddress: shippingAddr,
	}

	snapshot := buildCheckoutReviewSnapshot(lang, cartView.Items)
	shipment := buildCheckoutReviewShipment(lang, cartView, shippingAddr, method)
	billing := CheckoutReviewBilling{
		Address: billingAddr,
		Notes: []string{
			i18nOrDefault(lang, "checkout.review.billing.note", "Invoices and receipts will be sent to this contact once engraving completes."),
		},
		EditURL: "/checkout/address",
	}

	savedMethods := mockCheckoutSavedMethods(lang)
	requestedMethod := strings.TrimSpace(q.Get("method_id"))
	selectedMethod := selectCheckoutPaymentMethod(savedMethods, requestedMethod, sess.Checkout.PaymentMethodID)
	payment := buildCheckoutReviewPayment(lang, savedMethods, selectedMethod, cartView.Estimate.Total, cartView.Estimate.Currency)

	loyalty := buildCheckoutReviewLoyalty(lang, cartView.Estimate.Total)
	terms := buildCheckoutReviewTerms(lang)
	alerts := buildCheckoutReviewAlerts(lang, shippingAddr, billingAddr, method, payment.Method)

	view := CheckoutReviewView{
		Steps:    cartSteps(lang, "review"),
		Alerts:   alerts,
		Summary:  summary,
		Snapshot: snapshot,
		Shipment: shipment,
		Billing:  billing,
		Payment:  payment,
		Items:    cartView.Items,
		Loyalty:  loyalty,
		Terms:    terms,
		Support: CheckoutSupportCard{
			Title:    i18nOrDefault(lang, "checkout.review.support.title", "Need to adjust engraving after ordering?"),
			Body:     i18nOrDefault(lang, "checkout.review.support.body", "Our studio can hold shipment, upload revised proofs, or coordinate customs paperwork."),
			CTALabel: i18nOrDefault(lang, "checkout.support.cta", "Chat with concierge"),
			CTAHref:  "mailto:support@hanko-field.example",
		},
		BackURL:     "/checkout/payment",
		SubmitURL:   "/checkout/review/submit",
		LastUpdated: cartView.Estimate.UpdatedAt,
	}
	return view
}

func buildCheckoutReviewSnapshot(lang string, items []CartItem) CheckoutReviewSnapshot {
	if len(items) == 0 {
		return CheckoutReviewSnapshot{
			Title:     i18nOrDefault(lang, "checkout.review.snapshot.empty", "No items in cart"),
			Subtitle:  i18nOrDefault(lang, "checkout.review.snapshot.empty.subtitle", "Add designs to continue checkout."),
			ImageURL:  "/assets/placeholders/stamp-square.png",
			ImageAlt:  "Empty cart",
			MetaLines: []string{i18nOrDefault(lang, "checkout.review.snapshot.meta.empty", "Awaiting selections")},
			Badge:     CheckoutBadge{Label: i18nOrDefault(lang, "checkout.review.snapshot.badge.draft", "Draft"), Tone: "warning"},
		}
	}
	first := items[0]
	meta := []string{
		fmt.Sprintf("SKU %s · %s", first.SKU, first.Shape),
		fmt.Sprintf("%dmm · %s", first.Quantity, first.Material),
	}
	if first.ETA != "" {
		meta = append(meta, first.ETA)
	}
	return CheckoutReviewSnapshot{
		Title:      first.Name,
		Subtitle:   first.Subtitle,
		ImageURL:   first.Image,
		ImageAlt:   first.Name,
		Badge:      CheckoutBadge{Label: i18nOrDefault(lang, "checkout.review.snapshot.badge.primary", "Primary design"), Tone: "info"},
		MetaLines:  meta,
		PreviewURL: "/design/preview",
	}
}

func buildCheckoutReviewShipment(lang string, cartView CartView, addr *CheckoutAddress, methodID string) CheckoutReviewShipment {
	meta := shippingMethodMeta(lang, methodID)
	highlights := make([]string, 0, len(meta.Highlights)+1)
	if cartView.Estimate.ETA != "" {
		highlights = append(highlights, fmt.Sprintf("%s: %s", i18nOrDefault(lang, "checkout.summary.eta", "ETA"), cartView.Estimate.ETA))
	}
	highlights = append(highlights, meta.Highlights...)
	return CheckoutReviewShipment{
		MethodLabel: defaultString(meta.Label, cartView.Estimate.MethodLabel),
		Carrier:     meta.Carrier,
		Badge:       meta.Badge,
		BadgeTone:   meta.BadgeTone,
		ETA:         cartView.Estimate.ETA,
		Window:      meta.Window,
		Weight:      cartView.Estimate.WeightDisplay,
		Highlights:  highlights,
		Address:     addr,
		EditURL:     "/checkout/shipping",
	}
}

func buildCheckoutReviewPayment(lang string, methods []CheckoutSavedMethod, selected string, amount int64, currency string) CheckoutReviewPayment {
	method := findCheckoutSavedMethod(methods, selected)
	notes := []string{
		i18nOrDefault(lang, "checkout.review.payment.note", "Charges settle immediately so we can hand off to engraving."),
	}
	status := i18nOrDefault(lang, "checkout.review.payment.status", "Ready to capture")
	tone := "success"
	if method == nil {
		status = i18nOrDefault(lang, "checkout.review.payment.status.missing", "Add a payment method to continue")
		tone = "error"
	}
	return CheckoutReviewPayment{
		Method:     method,
		Amount:     amount,
		Currency:   currency,
		Status:     status,
		StatusTone: tone,
		Notes:      notes,
		EditURL:    "/checkout/payment",
	}
}

func buildCheckoutReviewLoyalty(lang string, total int64) CheckoutReviewLoyalty {
	points := int(total / 10)
	return CheckoutReviewLoyalty{
		Tier:     i18nOrDefault(lang, "checkout.review.loyalty.tier", "Studio Pro"),
		Points:   points,
		Summary:  i18nOrDefault(lang, "checkout.review.loyalty.summary", "You’ll earn loyalty points after delivery."),
		Detail:   i18nOrDefault(lang, "checkout.review.loyalty.detail", "Points convert to engraving rush credits and studio booking perks."),
		CTALabel: i18nOrDefault(lang, "checkout.review.loyalty.cta", "View rewards"),
		CTAHref:  "/account",
	}
}

func buildCheckoutReviewTerms(lang string) CheckoutReviewTerms {
	return CheckoutReviewTerms{
		Label:        i18nOrDefault(lang, "checkout.review.terms.label", "I understand engraving begins immediately after placing my order."),
		Description:  i18nOrDefault(lang, "checkout.review.terms.description", "By continuing you accept the Terms of Service and Privacy Policy."),
		PolicyURL:    "/legal/terms",
		PrivacyURL:   "/legal/privacy",
		RequiredNote: i18nOrDefault(lang, "checkout.review.terms.required", "Required to continue"),
	}
}

func buildCheckoutReviewAlerts(lang string, shipping, billing *CheckoutAddress, method string, payment *CheckoutSavedMethod) []CheckoutInlineAlert {
	var alerts []CheckoutInlineAlert
	if shipping == nil {
		alerts = append(alerts, CheckoutInlineAlert{
			Tone:  "error",
			Icon:  "map-pin",
			Title: i18nOrDefault(lang, "checkout.review.alert.shipping", "Select a shipping address"),
			Body:  i18nOrDefault(lang, "checkout.review.alert.shipping.body", "Choose a fulfillment address in the previous step."),
		})
	}
	if billing == nil {
		alerts = append(alerts, CheckoutInlineAlert{
			Tone:  "warning",
			Icon:  "identification",
			Title: i18nOrDefault(lang, "checkout.review.alert.billing", "Add a billing contact"),
			Body:  i18nOrDefault(lang, "checkout.review.alert.billing.body", "Billing receipts cannot be issued without a contact."),
		})
	}
	if method == "" {
		alerts = append(alerts, CheckoutInlineAlert{
			Tone:  "warning",
			Icon:  "truck",
			Title: i18nOrDefault(lang, "checkout.review.alert.method", "Confirm a shipping method"),
			Body:  i18nOrDefault(lang, "checkout.review.alert.method.body", "Pick a carrier so we can estimate delivery."),
		})
	}
	if payment == nil {
		alerts = append(alerts, CheckoutInlineAlert{
			Tone:  "error",
			Icon:  "credit-card",
			Title: i18nOrDefault(lang, "checkout.review.alert.payment", "Payment method missing"),
			Body:  i18nOrDefault(lang, "checkout.review.alert.payment.body", "Return to the payment step and select a method."),
		})
	}
	return alerts
}

func findCheckoutSavedMethod(methods []CheckoutSavedMethod, id string) *CheckoutSavedMethod {
	id = strings.TrimSpace(id)
	if id == "" {
		return nil
	}
	for i := range methods {
		if methods[i].ID == id {
			return &methods[i]
		}
	}
	return nil
}

func defaultString(value, fallback string) string {
	if strings.TrimSpace(value) != "" {
		return value
	}
	return fallback
}
