package ui

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"strings"

	adminpromotions "finitefield.org/hanko-admin/internal/admin/promotions"
	promotionstpl "finitefield.org/hanko-admin/internal/admin/templates/promotions"
)

type promotionValidationFormState struct {
	PromotionID    string
	Subtotal       string
	Currency       string
	SegmentKey     string
	ItemSKUs       []string
	ItemQuantities []string
	ItemPrices     []string
}

func defaultPromotionValidationState(detail adminpromotions.PromotionDetail) promotionValidationFormState {
	state := promotionValidationFormState{
		PromotionID: detail.Promotion.ID,
		Subtotal:    formatInt(detail.Promotion.MinOrderAmountMinor),
		Currency:    defaultCurrency(detail.Promotion.DiscountCurrency),
		SegmentKey:  strings.TrimSpace(detail.Promotion.Segment.Key),
	}
	state.ensureRows(3)
	return state
}

func promotionValidationStateFromValues(values url.Values) promotionValidationFormState {
	state := promotionValidationFormState{
		PromotionID:    strings.TrimSpace(values.Get("promotionID")),
		Subtotal:       strings.TrimSpace(values.Get("subtotal")),
		Currency:       strings.TrimSpace(values.Get("currency")),
		SegmentKey:     strings.TrimSpace(values.Get("segmentKey")),
		ItemSKUs:       cloneRaw(values["itemSKU"]),
		ItemQuantities: cloneRaw(values["itemQuantity"]),
		ItemPrices:     cloneRaw(values["itemPrice"]),
	}
	state.ensureRows(3)
	return state
}

func cloneRaw(values []string) []string {
	if len(values) == 0 {
		return nil
	}
	out := make([]string, len(values))
	for i, v := range values {
		out[i] = strings.TrimSpace(v)
	}
	return out
}

func (s *promotionValidationFormState) ensureRows(min int) {
	ensure := func(slice []string, min int) []string {
		if slice == nil {
			slice = []string{}
		}
		if len(slice) >= min {
			return slice
		}
		missing := min - len(slice)
		for i := 0; i < missing; i++ {
			slice = append(slice, "")
		}
		return slice
	}
	s.ItemSKUs = ensure(s.ItemSKUs, min)
	s.ItemQuantities = ensure(s.ItemQuantities, min)
	s.ItemPrices = ensure(s.ItemPrices, min)
}

func defaultCurrency(raw string) string {
	value := strings.ToUpper(strings.TrimSpace(raw))
	if value == "" {
		return "JPY"
	}
	return value
}

func parsePromotionValidationForm(form url.Values) (adminpromotions.ValidationRequest, promotionValidationFormState, map[string]string, string) {
	state := promotionValidationStateFromValues(form)
	errs := make(map[string]string)

	req := adminpromotions.ValidationRequest{
		PromotionID: strings.TrimSpace(state.PromotionID),
		Currency:    defaultCurrency(state.Currency),
		SegmentKey:  strings.TrimSpace(state.SegmentKey),
	}

	if req.PromotionID == "" {
		return req, state, map[string]string{"promotionID": "プロモーションが指定されていません。"}, "対象プロモーションが見つかりませんでした。"
	}

	if state.Subtotal != "" {
		subtotal, err := parsePromotionNonNegativeMoney(state.Subtotal)
		if err != nil {
			errs["subtotal"] = err.Error()
		} else {
			req.SubtotalMinor = subtotal
		}
	} else {
		req.SubtotalMinor = 0
	}

	skuValues := form["itemSKU"]
	qtyValues := form["itemQuantity"]
	priceValues := form["itemPrice"]
	maxLen := maxLen3(len(skuValues), len(qtyValues), len(priceValues))
	if maxLen < 3 {
		maxLen = 3
	}
	state.ensureRows(maxLen)

	items := make([]adminpromotions.ValidationRequestItem, 0, maxLen)
	for idx := 0; idx < maxLen; idx++ {
		sku := trimmedValue(skuValues, idx)
		qtyRaw := trimmedValue(qtyValues, idx)
		priceRaw := trimmedValue(priceValues, idx)

		if sku == "" && qtyRaw == "" && priceRaw == "" {
			continue
		}

		rowHasError := false
		if sku == "" {
			errs[itemFieldKey("sku", idx)] = "SKUを入力してください。"
			rowHasError = true
		}

		var qty int64
		if qtyRaw == "" {
			errs[itemFieldKey("quantity", idx)] = "数量を入力してください。"
			rowHasError = true
		} else {
			value, err := parsePromotionPositiveInt(qtyRaw)
			if err != nil {
				errs[itemFieldKey("quantity", idx)] = err.Error()
				rowHasError = true
			} else {
				qty = value
			}
		}

		var price int64
		if priceRaw == "" {
			errs[itemFieldKey("price", idx)] = "単価を入力してください。"
			rowHasError = true
		} else {
			value, err := parsePromotionNonNegativeMoney(priceRaw)
			if err != nil {
				errs[itemFieldKey("price", idx)] = err.Error()
				rowHasError = true
			} else {
				price = value
			}
		}

		if rowHasError {
			continue
		}

		items = append(items, adminpromotions.ValidationRequestItem{
			SKU:        sku,
			Quantity:   int(qty),
			PriceMinor: price,
		})
	}

	req.Items = items

	if len(errs) > 0 {
		return req, state, errs, "入力内容を確認してください。"
	}

	return req, state, nil, ""
}

func trimmedValue(values []string, idx int) string {
	if idx < 0 || idx >= len(values) {
		return ""
	}
	return strings.TrimSpace(values[idx])
}

func maxLen3(a, b, c int) int {
	if a < b {
		a = b
	}
	if a < c {
		a = c
	}
	return a
}

func itemFieldKey(kind string, idx int) string {
	return fmt.Sprintf("item_%s_%d", kind, idx)
}

func buildPromotionValidationModal(basePath string, detail adminpromotions.PromotionDetail, csrf string, state promotionValidationFormState, fieldErrors map[string]string, generalErr string, result *adminpromotions.ValidationResult) promotionstpl.ValidationModalData {
	if state.Currency == "" {
		state.Currency = defaultCurrency("")
	}
	if fieldErrors == nil {
		fieldErrors = map[string]string{}
	}
	state.ensureRows(3)

	form := promotionstpl.ValidationFormState{
		PromotionID:    state.PromotionID,
		Subtotal:       state.Subtotal,
		Currency:       state.Currency,
		SegmentKey:     state.SegmentKey,
		ItemSKUs:       append([]string(nil), state.ItemSKUs...),
		ItemQuantities: append([]string(nil), state.ItemQuantities...),
		ItemPrices:     append([]string(nil), state.ItemPrices...),
	}

	data := promotionstpl.ValidationModalData{
		Title:          "プロモーションドライラン検証",
		PromotionLabel: detail.Promotion.Name,
		PromotionCode:  detail.Promotion.Code,
		ActionURL:      joinBasePath(basePath, "/promotions/modal/validate"),
		Method:         http.MethodPost,
		CSRFToken:      csrf,
		Error:          strings.TrimSpace(generalErr),
		FieldErrors:    fieldErrors,
		Form:           form,
	}

	if result != nil {
		view := buildValidationResultView(*result)
		data.Result = &view
	}

	return data
}

func buildValidationResultView(result adminpromotions.ValidationResult) promotionstpl.ValidationResultView {
	ruleViews := make([]promotionstpl.ValidationRuleView, 0, len(result.Rules))
	blockers := make([]string, 0, len(result.Rules))
	for _, rule := range result.Rules {
		ruleViews = append(ruleViews, promotionstpl.ValidationRuleView{
			Key:      rule.Key,
			Label:    rule.Label,
			Passed:   rule.Passed,
			Blocking: rule.Blocking,
			Severity: rule.Severity,
			Message:  rule.Message,
		})
		if rule.Blocking && !rule.Passed {
			blockers = append(blockers, rule.Message)
		}
	}

	rawJSON := string(result.Raw)
	if formatted, err := indentJSON(result.Raw); err == nil {
		rawJSON = formatted
	}

	return promotionstpl.ValidationResultView{
		Eligible:   result.Eligible,
		Summary:    result.Summary,
		ExecutedAt: result.ExecutedAt,
		Rules:      ruleViews,
		Blockers:   blockers,
		RawJSON:    rawJSON,
	}
}

func indentJSON(raw json.RawMessage) (string, error) {
	if len(raw) == 0 {
		return "{}", nil
	}
	var buf bytes.Buffer
	if err := json.Indent(&buf, raw, "", "  "); err != nil {
		return "", err
	}
	return buf.String(), nil
}
