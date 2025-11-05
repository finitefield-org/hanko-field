package handlers

import (
	"context"
	"encoding/csv"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/hanko-field/api/internal/platform/auth"
	"github.com/hanko-field/api/internal/platform/httpx"
	"github.com/hanko-field/api/internal/services"
)

const maxPromotionRequestBody = 256 * 1024

// AdminPromotionHandlers exposes CRUD endpoints for promotions.
type AdminPromotionHandlers struct {
	authn      *auth.Authenticator
	promotions services.PromotionService
}

// NewAdminPromotionHandlers constructs the handler set for admin promotion routes.
func NewAdminPromotionHandlers(authn *auth.Authenticator, promotions services.PromotionService) *AdminPromotionHandlers {
	return &AdminPromotionHandlers{
		authn:      authn,
		promotions: promotions,
	}
}

// Routes registers admin promotion endpoints under /promotions.
func (h *AdminPromotionHandlers) Routes(r chi.Router) {
	if r == nil {
		return
	}
	if h.authn != nil {
		r.Use(h.authn.RequireFirebaseAuth(auth.RoleAdmin))
	}
	r.Post("/promotions:validate", h.validatePromotion)
	r.Route("/promotions", func(rt chi.Router) {
		rt.Get("/", h.listPromotions)
		rt.Get("/{promotionID}/usages", h.listPromotionUsage)
		rt.Post("/", h.createPromotion)
		rt.Put("/{promotionID}", h.updatePromotion)
		rt.Delete("/{promotionID}", h.deletePromotion)
	})
}

func (h *AdminPromotionHandlers) listPromotions(w http.ResponseWriter, r *http.Request) {
	if h.promotions == nil {
		httpx.WriteError(r.Context(), w, httpx.NewError("service_unavailable", "promotion service unavailable", http.StatusServiceUnavailable))
		return
	}
	query := r.URL.Query()
	filter := services.PromotionListFilter{
		Status: collectQueryValues(query["status"]),
		Kinds:  collectQueryValues(query["kind"]),
		Pagination: services.Pagination{
			PageToken: strings.TrimSpace(query.Get("pageToken")),
		},
	}
	if sizeStr := strings.TrimSpace(query.Get("pageSize")); sizeStr != "" {
		size, err := strconv.Atoi(sizeStr)
		if err != nil || size < 0 {
			httpx.WriteError(r.Context(), w, httpx.NewError("invalid_page_size", "pageSize must be a non-negative integer", http.StatusBadRequest))
			return
		}
		filter.Pagination.PageSize = size
	}
	if ts := strings.TrimSpace(query.Get("activeOn")); ts != "" {
		parsed, err := time.Parse(time.RFC3339, ts)
		if err != nil {
			httpx.WriteError(r.Context(), w, httpx.NewError("invalid_active_on", "activeOn must be RFC3339 timestamp", http.StatusBadRequest))
			return
		}
		filter.ActiveOn = &parsed
	}

	page, err := h.promotions.ListPromotions(r.Context(), filter)
	if err != nil {
		writeAdminPromotionError(r.Context(), w, err, "list")
		return
	}

	items := make([]adminPromotionResponse, 0, len(page.Items))
	for _, promo := range page.Items {
		items = append(items, newAdminPromotionResponse(promo))
	}
	response := promotionListResponse{
		Items:         items,
		NextPageToken: page.NextPageToken,
	}
	writeJSONResponse(w, http.StatusOK, response)
}

func (h *AdminPromotionHandlers) listPromotionUsage(w http.ResponseWriter, r *http.Request) {
	if h.promotions == nil {
		httpx.WriteError(r.Context(), w, httpx.NewError("service_unavailable", "promotion service unavailable", http.StatusServiceUnavailable))
		return
	}
	identity, ok := auth.IdentityFromContext(r.Context())
	uid := ""
	if ok && identity != nil {
		uid = strings.TrimSpace(identity.UID)
	}
	if uid == "" {
		httpx.WriteError(r.Context(), w, httpx.NewError("unauthenticated", "authentication required", http.StatusUnauthorized))
		return
	}

	promotionID := strings.TrimSpace(chi.URLParam(r, "promotionID"))
	if promotionID == "" {
		httpx.WriteError(r.Context(), w, httpx.NewError("invalid_request", "promotion id is required", http.StatusBadRequest))
		return
	}

	query := r.URL.Query()
	filter := services.PromotionUsageFilter{
		PromotionID: promotionID,
		Pagination: services.Pagination{
			PageToken: strings.TrimSpace(query.Get("pageToken")),
		},
		SortBy:    services.PromotionUsageSortLastUsed,
		SortOrder: services.SortDesc,
	}

	if sizeStr := strings.TrimSpace(query.Get("pageSize")); sizeStr != "" {
		size, err := strconv.Atoi(sizeStr)
		if err != nil || size < 0 {
			httpx.WriteError(r.Context(), w, httpx.NewError("invalid_page_size", "pageSize must be a non-negative integer", http.StatusBadRequest))
			return
		}
		filter.Pagination.PageSize = size
	}
	if minStr := strings.TrimSpace(query.Get("minUsage")); minStr != "" {
		min, err := strconv.Atoi(minStr)
		if err != nil {
			httpx.WriteError(r.Context(), w, httpx.NewError("invalid_min_usage", "minUsage must be numeric", http.StatusBadRequest))
			return
		}
		filter.MinTimes = min
	}
	if sortParam := strings.ToLower(strings.TrimSpace(query.Get("sort"))); sortParam != "" {
		switch sortParam {
		case "lastused", "lastusedat", "last_used":
			filter.SortBy = services.PromotionUsageSortLastUsed
		case "times", "usage", "count":
			filter.SortBy = services.PromotionUsageSortTimes
		default:
			httpx.WriteError(r.Context(), w, httpx.NewError("invalid_sort", "sort must be one of lastUsedAt or times", http.StatusBadRequest))
			return
		}
	}
	if orderParam := strings.ToLower(strings.TrimSpace(query.Get("order"))); orderParam != "" {
		switch orderParam {
		case "asc", "ascending":
			filter.SortOrder = services.SortAsc
		case "desc", "descending":
			filter.SortOrder = services.SortDesc
		default:
			httpx.WriteError(r.Context(), w, httpx.NewError("invalid_order", "order must be asc or desc", http.StatusBadRequest))
			return
		}
	}

	page, err := h.promotions.ListPromotionUsage(r.Context(), filter)
	if err != nil {
		writeAdminPromotionError(r.Context(), w, err, "list_usage")
		return
	}

	if format := strings.ToLower(strings.TrimSpace(query.Get("format"))); format == "csv" {
		if page.NextPageToken != "" {
			w.Header().Set("X-Next-Page-Token", page.NextPageToken)
		}
		if err := writePromotionUsageCSV(w, promotionID, page); err != nil {
			httpx.WriteError(r.Context(), w, httpx.NewError("export_failed", "failed to render csv export", http.StatusInternalServerError))
		}
		return
	}

	items := make([]promotionUsageResponse, 0, len(page.Items))
	for _, record := range page.Items {
		items = append(items, newPromotionUsageResponse(record))
	}
	response := promotionUsageListResponse{
		Items:         items,
		NextPageToken: page.NextPageToken,
	}
	writeJSONResponse(w, http.StatusOK, response)
}

func (h *AdminPromotionHandlers) validatePromotion(w http.ResponseWriter, r *http.Request) {
	if h.promotions == nil {
		httpx.WriteError(r.Context(), w, httpx.NewError("service_unavailable", "promotion service unavailable", http.StatusServiceUnavailable))
		return
	}
	identity, ok := auth.IdentityFromContext(r.Context())
	uid := ""
	if ok && identity != nil {
		uid = strings.TrimSpace(identity.UID)
	}
	if uid == "" {
		httpx.WriteError(r.Context(), w, httpx.NewError("unauthenticated", "authentication required", http.StatusUnauthorized))
		return
	}

	promotion, _, _, err := decodeAdminPromotionRequest(r, "", true)
	if err != nil {
		httpx.WriteError(r.Context(), w, httpx.NewError("invalid_request", err.Error(), http.StatusBadRequest))
		return
	}

	result, err := h.promotions.ValidatePromotionDefinition(r.Context(), promotion)
	if err != nil {
		writeAdminPromotionError(r.Context(), w, err, "validate")
		return
	}

	writeJSONResponse(w, http.StatusOK, newPromotionValidationResponse(result))
}

func (h *AdminPromotionHandlers) createPromotion(w http.ResponseWriter, r *http.Request) {
	if h.promotions == nil {
		httpx.WriteError(r.Context(), w, httpx.NewError("service_unavailable", "promotion service unavailable", http.StatusServiceUnavailable))
		return
	}
	identity, ok := auth.IdentityFromContext(r.Context())
	if !ok || identity == nil || strings.TrimSpace(identity.UID) == "" {
		httpx.WriteError(r.Context(), w, httpx.NewError("unauthenticated", "authentication required", http.StatusUnauthorized))
		return
	}

	promotion, allowOverride, usageLimitSet, err := decodeAdminPromotionRequest(r, "", false)
	if err != nil {
		httpx.WriteError(r.Context(), w, httpx.NewError("invalid_request", err.Error(), http.StatusBadRequest))
		return
	}

	created, err := h.promotions.CreatePromotion(r.Context(), services.UpsertPromotionCommand{
		Promotion:     promotion,
		ActorID:       identity.UID,
		UsageLimitSet: usageLimitSet,
	})
	if err != nil {
		writeAdminPromotionError(r.Context(), w, err, "create")
		return
	}

	writeJSONResponse(w, http.StatusCreated, newAdminPromotionResponse(created).withOverride(allowOverride))
}

func (h *AdminPromotionHandlers) updatePromotion(w http.ResponseWriter, r *http.Request) {
	if h.promotions == nil {
		httpx.WriteError(r.Context(), w, httpx.NewError("service_unavailable", "promotion service unavailable", http.StatusServiceUnavailable))
		return
	}
	identity, ok := auth.IdentityFromContext(r.Context())
	uid := ""
	if ok && identity != nil {
		uid = strings.TrimSpace(identity.UID)
	}
	if uid == "" {
		httpx.WriteError(r.Context(), w, httpx.NewError("unauthenticated", "authentication required", http.StatusUnauthorized))
		return
	}
	promotionID := strings.TrimSpace(chi.URLParam(r, "promotionID"))
	if promotionID == "" {
		httpx.WriteError(r.Context(), w, httpx.NewError("invalid_request", "promotion id is required", http.StatusBadRequest))
		return
	}

	promotion, allowOverride, usageLimitSet, err := decodeAdminPromotionRequest(r, promotionID, false)
	if err != nil {
		httpx.WriteError(r.Context(), w, httpx.NewError("invalid_request", err.Error(), http.StatusBadRequest))
		return
	}

	updated, err := h.promotions.UpdatePromotion(r.Context(), services.UpsertPromotionCommand{
		Promotion:             promotion,
		ActorID:               uid,
		AllowImmutableUpdates: allowOverride,
		UsageLimitSet:         usageLimitSet,
	})
	if err != nil {
		writeAdminPromotionError(r.Context(), w, err, "update")
		return
	}

	writeJSONResponse(w, http.StatusOK, newAdminPromotionResponse(updated).withOverride(allowOverride))
}

func (h *AdminPromotionHandlers) deletePromotion(w http.ResponseWriter, r *http.Request) {
	if h.promotions == nil {
		httpx.WriteError(r.Context(), w, httpx.NewError("service_unavailable", "promotion service unavailable", http.StatusServiceUnavailable))
		return
	}
	identity, ok := auth.IdentityFromContext(r.Context())
	uid := ""
	if ok && identity != nil {
		uid = strings.TrimSpace(identity.UID)
	}
	if uid == "" {
		httpx.WriteError(r.Context(), w, httpx.NewError("unauthenticated", "authentication required", http.StatusUnauthorized))
		return
	}
	promotionID := strings.TrimSpace(chi.URLParam(r, "promotionID"))
	if promotionID == "" {
		httpx.WriteError(r.Context(), w, httpx.NewError("invalid_request", "promotion id is required", http.StatusBadRequest))
		return
	}

	if err := h.promotions.DeletePromotion(r.Context(), promotionID, uid); err != nil {
		writeAdminPromotionError(r.Context(), w, err, "delete")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func decodeAdminPromotionRequest(r *http.Request, overrideID string, allowIncomplete bool) (services.Promotion, bool, bool, error) {
	if r.Body == nil {
		return services.Promotion{}, false, false, errors.New("request body is required")
	}
	defer r.Body.Close()

	limited := io.LimitReader(r.Body, maxPromotionRequestBody)
	decoder := json.NewDecoder(limited)
	decoder.DisallowUnknownFields()

	var payload adminPromotionRequest
	if err := decoder.Decode(&payload); err != nil {
		return services.Promotion{}, false, false, fmt.Errorf("invalid json: %w", err)
	}

	var (
		startsAt time.Time
		endsAt   time.Time
		err      error
	)
	if strings.TrimSpace(payload.StartsAt) != "" {
		startsAt, err = parseTimestamp(payload.StartsAt, "startsAt")
		if err != nil {
			return services.Promotion{}, false, false, err
		}
	} else if !allowIncomplete {
		return services.Promotion{}, false, false, fmt.Errorf("startsAt is required")
	}
	if strings.TrimSpace(payload.EndsAt) != "" {
		endsAt, err = parseTimestamp(payload.EndsAt, "endsAt")
		if err != nil {
			return services.Promotion{}, false, false, err
		}
	} else if !allowIncomplete {
		return services.Promotion{}, false, false, fmt.Errorf("endsAt is required")
	}

	promotion := services.Promotion{
		ID:                strings.TrimSpace(payload.ID),
		Code:              payload.Code,
		Name:              payload.Name,
		Description:       payload.Description,
		DescriptionPublic: payload.DescriptionPublic,
		Status:            payload.Status,
		IsActive:          payload.IsActive != nil && *payload.IsActive,
		Kind:              payload.Kind,
		Value:             payload.Value,
		Currency:          payload.Currency,
		StartsAt:          startsAt,
		EndsAt:            endsAt,
		UsageLimit:        derefInt(payload.UsageLimit),
		UsageCount:        derefInt(payload.UsageCount),
		LimitPerUser:      derefInt(payload.LimitPerUser),
		Notes:             payload.Notes,
		EligibleAudiences: payload.EligibleAudiences,
		InternalOnly:      payload.InternalOnly,
		RequiresAuth:      payload.RequiresAuth,
		Metadata:          payload.Metadata,
		Stacking: services.PromotionStacking{
			Combinable:    payload.Stacking.Combinable,
			WithSalePrice: payload.Stacking.WithSalePrice,
			MaxStack:      payload.Stacking.MaxStack,
		},
		Conditions: services.PromotionConditions{
			MinSubtotal:    payload.Conditions.MinSubtotal,
			CountryIn:      payload.Conditions.CountryIn,
			CurrencyIn:     payload.Conditions.CurrencyIn,
			ShapeIn:        payload.Conditions.ShapeIn,
			SizeMMBetween:  payload.Conditions.SizeMMBetween,
			ProductRefsIn:  payload.Conditions.ProductRefsIn,
			MaterialRefsIn: payload.Conditions.MaterialRefsIn,
			NewCustomerOnly: func(v *bool) *bool {
				if v == nil {
					return nil
				}
				value := *v
				return &value
			}(payload.Conditions.NewCustomerOnly),
		},
	}
	if overrideID != "" {
		promotion.ID = overrideID
	}
	usageLimitSet := payload.UsageLimit != nil
	return promotion, payload.AllowImmutableUpdates, usageLimitSet, nil
}

func parseTimestamp(value string, field string) (time.Time, error) {
	value = strings.TrimSpace(value)
	if value == "" {
		return time.Time{}, fmt.Errorf("%s is required", field)
	}
	parsed, err := time.Parse(time.RFC3339, value)
	if err != nil {
		return time.Time{}, fmt.Errorf("%s must be RFC3339 timestamp", field)
	}
	return parsed, nil
}

func derefInt(value *int) int {
	if value == nil {
		return 0
	}
	return *value
}

func collectQueryValues(values []string) []string {
	if len(values) == 0 {
		return nil
	}
	var collected []string
	seen := make(map[string]struct{})
	for _, entry := range values {
		for _, part := range strings.Split(entry, ",") {
			trimmed := strings.TrimSpace(part)
			if trimmed == "" {
				continue
			}
			if _, ok := seen[trimmed]; ok {
				continue
			}
			seen[trimmed] = struct{}{}
			collected = append(collected, trimmed)
		}
	}
	return collected
}

func writeAdminPromotionError(ctx context.Context, w http.ResponseWriter, err error, action string) {
	if err == nil {
		return
	}
	switch {
	case errors.Is(err, services.ErrPromotionInvalidInput):
		httpx.WriteError(ctx, w, httpx.NewError("invalid_promotion", err.Error(), http.StatusBadRequest))
	case errors.Is(err, services.ErrPromotionNotFound):
		httpx.WriteError(ctx, w, httpx.NewError("promotion_not_found", err.Error(), http.StatusNotFound))
	case errors.Is(err, services.ErrPromotionConflict):
		httpx.WriteError(ctx, w, httpx.NewError("promotion_conflict", err.Error(), http.StatusConflict))
	case errors.Is(err, services.ErrPromotionImmutableChange):
		httpx.WriteError(ctx, w, httpx.NewError("promotion_locked", err.Error(), http.StatusConflict))
	case errors.Is(err, services.ErrPromotionRepositoryMissing):
		httpx.WriteError(ctx, w, httpx.NewError("promotions_unavailable", "promotion service unavailable", http.StatusServiceUnavailable))
	case errors.Is(err, services.ErrPromotionOperationUnsupported):
		httpx.WriteError(ctx, w, httpx.NewError("promotion_operation_unsupported", "promotion operation unavailable", http.StatusNotImplemented))
	default:
		httpx.WriteError(ctx, w, httpx.NewError("promotion_"+action+"_failed", "failed to "+action+" promotion", http.StatusInternalServerError))
	}
}

type adminPromotionRequest struct {
	ID                    string                     `json:"id"`
	Code                  string                     `json:"code"`
	Name                  string                     `json:"name"`
	Description           string                     `json:"description"`
	DescriptionPublic     string                     `json:"descriptionPublic"`
	Status                string                     `json:"status"`
	IsActive              *bool                      `json:"isActive"`
	Kind                  string                     `json:"kind"`
	Value                 float64                    `json:"value"`
	Currency              string                     `json:"currency"`
	StartsAt              string                     `json:"startsAt"`
	EndsAt                string                     `json:"endsAt"`
	UsageLimit            *int                       `json:"usageLimit"`
	UsageCount            *int                       `json:"usageCount"`
	LimitPerUser          *int                       `json:"limitPerUser"`
	Notes                 string                     `json:"notes"`
	EligibleAudiences     []string                   `json:"eligibleAudiences"`
	InternalOnly          bool                       `json:"internalOnly"`
	RequiresAuth          bool                       `json:"requiresAuth"`
	Metadata              map[string]any             `json:"metadata"`
	Stacking              promotionStackingPayload   `json:"stacking"`
	Conditions            promotionConditionsPayload `json:"conditions"`
	AllowImmutableUpdates bool                       `json:"allowImmutableUpdates"`
}

type promotionStackingPayload struct {
	Combinable    bool `json:"combinable"`
	WithSalePrice bool `json:"withSalePrice"`
	MaxStack      *int `json:"maxStack"`
}

type promotionConditionsPayload struct {
	MinSubtotal     *int64                       `json:"minSubtotal"`
	CountryIn       []string                     `json:"countryIn"`
	CurrencyIn      []string                     `json:"currencyIn"`
	ShapeIn         []string                     `json:"shapeIn"`
	SizeMMBetween   *services.PromotionSizeRange `json:"sizeMmBetween"`
	ProductRefsIn   []string                     `json:"productRefsIn"`
	MaterialRefsIn  []string                     `json:"materialRefsIn"`
	NewCustomerOnly *bool                        `json:"newCustomerOnly"`
}

type promotionListResponse struct {
	Items         []adminPromotionResponse `json:"items"`
	NextPageToken string                   `json:"nextPageToken,omitempty"`
}

type promotionValidationResponse struct {
	Valid      bool                               `json:"valid"`
	Checks     []promotionValidationCheckResponse `json:"checks"`
	Normalized adminPromotionResponse             `json:"normalized"`
}

type promotionValidationCheckResponse struct {
	Constraint string   `json:"constraint"`
	Passed     bool     `json:"passed"`
	Issues     []string `json:"issues,omitempty"`
}

type promotionUsageListResponse struct {
	Items         []promotionUsageResponse `json:"items"`
	NextPageToken string                   `json:"nextPageToken,omitempty"`
}

type promotionUsageResponse struct {
	User        promotionUsageUserResponse `json:"user"`
	Times       int                        `json:"times"`
	LastUsedAt  string                     `json:"lastUsedAt,omitempty"`
	FirstUsedAt string                     `json:"firstUsedAt,omitempty"`
	OrderRefs   []string                   `json:"orderRefs,omitempty"`
	Blocked     bool                       `json:"blocked,omitempty"`
	Notes       string                     `json:"notes,omitempty"`
}

type promotionUsageUserResponse struct {
	ID          string `json:"id"`
	Email       string `json:"email,omitempty"`
	DisplayName string `json:"displayName,omitempty"`
}

type adminPromotionResponse struct {
	ID                string                           `json:"id"`
	Code              string                           `json:"code"`
	Name              string                           `json:"name,omitempty"`
	Description       string                           `json:"description,omitempty"`
	DescriptionPublic string                           `json:"descriptionPublic,omitempty"`
	Status            string                           `json:"status"`
	IsActive          bool                             `json:"isActive"`
	Kind              string                           `json:"kind"`
	Value             float64                          `json:"value"`
	Currency          string                           `json:"currency,omitempty"`
	StartsAt          string                           `json:"startsAt"`
	EndsAt            string                           `json:"endsAt"`
	UsageLimit        int                              `json:"usageLimit"`
	UsageCount        int                              `json:"usageCount"`
	LimitPerUser      int                              `json:"limitPerUser"`
	Notes             string                           `json:"notes,omitempty"`
	EligibleAudiences []string                         `json:"eligibleAudiences,omitempty"`
	InternalOnly      bool                             `json:"internalOnly"`
	RequiresAuth      bool                             `json:"requiresAuth"`
	Metadata          map[string]any                   `json:"metadata,omitempty"`
	Stacking          adminPromotionStackingResponse   `json:"stacking"`
	Conditions        adminPromotionConditionsResponse `json:"conditions"`
	CreatedAt         string                           `json:"createdAt,omitempty"`
	UpdatedAt         string                           `json:"updatedAt,omitempty"`
	AllowOverride     bool                             `json:"allowImmutableUpdates,omitempty"`
}

type adminPromotionStackingResponse struct {
	Combinable    bool `json:"combinable"`
	WithSalePrice bool `json:"withSalePrice"`
	MaxStack      *int `json:"maxStack,omitempty"`
}

type adminPromotionConditionsResponse struct {
	MinSubtotal     *int64                       `json:"minSubtotal,omitempty"`
	CountryIn       []string                     `json:"countryIn,omitempty"`
	CurrencyIn      []string                     `json:"currencyIn,omitempty"`
	ShapeIn         []string                     `json:"shapeIn,omitempty"`
	SizeMMBetween   *services.PromotionSizeRange `json:"sizeMmBetween,omitempty"`
	ProductRefsIn   []string                     `json:"productRefsIn,omitempty"`
	MaterialRefsIn  []string                     `json:"materialRefsIn,omitempty"`
	NewCustomerOnly *bool                        `json:"newCustomerOnly,omitempty"`
}

func newAdminPromotionResponse(promotion services.Promotion) adminPromotionResponse {
	response := adminPromotionResponse{
		ID:                promotion.ID,
		Code:              promotion.Code,
		Name:              promotion.Name,
		Description:       promotion.Description,
		DescriptionPublic: promotion.DescriptionPublic,
		Status:            promotion.Status,
		IsActive:          promotion.IsActive,
		Kind:              promotion.Kind,
		Value:             promotion.Value,
		Currency:          promotion.Currency,
		StartsAt:          formatPromotionTimestamp(promotion.StartsAt),
		EndsAt:            formatPromotionTimestamp(promotion.EndsAt),
		UsageLimit:        promotion.UsageLimit,
		UsageCount:        promotion.UsageCount,
		LimitPerUser:      promotion.LimitPerUser,
		Notes:             promotion.Notes,
		EligibleAudiences: cloneStringSlice(promotion.EligibleAudiences),
		InternalOnly:      promotion.InternalOnly,
		RequiresAuth:      promotion.RequiresAuth,
		Metadata:          promotion.Metadata,
		Stacking: adminPromotionStackingResponse{
			Combinable:    promotion.Stacking.Combinable,
			WithSalePrice: promotion.Stacking.WithSalePrice,
			MaxStack:      promotion.Stacking.MaxStack,
		},
		Conditions: adminPromotionConditionsResponse{
			MinSubtotal:     promotion.Conditions.MinSubtotal,
			CountryIn:       cloneStringSlice(promotion.Conditions.CountryIn),
			CurrencyIn:      cloneStringSlice(promotion.Conditions.CurrencyIn),
			ShapeIn:         cloneStringSlice(promotion.Conditions.ShapeIn),
			SizeMMBetween:   promotion.Conditions.SizeMMBetween,
			ProductRefsIn:   cloneStringSlice(promotion.Conditions.ProductRefsIn),
			MaterialRefsIn:  cloneStringSlice(promotion.Conditions.MaterialRefsIn),
			NewCustomerOnly: promotion.Conditions.NewCustomerOnly,
		},
		CreatedAt: formatPromotionTimestamp(promotion.CreatedAt),
		UpdatedAt: formatPromotionTimestamp(promotion.UpdatedAt),
	}
	return response
}

func newPromotionValidationResponse(result services.PromotionDefinitionValidationResult) promotionValidationResponse {
	checks := make([]promotionValidationCheckResponse, 0, len(result.Checks))
	for _, check := range result.Checks {
		var issues []string
		if len(check.Issues) > 0 {
			issues = make([]string, len(check.Issues))
			copy(issues, check.Issues)
		}
		checks = append(checks, promotionValidationCheckResponse{
			Constraint: string(check.Constraint),
			Passed:     check.Passed,
			Issues:     issues,
		})
	}
	return promotionValidationResponse{
		Valid:      result.Valid,
		Checks:     checks,
		Normalized: newAdminPromotionResponse(result.Normalized),
	}
}

func newPromotionUsageResponse(record services.PromotionUsageRecord) promotionUsageResponse {
	resp := promotionUsageResponse{
		User: promotionUsageUserResponse{
			ID:          strings.TrimSpace(record.User.ID),
			Email:       strings.TrimSpace(record.User.Email),
			DisplayName: strings.TrimSpace(record.User.DisplayName),
		},
		Times:     record.Usage.Times,
		OrderRefs: cloneStringSlice(record.Usage.OrderRefs),
		Blocked:   record.Usage.Blocked,
		Notes:     strings.TrimSpace(record.Usage.Notes),
	}
	if !record.Usage.LastUsed.IsZero() {
		resp.LastUsedAt = formatPromotionTimestamp(record.Usage.LastUsed)
	}
	if record.Usage.FirstUsed != nil {
		first := record.Usage.FirstUsed.UTC()
		if !first.IsZero() {
			resp.FirstUsedAt = formatPromotionTimestamp(first)
		}
	}
	if len(resp.OrderRefs) == 0 {
		resp.OrderRefs = nil
	}
	return resp
}

func writePromotionUsageCSV(w http.ResponseWriter, promotionID string, page services.PromotionUsagePage) error {
	w.Header().Set("Content-Type", "text/csv; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	if promotionID != "" {
		filename := fmt.Sprintf("promotion-%s-usage.csv", promotionID)
		w.Header().Set("Content-Disposition", fmt.Sprintf("attachment; filename=\"%s\"", filename))
	}

	writer := csv.NewWriter(w)
	header := []string{"uid", "email", "displayName", "times", "lastUsedAt", "firstUsedAt", "blocked", "orderRefs", "notes"}
	if err := writer.Write(header); err != nil {
		return err
	}

	for _, record := range page.Items {
		usage := newPromotionUsageResponse(record)
		orderRefs := strings.Join(usage.OrderRefs, ";")
		row := []string{
			usage.User.ID,
			usage.User.Email,
			usage.User.DisplayName,
			strconv.Itoa(usage.Times),
			usage.LastUsedAt,
			usage.FirstUsedAt,
			strconv.FormatBool(record.Usage.Blocked),
			orderRefs,
			usage.Notes,
		}
		if err := writer.Write(row); err != nil {
			return err
		}
	}

	writer.Flush()
	return writer.Error()
}

func (r adminPromotionResponse) withOverride(allow bool) adminPromotionResponse {
	if allow {
		r.AllowOverride = true
	}
	return r
}

func formatPromotionTimestamp(t time.Time) string {
	if t.IsZero() {
		return ""
	}
	return t.UTC().Format(time.RFC3339)
}
