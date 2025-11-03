package reviews

import (
	"fmt"
	"net/url"
	"sort"
	"strings"
	"time"

	adminreviews "finitefield.org/hanko-admin/internal/admin/reviews"
	"finitefield.org/hanko-admin/internal/admin/templates/components"
	"finitefield.org/hanko-admin/internal/admin/templates/helpers"
	"finitefield.org/hanko-admin/internal/admin/templates/partials"
)

// PageData represents the payload for the reviews moderation dashboard.
type PageData struct {
	Title             string
	Description       string
	Breadcrumbs       []partials.Breadcrumb
	TableEndpoint     string
	ResetURL          string
	Query             QueryState
	Filters           Filters
	SummaryChips      []SummaryChip
	Productivity      []ProductivityCard
	Table             TableData
	Detail            DetailData
	GeneratedAt       string
	GeneratedRelative string
	SelectedID        string
}

// QueryState captures the current filter state.
type QueryState struct {
	RawQuery   string
	Search     string
	Moderation string
	AgeBucket  string
	Sort       string
	Selected   string
	Ratings    []int
	Products   []string
	Flags      []string
	Channels   []string
	Page       int
	PageSize   int
}

// Filters renders the toolbar controls.
type Filters struct {
	Channels   []ChannelFilter
	Ratings    []RatingFilter
	Flags      []FlagFilter
	Products   []ProductFilter
	AgeBuckets []AgeBucketFilter
}

// ChannelFilter powers the channel select.
type ChannelFilter struct {
	Value    string
	Label    string
	Count    int
	Selected bool
}

// RatingFilter powers the rating chip group.
type RatingFilter struct {
	Value  int
	Label  string
	Count  int
	Active bool
}

// FlagFilter powers the flag chips.
type FlagFilter struct {
	Value       string
	Label       string
	Description string
	Tone        string
	Count       int
	Active      bool
}

// ProductFilter powers the product selection list.
type ProductFilter struct {
	Value    string
	Label    string
	SKU      string
	Count    int
	Selected bool
}

// AgeBucketFilter renders the age bucket selector.
type AgeBucketFilter struct {
	Value  string
	Label  string
	Active bool
}

// SummaryChip renders headline metrics.
type SummaryChip struct {
	Label   string
	Value   string
	Tone    string
	Icon    string
	Tooltip string
}

// ProductivityCard renders productivity meters.
type ProductivityCard struct {
	Label   string
	Value   string
	Subtext string
	Tone    string
	Icon    string
}

// TableData represents the table fragment payload.
type TableData struct {
	BasePath     string
	FragmentPath string
	Rows         []TableRow
	Error        string
	EmptyMessage string
	Pagination   components.PaginationProps
	RawQuery     string
	SelectedID   string
	LastUpdated  string
	LastRelative string
}

// TableRow is a display model for each row.
type TableRow struct {
	ID                string
	Selected          bool
	Rating            int
	RatingLabel       string
	Title             string
	Excerpt           string
	SubmittedAt       string
	SubmittedRelative string
	ChannelLabel      string
	ChannelIcon       string
	ChannelTone       string
	CustomerName      string
	CustomerAvatar    string
	CustomerLocation  string
	ProductName       string
	ProductVariant    string
	ProductImage      string
	ProductURL        string
	OrderNumber       string
	OrderURL          string
	Flags             []BadgeView
	ModerationLabel   string
	ModerationTone    string
	AttachmentsCount  int
	Reported          bool
	SelectURL         string
}

// BadgeView renders flag badges.
type BadgeView struct {
	Label   string
	Tone    string
	Tooltip string
	Icon    string
}

// DetailData powers the right-hand inspector pane.
type DetailData struct {
	Empty      bool
	SelectedID string
	Review     DetailReview
}

// DetailReview represents the selected review metadata.
type DetailReview struct {
	ID                string
	Title             string
	Rating            int
	Body              string
	SubmittedAt       string
	SubmittedRelative string
	ChannelLabel      string
	ChannelIcon       string
	ChannelTone       string
	Customer          DetailCustomer
	Product           DetailProduct
	Flags             []DetailFlag
	Attachments       []AttachmentView
	HelpfulYes        string
	HelpfulNo         string
	Moderation        DetailModeration
	Preview           PreviewView
}

// DetailCustomer renders customer information.
type DetailCustomer struct {
	Name       string
	Email      string
	AvatarURL  string
	Location   string
	Segment    string
	OrderCount string
	LastOrder  string
}

// DetailProduct renders product snippet information.
type DetailProduct struct {
	Name        string
	Variant     string
	SKU         string
	ImageURL    string
	DetailURL   string
	PriceLabel  string
	OrderNumber string
	OrderURL    string
}

// DetailFlag renders flag list entries.
type DetailFlag struct {
	Label       string
	Description string
	Tone        string
	Actor       string
	Occurred    string
}

// AttachmentView renders media attachments.
type AttachmentView struct {
	ID       string
	URL      string
	ThumbURL string
	Label    string
	Kind     string
}

// DetailModeration renders moderation metadata and controls.
type DetailModeration struct {
	StatusLabel  string
	StatusTone   string
	Notes        string
	LastActor    string
	LastOccurred string
	History      []ModerationEventView
	Actions      []ActionButton
}

// ModerationEventView renders history timeline entries.
type ModerationEventView struct {
	Label    string
	Outcome  string
	Reason   string
	Actor    string
	Occurred string
	Tone     string
}

// ActionButton renders moderation controls.
type ActionButton struct {
	Label    string
	Variant  string
	Icon     string
	HxGet    string
	HxTarget string
	HxSwap   string
	Disabled bool
}

// PreviewView shows storefront preview.
type PreviewView struct {
	DisplayName string
	ProductName string
	Headline    string
	Body        string
	Rating      int
	Photos      []AttachmentView
	Submitted   string
}

// BuildPageData assembles the full page payload.
func BuildPageData(basePath string, state QueryState, result adminreviews.ListResult, table TableData, detail DetailData) PageData {
	chips := buildSummaryChips(result.Summary)
	productivity := buildProductivityRow(result.Queue)
	generatedAt, generatedRelative := "-", ""
	if !result.GeneratedAt.IsZero() {
		generatedAt = helpers.Date(result.GeneratedAt, "2006-01-02 15:04")
		generatedRelative = helpers.Relative(result.GeneratedAt)
	}

	return PageData{
		Title:             "レビュー審査",
		Description:       "保留中のレビューを確認し、承認・却下・ブランドトーン調整を行います。",
		Breadcrumbs:       []partials.Breadcrumb{{Label: "レビュー審査"}},
		TableEndpoint:     joinBase(basePath, "/reviews/table"),
		ResetURL:          joinBase(basePath, "/reviews?moderation=pending"),
		Query:             state,
		Filters:           buildFilters(state, result.Filters),
		SummaryChips:      chips,
		Productivity:      productivity,
		Table:             table,
		Detail:            detail,
		GeneratedAt:       generatedAt,
		GeneratedRelative: generatedRelative,
		SelectedID:        detail.SelectedID,
	}
}

// TablePayload prepares the table fragment payload.
func TablePayload(basePath string, state QueryState, result adminreviews.ListResult, selectedID string, errMsg string) TableData {
	base := joinBase(basePath, "/reviews")
	fragment := joinBase(basePath, "/reviews/table")
	rows := make([]TableRow, 0, len(result.Reviews))
	for _, review := range result.Reviews {
		rows = append(rows, toTableRow(review, state, selectedID, fragment))
	}

	empty := ""
	if errMsg == "" && len(rows) == 0 {
		empty = "条件に一致するレビューがありません。フィルタを調整してください。"
	}

	total := result.Pagination.TotalItems
	pagination := components.PaginationProps{
		Info: components.PageInfo{
			PageSize:   result.Pagination.PageSize,
			Current:    result.Pagination.Page,
			Count:      len(rows),
			TotalItems: &total,
			Next:       result.Pagination.NextPage,
			Prev:       result.Pagination.PrevPage,
		},
		BasePath:      base,
		RawQuery:      cleanQuery(state.RawQuery, state.Moderation),
		FragmentPath:  fragment,
		FragmentQuery: cleanQuery(state.RawQuery, state.Moderation),
		Param:         "page",
		SizeParam:     "pageSize",
		HxTarget:      "#reviews-table",
		HxSwap:        "outerHTML",
		HxPushURL:     true,
		Label:         "レビュー一覧ページング",
	}

	lastUpdated, lastRelative := "-", ""
	if !result.GeneratedAt.IsZero() {
		lastUpdated = helpers.Date(result.GeneratedAt, "2006-01-02 15:04")
		lastRelative = helpers.Relative(result.GeneratedAt)
	}

	return TableData{
		BasePath:     base,
		FragmentPath: fragment,
		Rows:         rows,
		Error:        errMsg,
		EmptyMessage: empty,
		Pagination:   pagination,
		RawQuery:     cleanQuery(state.RawQuery, state.Moderation),
		SelectedID:   selectedID,
		LastUpdated:  lastUpdated,
		LastRelative: lastRelative,
	}
}

// DetailPayload prepares the detail inspector payload.
func DetailPayload(basePath, selectedID string, result adminreviews.ListResult) DetailData {
	if selectedID == "" {
		return DetailData{Empty: true}
	}
	for _, review := range result.Reviews {
		if review.ID == selectedID {
			return DetailData{
				SelectedID: selectedID,
				Review:     toDetailReview(basePath, review),
			}
		}
	}
	if len(result.Reviews) == 0 {
		return DetailData{Empty: true}
	}
	// Fallback to first review in the result set.
	first := result.Reviews[0]
	return DetailData{
		SelectedID: first.ID,
		Review:     toDetailReview(basePath, first),
	}
}

func buildSummaryChips(summary adminreviews.Summary) []SummaryChip {
	return []SummaryChip{
		{
			Label:   "保留中",
			Value:   fmt.Sprintf("%d件", summary.PendingCount),
			Tone:    "warning",
			Icon:    "⏳",
			Tooltip: "モデレーション待ちレビュー",
		},
		{
			Label:   "フラグ付き",
			Value:   fmt.Sprintf("%d件", summary.FlaggedCount),
			Tone:    "info",
			Icon:    "🚩",
			Tooltip: "確認・エスカレーションされたレビュー",
		},
		{
			Label:   "エスカレーション",
			Value:   fmt.Sprintf("%d件", summary.EscalatedCount),
			Tone:    "danger",
			Icon:    "⚠️",
			Tooltip: "ブランド基準の確認が必要なレビュー",
		},
		{
			Label:   "平均評価",
			Value:   fmt.Sprintf("%.1f ★", summary.AverageRating),
			Tone:    "success",
			Icon:    "⭐",
			Tooltip: "全レビューの平均評価",
		},
	}
}

func buildProductivityRow(queue adminreviews.QueueMetrics) []ProductivityCard {
	return []ProductivityCard{
		{
			Label:   "本日処理",
			Value:   fmt.Sprintf("%d件", queue.ProcessedToday),
			Subtext: fmt.Sprintf("今週 %d 件", queue.ProcessedThisWeek),
			Tone:    "success",
			Icon:    "✅",
		},
		{
			Label:   "保留中",
			Value:   fmt.Sprintf("%d件", queue.BacklogPending),
			Subtext: fmt.Sprintf("フラグ付き %d 件", queue.BacklogFlagged),
			Tone:    "warning",
			Icon:    "📥",
		},
		{
			Label:   "SLA 残り",
			Value:   formatSLADuration(queue.SLASecondsRemaining),
			Subtext: fmt.Sprintf("次の期限 %s", helpers.Date(queue.NextSLABreach, "15:04")),
			Tone:    "danger",
			Icon:    "⏱",
		},
	}
}

func buildFilters(state QueryState, summary adminreviews.FilterSummary) Filters {
	channelSelections := make([]string, 0, len(state.Channels))
	for _, ch := range state.Channels {
		channelSelections = append(channelSelections, strings.ToLower(strings.TrimSpace(ch)))
	}

	products := make([]ProductFilter, 0, len(summary.Products))
	for _, item := range summary.Products {
		products = append(products, ProductFilter{
			Value:    item.ID,
			Label:    labelWithSKU(item.Label, item.SKU),
			SKU:      item.SKU,
			Count:    item.Count,
			Selected: containsStringInsensitive(state.Products, item.ID),
		})
	}
	sort.Slice(products, func(i, j int) bool {
		return products[i].Label < products[j].Label
	})

	channels := make([]ChannelFilter, 0, len(summary.Channels))
	for _, option := range summary.Channels {
		channels = append(channels, ChannelFilter{
			Value:    option.Value,
			Label:    option.Label,
			Count:    option.Count,
			Selected: containsStringInsensitive(state.Channels, option.Value),
		})
	}
	sort.Slice(channels, func(i, j int) bool {
		return channels[i].Label < channels[j].Label
	})

	ratings := make([]RatingFilter, 0, len(summary.Ratings))
	for _, option := range summary.Ratings {
		ratings = append(ratings, RatingFilter{
			Value:  option.Value,
			Label:  option.Label,
			Count:  option.Count,
			Active: containsInt(state.Ratings, option.Value),
		})
	}

	flags := make([]FlagFilter, 0, len(summary.Flags))
	for _, option := range summary.Flags {
		flags = append(flags, FlagFilter{
			Value:       option.Value,
			Label:       option.Label,
			Description: option.Description,
			Tone:        option.Tone,
			Count:       option.Count,
			Active:      containsStringInsensitive(state.Flags, option.Value),
		})
	}

	ageBuckets := make([]AgeBucketFilter, 0, len(summary.AgeBuckets))
	for _, option := range summary.AgeBuckets {
		ageBuckets = append(ageBuckets, AgeBucketFilter{
			Value:  option.Value,
			Label:  option.Label,
			Active: strings.EqualFold(state.AgeBucket, option.Value),
		})
	}

	return Filters{
		Channels:   channels,
		Ratings:    ratings,
		Flags:      flags,
		Products:   products,
		AgeBuckets: ageBuckets,
	}
}

func toTableRow(review adminreviews.Review, state QueryState, selectedID string, fragmentPath string) TableRow {
	label, icon, tone := channelPresentation(review.Channel)
	selectURL := buildSelectURL(fragmentPath, state.RawQuery, state.Moderation, review.ID)

	return TableRow{
		ID:                review.ID,
		Selected:          review.ID == selectedID,
		Rating:            review.Rating,
		RatingLabel:       fmt.Sprintf("%d ★", review.Rating),
		Title:             review.Title,
		Excerpt:           excerpt(review.Body, 140),
		SubmittedAt:       helpers.Date(review.SubmittedAt, "2006-01-02 15:04"),
		SubmittedRelative: helpers.Relative(review.SubmittedAt),
		ChannelLabel:      label,
		ChannelIcon:       icon,
		ChannelTone:       tone,
		CustomerName:      review.Customer.Name,
		CustomerAvatar:    review.Customer.AvatarURL,
		CustomerLocation:  review.Customer.Location,
		ProductName:       review.Product.Name,
		ProductVariant:    review.Product.Variant,
		ProductImage:      review.Product.ImageURL,
		ProductURL:        review.Product.DetailURL,
		OrderNumber:       review.Order.Number,
		OrderURL:          review.Order.URL,
		Flags:             toBadgeViews(review.Flags),
		ModerationLabel:   review.Moderation.StatusLabel,
		ModerationTone:    review.Moderation.StatusTone,
		AttachmentsCount:  len(review.Attachments),
		Reported:          review.Reported,
		SelectURL:         selectURL,
	}
}

func toBadgeViews(flags []adminreviews.Flag) []BadgeView {
	if len(flags) == 0 {
		return nil
	}
	result := make([]BadgeView, 0, len(flags))
	for _, flag := range flags {
		label := flag.Label
		if label == "" {
			label = flag.Type
		}
		result = append(result, BadgeView{
			Label:   label,
			Tone:    flag.Tone,
			Tooltip: flag.Description,
			Icon:    "",
		})
	}
	return result
}

func toDetailReview(basePath string, review adminreviews.Review) DetailReview {
	channelLabel, channelIcon, channelTone := channelPresentation(review.Channel)
	attachments := make([]AttachmentView, 0, len(review.Attachments))
	for _, att := range review.Attachments {
		attachments = append(attachments, AttachmentView{
			ID:       att.ID,
			URL:      att.URL,
			ThumbURL: att.ThumbURL,
			Label:    att.Label,
			Kind:     att.Kind,
		})
	}
	flags := make([]DetailFlag, 0, len(review.Flags))
	for _, flag := range review.Flags {
		flags = append(flags, DetailFlag{
			Label:       flag.Label,
			Description: flag.Description,
			Tone:        flag.Tone,
			Actor:       flag.Actor,
			Occurred:    helpers.Relative(flag.CreatedAt),
		})
	}

	return DetailReview{
		ID:                review.ID,
		Title:             review.Title,
		Rating:            review.Rating,
		Body:              review.Body,
		SubmittedAt:       helpers.Date(review.SubmittedAt, "2006-01-02 15:04"),
		SubmittedRelative: helpers.Relative(review.SubmittedAt),
		ChannelLabel:      channelLabel,
		ChannelIcon:       channelIcon,
		ChannelTone:       channelTone,
		Customer: DetailCustomer{
			Name:       review.Customer.Name,
			Email:      review.Customer.Email,
			AvatarURL:  review.Customer.AvatarURL,
			Location:   review.Customer.Location,
			Segment:    review.Customer.Segment,
			OrderCount: fmt.Sprintf("%d件", review.Customer.OrderCount),
			LastOrder:  helpers.Relative(review.Customer.LastOrder),
		},
		Product: DetailProduct{
			Name:        review.Product.Name,
			Variant:     review.Product.Variant,
			SKU:         review.Product.SKU,
			ImageURL:    review.Product.ImageURL,
			DetailURL:   review.Product.DetailURL,
			PriceLabel:  helpers.Currency(review.Product.PriceMinor, review.Product.Currency),
			OrderNumber: review.Order.Number,
			OrderURL:    review.Order.URL,
		},
		Flags:       flags,
		Attachments: attachments,
		HelpfulYes:  fmt.Sprintf("%d", review.Helpful.Yes),
		HelpfulNo:   fmt.Sprintf("%d", review.Helpful.No),
		Moderation:  toDetailModeration(basePath, review),
		Preview:     toPreviewView(review),
	}
}

func toDetailModeration(basePath string, review adminreviews.Review) DetailModeration {
	history := make([]ModerationEventView, 0, len(review.Moderation.History))
	for _, event := range review.Moderation.History {
		history = append(history, ModerationEventView{
			Label:    event.Action,
			Outcome:  event.Outcome,
			Reason:   event.Reason,
			Actor:    event.Actor,
			Occurred: helpers.Relative(event.CreatedAt),
			Tone:     event.Tone,
		})
	}

	approveURL := joinBase(basePath, fmt.Sprintf("/reviews/%s/modal/moderate?decision=approve", review.ID))
	rejectURL := joinBase(basePath, fmt.Sprintf("/reviews/%s/modal/moderate?decision=reject", review.ID))

	actions := []ActionButton{
		{
			Label:    "承認して公開",
			Variant:  "primary",
			Icon:     "✅",
			HxGet:    approveURL,
			HxTarget: "#modal",
			HxSwap:   "innerHTML",
			Disabled: false,
		},
		{
			Label:    "却下 / 修正依頼",
			Variant:  "secondary",
			Icon:     "📝",
			HxGet:    rejectURL,
			HxTarget: "#modal",
			HxSwap:   "innerHTML",
			Disabled: false,
		},
	}

	return DetailModeration{
		StatusLabel:  review.Moderation.StatusLabel,
		StatusTone:   review.Moderation.StatusTone,
		Notes:        review.Moderation.Notes,
		LastActor:    review.Moderation.LastModerator,
		LastOccurred: helpers.Relative(review.Moderation.LastActionAt),
		History:      history,
		Actions:      actions,
	}
}

func toPreviewView(review adminreviews.Review) PreviewView {
	photos := make([]AttachmentView, 0, len(review.Preview.Photos))
	for _, photo := range review.Preview.Photos {
		photos = append(photos, AttachmentView{
			ID:       photo.ID,
			URL:      photo.URL,
			ThumbURL: photo.ThumbURL,
			Label:    photo.Label,
			Kind:     photo.Kind,
		})
	}
	return PreviewView{
		DisplayName: review.Preview.DisplayName,
		ProductName: review.Preview.ProductName,
		Headline:    review.Preview.Headline,
		Body:        review.Preview.Body,
		Rating:      review.Preview.Rating,
		Photos:      photos,
		Submitted:   helpers.Relative(review.Preview.SubmittedAt),
	}
}

func cleanQuery(raw string, moderation string) string {
	values, err := url.ParseQuery(raw)
	if err != nil {
		values = url.Values{}
	}
	if moderation != "" && len(values["moderation"]) == 0 {
		values.Set("moderation", moderation)
	}
	return values.Encode()
}

func buildSelectURL(fragmentPath, rawQuery, moderation, selected string) string {
	values, err := url.ParseQuery(rawQuery)
	if err != nil {
		values = url.Values{}
	}
	if moderation != "" && len(values["moderation"]) == 0 {
		values.Set("moderation", moderation)
	}
	values.Set("selected", selected)
	return fragmentPath + "?" + values.Encode()
}

func channelPresentation(channel string) (label, icon, tone string) {
	switch strings.ToLower(strings.TrimSpace(channel)) {
	case "email":
		return "メール", "✉️", "info"
	case "in_store":
		return "店舗", "🏬", "success"
	default:
		return "オンライン", "🛒", "slate"
	}
}

func excerpt(text string, length int) string {
	text = strings.TrimSpace(text)
	if len([]rune(text)) <= length {
		return text
	}
	runes := []rune(text)
	return string(runes[:length]) + "…"
}

func labelWithSKU(label, sku string) string {
	label = strings.TrimSpace(label)
	if label == "" {
		label = sku
	}
	if sku == "" {
		return label
	}
	return fmt.Sprintf("%s (%s)", label, strings.TrimSpace(sku))
}

func formatSLADuration(seconds int) string {
	if seconds <= 0 {
		return "期限超過"
	}
	duration := time.Duration(seconds) * time.Second
	h := int(duration.Hours())
	m := int(duration.Minutes()) % 60
	s := int(duration.Seconds()) % 60
	if h > 0 {
		return fmt.Sprintf("%02d:%02d:%02d", h, m, s)
	}
	return fmt.Sprintf("%02d:%02d", m, s)
}

func containsStringInsensitive(list []string, target string) bool {
	for _, item := range list {
		if strings.EqualFold(strings.TrimSpace(item), strings.TrimSpace(target)) {
			return true
		}
	}
	return false
}

func containsInt(list []int, value int) bool {
	for _, item := range list {
		if item == value {
			return true
		}
	}
	return false
}

func joinBase(base, suffix string) string {
	base = strings.TrimSpace(base)
	if base == "" {
		base = "/"
	}
	if !strings.HasPrefix(base, "/") {
		base = "/" + base
	}
	if base != "/" {
		base = strings.TrimRight(base, "/")
	}
	suffix = strings.TrimSpace(suffix)
	if suffix == "" {
		return base
	}
	if !strings.HasPrefix(suffix, "/") {
		suffix = "/" + suffix
	}
	if base == "/" {
		return strings.ReplaceAll(suffix, "//", "/")
	}
	return strings.ReplaceAll(base+suffix, "//", "/")
}
