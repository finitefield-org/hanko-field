package handlers

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"go.uber.org/zap"

	"github.com/hanko-field/api/internal/platform/httpx"
	"github.com/hanko-field/api/internal/platform/observability"
	"github.com/hanko-field/api/internal/services"
)

const maxInternalPromotionApplyBody = 4 * 1024

// InternalPromotionHandlers exposes internal-only promotion operations.
type InternalPromotionHandlers struct {
	promotions services.PromotionService
}

// NewInternalPromotionHandlers constructs promotion handlers for internal endpoints.
func NewInternalPromotionHandlers(promotions services.PromotionService) *InternalPromotionHandlers {
	return &InternalPromotionHandlers{promotions: promotions}
}

// Routes registers internal promotion endpoints.
func (h *InternalPromotionHandlers) Routes(r chi.Router) {
	if r == nil {
		return
	}
	r.Post("/promotions/apply", h.applyPromotion)
}

type internalPromotionApplyRequest struct {
	Code       string                   `json:"code"`
	UserID     string                   `json:"userId"`
	OrderRef   string                   `json:"orderRef,omitempty"`
	CartTotals *internalPromotionTotals `json:"cartTotals,omitempty"`
}

type internalPromotionTotals struct {
	Currency string `json:"currency"`
	Subtotal int64  `json:"subtotal"`
	Discount int64  `json:"discount"`
	Shipping int64  `json:"shipping"`
	Tax      int64  `json:"tax"`
	Fees     int64  `json:"fees"`
	Total    int64  `json:"total"`
}

type internalPromotionApplyResponse struct {
	Code            string                         `json:"code"`
	Applied         bool                           `json:"applied"`
	DiscountAmount  int64                          `json:"discountAmount"`
	Reason          string                         `json:"reason,omitempty"`
	PromotionID     string                         `json:"promotionId"`
	UsageCount      int                            `json:"usageCount"`
	UsageLimit      int                            `json:"usageLimit"`
	LimitPerUser    int                            `json:"limitPerUser"`
	RemainingUser   *int                           `json:"remainingForUser,omitempty"`
	RemainingGlobal *int                           `json:"remainingGlobal,omitempty"`
	AppliedAt       time.Time                      `json:"appliedAt"`
	UserUsage       internalPromotionUsageSnapshot `json:"userUsage"`
}

type internalPromotionUsageSnapshot struct {
	UserID    string     `json:"userId"`
	Times     int        `json:"times"`
	LastUsed  time.Time  `json:"lastUsed"`
	FirstUsed *time.Time `json:"firstUsed,omitempty"`
}

func (h *InternalPromotionHandlers) applyPromotion(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	if h == nil || h.promotions == nil {
		httpx.WriteError(ctx, w, httpx.NewError("promotions_unavailable", "promotion service unavailable", http.StatusServiceUnavailable))
		return
	}

	body := http.MaxBytesReader(w, r.Body, maxInternalPromotionApplyBody)
	defer body.Close()

	decoder := json.NewDecoder(body)
	decoder.DisallowUnknownFields()

	var req internalPromotionApplyRequest
	if err := decoder.Decode(&req); err != nil {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "invalid JSON payload", http.StatusBadRequest))
		return
	}

	if decoder.More() {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "unexpected data after payload", http.StatusBadRequest))
		return
	}

	code := strings.TrimSpace(req.Code)
	if code == "" {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "code is required", http.StatusBadRequest))
		return
	}
	userID := strings.TrimSpace(req.UserID)
	if userID == "" {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "userId is required", http.StatusBadRequest))
		return
	}

	command := services.PromotionApplyCommand{
		Code:       code,
		UserID:     userID,
		OrderRef:   strings.TrimSpace(req.OrderRef),
		CartTotals: convertInternalPromotionTotals(req.CartTotals),
	}

	result, err := h.promotions.ApplyPromotion(ctx, command)
	if err != nil {
		h.handleApplyError(ctx, w, err)
		return
	}

	response := buildInternalPromotionApplyResponse(result)
	logger := observability.FromContext(ctx).Named("internal.promotions")
	logger.Info("promotion applied",
		zap.String("code", response.Code),
		zap.String("userId", response.UserUsage.UserID),
		zap.Int("times", response.UserUsage.Times),
		zap.Int("usageCount", response.UsageCount),
	)

	writeJSONResponse(w, http.StatusOK, response)
}

func (h *InternalPromotionHandlers) handleApplyError(ctx context.Context, w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, services.ErrPromotionInvalidInput), errors.Is(err, services.ErrPromotionInvalidCode):
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", err.Error(), http.StatusBadRequest))
	case errors.Is(err, services.ErrPromotionNotFound):
		httpx.WriteError(ctx, w, httpx.NewError("promotion_not_found", err.Error(), http.StatusNotFound))
	case errors.Is(err, services.ErrPromotionUsageLimitReached):
		httpx.WriteError(ctx, w, httpx.NewError("usage_limit_reached", err.Error(), http.StatusConflict))
	case errors.Is(err, services.ErrPromotionUserLimitReached):
		httpx.WriteError(ctx, w, httpx.NewError("user_limit_reached", err.Error(), http.StatusConflict))
	case errors.Is(err, services.ErrPromotionUsageBlocked):
		httpx.WriteError(ctx, w, httpx.NewError("usage_blocked", err.Error(), http.StatusConflict))
	case errors.Is(err, services.ErrPromotionInactive):
		httpx.WriteError(ctx, w, httpx.NewError("promotion_inactive", err.Error(), http.StatusConflict))
	case errors.Is(err, services.ErrPromotionExpired):
		httpx.WriteError(ctx, w, httpx.NewError("promotion_expired", err.Error(), http.StatusConflict))
	case errors.Is(err, services.ErrPromotionUnavailable):
		httpx.WriteError(ctx, w, httpx.NewError("promotion_unavailable", err.Error(), http.StatusConflict))
	case errors.Is(err, services.ErrPromotionRepositoryMissing):
		httpx.WriteError(ctx, w, httpx.NewError("promotions_unavailable", "promotion repository unavailable", http.StatusServiceUnavailable))
	default:
		httpx.WriteError(ctx, w, httpx.NewError("apply_error", "failed to apply promotion", http.StatusInternalServerError))
	}
}

func convertInternalPromotionTotals(src *internalPromotionTotals) *services.PromotionCartTotals {
	if src == nil {
		return nil
	}
	return &services.PromotionCartTotals{
		Currency: strings.TrimSpace(src.Currency),
		Subtotal: clampToNonNegative(src.Subtotal),
		Discount: clampToNonNegative(src.Discount),
		Shipping: clampToNonNegative(src.Shipping),
		Tax:      clampToNonNegative(src.Tax),
		Fees:     clampToNonNegative(src.Fees),
		Total:    clampToNonNegative(src.Total),
	}
}

func clampToNonNegative(value int64) int64 {
	if value < 0 {
		return 0
	}
	return value
}

func buildInternalPromotionApplyResponse(result services.PromotionApplyResult) internalPromotionApplyResponse {
	promotion := result.Promotion
	usage := result.Usage
	validation := result.Validation

	resp := internalPromotionApplyResponse{
		Code:           strings.TrimSpace(promotion.Code),
		Applied:        true,
		DiscountAmount: validation.DiscountAmount,
		Reason:         strings.TrimSpace(validation.Reason),
		PromotionID:    strings.TrimSpace(promotion.ID),
		UsageCount:     promotion.UsageCount,
		UsageLimit:     promotion.UsageLimit,
		LimitPerUser:   promotion.LimitPerUser,
		AppliedAt:      result.AppliedAt,
		UserUsage: internalPromotionUsageSnapshot{
			UserID:    strings.TrimSpace(usage.UserID),
			Times:     usage.Times,
			LastUsed:  usage.LastUsed,
			FirstUsed: usage.FirstUsed,
		},
	}

	if promotion.LimitPerUser > 0 {
		remaining := promotion.LimitPerUser - usage.Times
		if remaining < 0 {
			remaining = 0
		}
		resp.RemainingUser = intPtr(remaining)
	}
	if promotion.UsageLimit > 0 {
		remaining := promotion.UsageLimit - promotion.UsageCount
		if remaining < 0 {
			remaining = 0
		}
		resp.RemainingGlobal = intPtr(remaining)
	}

	return resp
}

func intPtr(value int) *int {
	v := value
	return &v
}
