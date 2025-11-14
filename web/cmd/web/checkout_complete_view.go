package main

import (
	"fmt"
	"net/url"
	"strings"

	"finitefield.org/hanko-web/internal/format"
	mw "finitefield.org/hanko-web/internal/middleware"
)

// CheckoutCompleteView powers the `/checkout/complete` page.
type CheckoutCompleteView struct {
	Steps           []CheckoutStep
	Summary         CheckoutSummary
	Hero            CheckoutCompleteHero
	NextSteps       []CheckoutCompleteTask
	Share           CheckoutCompleteShare
	Recommendations CheckoutCompleteRecommendations
	Support         CheckoutSupportCard
	OrderID         string
}

// CheckoutCompleteHero highlights confirmation state and key metadata.
type CheckoutCompleteHero struct {
	Title      string
	Subtitle   string
	Message    string
	OrderID    string
	Status     string
	StatusTone string
	Badge      CheckoutBadge
	Highlights []CheckoutCompleteHighlight
	Actions    []CheckoutCompleteHeroAction
	ReceiptURL string
	ReceiptCTA string
}

// CheckoutCompleteHighlight renders celebratory badge stats.
type CheckoutCompleteHighlight struct {
	Label string
	Value string
	Icon  string
}

// CheckoutCompleteHeroAction renders CTA buttons in the hero.
type CheckoutCompleteHeroAction struct {
	Label   string
	Href    string
	Variant string
	Icon    string
}

// CheckoutCompleteTask renders the "next steps" task list.
type CheckoutCompleteTask struct {
	Title       string
	Description string
	Icon        string
	Status      string
	StatusTone  string
	ActionLabel string
	ActionHref  string
}

// CheckoutCompleteShare powers the share/referral strip.
type CheckoutCompleteShare struct {
	Title        string
	Subtitle     string
	ReferralCode string
	ReferralCopy string
	ShareURL     string
	Links        []CheckoutCompleteShareLink
}

// CheckoutCompleteShareLink renders share buttons.
type CheckoutCompleteShareLink struct {
	Label     string
	Icon      string
	Href      string
	Tooltip   string
	CopyValue string
	NewTab    bool
}

// CheckoutCompleteRecommendations groups accessories and guides.
type CheckoutCompleteRecommendations struct {
	Accessories []Product
	Guides      []CheckoutCompleteGuide
}

// CheckoutCompleteGuide is a lightweight guide card.
type CheckoutCompleteGuide struct {
	Title    string
	Summary  string
	Href     string
	Category string
	ReadTime string
}

func buildCheckoutCompleteView(lang string, q url.Values, sess *mw.SessionData, baseURL string) CheckoutCompleteView {
	addresses := mergeCheckoutAddresses(lang, sess.Checkout.Addresses)
	shippingAddr := findCheckoutAddress(addresses, sess.Checkout.ShippingAddressID)
	if shippingAddr == nil && len(addresses) > 0 {
		shippingAddr = &addresses[0]
	}

	orderID := strings.TrimSpace(q.Get("order"))
	if orderID == "" {
		orderID = mockOrderID()
	}
	orderSlug := checkoutOrderSlug(orderID)
	if baseURL == "" {
		baseURL = "https://hanko-field.example"
	}
	trackURL := fmt.Sprintf("%s/orders/%s/track", baseURL, url.PathEscape(orderSlug))
	receiptURL := fmt.Sprintf("%s/orders/%s/receipt.pdf", baseURL, url.PathEscape(orderSlug))
	referralURL := fmt.Sprintf("%s/refer/%s", baseURL, url.PathEscape(strings.ReplaceAll(strings.ToUpper(orderSlug), "-", "")))
	shareURL := fmt.Sprintf("%s/orders/%s/share", baseURL, url.PathEscape(orderSlug))

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

	spec := url.Values{}
	spec.Set("country", country)
	if postal != "" {
		spec.Set("postal", postal)
	}
	if method != "" {
		spec.Set("method", method)
	}
	if promo != "" {
		spec.Set("promo", promo)
	}

	cartView := buildCartView(lang, spec)
	if shippingAddr == nil && len(cartView.Items) > 0 {
		// Provide a simple fallback snippet so the summary never looks empty.
		shippingAddr = &CheckoutAddress{
			Recipient: "Hanko Field Studio",
			Line1:     i18nOrDefault(lang, "checkout.complete.pickup.line1", "Studio pickup ready"),
			City:      "Tokyo",
			Region:    "",
			Country:   country,
		}
	}

	summary := CheckoutSummary{
		Estimate: cartView.Estimate,
		Items: []CheckoutSummaryItem{
			{Label: i18nOrDefault(lang, "checkout.summary.items", "Items"), Value: fmt.Sprintf("%d", cartView.Estimate.ItemsCount)},
			{Label: i18nOrDefault(lang, "checkout.summary.method", "Method"), Value: cartView.Estimate.MethodLabel},
			{Label: i18nOrDefault(lang, "checkout.summary.eta", "ETA"), Value: cartView.Estimate.ETA},
		},
		Notes: []string{
			fmt.Sprintf("%s: %s", i18nOrDefault(lang, "checkout.payment.due_today", "Paid"), format.FmtCurrency(cartView.Estimate.Total, cartView.Estimate.Currency, lang)),
			i18nOrDefault(lang, "checkout.complete.summary.note", "You’ll also get a PDF receipt in email within a few minutes."),
		},
		ShippingAddress: shippingAddr,
	}

	hero := buildCheckoutCompleteHero(lang, orderID, cartView.Estimate, trackURL, receiptURL)
	nextSteps := buildCheckoutCompleteTasks(lang, trackURL, receiptURL, referralURL)
	share := buildCheckoutCompleteShare(lang, orderID, referralURL, shareURL)
	recs := CheckoutCompleteRecommendations{
		Accessories: checkoutCompletionAccessories(lang),
		Guides:      checkoutCompletionGuides(lang),
	}
	support := CheckoutSupportCard{
		Title:    i18nOrDefault(lang, "checkout.complete.support.title", "Need help coordinating delivery paperwork?"),
		Body:     i18nOrDefault(lang, "checkout.complete.support.body", "Our concierge can sync with customs brokers, finance approvers, or re-route urgent shipments."),
		CTALabel: i18nOrDefault(lang, "checkout.support.cta", "Chat with concierge"),
		CTAHref:  "mailto:support@hanko-field.example",
	}

	return CheckoutCompleteView{
		Steps:           cartSteps(lang, "complete"),
		Summary:         summary,
		Hero:            hero,
		NextSteps:       nextSteps,
		Share:           share,
		Recommendations: recs,
		Support:         support,
		OrderID:         orderID,
	}
}

func checkoutOrderSlug(orderID string) string {
	clean := strings.ToLower(strings.TrimSpace(orderID))
	if clean == "" {
		return "hf-order"
	}
	clean = strings.NewReplacer(" ", "-", ".", "-", "_", "-", "--", "-", ":", "-", "#", "-", "/", "-").Replace(clean)
	clean = strings.Trim(clean, "-")
	if clean == "" {
		return "hf-order"
	}
	return clean
}

func buildCheckoutCompleteHero(lang, orderID string, estimate CartEstimate, trackURL, receiptURL string) CheckoutCompleteHero {
	status := i18nOrDefault(lang, "checkout.complete.status.prep", "Queued for engraving")
	subtitle := i18nOrDefault(lang, "checkout.complete.subtitle", "Your studio order is confirmed. We’ll notify you when couriers pick up the parcel.")
	message := i18nOrDefault(lang, "checkout.complete.message", "Download your receipt, share tracking links with teammates, and pin the next steps below.")
	highlights := []CheckoutCompleteHighlight{
		{
			Label: i18nOrDefault(lang, "checkout.complete.highlight.total", "Total paid"),
			Value: format.FmtCurrency(estimate.Total, estimate.Currency, lang),
			Icon:  "check-circle",
		},
		{
			Label: i18nOrDefault(lang, "checkout.complete.highlight.eta", "Dispatch ETA"),
			Value: estimate.ETA,
			Icon:  "clock",
		},
		{
			Label: i18nOrDefault(lang, "checkout.complete.highlight.method", "Method"),
			Value: estimate.MethodLabel,
			Icon:  "arrows-right-left",
		},
	}

	actions := []CheckoutCompleteHeroAction{
		{
			Label:   i18nOrDefault(lang, "checkout.complete.action.track", "View tracking page"),
			Href:    trackURL,
			Variant: "primary",
			Icon:    "cursor-arrow-rays",
		},
		{
			Label:   i18nOrDefault(lang, "checkout.complete.action.share", "Share with team"),
			Href:    trackURL + "?share=1",
			Variant: "ghost",
			Icon:    "user-group",
		},
	}

	return CheckoutCompleteHero{
		Title:      i18nOrDefault(lang, "checkout.complete.title", "Order placed · thank you"),
		Subtitle:   subtitle,
		Message:    message,
		OrderID:    orderID,
		Status:     status,
		StatusTone: "success",
		Badge: CheckoutBadge{
			Label: i18nOrDefault(lang, "checkout.complete.badge", "Complete"),
			Tone:  "success",
		},
		Highlights: highlights,
		Actions:    actions,
		ReceiptURL: receiptURL,
		ReceiptCTA: i18nOrDefault(lang, "checkout.complete.action.receipt", "Download receipt"),
	}
}

func buildCheckoutCompleteTasks(lang, trackURL, receiptURL, referralURL string) []CheckoutCompleteTask {
	return []CheckoutCompleteTask{
		{
			Title:       i18nOrDefault(lang, "checkout.complete.task.track.title", "Track engraving & shipment"),
			Description: i18nOrDefault(lang, "checkout.complete.task.track.desc", "We’ll post progress updates from engraving through courier pickup."),
			Icon:        "sparkles",
			Status:      i18nOrDefault(lang, "checkout.complete.task.track.status", "Engraving queued"),
			StatusTone:  "info",
			ActionLabel: i18nOrDefault(lang, "checkout.complete.task.track.cta", "Open tracking"),
			ActionHref:  trackURL,
		},
		{
			Title:       i18nOrDefault(lang, "checkout.complete.task.docs.title", "Download invoice & HS docs"),
			Description: i18nOrDefault(lang, "checkout.complete.task.docs.desc", "Finance teams get a stamped PDF plus HS codes for customs."),
			Icon:        "document-text",
			Status:      i18nOrDefault(lang, "checkout.complete.task.docs.status", "Receipt ready"),
			StatusTone:  "success",
			ActionLabel: i18nOrDefault(lang, "checkout.complete.task.docs.cta", "Get documents"),
			ActionHref:  receiptURL,
		},
		{
			Title:       i18nOrDefault(lang, "checkout.complete.task.ref.title", "Refer a teammate"),
			Description: i18nOrDefault(lang, "checkout.complete.task.ref.desc", "Share a referral link so ops or HR can reuse your specs."),
			Icon:        "user-group",
			Status:      i18nOrDefault(lang, "checkout.complete.task.ref.status", "Optional"),
			StatusTone:  "muted",
			ActionLabel: i18nOrDefault(lang, "checkout.complete.task.ref.cta", "Copy referral link"),
			ActionHref:  referralURL,
		},
	}
}

func buildCheckoutCompleteShare(lang, orderID, referralURL, shareURL string) CheckoutCompleteShare {
	code := fmt.Sprintf("HF-%s", strings.ToUpper(strings.Trim(strings.ReplaceAll(orderID, "HF-", ""), " ")))
	if len(code) > 10 {
		code = code[:10]
	}
	if code == "HF-" || code == "HF" {
		code = "HF-TEAM"
	}
	return CheckoutCompleteShare{
		Title:        i18nOrDefault(lang, "checkout.complete.share.title", "Share with your team"),
		Subtitle:     i18nOrDefault(lang, "checkout.complete.share.subtitle", "Send the tracking link or invite ops to reuse engraving data."),
		ReferralCode: code,
		ReferralCopy: i18nOrDefault(lang, "checkout.complete.share.copy", "Give teammates ¥1,000 off accessories when they check out with this code."),
		ShareURL:     shareURL,
		Links: []CheckoutCompleteShareLink{
			{
				Label:   i18nOrDefault(lang, "checkout.complete.share.slack", "Post to Slack"),
				Icon:    "queue-list",
				Href:    shareURL + "?channel=slack",
				Tooltip: i18nOrDefault(lang, "checkout.complete.share.slack.tip", "Send the update to #operations"),
				NewTab:  true,
			},
			{
				Label:   i18nOrDefault(lang, "checkout.complete.share.mail", "Email finance"),
				Icon:    "document-text",
				Href:    fmt.Sprintf("mailto:?subject=%s&body=%s", url.QueryEscape("Hanko Field order "+orderID), url.QueryEscape(shareURL)),
				Tooltip: i18nOrDefault(lang, "checkout.complete.share.mail.tip", "Attach invoice + tracking details"),
			},
			{
				Label:     i18nOrDefault(lang, "checkout.complete.share.copy_link", "Copy link"),
				Icon:      "cursor-arrow-rays",
				Href:      referralURL,
				Tooltip:   i18nOrDefault(lang, "checkout.complete.share.copy.tip", "Copy referral link"),
				CopyValue: referralURL,
				NewTab:    false,
			},
		},
	}
}

func checkoutCompletionAccessories(lang string) []Product {
	all := productData(lang)
	if len(all) == 0 {
		return nil
	}
	var picks []Product
	for _, p := range all {
		if len(picks) >= 4 {
			break
		}
		if p.Material == "wood" && p.Size == "small" {
			picks = append(picks, p)
			continue
		}
		if p.Material == "metal" && p.Size == "medium" {
			picks = append(picks, p)
			continue
		}
		if p.Material == "rubber" && p.Size == "large" {
			picks = append(picks, p)
			continue
		}
	}
	for _, p := range all {
		if len(picks) >= 4 {
			break
		}
		picks = append(picks, p)
	}
	return picks
}

func checkoutCompletionGuides(lang string) []CheckoutCompleteGuide {
	return []CheckoutCompleteGuide{
		{
			Title:    i18nOrDefault(lang, "checkout.complete.guide.ops", "Operations onboarding checklist"),
			Summary:  i18nOrDefault(lang, "checkout.complete.guide.ops.summary", "Share the latest seal usage policy, custody log, and renewal reminders."),
			Href:     "/guides/ops-onboarding",
			Category: i18nOrDefault(lang, "checkout.complete.guide.category.ops", "Operations"),
			ReadTime: "6 min",
		},
		{
			Title:    i18nOrDefault(lang, "checkout.complete.guide.care", "Seal care & storage guide"),
			Summary:  i18nOrDefault(lang, "checkout.complete.guide.care.summary", "Keep engravings sharp with humidity tips and audit-ready custody forms."),
			Href:     "/guides/seal-care",
			Category: i18nOrDefault(lang, "checkout.complete.guide.category.care", "Guides"),
			ReadTime: "4 min",
		},
	}
}
