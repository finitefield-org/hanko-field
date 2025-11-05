package ui

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"

	"github.com/a-h/templ"
	"github.com/go-chi/chi/v5"

	adminfinance "finitefield.org/hanko-admin/internal/admin/finance"
	custommw "finitefield.org/hanko-admin/internal/admin/httpserver/middleware"
	financetpl "finitefield.org/hanko-admin/internal/admin/templates/finance"
)

type taxSettingsRequest struct {
	query adminfinance.JurisdictionsQuery
	state financetpl.QueryState
}

func parseTaxSettingsRequest(r *http.Request) taxSettingsRequest {
	values := r.URL.Query()
	region := strings.TrimSpace(values.Get("region"))
	country := strings.TrimSpace(values.Get("country"))
	search := strings.TrimSpace(values.Get("search"))
	selected := strings.TrimSpace(values.Get("selected"))
	includeSoon := parseCheckbox(values.Get("includeSoon"))

	state := financetpl.QueryState{
		Region:      region,
		Country:     country,
		Search:      search,
		SelectedID:  selected,
		IncludeSoon: includeSoon,
	}
	state.RawQuery = state.Encode()

	return taxSettingsRequest{
		query: adminfinance.JurisdictionsQuery{
			Region:      region,
			Country:     country,
			Search:      search,
			SelectedID:  selected,
			IncludeSoon: includeSoon,
		},
		state: state,
	}
}

func (req *taxSettingsRequest) setSelected(id string) {
	req.state.SelectedID = strings.TrimSpace(id)
	req.query.SelectedID = req.state.SelectedID
	req.state.RawQuery = req.state.Encode()
}

func (req *taxSettingsRequest) clearSelection() {
	req.state.SelectedID = ""
	req.query.SelectedID = ""
	req.state.RawQuery = req.state.Encode()
}

func (req *taxSettingsRequest) canonical(basePath string) string {
	base := joinBasePath(basePath, "/finance/taxes")
	raw := strings.TrimSpace(req.state.Encode())
	if raw == "" {
		return base
	}
	return fmt.Sprintf("%s?%s", base, raw)
}

func (h *Handlers) ReconciliationPage(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	dashboard, err := h.finance.ReconciliationDashboard(ctx, user.Token)
	if err != nil {
		log.Printf("finance: reconciliation dashboard fetch failed: %v", err)
		dashboard = adminfinance.ReconciliationDashboard{}
	}

	basePath := custommw.BasePathFromContext(ctx)
	triggerURL := joinBasePath(basePath, "/finance/reconciliation:trigger")
	data := financetpl.BuildReconciliationPageData(basePath, dashboard, triggerURL, custommw.CSRFTokenFromContext(ctx), nil)
	templ.Handler(financetpl.ReconciliationPage(data)).ServeHTTP(w, r)
}

func (h *Handlers) ReconciliationTrigger(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	dashboard, err := h.finance.TriggerReconciliation(ctx, user.Token)
	if err != nil {
		log.Printf("finance: reconciliation trigger failed: %v", err)
		http.Error(w, "リコンシリエーションの実行に失敗しました。時間を置いて再度お試しください。", http.StatusBadGateway)
		return
	}

	basePath := custommw.BasePathFromContext(ctx)
	triggerURL := joinBasePath(basePath, "/finance/reconciliation:trigger")
	snackbar := &financetpl.SnackbarView{Message: "リコンシリエーションジョブを実行しました。", Tone: "success"}
	if dashboard.Summary.TriggerDisabled {
		snackbar = &financetpl.SnackbarView{Message: "リコンシリエーションは現在ロックされています。", Tone: "warning"}
	}

	data := financetpl.BuildReconciliationPageData(basePath, dashboard, triggerURL, custommw.CSRFTokenFromContext(ctx), snackbar)
	templ.Handler(financetpl.ReconciliationRoot(data)).ServeHTTP(w, r)
}

func (h *Handlers) TaxSettingsPage(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	req := parseTaxSettingsRequest(r)
	basePath := custommw.BasePathFromContext(ctx)

	result, err := h.finance.Jurisdictions(ctx, user.Token, req.query)
	if err != nil {
		log.Printf("finance: list jurisdictions failed: %v", err)
		result = adminfinance.JurisdictionsResult{}
	}

	var detail *adminfinance.JurisdictionDetail
	if req.state.SelectedID == "" && len(result.Jurisdictions) > 0 {
		req.setSelected(result.Jurisdictions[0].ID)
	}

	if req.state.SelectedID != "" {
		if d, derr := h.finance.JurisdictionDetail(ctx, user.Token, req.state.SelectedID); derr == nil {
			detail = &d
		} else {
			if !errors.Is(derr, adminfinance.ErrJurisdictionNotFound) {
				log.Printf("finance: jurisdiction detail %s failed: %v", req.state.SelectedID, derr)
			}
			req.clearSelection()
		}
	}

	page := financetpl.BuildPageData(basePath, result, detail, req.state, nil)
	templ.Handler(financetpl.Index(page)).ServeHTTP(w, r)
}

func (h *Handlers) TaxSettingsGrid(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	req := parseTaxSettingsRequest(r)
	h.renderTaxSettingsGrid(ctx, w, r, user.Token, req, nil, nil, false)
}

func (h *Handlers) TaxRuleNewModal(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	jurisdictionID := strings.TrimSpace(chi.URLParam(r, "jurisdictionID"))
	if jurisdictionID == "" {
		http.Error(w, "管轄IDが不正です。", http.StatusBadRequest)
		return
	}

	detail, err := h.finance.JurisdictionDetail(ctx, user.Token, jurisdictionID)
	if err != nil {
		if errors.Is(err, adminfinance.ErrJurisdictionNotFound) {
			http.NotFound(w, r)
			return
		}
		http.Error(w, "税率の読み込みに失敗しました。", http.StatusBadGateway)
		return
	}

	req := parseTaxSettingsRequest(r)
	basePath := custommw.BasePathFromContext(ctx)
	state := financetpl.DefaultRuleFormState(detail, nil)
	form := financetpl.BuildRuleFormData(basePath, detail, nil, custommw.CSRFTokenFromContext(ctx), state, req.state.RawQuery, nil, "")
	templ.Handler(financetpl.RuleFormModal(form)).ServeHTTP(w, r)
}

func (h *Handlers) TaxRuleEditModal(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	jurisdictionID := strings.TrimSpace(chi.URLParam(r, "jurisdictionID"))
	ruleID := strings.TrimSpace(r.URL.Query().Get("rule"))
	if jurisdictionID == "" || ruleID == "" {
		http.Error(w, "リクエストが不正です。", http.StatusBadRequest)
		return
	}

	detail, err := h.finance.JurisdictionDetail(ctx, user.Token, jurisdictionID)
	if err != nil {
		if errors.Is(err, adminfinance.ErrJurisdictionNotFound) {
			http.NotFound(w, r)
			return
		}
		http.Error(w, "税率の読み込みに失敗しました。", http.StatusBadGateway)
		return
	}

	var target *adminfinance.TaxRule
	for idx := range detail.Rules {
		if detail.Rules[idx].ID == ruleID {
			rule := detail.Rules[idx]
			target = &rule
			break
		}
	}
	if target == nil {
		http.NotFound(w, r)
		return
	}

	req := parseTaxSettingsRequest(r)
	basePath := custommw.BasePathFromContext(ctx)
	state := financetpl.DefaultRuleFormState(detail, target)
	form := financetpl.BuildRuleFormData(basePath, detail, target, custommw.CSRFTokenFromContext(ctx), state, req.state.RawQuery, nil, "")
	templ.Handler(financetpl.RuleFormModal(form)).ServeHTTP(w, r)
}

func (h *Handlers) TaxRuleDeleteModal(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	jurisdictionID := strings.TrimSpace(chi.URLParam(r, "jurisdictionID"))
	ruleID := strings.TrimSpace(r.URL.Query().Get("rule"))
	if jurisdictionID == "" || ruleID == "" {
		http.Error(w, "リクエストが不正です。", http.StatusBadRequest)
		return
	}

	detail, err := h.finance.JurisdictionDetail(ctx, user.Token, jurisdictionID)
	if err != nil {
		if errors.Is(err, adminfinance.ErrJurisdictionNotFound) {
			http.NotFound(w, r)
			return
		}
		http.Error(w, "税率の読み込みに失敗しました。", http.StatusBadGateway)
		return
	}

	var target *adminfinance.TaxRule
	for idx := range detail.Rules {
		if detail.Rules[idx].ID == ruleID {
			rule := detail.Rules[idx]
			target = &rule
			break
		}
	}
	if target == nil {
		http.NotFound(w, r)
		return
	}

	req := parseTaxSettingsRequest(r)
	basePath := custommw.BasePathFromContext(ctx)
	modal := financetpl.BuildRuleDeleteModalData(basePath, detail, *target, custommw.CSRFTokenFromContext(ctx), req.state.RawQuery, "")
	templ.Handler(financetpl.RuleDeleteModal(modal)).ServeHTTP(w, r)
}

func (h *Handlers) TaxRuleCreate(w http.ResponseWriter, r *http.Request) {
	h.handleTaxRuleUpsert(w, r, false)
}

func (h *Handlers) TaxRuleUpdate(w http.ResponseWriter, r *http.Request) {
	h.handleTaxRuleUpsert(w, r, true)
}

func (h *Handlers) handleTaxRuleUpsert(w http.ResponseWriter, r *http.Request, isUpdate bool) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	if err := r.ParseForm(); err != nil {
		http.Error(w, "入力の解析に失敗しました。", http.StatusBadRequest)
		return
	}

	jurisdictionID := strings.TrimSpace(chi.URLParam(r, "jurisdictionID"))
	if jurisdictionID == "" {
		http.Error(w, "管轄IDが不正です。", http.StatusBadRequest)
		return
	}

	req := parseTaxSettingsRequestFromForm(r)
	basePath := custommw.BasePathFromContext(ctx)

	detail, err := h.finance.JurisdictionDetail(ctx, user.Token, jurisdictionID)
	if err != nil {
		if errors.Is(err, adminfinance.ErrJurisdictionNotFound) {
			http.NotFound(w, r)
			return
		}
		http.Error(w, "税率の取得に失敗しました。", http.StatusBadGateway)
		return
	}

	ruleID := ""
	if isUpdate {
		ruleID = strings.TrimSpace(chi.URLParam(r, "ruleID"))
		if ruleID == "" {
			ruleID = strings.TrimSpace(r.FormValue("ruleID"))
		}
		if ruleID == "" {
			http.Error(w, "ルールIDが不正です。", http.StatusBadRequest)
			return
		}
	}

	input, formState, fieldErrs, parseErr := buildTaxRuleInput(r, detail, ruleID)
	if parseErr != nil {
		log.Printf("finance: parse tax rule input failed: %v", parseErr)
		form := financetpl.BuildRuleFormData(basePath, detail, findRule(detail, ruleID), custommw.CSRFTokenFromContext(ctx), formState, req.state.RawQuery, fieldErrs, parseErr.Error())
		templ.Handler(financetpl.RuleFormModal(form)).ServeHTTP(w, r)
		return
	}

	updated, err := h.finance.UpsertTaxRule(ctx, user.Token, jurisdictionID, input)
	if err != nil {
		var validationErr *adminfinance.TaxRuleValidationError
		if errors.As(err, &validationErr) {
			form := financetpl.BuildRuleFormData(basePath, detail, findRule(detail, ruleID), custommw.CSRFTokenFromContext(ctx), formState, req.state.RawQuery, mergeFieldErrors(fieldErrs, validationErr.FieldErrors), validationErr.Message)
			templ.Handler(financetpl.RuleFormModal(form)).ServeHTTP(w, r)
			return
		}
		log.Printf("finance: upsert tax rule failed: %v", err)
		form := financetpl.BuildRuleFormData(basePath, detail, findRule(detail, ruleID), custommw.CSRFTokenFromContext(ctx), formState, req.state.RawQuery, fieldErrs, "税率の保存に失敗しました。時間を置いて再度お試しください。")
		templ.Handler(financetpl.RuleFormModal(form)).ServeHTTP(w, r)
		return
	}

	req.setSelected(jurisdictionID)
	snackbar := &financetpl.SnackbarView{Message: "税率を保存しました。", Tone: "success"}
	h.renderTaxSettingsGrid(ctx, w, r, user.Token, req, &updated, snackbar, true)
}

func (h *Handlers) TaxRuleDelete(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	if err := r.ParseForm(); err != nil {
		http.Error(w, "入力の解析に失敗しました。", http.StatusBadRequest)
		return
	}

	jurisdictionID := strings.TrimSpace(chi.URLParam(r, "jurisdictionID"))
	ruleID := strings.TrimSpace(chi.URLParam(r, "ruleID"))
	if jurisdictionID == "" || ruleID == "" {
		http.Error(w, "リクエストが不正です。", http.StatusBadRequest)
		return
	}

	req := parseTaxSettingsRequestFromForm(r)
	basePath := custommw.BasePathFromContext(ctx)

	detail, err := h.finance.JurisdictionDetail(ctx, user.Token, jurisdictionID)
	if err != nil {
		if errors.Is(err, adminfinance.ErrJurisdictionNotFound) {
			http.NotFound(w, r)
			return
		}
		http.Error(w, "税率の取得に失敗しました。", http.StatusBadGateway)
		return
	}

	updated, err := h.finance.DeleteTaxRule(ctx, user.Token, jurisdictionID, ruleID)
	if err != nil {
		var validationErr *adminfinance.TaxRuleValidationError
		if errors.As(err, &validationErr) {
			modal := financetpl.BuildRuleDeleteModalData(basePath, detail, findRuleValue(detail, ruleID), custommw.CSRFTokenFromContext(ctx), req.state.RawQuery, validationErr.Message)
			templ.Handler(financetpl.RuleDeleteModal(modal)).ServeHTTP(w, r)
			return
		}
		log.Printf("finance: delete tax rule failed: %v", err)
		modal := financetpl.BuildRuleDeleteModalData(basePath, detail, findRuleValue(detail, ruleID), custommw.CSRFTokenFromContext(ctx), req.state.RawQuery, "税率の削除に失敗しました。時間を置いて再度お試しください。")
		templ.Handler(financetpl.RuleDeleteModal(modal)).ServeHTTP(w, r)
		return
	}

	req.setSelected(jurisdictionID)
	snackbar := &financetpl.SnackbarView{Message: "税率を削除しました。", Tone: "success"}
	h.renderTaxSettingsGrid(ctx, w, r, user.Token, req, &updated, snackbar, true)
}

func (h *Handlers) renderTaxSettingsGrid(ctx context.Context, w http.ResponseWriter, r *http.Request, token string, req taxSettingsRequest, detail *adminfinance.JurisdictionDetail, snackbar *financetpl.SnackbarView, closeModal bool) {
	result, err := h.finance.Jurisdictions(ctx, token, req.query)
	if err != nil {
		log.Printf("finance: list jurisdictions failed: %v", err)
		result = adminfinance.JurisdictionsResult{}
	}

	if req.state.SelectedID == "" && len(result.Jurisdictions) > 0 {
		req.setSelected(result.Jurisdictions[0].ID)
	}

	if req.state.SelectedID != "" && detail == nil {
		if d, derr := h.finance.JurisdictionDetail(ctx, token, req.state.SelectedID); derr == nil {
			detail = &d
		} else {
			if !errors.Is(derr, adminfinance.ErrJurisdictionNotFound) {
				log.Printf("finance: jurisdiction detail %s failed: %v", req.state.SelectedID, derr)
			}
			req.clearSelection()
			detail = nil
		}
	}

	basePath := custommw.BasePathFromContext(ctx)
	page := financetpl.BuildPageData(basePath, result, detail, req.state, snackbar)
	w.Header().Set("HX-Push-Url", req.canonical(basePath))

	trigger := map[string]any{}
	if closeModal {
		trigger["modal:close"] = true
	}
	if len(trigger) > 0 {
		if payload, err := json.Marshal(trigger); err == nil {
			w.Header().Set("HX-Trigger", string(payload))
		}
	}

	templ.Handler(financetpl.GridWithSnackbar(page.Content, snackbar)).ServeHTTP(w, r)
}

func parseTaxSettingsRequestFromForm(r *http.Request) taxSettingsRequest {
	raw := strings.TrimSpace(r.FormValue("return_query"))
	if raw == "" {
		return parseTaxSettingsRequest(r)
	}
	values, err := url.ParseQuery(raw)
	if err != nil {
		return parseTaxSettingsRequest(r)
	}
	req := taxSettingsRequest{
		query: adminfinance.JurisdictionsQuery{
			Region:      strings.TrimSpace(values.Get("region")),
			Country:     strings.TrimSpace(values.Get("country")),
			Search:      strings.TrimSpace(values.Get("search")),
			SelectedID:  strings.TrimSpace(values.Get("selected")),
			IncludeSoon: parseCheckbox(values.Get("includeSoon")),
		},
	}
	req.state = financetpl.QueryState{
		Region:      req.query.Region,
		Country:     req.query.Country,
		Search:      req.query.Search,
		SelectedID:  req.query.SelectedID,
		IncludeSoon: req.query.IncludeSoon,
	}
	req.state.RawQuery = raw
	return req
}

func buildTaxRuleInput(r *http.Request, detail adminfinance.JurisdictionDetail, ruleID string) (adminfinance.TaxRuleInput, financetpl.RuleFormState, map[string]string, error) {
	state := financetpl.RuleFormState{
		RuleID:               ruleID,
		Label:                strings.TrimSpace(r.FormValue("label")),
		Scope:                strings.TrimSpace(r.FormValue("scope")),
		Type:                 strings.TrimSpace(r.FormValue("type")),
		Rate:                 strings.TrimSpace(r.FormValue("rate")),
		Threshold:            strings.TrimSpace(r.FormValue("threshold")),
		Currency:             detail.Metadata.Currency,
		EffectiveFrom:        strings.TrimSpace(r.FormValue("effective_from")),
		EffectiveTo:          strings.TrimSpace(r.FormValue("effective_to")),
		RegistrationNumber:   strings.TrimSpace(r.FormValue("registration")),
		RequiresRegistration: parseCheckbox(r.FormValue("requires_registration")),
		Default:              parseCheckbox(r.FormValue("default")),
		Notes:                strings.TrimSpace(r.FormValue("notes")),
	}
	if state.Type == "" {
		state.Type = inferRuleType(state.Scope, detail)
	}

	fieldErrs := make(map[string]string)

	if state.Label == "" {
		fieldErrs["label"] = "名称を入力してください。"
	}
	if state.Scope == "" {
		fieldErrs["scope"] = "課税区分を選択してください。"
	}

	var rate float64
	if state.Rate == "" {
		fieldErrs["rate"] = "税率を入力してください。"
	} else {
		val, err := strconv.ParseFloat(state.Rate, 64)
		if err != nil {
			fieldErrs["rate"] = "税率は数値で入力してください。"
		} else {
			rate = val
		}
	}

	var threshold int64
	if state.Threshold != "" {
		val, err := strconv.ParseInt(state.Threshold, 10, 64)
		if err != nil {
			fieldErrs["threshold"] = "閾値は整数で入力してください。"
		} else if val < 0 {
			fieldErrs["threshold"] = "閾値は0以上で入力してください。"
		} else {
			threshold = val
		}
	}

	var effectiveFrom time.Time
	if state.EffectiveFrom == "" {
		fieldErrs["effective_from"] = "適用開始日を入力してください。"
	} else {
		if ts, err := time.Parse("2006-01-02", state.EffectiveFrom); err == nil {
			effectiveFrom = ts
		} else {
			fieldErrs["effective_from"] = "日付形式が不正です。"
		}
	}

	var effectiveTo *time.Time
	if state.EffectiveTo != "" {
		if ts, err := time.Parse("2006-01-02", state.EffectiveTo); err == nil {
			effectiveTo = &ts
		} else {
			fieldErrs["effective_to"] = "日付形式が不正です。"
		}
	}

	notes := make([]string, 0)
	if state.Notes != "" {
		for _, line := range strings.Split(state.Notes, "\n") {
			line = strings.TrimSpace(line)
			if line != "" {
				notes = append(notes, line)
			}
		}
	}

	if len(fieldErrs) > 0 {
		return adminfinance.TaxRuleInput{}, state, fieldErrs, errors.New("validation failed")
	}

	input := adminfinance.TaxRuleInput{
		RuleID:               ruleID,
		Label:                state.Label,
		Scope:                state.Scope,
		Type:                 state.Type,
		RatePercent:          rate,
		ThresholdMinor:       threshold,
		ThresholdCurrency:    state.Currency,
		EffectiveFrom:        effectiveFrom,
		EffectiveTo:          effectiveTo,
		RegistrationNumber:   state.RegistrationNumber,
		RequiresRegistration: state.RequiresRegistration,
		Default:              state.Default,
		Notes:                notes,
	}
	return input, state, fieldErrs, nil
}

func inferRuleType(scope string, detail adminfinance.JurisdictionDetail) string {
	switch strings.ToLower(strings.TrimSpace(scope)) {
	case "state", "local":
		return "sales_tax"
	case "reduced", "standard":
		if strings.Contains(strings.ToLower(detail.Metadata.Region), "欧州") {
			return "vat"
		}
		return "consumption"
	default:
		return "consumption"
	}
}

func findRule(detail adminfinance.JurisdictionDetail, ruleID string) *adminfinance.TaxRule {
	for idx := range detail.Rules {
		if detail.Rules[idx].ID == ruleID {
			rule := detail.Rules[idx]
			return &rule
		}
	}
	return nil
}

func findRuleValue(detail adminfinance.JurisdictionDetail, ruleID string) adminfinance.TaxRule {
	if rule := findRule(detail, ruleID); rule != nil {
		return *rule
	}
	return adminfinance.TaxRule{}
}
