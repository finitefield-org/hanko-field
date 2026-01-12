package ui

import (
	"fmt"
	"net/url"
	"regexp"
	"strconv"
	"strings"
	"time"

	adminpromotions "finitefield.org/hanko-admin/internal/admin/promotions"
	promotionstpl "finitefield.org/hanko-admin/internal/admin/templates/promotions"
)

type promotionModalMode string

const (
	promotionModalModeNew  promotionModalMode = "new"
	promotionModalModeEdit promotionModalMode = "edit"
)

const (
	conditionDiscountType   = "discount-type"
	conditionShippingOption = "shipping-option"

	shippingOptionFree = "free"
	shippingOptionFlat = "flat"
)

var (
	defaultTimezone = time.Local
)

type promotionFormState struct {
	Values map[string]string
	Multi  map[string][]string
}

func buildPromotionModal(mode promotionModalMode, state promotionFormState, fieldErrors map[string]string, generalErr string, actionURL, method, csrf string) promotionstpl.ModalData {
	if state.Values == nil {
		state = defaultPromotionFormState()
	}
	if state.Multi == nil {
		state.Multi = map[string][]string{}
	}
	if fieldErrors == nil {
		fieldErrors = map[string]string{}
	}

	hidden := []promotionstpl.ModalHiddenField{{Name: "csrf_token", Value: csrf}}
	if version := strings.TrimSpace(state.Values["version"]); version != "" {
		hidden = append(hidden, promotionstpl.ModalHiddenField{Name: "version", Value: version})
	}

	conditions := map[string]string{
		conditionDiscountType:   strings.TrimSpace(state.Values["type"]),
		conditionShippingOption: strings.TrimSpace(state.Values["shippingOption"]),
	}

	title := "プロモーションを作成"
	description := "コード・割引内容・適用条件を設定し、配信チャネルを選択します。送信後にテーブルが更新されます。"
	submitLabel := "作成する"
	submitTone := "primary"
	if mode == promotionModalModeEdit {
		title = "プロモーションを編集"
		submitLabel = "更新する"
	}

	sections := buildPromotionSections(state, fieldErrors)

	return promotionstpl.ModalData{
		Title:        title,
		Description:  description,
		Mode:         string(mode),
		ActionURL:    actionURL,
		Method:       method,
		SubmitLabel:  submitLabel,
		SubmitTone:   submitTone,
		HiddenFields: hidden,
		Sections:     sections,
		Error:        generalErr,
		Conditions:   conditions,
	}
}

func buildPromotionSections(state promotionFormState, errs map[string]string) []promotionstpl.ModalSection {
	sections := []promotionstpl.ModalSection{
		basicInfoSection(state, errs),
		discountSection(state, errs),
		eligibilitySection(state, errs),
		scheduleSection(state, errs),
		usageSection(state, errs),
	}
	filtered := make([]promotionstpl.ModalSection, 0, len(sections))
	for _, section := range sections {
		if len(section.Fields) == 0 {
			continue
		}
		filtered = append(filtered, section)
	}
	return filtered
}

func basicInfoSection(state promotionFormState, errs map[string]string) promotionstpl.ModalSection {
	return promotionstpl.ModalSection{
		Title:       "基本情報",
		Description: "管理用の名称やコード、対象チャネルを設定します。コードはユーザーに表示されます。",
		Fields: []promotionstpl.ModalField{
			{
				Name:        "name",
				Label:       "プロモーション名",
				Type:        "text",
				Value:       state.Values["name"],
				Placeholder: "春の会員限定セール",
				Required:    true,
				Error:       errs["name"],
			},
			{
				Name:        "code",
				Label:       "クーポンコード",
				Type:        "text",
				Value:       state.Values["code"],
				Placeholder: "SPRING24",
				Hint:        "半角英数字とハイフンのみ使用可能",
				Required:    true,
				Error:       errs["code"],
			},
			{
				Name:     "status",
				Label:    "ステータス",
				Type:     "select",
				Value:    state.Values["status"],
				Options:  promotionStatusOptions(state.Values["status"]),
				Required: true,
				Error:    errs["status"],
			},
			{
				Name:      "channels",
				Label:     "配信チャネル",
				Type:      "multiselect",
				Multiple:  true,
				Options:   promotionChannelOptions(state.Multi["channels"]),
				FullWidth: true,
				Hint:      "Cmd/Ctrl + クリックで複数選択",
				Required:  true,
				Error:     errs["channels"],
			},
			{
				Name:      "description",
				Label:     "説明",
				Type:      "textarea",
				Value:     state.Values["description"],
				Rows:      3,
				FullWidth: true,
				Hint:      "内部メモやキャンペーン概要を入力",
				Error:     errs["description"],
			},
		},
	}
}

func discountSection(state promotionFormState, errs map[string]string) promotionstpl.ModalSection {
	fields := []promotionstpl.ModalField{
		{
			Name:     "type",
			Label:    "割引タイプ",
			Type:     "select",
			Value:    state.Values["type"],
			Options:  promotionTypeOptions(state.Values["type"]),
			Required: true,
			Error:    errs["type"],
			Attributes: map[string]string{
				"data-promotion-condition-source": conditionDiscountType,
			},
		},
		{
			Name:           "percentage",
			Label:          "割引率",
			Type:           "number",
			Value:          state.Values["percentage"],
			Suffix:         "%",
			Step:           "0.1",
			Min:            "0",
			Max:            "100",
			ConditionKey:   conditionDiscountType,
			ConditionValue: string(adminpromotions.TypePercentage),
			Error:          errs["percentage"],
		},
		{
			Name:           "amount",
			Label:          "割引額",
			Type:           "number",
			Value:          state.Values["amount"],
			Prefix:         "¥",
			Min:            "0",
			ConditionKey:   conditionDiscountType,
			ConditionValue: string(adminpromotions.TypeFixedAmount),
			Error:          errs["amount"],
		},
		{
			Name:           "currency",
			Label:          "通貨",
			Type:           "select",
			Value:          coalesce(state.Values["currency"], "JPY"),
			Options:        promotionCurrencyOptions(state.Values["currency"]),
			ConditionKey:   conditionDiscountType,
			ConditionValue: string(adminpromotions.TypeFixedAmount),
			Error:          errs["currency"],
		},
		{
			Name:           "bundleBuy",
			Label:          "購入点数",
			Type:           "number",
			Value:          state.Values["bundleBuy"],
			Min:            "1",
			ConditionKey:   conditionDiscountType,
			ConditionValue: string(adminpromotions.TypeBundle),
			Error:          errs["bundleBuy"],
		},
		{
			Name:           "bundleGet",
			Label:          "特典点数",
			Type:           "number",
			Value:          state.Values["bundleGet"],
			Min:            "1",
			ConditionKey:   conditionDiscountType,
			ConditionValue: string(adminpromotions.TypeBundle),
			Error:          errs["bundleGet"],
		},
		{
			Name:           "bundleDiscount",
			Label:          "特典割引率",
			Type:           "number",
			Value:          state.Values["bundleDiscount"],
			Suffix:         "%",
			Step:           "0.1",
			Min:            "0",
			Max:            "100",
			ConditionKey:   conditionDiscountType,
			ConditionValue: string(adminpromotions.TypeBundle),
			Error:          errs["bundleDiscount"],
		},
		{
			Name:           "shippingOption",
			Label:          "配送特典",
			Type:           "radio",
			Options:        promotionShippingOptions(state.Values["shippingOption"]),
			ConditionKey:   conditionDiscountType,
			ConditionValue: string(adminpromotions.TypeShipping),
			Attributes: map[string]string{
				"data-promotion-condition-source": conditionShippingOption,
			},
			Error: errs["shippingOption"],
		},
		{
			Name:           "shippingAmount",
			Label:          "送料割引額",
			Type:           "number",
			Value:          state.Values["shippingAmount"],
			Prefix:         "¥",
			Min:            "0",
			ConditionKey:   conditionShippingOption,
			ConditionValue: shippingOptionFlat,
			Error:          errs["shippingAmount"],
		},
		{
			Name:           "shippingCurrency",
			Label:          "配送通貨",
			Type:           "select",
			Value:          coalesce(state.Values["shippingCurrency"], "JPY"),
			Options:        promotionCurrencyOptions(state.Values["shippingCurrency"]),
			ConditionKey:   conditionShippingOption,
			ConditionValue: shippingOptionFlat,
			Error:          errs["shippingCurrency"],
		},
	}
	return promotionstpl.ModalSection{
		Title:       "割引設定",
		Description: "提供する割引内容と条件を定義します。割引タイプに応じて必要項目が変わります。",
		Fields:      fields,
	}
}

func eligibilitySection(state promotionFormState, errs map[string]string) promotionstpl.ModalSection {
	return promotionstpl.ModalSection{
		Title:       "対象・適用条件",
		Description: "適用するセグメントや追加条件を設定します。",
		Fields: []promotionstpl.ModalField{
			{
				Name:      "segment",
				Label:     "対象セグメント",
				Type:      "select",
				Value:     state.Values["segment"],
				Options:   promotionSegmentOptions(state.Values["segment"]),
				Required:  true,
				Error:     errs["segment"],
				FullWidth: true,
			},
			{
				Name:      "eligibility",
				Label:     "追加条件",
				Type:      "checkbox-group",
				Options:   promotionEligibilityOptions(state.Multi["eligibility"]),
				FullWidth: true,
				Error:     errs["eligibility"],
			},
			{
				Name:   "minOrder",
				Label:  "最低注文金額",
				Type:   "number",
				Value:  state.Values["minOrder"],
				Prefix: "¥",
				Hint:   "未入力の場合は下限なし",
				Error:  errs["minOrder"],
			},
		},
	}
}

func scheduleSection(state promotionFormState, errs map[string]string) promotionstpl.ModalSection {
	return promotionstpl.ModalSection{
		Title:       "スケジュール",
		Description: "開始・終了日時を指定します。終了未設定の場合は無期限です。",
		Fields: []promotionstpl.ModalField{
			{
				Name:     "startDate",
				Label:    "開始日",
				Type:     "date",
				Value:    state.Values["startDate"],
				Required: true,
				Error:    errs["startDate"],
			},
			{
				Name:     "startTime",
				Label:    "開始時刻",
				Type:     "time",
				Value:    state.Values["startTime"],
				Required: true,
				Step:     "900",
				Error:    errs["startTime"],
			},
			{
				Name:  "endDate",
				Label: "終了日",
				Type:  "date",
				Value: state.Values["endDate"],
				Error: errs["endDate"],
			},
			{
				Name:  "endTime",
				Label: "終了時刻",
				Type:  "time",
				Value: state.Values["endTime"],
				Step:  "900",
				Error: errs["endTime"],
			},
		},
	}
}

func usageSection(state promotionFormState, errs map[string]string) promotionstpl.ModalSection {
	return promotionstpl.ModalSection{
		Title:       "利用上限",
		Description: "キャンペーン全体および顧客単位の利用制限、予算上限を設定します。",
		Fields: []promotionstpl.ModalField{
			{
				Name:  "usageLimit",
				Label: "全体利用上限",
				Type:  "number",
				Value: state.Values["usageLimit"],
				Min:   "0",
				Hint:  "0 または未入力で無制限",
				Error: errs["usageLimit"],
			},
			{
				Name:  "perCustomerLimit",
				Label: "顧客あたり上限",
				Type:  "number",
				Value: state.Values["perCustomerLimit"],
				Min:   "0",
				Hint:  "0 または未入力で無制限",
				Error: errs["perCustomerLimit"],
			},
			{
				Name:   "budget",
				Label:  "予算上限",
				Type:   "number",
				Value:  state.Values["budget"],
				Prefix: "¥",
				Hint:   "未入力で制限なし",
				Error:  errs["budget"],
			},
		},
	}
}

func promotionStatusOptions(selected string) []promotionstpl.ModalOption {
	statuses := []adminpromotions.Status{
		adminpromotions.StatusDraft,
		adminpromotions.StatusScheduled,
		adminpromotions.StatusActive,
		adminpromotions.StatusPaused,
	}
	options := make([]promotionstpl.ModalOption, 0, len(statuses))
	for _, status := range statuses {
		options = append(options, promotionstpl.ModalOption{
			Value:    string(status),
			Label:    promotionStatusLabel(status),
			Selected: string(status) == strings.TrimSpace(selected),
		})
	}
	return options
}

func promotionTypeOptions(selected string) []promotionstpl.ModalOption {
	types := []adminpromotions.Type{
		adminpromotions.TypePercentage,
		adminpromotions.TypeFixedAmount,
		adminpromotions.TypeBundle,
		adminpromotions.TypeShipping,
	}
	options := make([]promotionstpl.ModalOption, 0, len(types))
	for _, kind := range types {
		options = append(options, promotionstpl.ModalOption{
			Value:    string(kind),
			Label:    promotionTypeLabel(kind),
			Selected: string(kind) == strings.TrimSpace(selected),
		})
	}
	return options
}

func promotionChannelOptions(selected []string) []promotionstpl.ModalOption {
	selectedSet := make(map[string]struct{}, len(selected))
	for _, value := range selected {
		selectedSet[strings.TrimSpace(value)] = struct{}{}
	}
	channels := []adminpromotions.Channel{
		adminpromotions.ChannelOnlineStore,
		adminpromotions.ChannelRetail,
		adminpromotions.ChannelApp,
	}
	options := make([]promotionstpl.ModalOption, 0, len(channels))
	for _, ch := range channels {
		value := string(ch)
		_, ok := selectedSet[value]
		options = append(options, promotionstpl.ModalOption{
			Value:    value,
			Label:    promotionChannelLabel(ch),
			Selected: ok,
		})
	}
	return options
}

func promotionShippingOptions(selected string) []promotionstpl.ModalOption {
	options := []promotionstpl.ModalOption{
		{Value: shippingOptionFree, Label: "送料を無料にする", Selected: strings.TrimSpace(selected) == shippingOptionFree},
		{Value: shippingOptionFlat, Label: "送料を定額割引", Selected: strings.TrimSpace(selected) == shippingOptionFlat},
	}
	if strings.TrimSpace(selected) == "" {
		options[0].Selected = true
	}
	return options
}

func promotionCurrencyOptions(selected string) []promotionstpl.ModalOption {
	currencies := []string{"JPY", "USD", "EUR"}
	options := make([]promotionstpl.ModalOption, 0, len(currencies))
	for _, code := range currencies {
		options = append(options, promotionstpl.ModalOption{
			Value:    code,
			Label:    code,
			Selected: strings.EqualFold(code, selected),
		})
	}
	return options
}

func promotionSegmentOptions(selected string) []promotionstpl.ModalOption {
	segments := []struct {
		Key   string
		Label string
		Desc  string
	}{
		{"vip_retention", "既存顧客 (VIP)", "LTV上位顧客への優待"},
		{"ring_intent", "リング検討層", "リングカテゴリ閲覧ユーザー"},
		{"app_members", "アプリ会員", "アプリ登録済みでPush許諾"},
		{"new_customers", "新規顧客", "初回購入予定の顧客"},
	}
	options := make([]promotionstpl.ModalOption, 0, len(segments))
	for _, segment := range segments {
		options = append(options, promotionstpl.ModalOption{
			Value:       segment.Key,
			Label:       segment.Label,
			Description: segment.Desc,
			Selected:    strings.TrimSpace(selected) == segment.Key,
		})
	}
	return options
}

func promotionEligibilityOptions(selected []string) []promotionstpl.ModalOption {
	set := make(map[string]struct{}, len(selected))
	for _, value := range selected {
		set[strings.TrimSpace(value)] = struct{}{}
	}
	options := []promotionstpl.ModalOption{
		{Value: "new_customers", Label: "新規顧客", Description: "初回購入ユーザーへの限定", Selected: has(set, "new_customers")},
		{Value: "loyal_members", Label: "ロイヤル会員", Description: "会員ランク Gold 以上", Selected: has(set, "loyal_members")},
		{Value: "abandoned_cart", Label: "カゴ落ち", Description: "直近7日でカゴ落ち", Selected: has(set, "abandoned_cart")},
		{Value: "app_push", Label: "アプリ通知許諾", Description: "Push 通知ONユーザー", Selected: has(set, "app_push")},
	}
	return options
}

func promotionStatusLabel(status adminpromotions.Status) string {
	switch status {
	case adminpromotions.StatusActive:
		return "アクティブ"
	case adminpromotions.StatusScheduled:
		return "公開予定"
	case adminpromotions.StatusPaused:
		return "一時停止"
	case adminpromotions.StatusDraft:
		return "下書き"
	case adminpromotions.StatusExpired:
		return "終了"
	default:
		return string(status)
	}
}

func promotionTypeLabel(kind adminpromotions.Type) string {
	switch kind {
	case adminpromotions.TypePercentage:
		return "割引(%)"
	case adminpromotions.TypeFixedAmount:
		return "固定額割引"
	case adminpromotions.TypeBundle:
		return "セット/バンドル"
	case adminpromotions.TypeShipping:
		return "配送特典"
	default:
		return string(kind)
	}
}

func promotionChannelLabel(ch adminpromotions.Channel) string {
	switch ch {
	case adminpromotions.ChannelOnlineStore:
		return "オンラインストア"
	case adminpromotions.ChannelRetail:
		return "店舗"
	case adminpromotions.ChannelApp:
		return "アプリ"
	default:
		return string(ch)
	}
}

func has(set map[string]struct{}, key string) bool {
	_, ok := set[key]
	return ok
}

func coalesce(values ...string) string {
	for _, value := range values {
		if trimmed := strings.TrimSpace(value); trimmed != "" {
			return trimmed
		}
	}
	return ""
}

func defaultPromotionFormState() promotionFormState {
	now := time.Now().In(defaultTimezone)
	values := map[string]string{
		"name":             "",
		"code":             "",
		"description":      "",
		"status":           string(adminpromotions.StatusDraft),
		"type":             string(adminpromotions.TypePercentage),
		"percentage":       "10",
		"amount":           "",
		"currency":         "JPY",
		"bundleBuy":        "2",
		"bundleGet":        "1",
		"bundleDiscount":   "100",
		"shippingOption":   shippingOptionFree,
		"shippingAmount":   "0",
		"shippingCurrency": "JPY",
		"segment":          "vip_retention",
		"minOrder":         "",
		"startDate":        now.Format("2006-01-02"),
		"startTime":        "09:00",
		"endDate":          "",
		"endTime":          "",
		"usageLimit":       "",
		"perCustomerLimit": "",
		"budget":           "",
		"version":          "",
	}
	multi := map[string][]string{
		"channels":    {string(adminpromotions.ChannelOnlineStore)},
		"eligibility": {},
	}
	return promotionFormState{Values: values, Multi: multi}
}

func promotionValuesFromDetail(detail adminpromotions.PromotionDetail) promotionFormState {
	state := defaultPromotionFormState()
	promo := detail.Promotion
	state.Values["name"] = promo.Name
	state.Values["code"] = promo.Code
	state.Values["description"] = promo.Description
	state.Values["status"] = string(promo.Status)
	state.Values["type"] = string(promo.Type)
	state.Values["percentage"] = formatFloat(promo.DiscountPercent)
	state.Values["amount"] = formatInt(promo.DiscountAmountMinor)
	state.Values["currency"] = coalesce(promo.DiscountCurrency, "JPY")
	state.Values["bundleBuy"] = formatInt(int64(promo.BundleBuyQty))
	state.Values["bundleGet"] = formatInt(int64(promo.BundleGetQty))
	state.Values["bundleDiscount"] = formatFloat(promo.BundleDiscountPercent)
	state.Values["shippingOption"] = coalesce(promo.ShippingOption, shippingOptionFree)
	state.Values["shippingAmount"] = formatInt(promo.ShippingAmountMinor)
	state.Values["shippingCurrency"] = coalesce(promo.ShippingCurrency, "JPY")
	state.Values["segment"] = coalesce(promo.Segment.Key, state.Values["segment"])
	state.Values["minOrder"] = formatInt(promo.MinOrderAmountMinor)
	state.Values["usageLimit"] = formatInt(int64(promo.UsageLimitTotal))
	state.Values["perCustomerLimit"] = formatInt(int64(promo.UsageLimitPerCustomer))
	state.Values["budget"] = formatInt(promo.BudgetMinor)
	state.Values["version"] = promo.Version
	if promo.StartAt != nil {
		state.Values["startDate"] = promo.StartAt.In(defaultTimezone).Format("2006-01-02")
		state.Values["startTime"] = promo.StartAt.In(defaultTimezone).Format("15:04")
	}
	if promo.EndAt != nil {
		state.Values["endDate"] = promo.EndAt.In(defaultTimezone).Format("2006-01-02")
		state.Values["endTime"] = promo.EndAt.In(defaultTimezone).Format("15:04")
	}
	channels := make([]string, 0, len(promo.Channels))
	for _, ch := range promo.Channels {
		channels = append(channels, string(ch))
	}
	state.Multi["channels"] = channels
	state.Multi["eligibility"] = append([]string(nil), promo.EligibilityRules...)
	return state
}

func promotionFormValues(form url.Values) promotionFormState {
	state := defaultPromotionFormState()
	for key := range state.Values {
		state.Values[key] = strings.TrimSpace(form.Get(key))
	}
	state.Multi["channels"] = cloneValues(form["channels"])
	state.Multi["eligibility"] = cloneValues(form["eligibility"])
	return state
}

func cloneValues(values []string) []string {
	if len(values) == 0 {
		return nil
	}
	out := make([]string, 0, len(values))
	for _, value := range values {
		if trimmed := strings.TrimSpace(value); trimmed != "" {
			out = append(out, trimmed)
		}
	}
	return out
}

func formatFloat(value float64) string {
	if value == 0 {
		return ""
	}
	return strings.TrimRight(strings.TrimRight(fmt.Sprintf("%.2f", value), "0"), ".")
}

func formatInt(value int64) string {
	if value == 0 {
		return ""
	}
	return strconv.FormatInt(value, 10)
}

func parsePromotionForm(form url.Values, requireVersion bool) (adminpromotions.PromotionInput, promotionFormState, map[string]string) {
	state := promotionFormValues(form)
	errs := make(map[string]string)
	input := adminpromotions.PromotionInput{}

	read := func(key string) string { return strings.TrimSpace(form.Get(key)) }

	input.Name = read("name")
	if input.Name == "" {
		errs["name"] = "名称を入力してください。"
	}

	input.Code = strings.ToUpper(read("code"))
	if input.Code == "" {
		errs["code"] = "コードを入力してください。"
	} else if !codePattern.MatchString(input.Code) {
		errs["code"] = "英数字とハイフンのみ使用できます。"
	}

	input.Description = read("description")

	status, ok := parsePromotionStatus(read("status"))
	if !ok {
		errs["status"] = "有効なステータスを選択してください。"
	}
	input.Status = status

	typeValue, ok := parsePromotionType(read("type"))
	if !ok {
		errs["type"] = "割引タイプを選択してください。"
	}
	input.Type = typeValue

	channels, channelErr := parseChannels(form["channels"])
	if channelErr != "" {
		errs["channels"] = channelErr
	}
	input.Channels = channels

	segment := read("segment")
	if segment == "" {
		errs["segment"] = "対象セグメントを選択してください。"
	}
	input.SegmentKey = segment

	input.EligibilityRules = cloneValues(form["eligibility"])

	switch input.Type {
	case adminpromotions.TypePercentage:
		value, err := parsePromotionPercentage(read("percentage"))
		if err != nil {
			errs["percentage"] = err.Error()
		} else {
			input.DiscountPercent = value
		}
	case adminpromotions.TypeFixedAmount:
		amount, err := parsePromotionMoney(read("amount"))
		if err != nil {
			errs["amount"] = err.Error()
		} else {
			input.DiscountAmountMinor = amount
		}
		currency := read("currency")
		if currency == "" {
			errs["currency"] = "通貨を選択してください。"
		}
		input.DiscountCurrency = currency
	case adminpromotions.TypeBundle:
		if value, err := parsePromotionPositiveInt(read("bundleBuy")); err != nil {
			errs["bundleBuy"] = err.Error()
		} else {
			input.BundleBuyQty = int(value)
		}
		if value, err := parsePromotionPositiveInt(read("bundleGet")); err != nil {
			errs["bundleGet"] = err.Error()
		} else {
			input.BundleGetQty = int(value)
		}
		if value, err := parsePromotionPercentage(read("bundleDiscount")); err != nil {
			errs["bundleDiscount"] = err.Error()
		} else {
			input.BundleDiscountPercent = value
		}
	case adminpromotions.TypeShipping:
		option := read("shippingOption")
		if option != shippingOptionFree && option != shippingOptionFlat {
			errs["shippingOption"] = "配送特典を選択してください。"
		}
		input.ShippingOption = option
		if option == shippingOptionFlat {
			amount, err := parsePromotionMoney(read("shippingAmount"))
			if err != nil {
				errs["shippingAmount"] = err.Error()
			} else {
				input.ShippingAmountMinor = amount
			}
			currency := read("shippingCurrency")
			if currency == "" {
				errs["shippingCurrency"] = "通貨を選択してください。"
			}
			input.ShippingCurrency = currency
		}
	}

	if value, err := parsePromotionNonNegativeMoney(read("minOrder")); err != nil {
		errs["minOrder"] = err.Error()
	} else {
		input.MinOrderAmountMinor = value
	}

	input.EligibilityRules = cloneValues(form["eligibility"])

	start, startErr := parsePromotionDateTime(read("startDate"), read("startTime"))
	if startErr != nil {
		errs["startDate"] = startErr.Error()
	} else {
		input.StartAt = start
	}

	endDate := read("endDate")
	endTime := read("endTime")
	if endDate != "" || endTime != "" {
		end, err := parsePromotionDateTime(endDate, endTime)
		if err != nil {
			errs["endDate"] = err.Error()
		} else {
			if startErr == nil && !end.After(input.StartAt) {
				errs["endDate"] = "終了日時は開始より後に設定してください。"
			} else {
				input.EndAt = &end
			}
		}
	}

	if value, err := parsePromotionNonNegativeInt(read("usageLimit")); err != nil {
		errs["usageLimit"] = err.Error()
	} else {
		input.UsageLimitTotal = int(value)
	}
	if value, err := parsePromotionNonNegativeInt(read("perCustomerLimit")); err != nil {
		errs["perCustomerLimit"] = err.Error()
	} else {
		input.UsageLimitPerCustomer = int(value)
	}
	if input.UsageLimitPerCustomer > 0 && input.UsageLimitTotal > 0 && input.UsageLimitPerCustomer > input.UsageLimitTotal {
		errs["perCustomerLimit"] = "顧客あたり上限は全体上限以下に設定してください。"
	}

	if value, err := parsePromotionNonNegativeMoney(read("budget")); err != nil {
		errs["budget"] = err.Error()
	} else {
		input.BudgetMinor = value
	}

	if requireVersion {
		version := read("version")
		if version == "" {
			errs["version"] = "最新の情報を取得してから再度実行してください。"
		}
		input.Version = version
	} else {
		input.Version = read("version")
	}

	state.Values["code"] = input.Code
	state.Values["status"] = string(input.Status)
	state.Values["type"] = string(input.Type)
	state.Values["currency"] = input.DiscountCurrency
	state.Values["shippingOption"] = input.ShippingOption
	state.Values["shippingCurrency"] = input.ShippingCurrency
	if input.DiscountPercent > 0 {
		state.Values["percentage"] = formatFloat(input.DiscountPercent)
	}
	if input.DiscountAmountMinor > 0 {
		state.Values["amount"] = formatInt(input.DiscountAmountMinor)
	}
	if input.BundleBuyQty > 0 {
		state.Values["bundleBuy"] = strconv.Itoa(input.BundleBuyQty)
	}
	if input.BundleGetQty > 0 {
		state.Values["bundleGet"] = strconv.Itoa(input.BundleGetQty)
	}
	if input.BundleDiscountPercent > 0 {
		state.Values["bundleDiscount"] = formatFloat(input.BundleDiscountPercent)
	}
	if input.ShippingAmountMinor > 0 {
		state.Values["shippingAmount"] = formatInt(input.ShippingAmountMinor)
	}
	state.Values["segment"] = input.SegmentKey
	if input.MinOrderAmountMinor > 0 {
		state.Values["minOrder"] = formatInt(input.MinOrderAmountMinor)
	}
	if !input.StartAt.IsZero() {
		state.Values["startDate"] = input.StartAt.In(defaultTimezone).Format("2006-01-02")
		state.Values["startTime"] = input.StartAt.In(defaultTimezone).Format("15:04")
	}
	if input.EndAt != nil {
		state.Values["endDate"] = input.EndAt.In(defaultTimezone).Format("2006-01-02")
		state.Values["endTime"] = input.EndAt.In(defaultTimezone).Format("15:04")
	}
	if input.UsageLimitTotal > 0 {
		state.Values["usageLimit"] = strconv.Itoa(input.UsageLimitTotal)
	}
	if input.UsageLimitPerCustomer > 0 {
		state.Values["perCustomerLimit"] = strconv.Itoa(input.UsageLimitPerCustomer)
	}
	if input.BudgetMinor > 0 {
		state.Values["budget"] = formatInt(input.BudgetMinor)
	}
	state.Multi["channels"] = channelsToStrings(input.Channels)
	state.Multi["eligibility"] = append([]string(nil), input.EligibilityRules...)

	return input, state, errs
}

func channelsToStrings(channels []adminpromotions.Channel) []string {
	if len(channels) == 0 {
		return nil
	}
	out := make([]string, 0, len(channels))
	for _, ch := range channels {
		out = append(out, string(ch))
	}
	return out
}

var codePattern = regexp.MustCompile(`^[A-Z0-9\-]{4,64}$`)

func parsePromotionStatus(raw string) (adminpromotions.Status, bool) {
	switch strings.ToLower(strings.TrimSpace(raw)) {
	case string(adminpromotions.StatusDraft):
		return adminpromotions.StatusDraft, true
	case string(adminpromotions.StatusScheduled):
		return adminpromotions.StatusScheduled, true
	case string(adminpromotions.StatusActive):
		return adminpromotions.StatusActive, true
	case string(adminpromotions.StatusPaused):
		return adminpromotions.StatusPaused, true
	default:
		return adminpromotions.Status(""), false
	}
}

func parsePromotionType(raw string) (adminpromotions.Type, bool) {
	switch strings.ToLower(strings.TrimSpace(raw)) {
	case string(adminpromotions.TypePercentage):
		return adminpromotions.TypePercentage, true
	case string(adminpromotions.TypeFixedAmount):
		return adminpromotions.TypeFixedAmount, true
	case string(adminpromotions.TypeBundle):
		return adminpromotions.TypeBundle, true
	case string(adminpromotions.TypeShipping):
		return adminpromotions.TypeShipping, true
	default:
		return adminpromotions.Type(""), false
	}
}

func parseChannels(raw []string) ([]adminpromotions.Channel, string) {
	if len(raw) == 0 {
		return nil, "チャネルを選択してください。"
	}
	channels := make([]adminpromotions.Channel, 0, len(raw))
	for _, value := range raw {
		switch strings.ToLower(strings.TrimSpace(value)) {
		case string(adminpromotions.ChannelOnlineStore):
			channels = append(channels, adminpromotions.ChannelOnlineStore)
		case string(adminpromotions.ChannelRetail):
			channels = append(channels, adminpromotions.ChannelRetail)
		case string(adminpromotions.ChannelApp):
			channels = append(channels, adminpromotions.ChannelApp)
		default:
			return nil, "有効なチャネルを選択してください。"
		}
	}
	return channels, ""
}

func parsePromotionPercentage(raw string) (float64, error) {
	value := strings.TrimSpace(raw)
	if value == "" {
		return 0, fmt.Errorf("値を入力してください。")
	}
	f, err := strconv.ParseFloat(value, 64)
	if err != nil {
		return 0, fmt.Errorf("数値で入力してください。")
	}
	if f <= 0 || f > 100 {
		return 0, fmt.Errorf("1〜100の範囲で入力してください。")
	}
	return f, nil
}

func parsePromotionMoney(raw string) (int64, error) {
	value := strings.TrimSpace(raw)
	if value == "" {
		return 0, fmt.Errorf("金額を入力してください。")
	}
	f, err := strconv.ParseFloat(value, 64)
	if err != nil {
		return 0, fmt.Errorf("金額は数値で入力してください。")
	}
	if f <= 0 {
		return 0, fmt.Errorf("0より大きい金額を入力してください。")
	}
	return int64(f + 0.5), nil
}

func parsePromotionNonNegativeMoney(raw string) (int64, error) {
	value := strings.TrimSpace(raw)
	if value == "" {
		return 0, nil
	}
	f, err := strconv.ParseFloat(value, 64)
	if err != nil {
		return 0, fmt.Errorf("金額は数値で入力してください。")
	}
	if f < 0 {
		return 0, fmt.Errorf("0以上で入力してください。")
	}
	return int64(f + 0.5), nil
}

func parsePromotionPositiveInt(raw string) (int64, error) {
	value := strings.TrimSpace(raw)
	if value == "" {
		return 0, fmt.Errorf("値を入力してください。")
	}
	i, err := strconv.ParseInt(value, 10, 64)
	if err != nil {
		return 0, fmt.Errorf("数値で入力してください。")
	}
	if i <= 0 {
		return 0, fmt.Errorf("1以上で入力してください。")
	}
	return i, nil
}

func parsePromotionNonNegativeInt(raw string) (int64, error) {
	value := strings.TrimSpace(raw)
	if value == "" {
		return 0, nil
	}
	i, err := strconv.ParseInt(value, 10, 64)
	if err != nil {
		return 0, fmt.Errorf("数値で入力してください。")
	}
	if i < 0 {
		return 0, fmt.Errorf("0以上で入力してください。")
	}
	return i, nil
}

func parsePromotionDateTime(dateRaw, timeRaw string) (time.Time, error) {
	date := strings.TrimSpace(dateRaw)
	timePart := strings.TrimSpace(timeRaw)
	if date == "" || timePart == "" {
		return time.Time{}, fmt.Errorf("日付と時刻の両方を入力してください。")
	}
	value := fmt.Sprintf("%s %s", date, timePart)
	parsed, err := time.ParseInLocation("2006-01-02 15:04", value, defaultTimezone)
	if err != nil {
		return time.Time{}, fmt.Errorf("正しい日時形式で入力してください。")
	}
	return parsed, nil
}
