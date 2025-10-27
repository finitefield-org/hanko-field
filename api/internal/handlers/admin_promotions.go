package handlers

import (
	"context"
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
	r.Route("/promotions", func(rt chi.Router) {
		rt.Get("/", h.listPromotions)
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
		if size, err := strconv.Atoi(sizeStr); err == nil {
			filter.Pagination.PageSize = size
		} else {
			httpx.WriteError(r.Context(), w, httpx.NewError("invalid_page_size", "pageSize must be numeric", http.StatusBadRequest))
			return
		}
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

	promotion, allowOverride, err := decodeAdminPromotionRequest(r, "")
	if err != nil {
		httpx.WriteError(r.Context(), w, httpx.NewError("invalid_request", err.Error(), http.StatusBadRequest))
		return
	}

	created, err := h.promotions.CreatePromotion(r.Context(), services.UpsertPromotionCommand{
		Promotion: promotion,
		ActorID:   identity.UID,
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

	promotion, allowOverride, err := decodeAdminPromotionRequest(r, promotionID)
	if err != nil {
		httpx.WriteError(r.Context(), w, httpx.NewError("invalid_request", err.Error(), http.StatusBadRequest))
		return
	}

	updated, err := h.promotions.UpdatePromotion(r.Context(), services.UpsertPromotionCommand{
		Promotion:             promotion,
		ActorID:               uid,
		AllowImmutableUpdates: allowOverride,
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

func decodeAdminPromotionRequest(r *http.Request, overrideID string) (services.Promotion, bool, error) {
	if r.Body == nil {
		return services.Promotion{}, false, errors.New("request body is required")
	}
	defer r.Body.Close()

	limited := io.LimitReader(r.Body, maxPromotionRequestBody)
	decoder := json.NewDecoder(limited)
	decoder.DisallowUnknownFields()

	var payload adminPromotionRequest
	if err := decoder.Decode(&payload); err != nil {
		return services.Promotion{}, false, fmt.Errorf("invalid json: %w", err)
	}

	startsAt, err := parseTimestamp(payload.StartsAt, "startsAt")
	if err != nil {
		return services.Promotion{}, false, err
	}
	endsAt, err := parseTimestamp(payload.EndsAt, "endsAt")
	if err != nil {
		return services.Promotion{}, false, err
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
	return promotion, payload.AllowImmutableUpdates, nil
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
