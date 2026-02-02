package catalog

import (
	"context"
	"fmt"
	"math/rand"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"
)

const (
	defaultCatalogPageSize = 10
	maxCatalogPageSize     = 50
)

type staticService struct {
	mu             sync.RWMutex
	now            time.Time
	rand           *rand.Rand
	assets         map[Kind][]catalogAsset
	lookup         map[Kind]map[string]catalogAsset
	updatedPresets []UpdatedRange
}

type catalogAsset struct {
	item   Item
	detail ItemDetail
}

// NewStaticService seeds the catalog UI with representative fixtures.
func NewStaticService() Service {
	now := time.Date(2024, time.March, 18, 12, 0, 0, 0, time.UTC)
	service := &staticService{
		now:  now,
		rand: rand.New(rand.NewSource(time.Now().UnixNano())),
		assets: map[Kind][]catalogAsset{
			KindTemplates: buildTemplateAssets(now),
			KindFonts:     buildFontAssets(now),
			KindMaterials: buildMaterialAssets(now),
			KindProducts:  buildProductAssets(now),
		},
		updatedPresets: []UpdatedRange{
			{Value: "24h", Label: "24時間以内", Hint: "直近 24h 更新"},
			{Value: "3d", Label: "直近3日", Hint: "レビュー対象"},
			{Value: "7d", Label: "今週", Hint: "SLA 7日"},
			{Value: "30d", Label: "今月", Hint: "キャンペーン準備"},
		},
	}

	service.lookup = make(map[Kind]map[string]catalogAsset, len(service.assets))
	for kind, list := range service.assets {
		m := make(map[string]catalogAsset, len(list))
		for _, asset := range list {
			m[asset.item.ID] = asset
		}
		service.lookup[kind] = m
	}
	return service
}

func (s *staticService) ListAssets(ctx context.Context, token string, query ListQuery) (ListResult, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	kind := query.Kind
	if kind == "" {
		kind = KindTemplates
	}

	view := NormalizeViewMode(string(query.View))
	assets := s.assets[kind]
	filtered := filterAssets(assets, query, s.now)
	sortAssets(filtered, query)
	page := normalizePage(query.Page)
	pageSize := normalizePageSize(query.PageSize)
	paged, pagination := paginateAssets(filtered, page, pageSize)

	items := make([]Item, 0, len(filtered))
	for _, asset := range paged {
		items = append(items, asset.item)
	}

	selectedID := strings.TrimSpace(query.SelectedID)
	var selectedDetail *ItemDetail

	if selectedID != "" {
		if detail, ok := s.lookup[kind][selectedID]; ok {
			copyDetail := detail.detail
			selectedDetail = &copyDetail
		}
	}
	if selectedDetail == nil && len(paged) > 0 {
		selectedID = paged[0].item.ID
		copyDetail := paged[0].detail
		selectedDetail = &copyDetail
	}

	summary := buildSummary(kind, filtered)
	filters := s.buildFilters(kind, assets, query)
	bulk := BulkSummary{
		Eligible: len(filtered),
		Actions:  defaultBulkActions(kind),
	}

	emptyMsg := ""
	if len(filtered) == 0 {
		emptyMsg = "該当するアセットが見つかりません。フィルタ条件を調整してください。"
	}

	return ListResult{
		Kind:           kind,
		Items:          items,
		Summary:        summary,
		Filters:        filters,
		Bulk:           bulk,
		View:           view,
		SelectedID:     selectedID,
		SelectedDetail: selectedDetail,
		EmptyMessage:   emptyMsg,
		Pagination:     pagination,
	}, nil
}

func (s *staticService) GetAsset(ctx context.Context, token string, kind Kind, id string) (ItemDetail, error) {
	k := NormalizeKind(string(kind))
	assetID := strings.TrimSpace(id)
	if assetID == "" {
		return ItemDetail{}, ErrItemNotFound
	}

	s.mu.RLock()
	defer s.mu.RUnlock()

	if bucket, ok := s.lookup[k]; ok {
		if asset, exists := bucket[assetID]; exists {
			return cloneItemDetail(asset), nil
		}
	}
	return ItemDetail{}, ErrItemNotFound
}

func (s *staticService) SaveAsset(ctx context.Context, token string, input AssetInput) (ItemDetail, error) {
	kind := NormalizeKind(string(input.Kind))
	s.mu.Lock()
	defer s.mu.Unlock()

	now := time.Now().UTC()
	if strings.TrimSpace(input.Version) == "" {
		input.Version = "v1"
	}
	if strings.TrimSpace(input.ID) == "" {
		input.ID = s.nextAssetID(kind)
	}
	if strings.TrimSpace(input.Identifier) == "" {
		input.Identifier = strings.ToUpper(input.ID)
	}
	if input.Status == "" {
		input.Status = StatusDraft
	}
	if input.PreviewAlt == "" {
		input.PreviewAlt = input.Name
	}

	asset := catalogAsset{}
	if bucket, ok := s.lookup[kind]; ok {
		if existing, exists := bucket[input.ID]; exists {
			if strings.TrimSpace(existing.item.Version) != "" && strings.TrimSpace(input.Version) != "" && strings.TrimSpace(existing.item.Version) != strings.TrimSpace(input.Version) {
				return ItemDetail{}, ErrVersionConflict
			}
			asset = existing
		}
	}

	updated := buildAssetFromInput(asset, input, now)
	if s.assets[kind] == nil {
		s.assets[kind] = []catalogAsset{}
	}
	if s.lookup[kind] == nil {
		s.lookup[kind] = map[string]catalogAsset{}
	}

	if _, exists := s.lookup[kind][updated.item.ID]; exists {
		for i := range s.assets[kind] {
			if s.assets[kind][i].item.ID == updated.item.ID {
				s.assets[kind][i] = updated
				break
			}
		}
	} else {
		s.assets[kind] = append([]catalogAsset{updated}, s.assets[kind]...)
	}
	s.lookup[kind][updated.item.ID] = updated

	return cloneItemDetail(updated), nil
}

func (s *staticService) DeleteAsset(ctx context.Context, token string, req DeleteRequest) error {
	kind := NormalizeKind(string(req.Kind))
	id := strings.TrimSpace(req.ID)
	if id == "" {
		return ErrItemNotFound
	}

	s.mu.Lock()
	defer s.mu.Unlock()

	bucket, ok := s.lookup[kind]
	if !ok {
		return ErrItemNotFound
	}
	asset, exists := bucket[id]
	if !exists {
		return ErrItemNotFound
	}
	if strings.TrimSpace(req.Version) != "" && strings.TrimSpace(asset.item.Version) != "" && strings.TrimSpace(req.Version) != strings.TrimSpace(asset.item.Version) {
		return ErrVersionConflict
	}
	delete(bucket, id)
	list := s.assets[kind]
	for i := range list {
		if list[i].item.ID == id {
			s.assets[kind] = append(list[:i], list[i+1:]...)
			break
		}
	}
	return nil
}

func (s *staticService) CancelSchedule(ctx context.Context, token string, req ScheduleRequest) (ItemDetail, error) {
	kind := NormalizeKind(string(req.Kind))
	id := strings.TrimSpace(req.ID)
	if id == "" {
		return ItemDetail{}, ErrItemNotFound
	}

	s.mu.Lock()
	defer s.mu.Unlock()

	bucket, ok := s.lookup[kind]
	if !ok {
		return ItemDetail{}, ErrItemNotFound
	}
	asset, exists := bucket[id]
	if !exists {
		return ItemDetail{}, ErrItemNotFound
	}
	if strings.TrimSpace(req.Version) != "" && strings.TrimSpace(asset.item.Version) != "" && strings.TrimSpace(req.Version) != strings.TrimSpace(asset.item.Version) {
		return ItemDetail{}, ErrVersionConflict
	}

	asset.item.ScheduledPublishAt = nil
	asset.detail.ScheduledPublishAt = nil
	if asset.item.Status == StatusScheduled {
		asset.item.Status = StatusDraft
		asset.item.StatusLabel = statusLabel(asset.item.Status)
		asset.item.StatusTone = statusTone(asset.item.Status)
		asset.item.UsageLabel = usageLabelForStatus(asset.item.Status)
		asset.detail.Item = asset.item
	}

	bucket[id] = asset
	list := s.assets[kind]
	for i := range list {
		if list[i].item.ID == id {
			list[i] = asset
			break
		}
	}
	s.assets[kind] = list

	return cloneItemDetail(asset), nil
}

func filterAssets(assets []catalogAsset, query ListQuery, refTime time.Time) []catalogAsset {
	if len(assets) == 0 {
		return nil
	}

	statusFilter := make(map[Status]struct{}, len(query.Statuses))
	for _, status := range query.Statuses {
		statusFilter[status] = struct{}{}
	}

	tagFilter := normalizeStrings(query.Tags)
	category := strings.ToLower(strings.TrimSpace(query.Category))
	search := strings.ToLower(strings.TrimSpace(query.Search))
	owner := strings.ToLower(strings.TrimSpace(query.Owner))

	result := make([]catalogAsset, 0, len(assets))
	updatedPreset := strings.TrimSpace(query.UpdatedRange)
	for _, asset := range assets {
		if len(statusFilter) > 0 {
			if _, ok := statusFilter[asset.item.Status]; !ok {
				continue
			}
		}

		if updatedPreset != "" && !matchesUpdatedRange(updatedPreset, asset.item.UpdatedAt, refTime) {
			continue
		}

		if category != "" && strings.ToLower(strings.TrimSpace(asset.item.Category)) != category {
			continue
		}

		if owner != "" && owner != strings.ToLower(asset.item.Owner.Name) {
			continue
		}

		if len(tagFilter) > 0 {
			if !containsAnyTag(asset.item.Tags, tagFilter) {
				continue
			}
		}

		if search != "" && !matchesSearch(asset.item, search) {
			continue
		}

		result = append(result, asset)
	}
	return result
}

func sortAssets(assets []catalogAsset, query ListQuery) {
	if len(assets) <= 1 {
		return
	}
	key := strings.ToLower(strings.TrimSpace(query.SortKey))
	if key == "" {
		key = "updated_at"
	}
	direction := query.SortDirection
	if direction != SortDirectionAsc {
		direction = SortDirectionDesc
	}

	sort.SliceStable(assets, func(i, j int) bool {
		a := assets[i].item
		b := assets[j].item
		cmp := compareCatalogItems(a, b, key)
		if direction == SortDirectionDesc {
			return cmp > 0
		}
		return cmp < 0
	})
}

func compareCatalogItems(a, b Item, key string) int {
	switch key {
	case "name":
		return strings.Compare(strings.ToLower(a.Name), strings.ToLower(b.Name))
	case "status":
		return strings.Compare(strings.ToLower(a.StatusLabel), strings.ToLower(b.StatusLabel))
	case "owner":
		return strings.Compare(strings.ToLower(a.Owner.Name), strings.ToLower(b.Owner.Name))
	default:
		if a.UpdatedAt.Equal(b.UpdatedAt) {
			return 0
		}
		if a.UpdatedAt.Before(b.UpdatedAt) {
			return -1
		}
		return 1
	}
}

func normalizePage(page int) int {
	if page <= 0 {
		return 1
	}
	return page
}

func normalizePageSize(size int) int {
	if size <= 0 {
		return defaultCatalogPageSize
	}
	if size > maxCatalogPageSize {
		return maxCatalogPageSize
	}
	return size
}

func timePtr(t time.Time) *time.Time {
	return &t
}

func paginateAssets(assets []catalogAsset, page, size int) ([]catalogAsset, Pagination) {
	total := len(assets)
	if size <= 0 {
		size = defaultCatalogPageSize
	}
	if page <= 0 {
		page = 1
	}
	maxPage := 1
	if total > 0 {
		maxPage = (total + size - 1) / size
		if page > maxPage {
			page = maxPage
		}
	} else {
		page = 1
	}

	start := (page - 1) * size
	if start > total {
		start = total
	}
	end := start + size
	if end > total {
		end = total
	}

	var slice []catalogAsset
	if start < end {
		slice = assets[start:end]
	}

	pagination := Pagination{
		Page:       page,
		PageSize:   size,
		TotalItems: total,
	}
	if page < maxPage {
		next := page + 1
		pagination.NextPage = &next
	}
	if page > 1 && total > 0 {
		prev := page - 1
		pagination.PrevPage = &prev
	}
	return slice, pagination
}

func matchesSearch(item Item, query string) bool {
	values := []string{
		strings.ToLower(item.Name),
		strings.ToLower(item.Identifier),
		strings.ToLower(item.Description),
	}
	for _, tag := range item.Tags {
		values = append(values, strings.ToLower(tag))
	}
	for _, value := range values {
		if strings.Contains(value, query) {
			return true
		}
	}
	return false
}

func containsAnyTag(tags []string, filter map[string]struct{}) bool {
	for _, tag := range tags {
		if _, ok := filter[strings.ToLower(tag)]; ok {
			return true
		}
	}
	return false
}

func normalizeStrings(values []string) map[string]struct{} {
	result := make(map[string]struct{}, len(values))
	for _, value := range values {
		value = strings.ToLower(strings.TrimSpace(value))
		if value == "" {
			continue
		}
		result[value] = struct{}{}
	}
	return result
}

var updatedRangeDurations = map[string]time.Duration{
	"24h": 24 * time.Hour,
	"3d":  72 * time.Hour,
	"7d":  7 * 24 * time.Hour,
	"30d": 30 * 24 * time.Hour,
}

func matchesUpdatedRange(preset string, updatedAt, ref time.Time) bool {
	preset = strings.TrimSpace(preset)
	if preset == "" {
		return true
	}
	if updatedAt.IsZero() || ref.IsZero() {
		return false
	}
	duration, ok := updatedRangeDurations[preset]
	if !ok {
		return true
	}
	cutoff := ref.Add(-duration)
	return !updatedAt.Before(cutoff)
}

func buildSummary(kind Kind, assets []catalogAsset) Summary {
	summary := Summary{
		PrimaryLabel: kind.Label(),
	}
	summary.Total = len(assets)
	var latest time.Time
	for _, asset := range assets {
		switch asset.item.Status {
		case StatusPublished:
			summary.Published++
		case StatusScheduled:
			summary.Scheduled++
		case StatusDraft:
			summary.Drafts++
		case StatusArchived:
			summary.Archived++
		case StatusInReview:
			summary.InReview++
		}
		if asset.item.UpdatedAt.After(latest) {
			latest = asset.item.UpdatedAt
		}
	}
	summary.LastUpdated = latest
	return summary
}

func (s *staticService) buildFilters(kind Kind, assets []catalogAsset, query ListQuery) FilterSummary {
	filter := FilterSummary{}
	filter.Statuses = buildStatusOptions(assets, query.Statuses)
	filter.Categories = buildCategoryOptions(assets, query.Category)
	filter.Owners = buildOwnerOptions(assets, query.Owner)
	filter.Tags = buildTagOptions(assets, query.Tags)
	filter.UpdatedRanges = markActiveRanges(s.updatedPresets, query.UpdatedRange)
	return filter
}

func buildCategoryOptions(assets []catalogAsset, active string) []FilterOption {
	counts := map[string]int{}
	labels := map[string]string{}
	for _, asset := range assets {
		key := strings.ToLower(strings.TrimSpace(asset.item.Category))
		if key == "" {
			continue
		}
		counts[key]++
		label := asset.item.CategoryLabel
		if label == "" {
			label = strings.Title(key)
		}
		labels[key] = label
	}

	keys := make([]string, 0, len(labels))
	for key := range labels {
		keys = append(keys, key)
	}
	sort.Strings(keys)

	activeKey := strings.ToLower(strings.TrimSpace(active))
	result := make([]FilterOption, 0, len(keys))
	for _, key := range keys {
		result = append(result, FilterOption{
			Value:  key,
			Label:  labels[key],
			Count:  counts[key],
			Active: key == activeKey && activeKey != "",
		})
	}
	return result
}

func buildStatusOptions(assets []catalogAsset, active []Status) []FilterOption {
	counts := map[Status]int{}
	for _, asset := range assets {
		counts[asset.item.Status]++
	}

	activeSet := make(map[Status]struct{}, len(active))
	for _, s := range active {
		activeSet[s] = struct{}{}
	}

	statuses := []Status{StatusPublished, StatusScheduled, StatusDraft, StatusInReview, StatusArchived}
	result := make([]FilterOption, 0, len(statuses))
	for _, status := range statuses {
		result = append(result, FilterOption{
			Value:  string(status),
			Label:  statusLabel(status),
			Count:  counts[status],
			Active: hasStatus(activeSet, status),
		})
	}
	return result
}

func hasStatus(set map[Status]struct{}, status Status) bool {
	_, ok := set[status]
	return ok
}

func buildOwnerOptions(assets []catalogAsset, active string) []FilterOption {
	counts := map[string]int{}
	labels := map[string]string{}
	for _, asset := range assets {
		key := strings.ToLower(asset.item.Owner.Name)
		counts[key]++
		labels[key] = asset.item.Owner.Name
	}

	keys := make([]string, 0, len(labels))
	for key := range labels {
		keys = append(keys, key)
	}
	sort.Strings(keys)

	activeKey := strings.ToLower(strings.TrimSpace(active))
	result := make([]FilterOption, 0, len(keys))
	for _, key := range keys {
		result = append(result, FilterOption{
			Value:  key,
			Label:  labels[key],
			Count:  counts[key],
			Active: key == activeKey && activeKey != "",
		})
	}
	return result
}

func buildTagOptions(assets []catalogAsset, active []string) []FilterOption {
	counts := map[string]int{}
	for _, asset := range assets {
		for _, tag := range asset.item.Tags {
			key := strings.ToLower(tag)
			counts[key]++
		}
	}

	keys := make([]string, 0, len(counts))
	for key := range counts {
		keys = append(keys, key)
	}
	sort.Strings(keys)

	activeSet := normalizeStrings(active)
	result := make([]FilterOption, 0, len(keys))
	for _, key := range keys {
		_, selected := activeSet[key]
		result = append(result, FilterOption{
			Value:  key,
			Label:  key,
			Count:  counts[key],
			Active: selected,
		})
	}
	return result
}

func markActiveRanges(ranges []UpdatedRange, active string) []UpdatedRange {
	result := make([]UpdatedRange, len(ranges))
	activeValue := strings.TrimSpace(active)
	for i, preset := range ranges {
		result[i] = preset
		result[i].Active = preset.Value == activeValue && activeValue != ""
	}
	return result
}

func defaultBulkActions(kind Kind) []BulkAction {
	return []BulkAction{
		{
			Value:       "publish",
			Label:       "公開",
			Tone:        "primary",
			Description: "選択したアセットをまとめて公開します。",
		},
		{
			Value:       "unpublish",
			Label:       "公開停止",
			Tone:        "secondary",
			Description: "非公開にし、下書きに戻します。",
		},
	}
}

func makeCatalogAsset(item Item, detail ItemDetail) catalogAsset {
	detail.Item = item
	if detail.Owner.Name == "" {
		detail.Owner = item.Owner
	}
	if len(detail.Tags) == 0 {
		detail.Tags = item.Tags
	}
	if detail.UpdatedAt.IsZero() {
		detail.UpdatedAt = item.UpdatedAt
	}
	if len(detail.Properties) > 0 {
		// ensure values are normalised consistently
		detail.Properties = mergeProperties(nil, detail.Properties)
	}
	return catalogAsset{item: item, detail: detail}
}

func withProperties(detail ItemDetail, props map[string]string) ItemDetail {
	if len(props) == 0 {
		return detail
	}
	detail.Properties = mergeProperties(detail.Properties, props)
	return detail
}

func (s *staticService) nextAssetID(kind Kind) string {
	prefix := map[Kind]string{
		KindFonts:     "font",
		KindMaterials: "mat",
		KindProducts:  "prd",
		KindTemplates: "tmpl",
	}
	label, ok := prefix[kind]
	if !ok {
		label = "cat"
	}
	return fmt.Sprintf("%s-%06d", label, s.rand.Intn(900000)+100000)
}

func cloneItemDetail(asset catalogAsset) ItemDetail {
	detail := asset.detail
	detail.Item = asset.item
	if asset.item.ScheduledPublishAt != nil {
		ts := *asset.item.ScheduledPublishAt
		detail.Item.ScheduledPublishAt = &ts
	}
	if asset.item.LastPublishedAt != nil {
		ts := *asset.item.LastPublishedAt
		detail.Item.LastPublishedAt = &ts
	}
	detail.Item.LastPublishedBy = asset.item.LastPublishedBy
	if len(detail.Tags) > 0 {
		tags := make([]string, len(detail.Tags))
		copy(tags, detail.Tags)
		detail.Tags = tags
	}
	if len(detail.Metadata) > 0 {
		entries := make([]MetadataEntry, len(detail.Metadata))
		copy(entries, detail.Metadata)
		detail.Metadata = entries
	}
	if detail.Properties != nil {
		props := make(map[string]string, len(detail.Properties))
		for key, value := range detail.Properties {
			props[key] = value
		}
		detail.Properties = props
	}
	if len(detail.Usage) > 0 {
		usage := make([]UsageMetric, len(detail.Usage))
		copy(usage, detail.Usage)
		detail.Usage = usage
	}
	if len(detail.Dependencies) > 0 {
		deps := make([]Dependency, len(detail.Dependencies))
		copy(deps, detail.Dependencies)
		detail.Dependencies = deps
	}
	if len(detail.AuditTrail) > 0 {
		audit := make([]AuditEntry, len(detail.AuditTrail))
		copy(audit, detail.AuditTrail)
		detail.AuditTrail = audit
	}
	if detail.ScheduledPublishAt != nil {
		ts := *detail.ScheduledPublishAt
		detail.ScheduledPublishAt = &ts
	}
	if detail.LastPublishedAt != nil {
		ts := *detail.LastPublishedAt
		detail.LastPublishedAt = &ts
	}
	detail.LastPublishedBy = asset.detail.LastPublishedBy
	return detail
}

func buildAssetFromInput(existing catalogAsset, input AssetInput, updatedAt time.Time) catalogAsset {
	item := existing.item
	detail := existing.detail

	item.ID = strings.TrimSpace(input.ID)
	item.Kind = NormalizeKind(string(input.Kind))
	item.Name = strings.TrimSpace(input.Name)
	if item.Name == "" {
		item.Name = "未設定アセット"
	}
	item.Identifier = strings.TrimSpace(input.Identifier)
	item.Description = strings.TrimSpace(input.Description)
	item.Status = input.Status
	item.StatusLabel = statusLabel(item.Status)
	item.StatusTone = statusTone(item.Status)
	item.Category = strings.TrimSpace(input.Category)
	item.CategoryLabel = categoryLabelFor(item.Kind, item.Category)
	item.Tags = sanitizeTags(input.Tags)
	item.Owner = OwnerInfo{
		Name:  coalesce(input.OwnerName, item.Owner.Name, "Catalog Ops"),
		Email: coalesce(input.OwnerEmail, item.Owner.Email, "ops@hanko.example.com"),
	}
	item.UpdatedAt = updatedAt
	item.Version = strings.TrimSpace(input.Version)
	item.UsageLabel = usageLabelForStatus(item.Status)
	item.PreviewURL = coalesce(input.PreviewURL, item.PreviewURL, defaultPreviewFor(item.Kind))
	item.PreviewAssetID = coalesce(input.PreviewAssetID, item.PreviewAssetID)
	item.PreviewFileName = coalesce(input.PreviewFileName, item.PreviewFileName)
	item.PreviewAlt = coalesce(input.PreviewAlt, item.PreviewAlt, item.Name)
	item.PrimaryColor = coalesce(input.PrimaryColor, item.PrimaryColor, "#0F172A")
	item.Metrics = buildItemMetrics(item.Kind, input)
	if input.ScheduledPublishAt != nil {
		scheduled := input.ScheduledPublishAt.UTC()
		item.ScheduledPublishAt = &scheduled
		detail.ScheduledPublishAt = &scheduled
	} else {
		item.ScheduledPublishAt = nil
		detail.ScheduledPublishAt = nil
	}
	detail.LastPublishedAt = existing.detail.LastPublishedAt
	detail.LastPublishedBy = existing.detail.LastPublishedBy
	item.LastPublishedAt = existing.item.LastPublishedAt
	item.LastPublishedBy = existing.item.LastPublishedBy

	detail.Item = item
	detail.Description = item.Description
	detail.Owner = item.Owner
	detail.Tags = item.Tags
	detail.PreviewURL = item.PreviewURL
	detail.PreviewAssetID = item.PreviewAssetID
	detail.PreviewFileName = item.PreviewFileName
	detail.PreviewAlt = item.PreviewAlt
	detail.SVGPath = coalesce(input.SVGPath, detail.SVGPath)
	detail.SVGAssetID = coalesce(input.SVGAssetID, detail.SVGAssetID)
	detail.SVGFileName = coalesce(input.SVGFileName, detail.SVGFileName)
	detail.Metadata = buildMetadataEntries(item.Kind, input)
	detail.UpdatedAt = updatedAt
	detail.Properties = mergeProperties(detail.Properties, propertiesFromInput(input))

	return catalogAsset{item: item, detail: detail}
}

func sanitizeTags(tags []string) []string {
	if len(tags) == 0 {
		return nil
	}
	set := make([]string, 0, len(tags))
	seen := map[string]struct{}{}
	for _, tag := range tags {
		value := strings.TrimSpace(tag)
		if value == "" {
			continue
		}
		if _, ok := seen[value]; ok {
			continue
		}
		seen[value] = struct{}{}
		set = append(set, value)
	}
	return set
}

func usageLabelForStatus(status Status) string {
	switch status {
	case StatusPublished:
		return "公開中"
	case StatusScheduled:
		return "公開予定"
	case StatusInReview:
		return "レビュー中"
	case StatusArchived:
		return "アーカイブ済み"
	default:
		return "下書き"
	}
}

func coalesce(values ...string) string {
	for _, value := range values {
		if strings.TrimSpace(value) != "" {
			return strings.TrimSpace(value)
		}
	}
	return ""
}

func defaultPreviewFor(kind Kind) string {
	switch kind {
	case KindFonts:
		return "/public/static/placeholders/catalog-font-serif.png"
	case KindMaterials:
		return "/public/static/placeholders/catalog-material-washi.png"
	case KindProducts:
		return "/public/static/placeholders/catalog-product-kit.png"
	default:
		return "/public/static/placeholders/catalog-template-fuji.png"
	}
}

func categoryLabelFor(kind Kind, category string) string {
	value := strings.TrimSpace(category)
	if value == "" {
		return "未分類"
	}
	lookup := map[Kind]map[string]string{
		KindTemplates: {
			"seasonal":        "季節・年賀状",
			"business":        "法人向け",
			"family":          "ファミリー",
			"seasonal_bundle": "季節ギフト",
		},
		KindFonts: {
			"serif":  "セリフ",
			"sans":   "サンセリフ",
			"script": "スクリプト",
		},
		KindMaterials: {
			"textured": "テクスチャ",
			"gloss":    "グロス",
			"matte":    "マット",
		},
		KindProducts: {
			"engraving":       "名入れ商品",
			"seasonal_bundle": "季節ギフト",
			"cards":           "カード",
		},
	}
	if labels, ok := lookup[kind]; ok {
		if label, ok := labels[value]; ok {
			return label
		}
	}
	return strings.ToUpper(value[:1]) + value[1:]
}

func buildItemMetrics(kind Kind, input AssetInput) []ItemMetric {
	switch kind {
	case KindFonts:
		return []ItemMetric{
			{Label: "ウェイト", Value: strings.Join(sanitizeTags(input.FontWeights), ", "), Icon: "⚖️"},
			{Label: "ライセンス", Value: coalesce(input.License, "商用"), Icon: "⚖️"},
		}
	case KindMaterials:
		inv := ""
		if input.Inventory > 0 {
			inv = fmt.Sprintf("%d 枚", input.Inventory)
		}
		return []ItemMetric{
			{Label: "SKU", Value: coalesce(input.MaterialSKU, input.Identifier), Icon: "🏷"},
			{Label: "在庫", Value: inv, Icon: "📦"},
		}
	case KindProducts:
		price := ""
		if input.PriceMinor > 0 {
			price = formatYen(input.PriceMinor)
		}
		lead := ""
		if input.LeadTimeDays > 0 {
			lead = fmt.Sprintf("%d 日", input.LeadTimeDays)
		}
		return []ItemMetric{
			{Label: "単価", Value: price, Icon: "💴"},
			{Label: "リードタイム", Value: lead, Icon: "⏱"},
		}
	default:
		return []ItemMetric{
			{Label: "テンプレID", Value: coalesce(input.TemplateID, input.Identifier), Icon: "🆔"},
			{Label: "SVG", Value: coalesce(input.SVGPath, "未設定"), Icon: "🧩"},
		}
	}
}

func buildMetadataEntries(kind Kind, input AssetInput) []MetadataEntry {
	entries := []MetadataEntry{}
	switch kind {
	case KindFonts:
		entries = append(entries,
			MetadataEntry{Key: "ファミリー", Value: coalesce(input.FontFamily, input.Name), Icon: "🔤"},
			MetadataEntry{Key: "ライセンス", Value: coalesce(input.License, "商用"), Icon: "⚖️"},
		)
	case KindMaterials:
		entries = append(entries,
			MetadataEntry{Key: "SKU", Value: coalesce(input.MaterialSKU, input.Identifier), Icon: "🏷"},
			MetadataEntry{Key: "カラー", Value: coalesce(input.Color, input.PrimaryColor), Icon: "🎨"},
		)
	case KindProducts:
		entries = append(entries,
			MetadataEntry{Key: "SKU", Value: coalesce(input.ProductSKU, input.Identifier), Icon: "🏷"},
			MetadataEntry{Key: "価格", Value: formatYen(input.PriceMinor), Icon: "💴"},
			MetadataEntry{Key: "リードタイム", Value: fmt.Sprintf("%d 日", input.LeadTimeDays), Icon: "⏱"},
		)
	default:
		entries = append(entries,
			MetadataEntry{Key: "テンプレID", Value: coalesce(input.TemplateID, input.Identifier), Icon: "🆔"},
			MetadataEntry{Key: "SVG パス", Value: coalesce(input.SVGPath, "未設定"), Icon: "🧩"},
		)
	}
	if len(input.PhotoURLs) > 0 {
		entries = append(entries, MetadataEntry{Key: "プレビュー", Value: input.PhotoURLs[0], Icon: "🖼"})
	}
	return entries
}

func propertiesFromInput(input AssetInput) map[string]string {
	values := map[string]string{
		"id":              input.ID,
		"kind":            string(input.Kind),
		"version":         input.Version,
		"name":            input.Name,
		"identifier":      input.Identifier,
		"description":     input.Description,
		"status":          string(input.Status),
		"category":        input.Category,
		"templateID":      input.TemplateID,
		"svgPath":         input.SVGPath,
		"svgAssetID":      input.SVGAssetID,
		"svgFileName":     input.SVGFileName,
		"previewURL":      input.PreviewURL,
		"previewAssetID":  input.PreviewAssetID,
		"previewFileName": input.PreviewFileName,
		"previewAlt":      input.PreviewAlt,
		"fontFamily":      input.FontFamily,
		"fontWeights":     strings.Join(input.FontWeights, ", "),
		"license":         input.License,
		"materialSKU":     input.MaterialSKU,
		"color":           input.Color,
		"inventory":       strconv.Itoa(input.Inventory),
		"productSKU":      input.ProductSKU,
		"price":           strconv.FormatInt(input.PriceMinor, 10),
		"currency":        input.Currency,
		"leadTime":        strconv.Itoa(input.LeadTimeDays),
		"photoURLs":       strings.Join(input.PhotoURLs, "\n"),
		"primaryColor":    input.PrimaryColor,
		"ownerName":       input.OwnerName,
		"ownerEmail":      input.OwnerEmail,
		"tags":            strings.Join(input.Tags, ", "),
		"scheduledPublishAt": func() string {
			if input.ScheduledPublishAt == nil {
				return ""
			}
			return input.ScheduledPublishAt.UTC().Format(time.RFC3339)
		}(),
	}
	for key, value := range values {
		values[key] = cleanPropertyValue(key, value)
	}
	return values
}

func mergeProperties(existing, updates map[string]string) map[string]string {
	if len(existing) == 0 && len(updates) == 0 {
		return nil
	}
	merged := make(map[string]string, len(existing)+len(updates))
	for key, value := range existing {
		merged[key] = cleanPropertyValue(key, value)
	}
	for key, value := range updates {
		merged[key] = cleanPropertyValue(key, value)
	}
	if len(merged) == 0 {
		return nil
	}
	return merged
}

func cleanPropertyValue(key, value string) string {
	switch key {
	case "photoURLs", "description":
		return strings.TrimRight(value, "\r\n ")
	default:
		return strings.TrimSpace(value)
	}
}

func formatYen(v int64) string {
	if v <= 0 {
		return "¥0"
	}
	s := fmt.Sprintf("%d", v)
	var builder strings.Builder
	mod := len(s) % 3
	for i, r := range s {
		if i != 0 && (i-mod)%3 == 0 {
			builder.WriteRune(',')
		}
		builder.WriteRune(r)
	}
	return "¥" + builder.String()
}

func buildTemplateAssets(now time.Time) []catalogAsset {
	base := now
	return []catalogAsset{
		makeCatalogAsset(
			Item{
				ID:            "tmpl-2024-fuji",
				Name:          "2024年 年賀状（富士）",
				Identifier:    "TMP-2024-FUJI",
				Kind:          KindTemplates,
				Category:      "seasonal",
				CategoryLabel: "季節・年賀状",
				Status:        StatusPublished,
				StatusLabel:   "公開中",
				StatusTone:    "success",
				Description:   "富士山と朝日の伝統的な構図に、箔押しテクスチャを合わせた人気テンプレート。",
				Owner: OwnerInfo{
					Name:  "Akari Sato",
					Email: "akari.sato@example.com",
				},
				UpdatedAt:       base.Add(-4 * time.Hour),
				Version:         "v12",
				UsageCount:      4821,
				UsageLabel:      "4,821件の注文",
				Tags:            []string{"newyear", "featured", "2024"},
				PreviewURL:      "/public/static/placeholders/catalog-template-fuji.png",
				PreviewAlt:      "富士山テンプレート",
				Channels:        []string{"アプリ", "Web"},
				Format:          "148x100mm",
				PrimaryColor:    "#F97316",
				LastPublishedAt: timePtr(base.Add(-5 * time.Hour)),
				LastPublishedBy: "Akari Sato",
				Metrics: []ItemMetric{
					{Label: "CVR", Value: "3.2%", Icon: "📈"},
					{Label: "保存", Value: "1,204", Icon: "⭐"},
				},
				Badge:     "キャンペーン",
				BadgeTone: "info",
			},
			withProperties(
				ItemDetail{
					PreviewURL:  "/public/static/placeholders/catalog-template-fuji.png",
					PreviewAlt:  "富士山テンプレート",
					Description: "年末年始のトップセラー。メインの背景イラストはベクター化されているため、箔や特色にも対応可能です。",
					Usage: []UsageMetric{
						{Label: "今週", Value: "912 件", Icon: "🗓"},
						{Label: "リピート率", Value: "28%", Icon: "🔁"},
					},
					Metadata: []MetadataEntry{
						{Key: "カテゴリ", Value: "年賀状 > プレミアム", Icon: "🏷"},
						{Key: "チャネル", Value: "iOS / Web", Icon: "🌐"},
						{Key: "最終更新", Value: base.Add(-4 * time.Hour).Format("2006-01-02 15:04"), Icon: "⏱"},
					},
					Dependencies: []Dependency{
						{Label: "フォント: Hanko Serif", Kind: "font", Status: "承認済み", Tone: "success"},
						{Label: "素材: 和紙パール", Kind: "material", Status: "在庫 64%", Tone: "warning"},
					},
					AuditTrail: []AuditEntry{
						{Timestamp: base.Add(-4 * time.Hour), Actor: "Akari Sato", Action: "配色を更新", Channel: "web"},
						{Timestamp: base.Add(-26 * time.Hour), Actor: "Nobu Kato", Action: "レビュー承認", Channel: "mobile"},
					},
					LastPublishedAt: timePtr(base.Add(-5 * time.Hour)),
					LastPublishedBy: "Akari Sato",
				},
				map[string]string{
					"templateID": "TMP-2024-FUJI",
					"svgPath":    "/designs/templates/2024-fuji.svg",
					"photoURLs":  "/public/static/placeholders/catalog-template-fuji.png",
				},
			),
		),
		makeCatalogAsset(
			Item{
				ID:            "tmpl-minimal-stamp",
				Name:          "ミニマル判子フレーム",
				Identifier:    "TMP-MINIMAL-STAMP",
				Kind:          KindTemplates,
				Category:      "business",
				CategoryLabel: "法人向け",
				Status:        StatusDraft,
				StatusLabel:   "下書き",
				StatusTone:    "warning",
				Description:   "シンプルな三日月判子をアクセントにしたミニマルデザイン。法人挨拶状に最適。",
				Owner: OwnerInfo{
					Name:  "Nobu Kato",
					Email: "nobu.kato@example.com",
				},
				UpdatedAt:          base.Add(-30 * time.Hour),
				Version:            "v4",
				UsageCount:         0,
				UsageLabel:         "未公開",
				Tags:               []string{"b2b", "minimal", "draft"},
				PreviewURL:         "/public/static/placeholders/catalog-template-stamp.png",
				PreviewAlt:         "ミニマルテンプレート",
				Channels:           []string{"Web"},
				Format:             "210x148mm",
				PrimaryColor:       "#0F172A",
				ScheduledPublishAt: timePtr(base.Add(14 * time.Hour)),
				Metrics: []ItemMetric{
					{Label: "想定単価", Value: "¥1,280", Icon: "💰"},
				},
			},
			withProperties(
				ItemDetail{
					PreviewURL:  "/public/static/placeholders/catalog-template-stamp.png",
					Description: "法人用テンプレート。ロゴ差し替えと箔押し指定に対応予定。",
					Usage: []UsageMetric{
						{Label: "カスタマイズ", Value: "12 件", Icon: "✏️"},
					},
					Metadata: []MetadataEntry{
						{Key: "対象", Value: "B2B", Icon: "🏢"},
						{Key: "最終更新", Value: base.Add(-30 * time.Hour).Format("2006-01-02 15:04"), Icon: "⏱"},
					},
					Dependencies: []Dependency{
						{Label: "フォント: Maru Gothic", Kind: "font", Status: "レビュー待ち", Tone: "info"},
					},
					AuditTrail: []AuditEntry{
						{Timestamp: base.Add(-30 * time.Hour), Actor: "Nobu Kato", Action: "下書きを保存", Channel: "web"},
						{Timestamp: base.Add(-12 * time.Hour), Actor: "Akari Sato", Action: "公開予約を設定", Channel: "web"},
					},
					Tags:               []string{"b2b", "minimal"},
					ScheduledPublishAt: timePtr(base.Add(14 * time.Hour)),
					LastPublishedBy:    "Akari Sato",
				},
				map[string]string{
					"templateID": "TMP-MINIMAL-STAMP",
					"svgPath":    "/designs/templates/minimal-stamp.svg",
					"photoURLs":  "/public/static/placeholders/catalog-template-stamp.png",
				},
			),
		),
		makeCatalogAsset(
			Item{
				ID:            "tmpl-collage-story",
				Name:          "写真コラージュ・ストーリー",
				Identifier:    "TMP-COLLAGE-STORY",
				Kind:          KindTemplates,
				Category:      "family",
				CategoryLabel: "ファミリー",
				Status:        StatusScheduled,
				StatusLabel:   statusLabel(StatusScheduled),
				StatusTone:    statusTone(StatusScheduled),
				Description:   "最大 6 枚の写真を柔軟にレイアウトできるファミリー向けテンプレート。",
				Owner: OwnerInfo{
					Name:  "Akari Sato",
					Email: "akari.sato@example.com",
				},
				UpdatedAt:          base.Add(-12 * time.Hour),
				Version:            "v5",
				UsageCount:         240,
				UsageLabel:         "テスト利用 240 件",
				Tags:               []string{"family", "photo", "beta"},
				PreviewURL:         "/public/static/placeholders/catalog-template-collage.png",
				PreviewAlt:         "コラージュテンプレート",
				Channels:           []string{"iOS", "Android"},
				Format:             "148x100mm",
				PrimaryColor:       "#0EA5E9",
				ScheduledPublishAt: timePtr(base.Add(6 * time.Hour)),
				Metrics: []ItemMetric{
					{Label: "保存率", Value: "62%", Icon: "💾"},
					{Label: "レビュー", Value: "⭐4.6", Icon: "💬"},
				},
			},
			withProperties(
				ItemDetail{
					PreviewURL:  "/public/static/placeholders/catalog-template-collage.png",
					Description: "写真アップロードを前提とした UI 変更を伴うテンプレート。利用ログは計測済み。",
					Usage: []UsageMetric{
						{Label: "ベータ", Value: "240 件", Icon: "🧪"},
					},
					Metadata: []MetadataEntry{
						{Key: "チャネル", Value: "Mobile", Icon: "📱"},
						{Key: "承認ステータス", Value: "QA中", Icon: "🧪"},
					},
					Dependencies: []Dependency{
						{Label: "素材: リネンホワイト", Kind: "material", Status: "在庫良好", Tone: "success"},
						{Label: "フォント: Rounded Sans", Kind: "font", Status: "公開中", Tone: "success"},
					},
					AuditTrail: []AuditEntry{
						{Timestamp: base.Add(-12 * time.Hour), Actor: "QA Bot", Action: "UI自動テスト", Channel: "ci"},
						{Timestamp: base.Add(-2 * time.Hour), Actor: "Nobu Kato", Action: "公開予約を設定", Channel: "web"},
					},
					ScheduledPublishAt: timePtr(base.Add(6 * time.Hour)),
				},
				map[string]string{
					"templateID": "TMP-COLLAGE-STORY",
					"svgPath":    "/designs/templates/collage-story.svg",
					"photoURLs":  "/public/static/placeholders/catalog-template-collage.png",
				},
			),
		),
	}
}

func buildFontAssets(now time.Time) []catalogAsset {
	return []catalogAsset{
		makeCatalogAsset(
			Item{
				ID:            "font-hanko-serif",
				Name:          "Hanko Serif JP",
				Identifier:    "FNT-HANKO-SERIF",
				Kind:          KindFonts,
				Category:      "serif",
				CategoryLabel: "セリフ",
				Status:        StatusPublished,
				StatusLabel:   "公開中",
				StatusTone:    "success",
				Description:   "判子のエッジをモチーフにしたセリフ体。小サイズでも可読性を維持。",
				Owner: OwnerInfo{
					Name:  "Mika Ito",
					Email: "mika.ito@example.com",
				},
				UpdatedAt:    now.Add(-48 * time.Hour),
				Version:      "1.8.2",
				UsageCount:   1280,
				UsageLabel:   "利用 1,280 件",
				Tags:         []string{"serif", "brand", "jp"},
				PreviewURL:   "/public/static/placeholders/catalog-font-serif.png",
				PreviewAlt:   "Hanko Serif",
				Channels:     []string{"Canvas", "Renderer"},
				Format:       "OTF",
				PrimaryColor: "#F97316",
			},
			withProperties(
				ItemDetail{
					PreviewURL:  "/public/static/placeholders/catalog-font-serif.png",
					Description: "本文・見出し兼用のブランドフォント。可変版も準備中。",
					Metadata: []MetadataEntry{
						{Key: "フォーマット", Value: "OTF / WOFF2", Icon: "📦"},
						{Key: "ライセンス", Value: "商用 / Web", Icon: "⚖️"},
					},
					Usage: []UsageMetric{
						{Label: "テンプレ適用", Value: "58%", Icon: "🧩"},
					},
					Dependencies: []Dependency{
						{Label: "Renderer pipeline", Kind: "service", Status: "v2.3", Tone: "info"},
					},
				},
				map[string]string{
					"fontFamily":  "Hanko Serif JP",
					"fontWeights": "400,700",
					"license":     "商用 / Web",
					"photoURLs":   "/public/static/placeholders/catalog-font-serif.png",
				},
			),
		),
		makeCatalogAsset(
			Item{
				ID:            "font-brushwave",
				Name:          "Brush Wave",
				Identifier:    "FNT-BRUSH-WAVE",
				Kind:          KindFonts,
				Category:      "brush",
				CategoryLabel: "筆記体",
				Status:        StatusPublished,
				StatusLabel:   "公開中",
				StatusTone:    "success",
				Description:   "毛筆の揺らぎを活かした手書き風フォント。賀詞に人気。",
				Owner: OwnerInfo{
					Name:  "Mika Ito",
					Email: "mika.ito@example.com",
				},
				UpdatedAt:    now.Add(-72 * time.Hour),
				Version:      "2.0.0",
				UsageCount:   824,
				UsageLabel:   "使用 824 件",
				Tags:         []string{"brush", "seasonal"},
				PreviewURL:   "/public/static/placeholders/catalog-font-brush.png",
				PreviewAlt:   "Brush Wave",
				Channels:     []string{"Renderer"},
				Format:       "TTF",
				PrimaryColor: "#A855F7",
			},
			withProperties(
				ItemDetail{
					PreviewURL:  "/public/static/placeholders/catalog-font-brush.png",
					Description: "濃淡を保持したSVGグリフを同梱。Web Canvas で最適化済み。",
					Dependencies: []Dependency{
						{Label: "OpenType Layout", Kind: "feature", Status: "完成", Tone: "success"},
					},
				},
				map[string]string{
					"fontFamily":  "Brush Wave",
					"fontWeights": "300,600",
					"license":     "商用 / App",
					"photoURLs":   "/public/static/placeholders/catalog-font-brush.png",
				},
			),
		),
		makeCatalogAsset(
			Item{
				ID:          "font-classic-slab",
				Name:        "Classic Slab",
				Identifier:  "FNT-CLASSIC-SLAB",
				Kind:        KindFonts,
				Status:      StatusArchived,
				StatusLabel: "アーカイブ",
				StatusTone:  "muted",
				Description: "旧世代テンプレート用のセリフ体。互換性維持のためのみ提供。",
				Owner: OwnerInfo{
					Name:  "Mika Ito",
					Email: "mika.ito@example.com",
				},
				UpdatedAt:    now.Add(-500 * time.Hour),
				Version:      "0.9.1",
				UsageCount:   12,
				UsageLabel:   "互換用",
				Tags:         []string{"legacy"},
				PreviewURL:   "/public/static/placeholders/catalog-font-slab.png",
				PreviewAlt:   "Classic Slab",
				Channels:     []string{"Renderer"},
				Format:       "OTF",
				PrimaryColor: "#475569",
			},
			withProperties(
				ItemDetail{
					PreviewURL:  "/public/static/placeholders/catalog-font-slab.png",
					Description: "旧バッチとの互換性を保つためアーカイブ。依存テンプレートの移行完了後に削除予定。",
					Dependencies: []Dependency{
						{Label: "テンプレ: TMP-LEGACY-01", Kind: "template", Status: "移行中", Tone: "warning"},
					},
				},
				map[string]string{
					"fontFamily":  "Classic Slab",
					"fontWeights": "400",
					"license":     "社内限定",
					"photoURLs":   "/public/static/placeholders/catalog-font-slab.png",
				},
			),
		),
	}
}

func buildMaterialAssets(now time.Time) []catalogAsset {
	return []catalogAsset{
		makeCatalogAsset(
			Item{
				ID:            "mat-washi-pearl",
				Name:          "和紙パール 0.26mm",
				Identifier:    "MAT-WASHI-PEARL",
				Kind:          KindMaterials,
				Category:      "premium",
				CategoryLabel: "プレミアム素材",
				Status:        StatusPublished,
				StatusLabel:   "供給中",
				StatusTone:    "success",
				Description:   "細かなパール粒子を含んだ和紙。高級感と発色を両立。",
				Owner: OwnerInfo{
					Name:  "Hiro Tanaka",
					Email: "hiro.tanaka@example.com",
				},
				UpdatedAt:    now.Add(-6 * time.Hour),
				Version:      "Lot 2024-03",
				UsageCount:   1920,
				UsageLabel:   "稼働率 84%",
				Tags:         []string{"premium", "washi"},
				PreviewURL:   "/public/static/placeholders/catalog-material-washi.png",
				PreviewAlt:   "和紙サンプル",
				Channels:     []string{"Factory A"},
				Format:       "Sheet",
				PrimaryColor: "#60A5FA",
			},
			withProperties(
				ItemDetail{
					PreviewURL:  "/public/static/placeholders/catalog-material-washi.png",
					Description: "富士和紙工房からの限定ロット。吸湿による伸縮があるため、保管環境注意。",
					Metadata: []MetadataEntry{
						{Key: "坪量", Value: "216 g/m²", Icon: "⚖️"},
						{Key: "在庫", Value: "4,600枚", Icon: "📦"},
					},
					Dependencies: []Dependency{
						{Label: "仕入れ: FW-PEARL-24-03", Kind: "PO", Status: "入庫済み", Tone: "success"},
					},
				},
				map[string]string{
					"materialSKU": "MAT-WASHI-PEARL",
					"color":       "パールホワイト",
					"inventory":   "4600",
					"photoURLs":   "/public/static/placeholders/catalog-material-washi.png",
				},
			),
		),
		makeCatalogAsset(
			Item{
				ID:            "mat-recycled-kraft",
				Name:          "再生クラフト 0.18mm",
				Identifier:    "MAT-RECYCLE-KRAFT",
				Kind:          KindMaterials,
				Category:      "sustainable",
				CategoryLabel: "サステナブル",
				Status:        StatusDraft,
				StatusLabel:   "テスト中",
				StatusTone:    "warning",
				Description:   "100%再生紙のクラフト。温かみとエコ訴求向き。",
				Owner: OwnerInfo{
					Name:  "Hiro Tanaka",
					Email: "hiro.tanaka@example.com",
				},
				UpdatedAt:    now.Add(-20 * time.Hour),
				Version:      "Prototype",
				UsageCount:   48,
				UsageLabel:   "試験ロット",
				Tags:         []string{"eco", "draft"},
				PreviewURL:   "/public/static/placeholders/catalog-material-kraft.png",
				PreviewAlt:   "クラフト紙",
				Channels:     []string{"Factory B"},
				Format:       "Roll",
				PrimaryColor: "#B45309",
			},
			withProperties(
				ItemDetail{
					PreviewURL:  "/public/static/placeholders/catalog-material-kraft.png",
					Description: "オンデマンド印刷での乾燥テスト中。表面コーティングを追加予定。",
					Dependencies: []Dependency{
						{Label: "印刷ラインB", Kind: "line", Status: "調整中", Tone: "info"},
					},
				},
				map[string]string{
					"materialSKU": "MAT-RECYCLE-KRAFT",
					"color":       "ブラウン",
					"inventory":   "1200",
					"photoURLs":   "/public/static/placeholders/catalog-material-kraft.png",
				},
			),
		),
		makeCatalogAsset(
			Item{
				ID:            "mat-metallic-gold",
				Name:          "メタリックゴールドフィルム",
				Identifier:    "MAT-METALLIC-GOLD",
				Kind:          KindMaterials,
				Category:      "specialty",
				CategoryLabel: "特殊加工",
				Status:        StatusPublished,
				StatusLabel:   "供給中",
				StatusTone:    "success",
				Description:   "鏡面ゴールドのフィルム。箔押し圧を強めることで発色が安定。",
				Owner: OwnerInfo{
					Name:  "Hiro Tanaka",
					Email: "hiro.tanaka@example.com",
				},
				UpdatedAt:    now.Add(-90 * time.Hour),
				Version:      "Lot 2024-02B",
				UsageCount:   312,
				UsageLabel:   "リードタイム 5日",
				Tags:         []string{"metallic", "foil"},
				PreviewURL:   "/public/static/placeholders/catalog-material-metallic.png",
				PreviewAlt:   "ゴールドフィルム",
				Channels:     []string{"Factory A"},
				Format:       "Roll",
				PrimaryColor: "#FACC15",
			},
			withProperties(
				ItemDetail{
					PreviewURL:  "/public/static/placeholders/catalog-material-metallic.png",
					Description: "華やかなゴールド加工用フィルム。粘着層が厚いため低温保管が必須。",
					Metadata: []MetadataEntry{
						{Key: "推奨温度", Value: "18℃", Icon: "🌡"},
					},
					Dependencies: []Dependency{
						{Label: "サプライヤー: TK Metals", Kind: "vendor", Status: "契約更新", Tone: "warning"},
					},
				},
				map[string]string{
					"materialSKU": "MAT-METALLIC-GOLD",
					"color":       "ゴールド",
					"inventory":   "3200",
					"photoURLs":   "/public/static/placeholders/catalog-material-metallic.png",
				},
			),
		),
	}
}

func buildProductAssets(now time.Time) []catalogAsset {
	return []catalogAsset{
		makeCatalogAsset(
			Item{
				ID:            "prd-nenga-kit",
				Name:          "年賀状プレミアムセット",
				Identifier:    "PRD-NENGA-PREMIUM",
				Kind:          KindProducts,
				Category:      "seasonal_bundle",
				CategoryLabel: "季節ギフト",
				Status:        StatusPublished,
				StatusLabel:   "販売中",
				StatusTone:    "success",
				Description:   "テンプレ + 素材 + 投函代行を含む人気セット。平均単価 ¥4,980。",
				Owner: OwnerInfo{
					Name:  "Kana Fujii",
					Email: "kana.fujii@example.com",
				},
				UpdatedAt:    now.Add(-10 * time.Hour),
				Version:      "Bundle v6",
				UsageCount:   1420,
				UsageLabel:   "販売 1,420 件",
				Tags:         []string{"bundle", "seasonal"},
				PreviewURL:   "/public/static/placeholders/catalog-product-kit.png",
				PreviewAlt:   "年賀状セット",
				Channels:     []string{"App", "Web"},
				Format:       "Bundle",
				PrimaryColor: "#EF4444",
			},
			withProperties(
				ItemDetail{
					PreviewURL:  "/public/static/placeholders/catalog-product-kit.png",
					Description: "テンプレート3種 + プレミアム素材 + 投函代行クレジットを含むセット。オプションにフォント追加を予定。",
					Usage: []UsageMetric{
						{Label: "平均単価", Value: "¥5,420", Icon: "💴"},
						{Label: "粗利", Value: "48%", Icon: "📊"},
					},
					Dependencies: []Dependency{
						{Label: "素材: 和紙パール", Kind: "material", Status: "供給中", Tone: "success"},
						{Label: "テンプレ: TMP-2024-FUJI", Kind: "template", Status: "公開中", Tone: "success"},
					},
					AuditTrail: []AuditEntry{
						{Timestamp: now.Add(-10 * time.Hour), Actor: "Kana Fujii", Action: "価格を更新 (¥4,980→¥5,200)", Channel: "web"},
					},
				},
				map[string]string{
					"productSKU": "PRD-NENGA-PREMIUM",
					"price":      "5200",
					"currency":   "JPY",
					"leadTime":   "5",
					"photoURLs":  "/public/static/placeholders/catalog-product-kit.png",
				},
			),
		),
		makeCatalogAsset(
			Item{
				ID:            "prd-engraved-stamp",
				Name:          "真鍮製はんこ + 桐箱",
				Identifier:    "PRD-ENGRAVED-STAMP",
				Kind:          KindProducts,
				Category:      "engraving",
				CategoryLabel: "名入れ商品",
				Status:        StatusInReview,
				StatusLabel:   "準備中",
				StatusTone:    "info",
				Description:   "真鍮の印鑑と桐箱のセット。発送リードタイム 7 日。",
				Owner: OwnerInfo{
					Name:  "Kana Fujii",
					Email: "kana.fujii@example.com",
				},
				UpdatedAt:    now.Add(-36 * time.Hour),
				Version:      "Pilot",
				UsageCount:   120,
				UsageLabel:   "先行販売 120 件",
				Tags:         []string{"gift", "pilot"},
				PreviewURL:   "/public/static/placeholders/catalog-product-stamp.png",
				PreviewAlt:   "真鍮はんこ",
				Channels:     []string{"App"},
				Format:       "Bundle",
				PrimaryColor: "#F59E0B",
			},
			withProperties(
				ItemDetail{
					PreviewURL:  "/public/static/placeholders/catalog-product-stamp.png",
					Description: "ギフト需要向け。刻印 API の検証が完了次第ローンチ予定。",
					Dependencies: []Dependency{
						{Label: "刻印API", Kind: "service", Status: "QA中", Tone: "info"},
						{Label: "素材: 真鍮ロッド", Kind: "material", Status: "在庫要補充", Tone: "warning"},
					},
				},
				map[string]string{
					"productSKU": "PRD-ENGRAVED-STAMP",
					"price":      "7800",
					"currency":   "JPY",
					"leadTime":   "7",
					"photoURLs":  "/public/static/placeholders/catalog-product-stamp.png",
				},
			),
		),
		makeCatalogAsset(
			Item{
				ID:          "prd-premium-bundle",
				Name:        "プレミアム名入れギフトセット",
				Identifier:  "PRD-PREMIUM-GIFT",
				Kind:        KindProducts,
				Status:      StatusDraft,
				StatusLabel: "構成中",
				StatusTone:  "warning",
				Description: "名入れポスター + 木製フレーム + ギフトボックスの組み合わせ。夏ローンチ予定。",
				Owner: OwnerInfo{
					Name:  "Kana Fujii",
					Email: "kana.fujii@example.com",
				},
				UpdatedAt:    now.Add(-5 * time.Hour),
				Version:      "Spec draft",
				UsageCount:   0,
				UsageLabel:   "未公開",
				Tags:         []string{"gift", "draft"},
				PreviewURL:   "/public/static/placeholders/catalog-product-gift.png",
				PreviewAlt:   "ギフトセット",
				Channels:     []string{"Web"},
				Format:       "Bundle",
				PrimaryColor: "#7C3AED",
			},
			withProperties(
				ItemDetail{
					PreviewURL:  "/public/static/placeholders/catalog-product-gift.png",
					Description: "撮影中のためダミー画像。SKU 構成と在庫引当ルールを検討中。",
					Dependencies: []Dependency{
						{Label: "木工パートナー", Kind: "vendor", Status: "契約交渉", Tone: "warning"},
					},
				},
				map[string]string{
					"productSKU": "PRD-PREMIUM-GIFT",
					"price":      "9800",
					"currency":   "JPY",
					"leadTime":   "6",
					"photoURLs":  "/public/static/placeholders/catalog-product-gift.png",
				},
			),
		),
	}
}
