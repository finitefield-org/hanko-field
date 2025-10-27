package main

import (
	"fmt"
	"strings"
	"time"

	"finitefield.org/hanko-web/internal/seo"
)

const (
	supportMaxAttachmentBytes = 5 * 1024 * 1024
	supportMaxAttachments     = 3
)

// SupportPageView models the `/support` page content.
type SupportPageView struct {
	Header   SupportHeaderView
	Form     SupportFormView
	FAQ      []SupportFAQItem
	Channels []SupportChannelCard
	Timeline SupportTimelineView
	Callout  SupportCalloutView
}

// SupportHeaderView renders the hero/header copy for the support page.
type SupportHeaderView struct {
	Eyebrow string
	Title   string
	Summary string
	Icon    string
}

// SupportFormView represents the contact form state.
type SupportFormView struct {
	Values            map[string]string
	Errors            map[string]string
	Topics            []SupportOption
	Priorities        []SupportOption
	AttachmentHint    string
	AttachmentSummary string
	AttachmentNames   []string
	Alert             *SupportAlert
	Success           bool
	Ticket            *SupportTicketInfo
	SubmitLabel       string
}

// SupportOption is a select option with optional helper copy.
type SupportOption struct {
	Value       string
	Label       string
	Description string
	OptionLabel string
	Selected    bool
}

// SupportAlert renders form-level messaging.
type SupportAlert struct {
	Tone  string
	Title string
	Body  string
}

// SupportTicketInfo is returned after a successful submission.
type SupportTicketInfo struct {
	ID           string
	Status       string
	StatusLabel  string
	ResponseETA  string
	FollowUp     string
	CreatedAt    time.Time
	Created      string
	CreatedISO   string
	ReferenceURL string
}

// SupportFAQItem represents a top FAQ accordion entry.
type SupportFAQItem struct {
	ID       string
	Question string
	Answer   string
	Href     string
}

// SupportChannelCard renders a support channel card (chat/email/phone).
type SupportChannelCard struct {
	Title       string
	Description string
	Icon        string
	CTA         SupportCTA
	Meta        string
	Tone        string
}

// SupportCTA models a call-to-action link or button.
type SupportCTA struct {
	Label    string
	Href     string
	External bool
}

// SupportTimelineView displays expected response milestones.
type SupportTimelineView struct {
	Title    string
	Subtitle string
	Entries  []SupportTimelineEntry
}

// SupportTimelineEntry captures one milestone in the response timeline.
type SupportTimelineEntry struct {
	Title       string
	Description string
	Duration    string
	Status      string
	StatusLabel string
}

// SupportCalloutView renders the community/forum CTA band.
type SupportCalloutView struct {
	Title string
	Body  string
	CTA   SupportCTA
	Icon  string
}

// SupportFormState carries mutable form state into the view builder.
type SupportFormState struct {
	Values          map[string]string
	Errors          map[string]string
	Alert           *SupportAlert
	Ticket          *SupportTicketInfo
	AttachmentNames []string
	Success         bool
}

// buildSupportPageView assembles the localized support page view model.
func buildSupportPageView(lang string, state SupportFormState) SupportPageView {
	values := map[string]string{
		"name":     "",
		"email":    "",
		"company":  "",
		"order":    "",
		"topic":    "orders",
		"priority": "normal",
		"message":  "",
	}
	for k, v := range state.Values {
		values[k] = v
	}

	header := SupportHeaderView{
		Eyebrow: i18nOrDefault(lang, "support.header.eyebrow", "Support"),
		Title:   i18nOrDefault(lang, "support.header.title", "Contact support"),
		Summary: i18nOrDefault(lang, "support.header.summary", "Reach our operations team for orders, billing, or technical assistance."),
		Icon:    "chat-bubble-left-right",
	}

	topics := []SupportOption{
		{
			Value:       "orders",
			Label:       i18nOrDefault(lang, "support.form.topic.orders", "Orders"),
			Description: i18nOrDefault(lang, "support.form.topic.orders_desc", "Shipping status, design adjustments, production escalations."),
		},
		{
			Value:       "billing",
			Label:       i18nOrDefault(lang, "support.form.topic.billing", "Billing & invoices"),
			Description: i18nOrDefault(lang, "support.form.topic.billing_desc", "Invoices, payment confirmations, tax receipts, purchase orders."),
		},
		{
			Value:       "technical",
			Label:       i18nOrDefault(lang, "support.form.topic.technical", "Technical support"),
			Description: i18nOrDefault(lang, "support.form.topic.technical_desc", "Editor issues, integrations, or account access problems."),
		},
		{
			Value:       "account",
			Label:       i18nOrDefault(lang, "support.form.topic.account", "Account & admin"),
			Description: i18nOrDefault(lang, "support.form.topic.account_desc", "User management, permissions, localization, compliance."),
		},
	}
	for i := range topics {
		topics[i].Selected = values["topic"] == topics[i].Value
		label := topics[i].Label
		if topics[i].Description != "" {
			label = fmt.Sprintf("%s — %s", topics[i].Label, topics[i].Description)
		}
		topics[i].OptionLabel = label
	}

	priorities := []SupportOption{
		{
			Value:       "normal",
			Label:       i18nOrDefault(lang, "support.form.priority.normal", "Standard (reply within 2h)"),
			Description: i18nOrDefault(lang, "support.form.priority.normal_desc", "Typical requests; we reply within business hours."),
		},
		{
			Value:       "high",
			Label:       i18nOrDefault(lang, "support.form.priority.high", "Urgent (reply within 1h)"),
			Description: i18nOrDefault(lang, "support.form.priority.high_desc", "Time-sensitive requests impacting orders or compliance."),
		},
		{
			Value:       "low",
			Label:       i18nOrDefault(lang, "support.form.priority.low", "Low (reply within 1 day)"),
			Description: i18nOrDefault(lang, "support.form.priority.low_desc", "General questions or feedback without deadlines."),
		},
	}
	for i := range priorities {
		priorities[i].Selected = values["priority"] == priorities[i].Value
		label := priorities[i].Label
		if priorities[i].Description != "" {
			label = fmt.Sprintf("%s — %s", priorities[i].Label, priorities[i].Description)
		}
		priorities[i].OptionLabel = label
	}

	attachmentSummary := fmt.Sprintf(
		i18nOrDefault(lang, "support.form.attachments.limit", "Up to %d files, %s each."),
		supportMaxAttachments,
		humanReadableBytes(supportMaxAttachmentBytes),
	)
	form := SupportFormView{
		Values:            values,
		Errors:            copyMap(state.Errors),
		Topics:            topics,
		Priorities:        priorities,
		AttachmentHint:    i18nOrDefault(lang, "support.form.attachments.hint", "Attach proofs, invoices, or screenshots to help us triage quickly."),
		AttachmentSummary: attachmentSummary,
		AttachmentNames:   append([]string(nil), state.AttachmentNames...),
		Alert:             state.Alert,
		Success:           state.Success,
		SubmitLabel:       i18nOrDefault(lang, "support.form.submit", "Send request"),
	}
	if state.Ticket != nil {
		ticket := *state.Ticket
		if ticket.StatusLabel == "" {
			ticket.StatusLabel = i18nOrDefault(lang, "support.status.received", "Received")
		}
		if ticket.ResponseETA == "" {
			ticket.ResponseETA = i18nOrDefault(lang, "support.response.eta", "within 2 business hours")
		}
		ticket.Created, ticket.CreatedISO = displayDateTime(ticket.CreatedAt, lang)
		form.Ticket = &ticket
	}

	faq := []SupportFAQItem{
		{
			ID:       "faq-orders",
			Question: i18nOrDefault(lang, "support.faq.orders.question", "Where can I track my order status?"),
			Answer:   i18nOrDefault(lang, "support.faq.orders.answer", "Visit the Orders page to see live production stages, shipping timelines, and escalation options."),
			Href:     "/account/orders",
		},
		{
			ID:       "faq-billing",
			Question: i18nOrDefault(lang, "support.faq.billing.question", "Can you reissue invoices or update billing details?"),
			Answer:   i18nOrDefault(lang, "support.faq.billing.answer", "Yes. Attach your order reference and the revised billing information; finance will reissue documents within one business day."),
			Href:     "/guides/billing-workflow",
		},
		{
			ID:       "faq-technical",
			Question: i18nOrDefault(lang, "support.faq.technical.question", "How do I resolve editor sync or login issues?"),
			Answer:   i18nOrDefault(lang, "support.faq.technical.answer", "Capture a screenshot or HAR file if possible. Our engineers will confirm status and provide next steps or workarounds."),
			Href:     "/status",
		},
	}

	channels := []SupportChannelCard{
		{
			Title:       i18nOrDefault(lang, "support.channel.chat.title", "Live chat"),
			Description: i18nOrDefault(lang, "support.channel.chat.desc", "Chat with concierge during business hours for quick triage and escalations."),
			Icon:        "chat-bubble-left-right",
			Meta:        i18nOrDefault(lang, "support.channel.chat.meta", "Weekdays 09:00–18:00 JST"),
			CTA: SupportCTA{
				Label:    i18nOrDefault(lang, "support.channel.chat.cta", "Start chat"),
				Href:     "/chat",
				External: false,
			},
			Tone: "primary",
		},
		{
			Title:       i18nOrDefault(lang, "support.channel.email.title", "Email"),
			Description: i18nOrDefault(lang, "support.channel.email.desc", "Send detailed requests with attachments. We route tickets to the right specialist."),
			Icon:        "envelope-open",
			Meta:        "support@hanko-field.example",
			CTA: SupportCTA{
				Label:    i18nOrDefault(lang, "support.channel.email.cta", "Email support"),
				Href:     "mailto:support@hanko-field.example",
				External: true,
			},
			Tone: "neutral",
		},
		{
			Title:       i18nOrDefault(lang, "support.channel.phone.title", "Phone"),
			Description: i18nOrDefault(lang, "support.channel.phone.desc", "For urgent stamp pickups or compliance requests, call our operations desk."),
			Icon:        "device-phone-mobile",
			Meta:        "+81-3-1234-5678",
			CTA: SupportCTA{
				Label:    i18nOrDefault(lang, "support.channel.phone.cta", "Call operations"),
				Href:     "tel:+81312345678",
				External: true,
			},
			Tone: "secondary",
		},
	}

	timelineEntries := []SupportTimelineEntry{
		{
			Title:       i18nOrDefault(lang, "support.timeline.intake.title", "Ticket received"),
			Description: i18nOrDefault(lang, "support.timeline.intake.desc", "A concierge reviews your details and assigns the request to the correct specialist."),
			Duration:    i18nOrDefault(lang, "support.timeline.intake.sla", "Within 15 minutes"),
			Status:      "pending",
			StatusLabel: i18nOrDefault(lang, "support.status.pending", "Pending"),
		},
		{
			Title:       i18nOrDefault(lang, "support.timeline.response.title", "First response"),
			Description: i18nOrDefault(lang, "support.timeline.response.desc", "We confirm next steps or request additional information if needed."),
			Duration:    i18nOrDefault(lang, "support.timeline.response.sla", "Under 2 business hours"),
			Status:      "upcoming",
			StatusLabel: i18nOrDefault(lang, "support.status.upcoming", "Upcoming"),
		},
		{
			Title:       i18nOrDefault(lang, "support.timeline.resolution.title", "Resolution & follow-up"),
			Description: i18nOrDefault(lang, "support.timeline.resolution.desc", "Specialists coordinate shipments, issue paperwork, or escalate incidents."),
			Duration:    i18nOrDefault(lang, "support.timeline.resolution.sla", "Varies by request"),
			Status:      "upcoming",
			StatusLabel: i18nOrDefault(lang, "support.status.upcoming", "Upcoming"),
		},
	}
	if state.Success && form.Ticket != nil {
		timelineEntries[0].Status = "complete"
		timelineEntries[0].StatusLabel = i18nOrDefault(lang, "support.status.received", "Received")
		timelineEntries[1].Status = "current"
		timelineEntries[1].StatusLabel = i18nOrDefault(lang, "support.status.in_progress", "In progress")
	}

	timeline := SupportTimelineView{
		Title:    i18nOrDefault(lang, "support.timeline.title", "Response timeline"),
		Subtitle: i18nOrDefault(lang, "support.timeline.subtitle", "We keep you informed at every step until resolution."),
		Entries:  timelineEntries,
	}

	callout := SupportCalloutView{
		Title: i18nOrDefault(lang, "support.callout.title", "Join the community"),
		Body:  i18nOrDefault(lang, "support.callout.body", "Share best practices and learn from other seal managers in our community forum."),
		CTA: SupportCTA{
			Label:    i18nOrDefault(lang, "support.callout.cta", "Visit community forum"),
			Href:     "https://community.hanko-field.example",
			External: true,
		},
		Icon: "user-group",
	}

	return SupportPageView{
		Header:   header,
		Form:     form,
		FAQ:      faq,
		Channels: channels,
		Timeline: timeline,
		Callout:  callout,
	}
}

// supportJSONLDPayloads builds structured data for FAQ and breadcrumbs.
func supportJSONLDPayloads(baseURL, lang string, view SupportPageView) []string {
	var payloads []string
	if len(view.FAQ) > 0 {
		var entities []map[string]any
		for _, item := range view.FAQ {
			q := strings.TrimSpace(item.Question)
			a := strings.TrimSpace(item.Answer)
			if q == "" || a == "" {
				continue
			}
			entities = append(entities, map[string]any{
				"@type": "Question",
				"name":  q,
				"acceptedAnswer": map[string]any{
					"@type": "Answer",
					"text":  a,
				},
			})
		}
		if len(entities) > 0 {
			payloads = append(payloads, seo.JSON(map[string]any{
				"@context":   "https://schema.org",
				"@type":      "FAQPage",
				"mainEntity": entities,
			}))
		}
	}

	if baseURL != "" {
		items := []seo.BreadcrumbItem{
			{Name: i18nOrDefault(lang, "nav.home", "Home"), Item: strings.TrimSuffix(baseURL, "/") + "/"},
			{Name: view.Header.Title, Item: strings.TrimSuffix(baseURL, "/") + "/support"},
		}
		payloads = append(payloads, seo.JSON(seo.BreadcrumbList(items)))
	}
	return payloads
}

// humanReadableBytes renders a friendly byte size string (e.g. "5 MB").
func humanReadableBytes(b int) string {
	const (
		kb = 1024
		mb = 1024 * kb
		gb = 1024 * mb
	)
	switch {
	case b >= gb:
		return fmt.Sprintf("%.1f GB", float64(b)/float64(gb))
	case b >= mb:
		return fmt.Sprintf("%.1f MB", float64(b)/float64(mb))
	case b >= kb:
		return fmt.Sprintf("%.0f KB", float64(b)/float64(kb))
	default:
		return fmt.Sprintf("%d B", b)
	}
}

func copyMap(src map[string]string) map[string]string {
	if len(src) == 0 {
		return map[string]string{}
	}
	dst := make(map[string]string, len(src))
	for k, v := range src {
		dst[k] = v
	}
	return dst
}
