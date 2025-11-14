package main

import (
	"fmt"
	"net/url"
	"strings"
	"time"

	"finitefield.org/hanko-web/internal/format"
	mw "finitefield.org/hanko-web/internal/middleware"
)

// AccountOrderDetailPageView powers the `/account/orders/{id}` layout.
type AccountOrderDetailPageView struct {
	Lang     string
	User     AccountUser
	NavItems []AccountNavItem

	Header     AccountOrderDetailHeaderView
	Tabs       []AccountOrderDetailTabView
	ActiveTab  string
	Summary    AccountOrderSummaryView
	Payments   AccountOrderPaymentsView
	Production AccountOrderProductionView
	Tracking   AccountOrderTrackingView
	Invoice    AccountOrderInvoiceView
	LastSynced time.Time
}

// AccountOrderDetailHeaderView renders the status panel at the top of the page.
type AccountOrderDetailHeaderView struct {
	ID          string
	Number      string
	StatusKey   string
	StatusLabel string
	StatusTone  string
	PlacedAt    time.Time
	LastUpdated time.Time
	ExpectedAt  time.Time
	PrimaryItem string
	Destination string
	Total       int64
	Currency    string
	SupportCTA  AccountOrderDetailSupportCTA
	Steps       []AccountOrderDetailStepView
	Meta        []AccountOrderDetailMetaStat
}

// AccountOrderDetailMetaStat summarises key metrics shown in the status panel.
type AccountOrderDetailMetaStat struct {
	Label string
	Value string
}

// AccountOrderDetailSupportCTA configures the support button.
type AccountOrderDetailSupportCTA struct {
	Label string
	Href  string
}

// AccountOrderDetailStepView feeds the progress timeline in the status panel.
type AccountOrderDetailStepView struct {
	Key       string
	Label     string
	Note      string
	Timestamp time.Time
	State     string // complete, current, upcoming, blocked
}

// AccountOrderDetailTabView drives the tab navigation.
type AccountOrderDetailTabView struct {
	Key         string
	Label       string
	Description string
	Href        string
	Active      bool
}

// AccountOrderSummaryView renders the "Summary" tab content.
type AccountOrderSummaryView struct {
	Lang         string
	OrderNumber  string
	PlacedAt     time.Time
	ExpectedAt   time.Time
	PrimaryItem  string
	Destination  string
	ReorderHref  string
	Items        []AccountOrderItemView
	Shipping     AccountOrderAddressView
	Billing      AccountOrderAddressView
	Contacts     []AccountOrderContactView
	Totals       AccountOrderTotalsView
	Notes        []AccountOrderNoteView
	LastModified time.Time
}

// AccountOrderItemView represents a line item in the order summary.
type AccountOrderItemView struct {
	Name        string
	SKU         string
	Quantity    int
	UnitPrice   int64
	Total       int64
	Attributes  []string
	Stage       string
	StageLabel  string
	StageTone   string
	DeliveryETA time.Time
}

// AccountOrderAddressView represents a shipping/billing card.
type AccountOrderAddressView struct {
	Title   string
	Name    string
	Company string
	Lines   []string
	Phone   string
	Email   string
	Notes   []string
}

// AccountOrderContactView lists stakeholders tied to the order.
type AccountOrderContactView struct {
	Role   string
	Name   string
	Email  string
	Phone  string
	Status string
}

// AccountOrderTotalsView summarises monetary totals.
type AccountOrderTotalsView struct {
	Currency     string
	Subtotal     int64
	Discounts    int64
	Shipping     int64
	Taxes        int64
	Fees         int64
	GrandTotal   int64
	BalanceDue   int64
	FormattedDue string
}

// AccountOrderNoteView captures internal notes or highlights.
type AccountOrderNoteView struct {
	Title     string
	Body      string
	Timestamp time.Time
	Author    string
}

// AccountOrderPaymentsView renders the "Payments" tab.
type AccountOrderPaymentsView struct {
	Lang        string
	Method      AccountOrderPaymentMethodView
	Charges     []AccountOrderChargeView
	Upcoming    []AccountOrderPaymentScheduleView
	Adjustments []AccountOrderAdjustmentView
	BalanceDue  int64
	Currency    string
	LastUpdated time.Time
}

// AccountOrderPaymentMethodView describes the current payment method.
type AccountOrderPaymentMethodView struct {
	Label     string
	Details   string
	Status    string
	Autopay   bool
	UpdatedAt time.Time
}

// AccountOrderChargeView lists captured payments/refunds.
type AccountOrderChargeView struct {
	ID          string
	CreatedAt   time.Time
	Amount      int64
	Currency    string
	StatusKey   string
	StatusLabel string
	StatusTone  string
	Method      string
	Note        string
	ReceiptURL  string
}

// AccountOrderPaymentScheduleView outlines upcoming payment milestones.
type AccountOrderPaymentScheduleView struct {
	Label     string
	DueDate   time.Time
	Amount    int64
	Currency  string
	Status    string
	StatusKey string
}

// AccountOrderAdjustmentView highlights manual adjustments to the invoice.
type AccountOrderAdjustmentView struct {
	Label    string
	Amount   int64
	Currency string
	Reason   string
}

// AccountOrderProductionView renders the "Production" tab.
type AccountOrderProductionView struct {
	Lang        string
	Overview    []AccountOrderProductionMetric
	Workstreams []AccountOrderWorkstreamView
	Timeline    []AccountOrderTimelineEvent
	LastUpdated time.Time
}

// AccountOrderProductionMetric displays aggregate stats about production.
type AccountOrderProductionMetric struct {
	Label string
	Value string
	Note  string
}

// AccountOrderWorkstreamView summarises a production lane.
type AccountOrderWorkstreamView struct {
	Name      string
	Owner     string
	Progress  int
	Stage     string
	StageTone string
	DueDate   time.Time
	Notes     []string
}

// AccountOrderTimelineEvent is reused by production/tracking/invoice tabs.
type AccountOrderTimelineEvent struct {
	Title     string
	Body      string
	Actor     string
	Timestamp time.Time
	Tone      string
	Icon      string
}

// AccountOrderTrackingView renders the "Tracking" tab.
type AccountOrderTrackingView struct {
	Lang        string
	Shipments   []AccountOrderShipmentView
	Timeline    []AccountOrderTimelineEvent
	SupportNote string
	LastUpdated time.Time
}

// AccountOrderShipmentView describes a fulfilment package.
type AccountOrderShipmentView struct {
	ID             string
	Carrier        string
	Service        string
	TrackingID     string
	StatusKey      string
	StatusLabel    string
	StatusTone     string
	LastScan       string
	EstimatedAt    time.Time
	TrackingURL    string
	Packages       []AccountOrderPackageView
	SpecialHandler string
}

// AccountOrderPackageView lists package metadata within a shipment.
type AccountOrderPackageView struct {
	Label      string
	Contents   []string
	Weight     string
	Dimensions string
}

// AccountOrderInvoiceView renders the "Invoice" tab.
type AccountOrderInvoiceView struct {
	Lang        string
	Documents   []AccountOrderDocumentView
	Recipients  []AccountOrderContactView
	History     []AccountOrderTimelineEvent
	LastUpdated time.Time
	Message     string
}

// AccountOrderDocumentView represents downloadable documents for the order.
type AccountOrderDocumentView struct {
	ID        string
	Label     string
	Type      string
	Size      string
	Status    string
	StatusKey string
	UpdatedAt time.Time
	URL       string
}

// buildAccountOrderDetailPageView assembles the page view model.
func buildAccountOrderDetailPageView(lang string, sess *mw.SessionData, orderID, tab string) (AccountOrderDetailPageView, bool) {
	if tab == "" {
		tab = "summary"
	}
	profile := sessionProfileOrFallback(sess.Profile, lang)
	user := accountUserFromProfile(profile, lang)

	detail, ok := accountOrderDetailMock(orderID, lang)
	if !ok {
		return AccountOrderDetailPageView{}, false
	}

	active := tab
	if active == "" {
		active = "summary"
	}
	tabs := buildAccountOrderDetailTabs(lang, orderID, active)
	header := buildAccountOrderDetailHeader(lang, detail)
	summary := buildAccountOrderSummaryView(lang, detail)
	payments := buildAccountOrderPaymentsView(lang, detail)
	production := buildAccountOrderProductionView(lang, detail)
	tracking := buildAccountOrderTrackingView(lang, detail)
	invoice := buildAccountOrderInvoiceView(lang, detail)

	view := AccountOrderDetailPageView{
		Lang:       lang,
		User:       user,
		NavItems:   accountNavItems(lang, "orders"),
		Header:     header,
		Tabs:       tabs,
		ActiveTab:  active,
		Summary:    summary,
		Payments:   payments,
		Production: production,
		Tracking:   tracking,
		Invoice:    invoice,
		LastSynced: detail.lastUpdated,
	}

	return view, true
}

// buildAccountOrderDetailTabPayload materialises a tab fragment view model.
func buildAccountOrderDetailTabPayload(lang, orderID, tab string) (any, bool) {
	detail, ok := accountOrderDetailMock(orderID, lang)
	if !ok {
		return nil, false
	}
	switch tab {
	case "", "summary":
		return buildAccountOrderSummaryView(lang, detail), true
	case "payments":
		return buildAccountOrderPaymentsView(lang, detail), true
	case "production":
		return buildAccountOrderProductionView(lang, detail), true
	case "tracking":
		return buildAccountOrderTrackingView(lang, detail), true
	case "invoice":
		return buildAccountOrderInvoiceView(lang, detail), true
	default:
		return nil, false
	}
}

func buildAccountOrderDetailTabs(lang, orderID, active string) []AccountOrderDetailTabView {
	orderPath := "/account/orders/" + url.PathEscape(orderID)
	tabDefs := []struct {
		key   string
		label string
		desc  string
	}{
		{"summary", i18nOrDefault(lang, "account.order.tabs.summary", "Summary"), i18nOrDefault(lang, "account.order.tabs.summary.desc", "Line items, addresses, and owner notes.")},
		{"payments", i18nOrDefault(lang, "account.order.tabs.payments", "Payments"), i18nOrDefault(lang, "account.order.tabs.payments.desc", "Charges, balances, and payment schedule.")},
		{"production", i18nOrDefault(lang, "account.order.tabs.production", "Production"), i18nOrDefault(lang, "account.order.tabs.production.desc", "Workstreams, approvals, and capacity signals.")},
		{"tracking", i18nOrDefault(lang, "account.order.tabs.tracking", "Tracking"), i18nOrDefault(lang, "account.order.tabs.tracking.desc", "Shipments, scans, and delivery updates.")},
		{"invoice", i18nOrDefault(lang, "account.order.tabs.invoice", "Invoice"), i18nOrDefault(lang, "account.order.tabs.invoice.desc", "Documents, recipients, and audit history.")},
	}
	tabs := make([]AccountOrderDetailTabView, 0, len(tabDefs))
	if active == "" {
		active = "summary"
	}
	for _, def := range tabDefs {
		tabs = append(tabs, AccountOrderDetailTabView{
			Key:         def.key,
			Label:       def.label,
			Description: def.desc,
			Href:        fmt.Sprintf("%s/tabs/%s", orderPath, def.key),
			Active:      def.key == active,
		})
	}
	return tabs
}

func buildAccountOrderDetailHeader(lang string, detail accountOrderDetailData) AccountOrderDetailHeaderView {
	steps := make([]AccountOrderDetailStepView, 0, len(detail.steps))
	for _, step := range detail.steps {
		label := step.label
		if step.labelKey != "" {
			label = i18nOrDefault(lang, step.labelKey, step.label)
		}
		steps = append(steps, AccountOrderDetailStepView{
			Key:       step.key,
			Label:     label,
			Note:      step.note,
			Timestamp: step.timestamp,
			State:     step.state,
		})
	}
	meta := []AccountOrderDetailMetaStat{
		{
			Label: i18nOrDefault(lang, "account.order.meta.destination", "Destination"),
			Value: detail.destination,
		},
		{
			Label: i18nOrDefault(lang, "account.order.meta.primary_item", "Primary item"),
			Value: detail.primaryItem,
		},
		{
			Label: i18nOrDefault(lang, "account.order.meta.order_total", "Order total"),
			Value: format.FmtCurrency(detail.total, detail.currency, lang),
		},
	}

	return AccountOrderDetailHeaderView{
		ID:          detail.id,
		Number:      detail.number,
		StatusKey:   detail.status,
		StatusLabel: accountOrderStatusLabel(lang, detail.status),
		StatusTone:  accountOrderStatusTone(detail.status),
		PlacedAt:    detail.placedAt,
		LastUpdated: detail.lastUpdated,
		ExpectedAt:  detail.expectedDelivery,
		PrimaryItem: detail.primaryItem,
		Destination: detail.destination,
		Total:       detail.total,
		Currency:    detail.currency,
		SupportCTA: AccountOrderDetailSupportCTA{
			Label: i18nOrDefault(lang, "account.order.support.cta", "Contact operations support"),
			Href:  "/support?topic=orders&ref=" + url.QueryEscape(detail.id),
		},
		Steps: steps,
		Meta:  meta,
	}
}

func buildAccountOrderSummaryView(lang string, detail accountOrderDetailData) AccountOrderSummaryView {
	items := make([]AccountOrderItemView, 0, len(detail.items))
	for _, item := range detail.items {
		stageLabel := item.stageLabel
		if item.stageLabelKey != "" {
			stageLabel = i18nOrDefault(lang, item.stageLabelKey, item.stageLabel)
		}
		items = append(items, AccountOrderItemView{
			Name:        item.name,
			SKU:         item.sku,
			Quantity:    item.quantity,
			UnitPrice:   item.unitPrice,
			Total:       item.total,
			Attributes:  item.attributes,
			Stage:       item.stage,
			StageLabel:  stageLabel,
			StageTone:   item.stageTone,
			DeliveryETA: item.deliveryETA,
		})
	}

	notes := make([]AccountOrderNoteView, 0, len(detail.notes))
	for _, note := range detail.notes {
		notes = append(notes, AccountOrderNoteView{
			Title:     note.title,
			Body:      note.body,
			Timestamp: note.timestamp,
			Author:    note.author,
		})
	}

	contacts := make([]AccountOrderContactView, 0, len(detail.contacts))
	for _, c := range detail.contacts {
		contacts = append(contacts, AccountOrderContactView{
			Role:   c.role,
			Name:   c.name,
			Email:  c.email,
			Phone:  c.phone,
			Status: c.status,
		})
	}

	return AccountOrderSummaryView{
		Lang:        lang,
		OrderNumber: detail.number,
		PlacedAt:    detail.placedAt,
		ExpectedAt:  detail.expectedDelivery,
		PrimaryItem: detail.primaryItem,
		Destination: detail.destination,
		ReorderHref: fmt.Sprintf("/design/new?source=order&order=%s", url.QueryEscape(detail.id)),
		Items:       items,
		Shipping:    detail.shipping,
		Billing:     detail.billing,
		Contacts:    contacts,
		Totals: AccountOrderTotalsView{
			Currency:     detail.currency,
			Subtotal:     detail.totals.subtotal,
			Discounts:    detail.totals.discounts,
			Shipping:     detail.totals.shipping,
			Taxes:        detail.totals.taxes,
			Fees:         detail.totals.fees,
			GrandTotal:   detail.totals.grandTotal,
			BalanceDue:   detail.totals.balanceDue,
			FormattedDue: format.FmtCurrency(detail.totals.balanceDue, detail.currency, lang),
		},
		Notes:        notes,
		LastModified: detail.lastUpdated,
	}
}

func buildAccountOrderPaymentsView(lang string, detail accountOrderDetailData) AccountOrderPaymentsView {
	charges := make([]AccountOrderChargeView, 0, len(detail.charges))
	for _, ch := range detail.charges {
		statusLabel := ch.statusLabel
		if ch.statusLabelKey != "" {
			statusLabel = i18nOrDefault(lang, ch.statusLabelKey, ch.statusLabel)
		}
		charges = append(charges, AccountOrderChargeView{
			ID:          ch.id,
			CreatedAt:   ch.createdAt,
			Amount:      ch.amount,
			Currency:    detail.currency,
			StatusKey:   ch.status,
			StatusLabel: statusLabel,
			StatusTone:  ch.tone,
			Method:      ch.method,
			Note:        ch.note,
			ReceiptURL:  ch.receiptURL,
		})
	}

	terms := make([]AccountOrderPaymentScheduleView, 0, len(detail.schedule))
	for _, term := range detail.schedule {
		terms = append(terms, AccountOrderPaymentScheduleView{
			Label:     term.label,
			DueDate:   term.dueDate,
			Amount:    term.amount,
			Currency:  detail.currency,
			Status:    term.status,
			StatusKey: term.statusKey,
		})
	}

	adjustments := make([]AccountOrderAdjustmentView, 0, len(detail.adjustments))
	for _, adj := range detail.adjustments {
		adjustments = append(adjustments, AccountOrderAdjustmentView{
			Label:    adj.label,
			Amount:   adj.amount,
			Currency: detail.currency,
			Reason:   adj.reason,
		})
	}

	return AccountOrderPaymentsView{
		Lang: lang,
		Method: AccountOrderPaymentMethodView{
			Label:     detail.paymentMethod.label,
			Details:   detail.paymentMethod.details,
			Status:    detail.paymentMethod.status,
			Autopay:   detail.paymentMethod.autopay,
			UpdatedAt: detail.paymentMethod.updatedAt,
		},
		Charges:     charges,
		Upcoming:    terms,
		Adjustments: adjustments,
		BalanceDue:  detail.totals.balanceDue,
		Currency:    detail.currency,
		LastUpdated: detail.lastUpdated,
	}
}

func buildAccountOrderProductionView(lang string, detail accountOrderDetailData) AccountOrderProductionView {
	metrics := make([]AccountOrderProductionMetric, 0, len(detail.productionMetrics))
	for _, m := range detail.productionMetrics {
		metrics = append(metrics, AccountOrderProductionMetric{
			Label: m.label,
			Value: m.value,
			Note:  m.note,
		})
	}

	workstreams := make([]AccountOrderWorkstreamView, 0, len(detail.workstreams))
	for _, ws := range detail.workstreams {
		stage := ws.stage
		if ws.stageKey != "" {
			stage = i18nOrDefault(lang, ws.stageKey, ws.stage)
		}
		workstreams = append(workstreams, AccountOrderWorkstreamView{
			Name:      ws.name,
			Owner:     ws.owner,
			Progress:  ws.progress,
			Stage:     stage,
			StageTone: ws.tone,
			DueDate:   ws.due,
			Notes:     ws.notes,
		})
	}

	timeline := make([]AccountOrderTimelineEvent, 0, len(detail.productionTimeline))
	for _, ev := range detail.productionTimeline {
		timeline = append(timeline, AccountOrderTimelineEvent{
			Title:     ev.title,
			Body:      ev.body,
			Actor:     ev.actor,
			Timestamp: ev.timestamp,
			Tone:      ev.tone,
			Icon:      ev.icon,
		})
	}

	return AccountOrderProductionView{
		Lang:        lang,
		Overview:    metrics,
		Workstreams: workstreams,
		Timeline:    timeline,
		LastUpdated: detail.lastUpdated,
	}
}

func buildAccountOrderTrackingView(lang string, detail accountOrderDetailData) AccountOrderTrackingView {
	shipments := make([]AccountOrderShipmentView, 0, len(detail.shipments))
	for _, sh := range detail.shipments {
		statusLabel := sh.statusLabel
		if sh.statusLabelKey != "" {
			statusLabel = i18nOrDefault(lang, sh.statusLabelKey, sh.statusLabel)
		}
		packages := make([]AccountOrderPackageView, 0, len(sh.packages))
		for _, pkg := range sh.packages {
			packages = append(packages, AccountOrderPackageView{
				Label:      pkg.label,
				Contents:   pkg.contents,
				Weight:     pkg.weight,
				Dimensions: pkg.dimensions,
			})
		}
		shipments = append(shipments, AccountOrderShipmentView{
			ID:             sh.id,
			Carrier:        sh.carrier,
			Service:        sh.service,
			TrackingID:     sh.trackingID,
			StatusKey:      sh.status,
			StatusLabel:    statusLabel,
			StatusTone:     sh.tone,
			LastScan:       sh.lastScan,
			EstimatedAt:    sh.eta,
			TrackingURL:    sh.trackingURL,
			Packages:       packages,
			SpecialHandler: sh.special,
		})
	}

	timeline := make([]AccountOrderTimelineEvent, 0, len(detail.trackingTimeline))
	for _, ev := range detail.trackingTimeline {
		timeline = append(timeline, AccountOrderTimelineEvent{
			Title:     ev.title,
			Body:      ev.body,
			Actor:     ev.actor,
			Timestamp: ev.timestamp,
			Tone:      ev.tone,
			Icon:      ev.icon,
		})
	}

	return AccountOrderTrackingView{
		Lang:        lang,
		Shipments:   shipments,
		Timeline:    timeline,
		SupportNote: detail.trackingSupport,
		LastUpdated: detail.lastUpdated,
	}
}

func buildAccountOrderInvoiceView(lang string, detail accountOrderDetailData) AccountOrderInvoiceView {
	docs := make([]AccountOrderDocumentView, 0, len(detail.documents))
	for _, doc := range detail.documents {
		status := doc.status
		if doc.statusKey != "" {
			status = i18nOrDefault(lang, doc.statusKey, doc.status)
		}
		docs = append(docs, AccountOrderDocumentView{
			ID:        doc.id,
			Label:     doc.label,
			Type:      doc.docType,
			Size:      doc.size,
			Status:    status,
			StatusKey: doc.statusKey,
			UpdatedAt: doc.updatedAt,
			URL:       doc.url,
		})
	}

	recipients := make([]AccountOrderContactView, 0, len(detail.invoiceRecipients))
	for _, r := range detail.invoiceRecipients {
		recipients = append(recipients, AccountOrderContactView{
			Role:   r.role,
			Name:   r.name,
			Email:  r.email,
			Phone:  r.phone,
			Status: r.status,
		})
	}

	history := make([]AccountOrderTimelineEvent, 0, len(detail.invoiceTimeline))
	for _, ev := range detail.invoiceTimeline {
		history = append(history, AccountOrderTimelineEvent{
			Title:     ev.title,
			Body:      ev.body,
			Actor:     ev.actor,
			Timestamp: ev.timestamp,
			Tone:      ev.tone,
			Icon:      ev.icon,
		})
	}

	return AccountOrderInvoiceView{
		Lang:        lang,
		Documents:   docs,
		Recipients:  recipients,
		History:     history,
		LastUpdated: detail.lastUpdated,
		Message:     detail.invoiceMessage,
	}
}

// --- mock data ----------------------------------------------------------------

type accountOrderDetailData struct {
	id               string
	number           string
	status           string
	primaryItem      string
	destination      string
	total            int64
	currency         string
	placedAt         time.Time
	lastUpdated      time.Time
	expectedDelivery time.Time

	shipping AccountOrderAddressView
	billing  AccountOrderAddressView

	items    []accountOrderDetailItem
	contacts []accountOrderDetailContact
	notes    []accountOrderDetailNote
	totals   accountOrderDetailTotals

	steps []accountOrderDetailStep

	paymentMethod accountOrderDetailPaymentMethod
	charges       []accountOrderDetailCharge
	schedule      []accountOrderDetailSchedule
	adjustments   []accountOrderDetailAdjustment

	productionMetrics  []accountOrderDetailMetric
	workstreams        []accountOrderDetailWorkstream
	productionTimeline []accountOrderDetailTimelineEntry

	shipments        []accountOrderDetailShipment
	trackingTimeline []accountOrderDetailTimelineEntry
	trackingSupport  string

	documents         []accountOrderDetailDocument
	invoiceRecipients []accountOrderDetailContact
	invoiceTimeline   []accountOrderDetailTimelineEntry
	invoiceMessage    string
}

type accountOrderDetailItem struct {
	name          string
	sku           string
	quantity      int
	unitPrice     int64
	total         int64
	attributes    []string
	stage         string
	stageLabel    string
	stageLabelKey string
	stageTone     string
	deliveryETA   time.Time
}

type accountOrderDetailContact struct {
	role   string
	name   string
	email  string
	phone  string
	status string
}

type accountOrderDetailNote struct {
	title     string
	body      string
	timestamp time.Time
	author    string
}

type accountOrderDetailTotals struct {
	subtotal   int64
	discounts  int64
	shipping   int64
	taxes      int64
	fees       int64
	grandTotal int64
	balanceDue int64
}

type accountOrderDetailStep struct {
	key       string
	label     string
	labelKey  string
	note      string
	timestamp time.Time
	state     string
}

type accountOrderDetailPaymentMethod struct {
	label     string
	details   string
	status    string
	autopay   bool
	updatedAt time.Time
}

type accountOrderDetailCharge struct {
	id             string
	createdAt      time.Time
	amount         int64
	status         string
	statusLabel    string
	statusLabelKey string
	tone           string
	method         string
	note           string
	receiptURL     string
}

type accountOrderDetailSchedule struct {
	label     string
	dueDate   time.Time
	amount    int64
	status    string
	statusKey string
}

type accountOrderDetailAdjustment struct {
	label  string
	amount int64
	reason string
}

type accountOrderDetailMetric struct {
	label string
	value string
	note  string
}

type accountOrderDetailWorkstream struct {
	name     string
	owner    string
	progress int
	stage    string
	stageKey string
	tone     string
	due      time.Time
	notes    []string
}

type accountOrderDetailTimelineEntry struct {
	title     string
	body      string
	actor     string
	timestamp time.Time
	tone      string
	icon      string
}

type accountOrderDetailShipment struct {
	id             string
	carrier        string
	service        string
	trackingID     string
	status         string
	statusLabel    string
	statusLabelKey string
	tone           string
	lastScan       string
	eta            time.Time
	trackingURL    string
	packages       []accountOrderDetailPackage
	special        string
}

type accountOrderDetailPackage struct {
	label      string
	contents   []string
	weight     string
	dimensions string
}

type accountOrderDetailDocument struct {
	id        string
	label     string
	docType   string
	size      string
	status    string
	statusKey string
	updatedAt time.Time
	url       string
}

func accountOrderDetailMock(orderID, lang string) (accountOrderDetailData, bool) {
	var selected accountOrder
	var has bool
	for _, o := range accountOrdersMockData() {
		if o.ID == orderID {
			selected = o
			has = true
			break
		}
	}
	if !has {
		return accountOrderDetailData{}, false
	}

	now := accountOrdersNow
	base := selected.PlacedAt
	expected := base.Add(5 * 24 * time.Hour)
	lastUpdated := minTime(now, expected.Add(-12*time.Hour))

	shipping := AccountOrderAddressView{
		Title:   i18nOrDefault(lang, "account.order.summary.shipping", "Shipping"),
		Name:    "Haruka Sato",
		Company: "Finite Field Logistics",
		Lines: []string{
			selected.Destination,
			"1-2-3 Nihonbashi, Chuo-ku",
			"Tokyo 103-0027",
			"Japan",
		},
		Phone: "+81-3-1234-5678",
		Email: "logistics@finitefield.org",
		Notes: []string{i18nOrDefault(lang, "account.order.summary.deliver_note", "Dock access requires 30 min notice.")},
	}

	billing := AccountOrderAddressView{
		Title:   i18nOrDefault(lang, "account.order.summary.billing", "Billing"),
		Name:    "Naoki Fujimori",
		Company: "Finite Field Finance",
		Lines: []string{
			"5F Marunouchi North Tower",
			"2-7-2 Marunouchi, Chiyoda-ku",
			"Tokyo 100-0005",
			"Japan",
		},
		Phone: "+81-3-9876-5432",
		Email: "finance@finitefield.org",
		Notes: []string{i18nOrDefault(lang, "account.order.summary.billing_note", "PO HF-2025-OPS-48 net 30.")},
	}

	items := buildAccountOrderDetailItems(selected)
	contacts := []accountOrderDetailContact{
		{role: i18nOrDefault(lang, "account.order.contact.owner", "Order owner"), name: "Haruka Sato", email: "haruka.sato@finitefield.org", phone: "+81-90-1234-5678", status: i18nOrDefault(lang, "account.order.contact.active", "Active")},
		{role: i18nOrDefault(lang, "account.order.contact.production", "Production lead"), name: "Minori Takada", email: "minori.takada@finitefield.org", phone: "+81-80-2345-6789", status: i18nOrDefault(lang, "account.order.contact.onshift", "On shift")},
		{role: i18nOrDefault(lang, "account.order.contact.finance", "Finance AP"), name: "Naoki Fujimori", email: "naoki.fujimori@finitefield.org", phone: "+81-70-3456-7890", status: i18nOrDefault(lang, "account.order.contact.ontrack", "On track")},
	}

	notes := []accountOrderDetailNote{
		{
			title:     i18nOrDefault(lang, "account.order.notes.kickoff", "Kickoff briefing"),
			body:      i18nOrDefault(lang, "account.order.notes.kickoff.body", "Ops confirmed signature order with leadership; requested expedited engraving for eight premium seals."),
			timestamp: base.Add(2 * time.Hour),
			author:    "Haruka Sato",
		},
		{
			title:     i18nOrDefault(lang, "account.order.notes.qc", "QC variance"),
			body:      i18nOrDefault(lang, "account.order.notes.qc.body", "One hinoki seal required re-etching due to minor alignment variance. Resolved and re-run logged."),
			timestamp: base.Add(52 * time.Hour),
			author:    "Minori Takada",
		},
	}

	totals := accountOrderDetailTotals{
		subtotal:   selected.Total - 48000,
		discounts:  -32000,
		shipping:   28000,
		taxes:      152000,
		fees:       12000,
		grandTotal: selected.Total,
		balanceDue: selected.Total / 4, // assume 25% due
	}

	steps := buildAccountOrderDetailSteps(selected, base)
	paymentMethod := accountOrderDetailPaymentMethod{
		label:     "Corporate card · Finite Field",
		details:   "Visa •••• 4242 · auth by T. Nakamura",
		status:    i18nOrDefault(lang, "account.order.payment.method.active", "Active"),
		autopay:   true,
		updatedAt: lastUpdated.Add(-6 * time.Hour),
	}

	charges := []accountOrderDetailCharge{
		{
			id:             "chg_" + strings.ToLower(selected.ID),
			createdAt:      base.Add(6 * time.Hour),
			amount:         totals.grandTotal / 2,
			status:         "succeeded",
			statusLabel:    i18nOrDefault(lang, "account.order.payment.charge.captured", "Captured"),
			statusLabelKey: "",
			tone:           "success",
			method:         "Visa •••• 4242",
			note:           i18nOrDefault(lang, "account.order.payment.initial_deposit", "Initial 50% deposit processed automatically."),
			receiptURL:     "#",
		},
		{
			id:             fmt.Sprintf("inv_%s", strings.ToLower(selected.ID)),
			createdAt:      lastUpdated.Add(-18 * time.Hour),
			amount:         totals.grandTotal / 4,
			status:         "pending",
			statusLabel:    i18nOrDefault(lang, "account.order.payment.pending_review", "Pending review"),
			statusLabelKey: "",
			tone:           "info",
			method:         "Bank transfer · Mizuho",
			note:           i18nOrDefault(lang, "account.order.payment.pending_note", "Awaiting remittance confirmation from finance."),
			receiptURL:     "",
		},
	}

	schedule := []accountOrderDetailSchedule{
		{
			label:     i18nOrDefault(lang, "account.order.payment.schedule.milestone.production", "Production release"),
			dueDate:   base.Add(24 * time.Hour),
			amount:    totals.grandTotal / 4,
			status:    i18nOrDefault(lang, "account.order.payment.schedule.completed", "Completed"),
			statusKey: "complete",
		},
		{
			label:     i18nOrDefault(lang, "account.order.payment.schedule.milestone.ship", "Before shipment"),
			dueDate:   expected.Add(-24 * time.Hour),
			amount:    totals.grandTotal / 4,
			status:    i18nOrDefault(lang, "account.order.payment.schedule.awaiting", "Awaiting confirmation"),
			statusKey: "pending",
		},
	}

	adjustments := []accountOrderDetailAdjustment{
		{
			label:  i18nOrDefault(lang, "account.order.payment.adjustment.bulk", "Bulk discount"),
			amount: -32000,
			reason: i18nOrDefault(lang, "account.order.payment.adjustment.bulk.desc", "Applied automatically for 12+ unit order."),
		},
		{
			label:  i18nOrDefault(lang, "account.order.payment.adjustment.rush", "Rush engraving"),
			amount: 48000,
			reason: i18nOrDefault(lang, "account.order.payment.adjustment.rush.desc", "Premium hinoki material rush fee."),
		},
	}

	productionMetrics := []accountOrderDetailMetric{
		{label: i18nOrDefault(lang, "account.order.production.metric.stations", "Stations active"), value: "5/6", note: i18nOrDefault(lang, "account.order.production.metric.stations.note", "Engraving, lacquer, drying, QC, packing online. Finish pending.")},
		{label: i18nOrDefault(lang, "account.order.production.metric.capacity", "Capacity load"), value: "82%", note: i18nOrDefault(lang, "account.order.production.metric.capacity.note", "Facility running on green capacity for this batch.")},
		{label: i18nOrDefault(lang, "account.order.production.metric.variance", "Variance"), value: "+6h", note: i18nOrDefault(lang, "account.order.production.metric.variance.note", "QC re-run extended timeline; shipment still on track.")},
	}

	workstreams := []accountOrderDetailWorkstream{
		{
			name:     i18nOrDefault(lang, "account.order.production.stream.engraving", "Engraving"),
			owner:    "Minori Takada",
			progress: 90,
			stage:    i18nOrDefault(lang, "account.order.production.stream.stage.sealing", "Sealing coats"),
			stageKey: "",
			tone:     "indigo",
			due:      expected.Add(-36 * time.Hour),
			notes: []string{
				i18nOrDefault(lang, "account.order.production.stream.engraving.note1", "Premium hinoki blocks acclimated for 12h to reduce moisture."),
				i18nOrDefault(lang, "account.order.production.stream.engraving.note2", "Kanji alignment validated against submitted CSV."),
			},
		},
		{
			name:     i18nOrDefault(lang, "account.order.production.stream.qc", "Quality check"),
			owner:    "Aya Nishida",
			progress: 60,
			stage:    i18nOrDefault(lang, "account.order.production.stream.stage.inspecting", "Inspecting impressions"),
			stageKey: "",
			tone:     "info",
			due:      expected.Add(-30 * time.Hour),
			notes: []string{
				i18nOrDefault(lang, "account.order.production.stream.qc.note1", "Batch 1 (6 units) passed QC."),
				i18nOrDefault(lang, "account.order.production.stream.qc.note2", "Batch 2 re-run scheduled 10:00 JST."),
			},
		},
		{
			name:     i18nOrDefault(lang, "account.order.production.stream.kit", "Kit assembly"),
			owner:    "Shota Koyama",
			progress: 40,
			stage:    i18nOrDefault(lang, "account.order.production.stream.stage.packing", "Packing & inserts"),
			stageKey: "",
			tone:     "muted",
			due:      expected.Add(-18 * time.Hour),
			notes: []string{
				i18nOrDefault(lang, "account.order.production.stream.kit.note1", "Awaiting QC go signal to start final packing."),
			},
		},
	}

	productionTimeline := []accountOrderDetailTimelineEntry{
		{
			title:     i18nOrDefault(lang, "account.order.production.timeline.design_lock", "Design lock confirmed"),
			body:      i18nOrDefault(lang, "account.order.production.timeline.design_lock.body", "DesignOps signed off on engraving template v4.1."),
			actor:     "DesignOps · R. Miyake",
			timestamp: base.Add(8 * time.Hour),
			tone:      "success",
			icon:      "check-badge",
		},
		{
			title:     i18nOrDefault(lang, "account.order.production.timeline.engraving_start", "Engraving started"),
			body:      i18nOrDefault(lang, "account.order.production.timeline.engraving_start.body", "Hinoki blocks prepared; automated engraving workflows initiated."),
			actor:     "Factory · Line 3",
			timestamp: base.Add(24 * time.Hour),
			tone:      "info",
			icon:      "cog-8-tooth",
		},
		{
			title:     i18nOrDefault(lang, "account.order.production.timeline.qc_flag", "QC variance logged"),
			body:      i18nOrDefault(lang, "account.order.production.timeline.qc_flag.body", "Minor alignment issue flagged on unit 5; re-run started."),
			actor:     "Quality · Aya Nishida",
			timestamp: base.Add(50 * time.Hour),
			tone:      "warning",
			icon:      "exclamation-circle",
		},
	}

	shipments := buildAccountOrderDetailShipments(selected, lang, expected, lastUpdated)
	trackingTimeline := []accountOrderDetailTimelineEntry{
		{
			title:     i18nOrDefault(lang, "account.order.tracking.timeline.ready", "Shipment ready for carrier"),
			body:      i18nOrDefault(lang, "account.order.tracking.timeline.ready.body", "Packing completed; awaiting Yamato pickup."),
			actor:     "Logistics · S. Koyama",
			timestamp: expected.Add(-18 * time.Hour),
			tone:      "info",
			icon:      "truck",
		},
		{
			title:     i18nOrDefault(lang, "account.order.tracking.timeline.pickup", "Carrier pickup booked"),
			body:      i18nOrDefault(lang, "account.order.tracking.timeline.pickup.body", "Yamato 10:30 JST pickup confirmed with dock team."),
			actor:     "Yamato Express",
			timestamp: expected.Add(-12 * time.Hour),
			tone:      "success",
			icon:      "arrow-up-right",
		},
	}

	trackingSupport := i18nOrDefault(lang, "account.order.tracking.support", "Carrier delays longer than 12h? Escalate to ops via the support drawer.")

	documents := []accountOrderDetailDocument{
		{
			id:        "doc_invoice_" + strings.ToLower(selected.ID),
			label:     i18nOrDefault(lang, "account.order.invoice.document.invoice", "Invoice (rev 2)"),
			docType:   "PDF",
			size:      "1.4 MB",
			status:    i18nOrDefault(lang, "account.order.invoice.status.awaiting_sign", "Awaiting countersignature"),
			statusKey: "",
			updatedAt: lastUpdated.Add(-4 * time.Hour),
			url:       "#",
		},
		{
			id:        "doc_packing_" + strings.ToLower(selected.ID),
			label:     i18nOrDefault(lang, "account.order.invoice.document.packing", "Packing list"),
			docType:   "PDF",
			size:      "620 KB",
			status:    i18nOrDefault(lang, "account.order.invoice.status.published", "Published"),
			statusKey: "",
			updatedAt: lastUpdated.Add(-20 * time.Hour),
			url:       "#",
		},
		{
			id:        "doc_label_" + strings.ToLower(selected.ID),
			label:     i18nOrDefault(lang, "account.order.invoice.document.label", "Shipping label"),
			docType:   "ZPL",
			size:      "88 KB",
			status:    i18nOrDefault(lang, "account.order.invoice.status.synced", "Synced to carrier"),
			statusKey: "",
			updatedAt: lastUpdated.Add(-10 * time.Hour),
			url:       "#",
		},
	}

	invoiceRecipients := []accountOrderDetailContact{
		{role: i18nOrDefault(lang, "account.order.invoice.recipient.primary", "Primary billing"), name: "Naoki Fujimori", email: "naoki.fujimori@finitefield.org", phone: "+81-70-3456-7890", status: i18nOrDefault(lang, "account.order.invoice.recipient.auto", "Auto-send")},
		{role: i18nOrDefault(lang, "account.order.invoice.recipient.cc", "CC"), name: "Haruka Sato", email: "haruka.sato@finitefield.org", phone: "+81-90-1234-5678", status: i18nOrDefault(lang, "account.order.invoice.recipient.cc_status", "Subscribed")},
	}

	invoiceTimeline := []accountOrderDetailTimelineEntry{
		{
			title:     i18nOrDefault(lang, "account.order.invoice.timeline.generated", "Invoice generated"),
			body:      i18nOrDefault(lang, "account.order.invoice.timeline.generated.body", "Revision 2 issued with QC adjustment noted."),
			actor:     "Finance Automation",
			timestamp: lastUpdated.Add(-22 * time.Hour),
			tone:      "info",
			icon:      "document-text",
		},
		{
			title:     i18nOrDefault(lang, "account.order.invoice.timeline.sent", "Invoice sent to recipients"),
			body:      i18nOrDefault(lang, "account.order.invoice.timeline.sent.body", "Email delivery confirmed for Naoki Fujimori and CC list."),
			actor:     "Billing Bot",
			timestamp: lastUpdated.Add(-21 * time.Hour),
			tone:      "success",
			icon:      "paper-airplane",
		},
	}

	invoiceMessage := i18nOrDefault(lang, "account.order.invoice.message", "Need a purchase certificate or customs document? Use the support button above with reference to this order.")

	return accountOrderDetailData{
		id:                 selected.ID,
		number:             selected.Number,
		status:             selected.Status,
		primaryItem:        selected.PrimaryItem,
		destination:        selected.Destination,
		total:              selected.Total,
		currency:           selected.Currency,
		placedAt:           selected.PlacedAt,
		lastUpdated:        lastUpdated,
		expectedDelivery:   expected,
		shipping:           shipping,
		billing:            billing,
		items:              items,
		contacts:           contacts,
		notes:              notes,
		totals:             totals,
		steps:              steps,
		paymentMethod:      paymentMethod,
		charges:            charges,
		schedule:           schedule,
		adjustments:        adjustments,
		productionMetrics:  productionMetrics,
		workstreams:        workstreams,
		productionTimeline: productionTimeline,
		shipments:          shipments,
		trackingTimeline:   trackingTimeline,
		trackingSupport:    trackingSupport,
		documents:          documents,
		invoiceRecipients:  invoiceRecipients,
		invoiceTimeline:    invoiceTimeline,
		invoiceMessage:     invoiceMessage,
	}, true
}

func buildAccountOrderDetailItems(order accountOrder) []accountOrderDetailItem {
	baseSKU := strings.ToUpper(strings.TrimPrefix(order.ID, "ord_"))
	if len(baseSKU) > 8 {
		baseSKU = baseSKU[:8]
	}
	unitPrice := order.Total / 10
	if unitPrice <= 0 {
		unitPrice = 148000
	}
	eta := order.PlacedAt.Add(96 * time.Hour)

	items := []accountOrderDetailItem{
		{
			name:        order.PrimaryItem,
			sku:         "HF-" + baseSKU + "-A",
			quantity:    4,
			unitPrice:   unitPrice,
			total:       unitPrice * 4,
			attributes:  []string{"Hinoki wood", "Laser-etched"},
			stage:       "coating",
			stageLabel:  "Coating",
			stageTone:   "info",
			deliveryETA: eta,
		},
		{
			name:        "Presentation cases",
			sku:         "HF-" + baseSKU + "-CASE",
			quantity:    4,
			unitPrice:   38000,
			total:       152000,
			attributes:  []string{"Indigo velvet insert"},
			stage:       "assembly",
			stageLabel:  "Assembly",
			stageTone:   "muted",
			deliveryETA: eta.Add(12 * time.Hour),
		},
		{
			name:        "Certificate of authenticity",
			sku:         "HF-" + baseSKU + "-CERT",
			quantity:    4,
			unitPrice:   12000,
			total:       48000,
			attributes:  []string{"Bilingual JP/EN"},
			stage:       "printed",
			stageLabel:  "Printed",
			stageTone:   "success",
			deliveryETA: eta.Add(-12 * time.Hour),
		},
	}

	return items
}

func buildAccountOrderDetailSteps(order accountOrder, base time.Time) []accountOrderDetailStep {
	stepKeys := []string{"received", "processing", "production", "qc", "shipped", "delivered"}
	defaultLabels := []string{"Order received", "Processing", "In production", "Quality check", "Shipped", "Delivered"}
	notes := []string{
		"Submitted via account portal",
		"Materials allocated and procurement confirmed",
		"Engraving & finishing underway",
		"QC validating impressions",
		"Handed over to carrier",
		"Delivery confirmation pending",
	}

	stateIndex := map[string]int{
		"processing": 1,
		"production": 2,
		"shipped":    4,
		"fulfilled":  5,
		"cancelled":  1,
		"draft":      0,
	}
	activeIdx, ok := stateIndex[order.Status]
	if !ok {
		activeIdx = 0
	}
	steps := make([]accountOrderDetailStep, 0, len(stepKeys))
	for idx, key := range stepKeys {
		state := "upcoming"
		timestamp := base.Add(time.Duration(idx*18) * time.Hour)
		if idx < activeIdx {
			state = "complete"
		} else if idx == activeIdx {
			if order.Status == "cancelled" {
				state = "blocked"
			} else {
				state = "current"
			}
		}
		labelKey := fmt.Sprintf("account.order.steps.%s", key)
		steps = append(steps, accountOrderDetailStep{
			key:       key,
			label:     defaultLabels[idx],
			labelKey:  labelKey,
			note:      notes[idx],
			timestamp: timestamp,
			state:     state,
		})
	}
	return steps
}

func buildAccountOrderDetailShipments(order accountOrder, lang string, expected, lastUpdated time.Time) []accountOrderDetailShipment {
	var shipments []accountOrderDetailShipment
	switch order.Status {
	case "shipped", "fulfilled":
		shipments = append(shipments, accountOrderDetailShipment{
			id:          "ship_" + strings.ToLower(order.ID),
			carrier:     "Yamato Transport",
			service:     "Cool TA-Q-BIN",
			trackingID:  "JP45" + strings.ToUpper(order.ID[len(order.ID)-4:]),
			status:      "in_transit",
			statusLabel: i18nOrDefault(lang, "account.order.tracking.shipment.in_transit", "In transit"),
			tone:        "info",
			lastScan:    fmt.Sprintf("Tokyo hub · %s", lastUpdated.Add(-6*time.Hour).Format("15:04")),
			eta:         expected,
			trackingURL: "#",
			packages: []accountOrderDetailPackage{
				{
					label:      i18nOrDefault(lang, "account.order.tracking.package.main", "Main case"),
					contents:   []string{order.PrimaryItem, "Certificates"},
					weight:     "4.2 kg",
					dimensions: "45 × 30 × 20 cm",
				},
				{
					label:      i18nOrDefault(lang, "account.order.tracking.package.accessories", "Accessory kit"),
					contents:   []string{"Presentation cases", "Care kits"},
					weight:     "1.8 kg",
					dimensions: "40 × 25 × 18 cm",
				},
			},
			special: i18nOrDefault(lang, "account.order.tracking.shipment.special", "Hold at dock if receiving bay is occupied."),
		})
	default:
		shipments = append(shipments, accountOrderDetailShipment{
			id:          "ship_" + strings.ToLower(order.ID),
			carrier:     "Yamato Transport",
			service:     "Cool TA-Q-BIN",
			trackingID:  "Pending",
			status:      "pending",
			statusLabel: i18nOrDefault(lang, "account.order.tracking.shipment.pending", "Pending pickup"),
			tone:        "muted",
			lastScan:    i18nOrDefault(lang, "account.order.tracking.shipment.not_ready", "Label generated"),
			eta:         expected,
			trackingURL: "#",
			packages: []accountOrderDetailPackage{
				{
					label:      i18nOrDefault(lang, "account.order.tracking.package.main", "Main case"),
					contents:   []string{order.PrimaryItem},
					weight:     "3.9 kg",
					dimensions: "45 × 30 × 20 cm",
				},
			},
			special: i18nOrDefault(lang, "account.order.tracking.shipment.special_pending", "Carrier pickup scheduled once QC clears remaining units."),
		})
	}
	return shipments
}

func minTime(a, b time.Time) time.Time {
	if a.IsZero() {
		return b
	}
	if b.IsZero() {
		return a
	}
	if a.Before(b) {
		return a
	}
	return b
}
