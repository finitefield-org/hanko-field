package handlers

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"

	domain "github.com/hanko-field/api/internal/domain"
	"github.com/hanko-field/api/internal/platform/auth"
	"github.com/hanko-field/api/internal/platform/httpx"
	"github.com/hanko-field/api/internal/services"
)

const (
	defaultAdminReviewPageSize = 50
	maxAdminReviewPageSize     = 200
	maxAdminReviewBodySize     = 8 * 1024
)

// AdminReviewOption customises admin review handler behaviour.
type AdminReviewOption func(*AdminReviewHandlers)

// WithAdminReviewClock overrides the clock used for audit timestamps.
func WithAdminReviewClock(clock func() time.Time) AdminReviewOption {
	return func(h *AdminReviewHandlers) {
		if clock != nil {
			h.clock = func() time.Time {
				return clock().UTC()
			}
		}
	}
}

// AdminReviewHandlers exposes moderation endpoints for staff and admin users.
type AdminReviewHandlers struct {
	authn   *auth.Authenticator
	reviews services.ReviewService
	audit   services.AuditLogService
	clock   func() time.Time
}

// NewAdminReviewHandlers constructs admin review handlers enforcing authentication.
func NewAdminReviewHandlers(authn *auth.Authenticator, reviews services.ReviewService, audit services.AuditLogService, opts ...AdminReviewOption) *AdminReviewHandlers {
	handler := &AdminReviewHandlers{
		authn:   authn,
		reviews: reviews,
		audit:   audit,
		clock: func() time.Time {
			return time.Now().UTC()
		},
	}
	for _, opt := range opts {
		if opt != nil {
			opt(handler)
		}
	}
	return handler
}

// Routes registers admin review moderation endpoints under /admin/reviews.
func (h *AdminReviewHandlers) Routes(r chi.Router) {
	if r == nil {
		return
	}
	if h.authn != nil {
		r.Use(h.authn.RequireFirebaseAuth(auth.RoleAdmin, auth.RoleStaff))
	}
	r.Route("/reviews", func(rt chi.Router) {
		rt.Get("/", h.listReviews)
		rt.Put("/{reviewID}:moderate", h.moderateReview)
		rt.Post("/{reviewID}:store-reply", h.storeReviewReply)
	})
}

func (h *AdminReviewHandlers) listReviews(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	if h.reviews == nil {
		httpx.WriteError(ctx, w, httpx.NewError("review_service_unavailable", "review service unavailable", http.StatusServiceUnavailable))
		return
	}

	identity, ok := auth.IdentityFromContext(ctx)
	if !ok || identity == nil || strings.TrimSpace(identity.UID) == "" {
		httpx.WriteError(ctx, w, httpx.NewError("unauthenticated", "authentication required", http.StatusUnauthorized))
		return
	}
	if !identity.HasAnyRole(auth.RoleAdmin, auth.RoleStaff) {
		httpx.WriteError(ctx, w, httpx.NewError("insufficient_role", "admin or staff role required", http.StatusForbidden))
		return
	}

	values := r.URL.Query()

	pageSize := defaultAdminReviewPageSize
	if raw := strings.TrimSpace(firstQueryValue(values, "page_size", "pageSize")); raw != "" {
		size, err := strconv.Atoi(raw)
		if err != nil {
			httpx.WriteError(ctx, w, httpx.NewError("invalid_page_size", "page_size must be an integer", http.StatusBadRequest))
			return
		}
		switch {
		case size <= 0:
			pageSize = defaultAdminReviewPageSize
		case size > maxAdminReviewPageSize:
			pageSize = maxAdminReviewPageSize
		default:
			pageSize = size
		}
	}

	statuses, err := parseAdminReviewStatuses(values)
	if err != nil {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_moderation_filter", err.Error(), http.StatusBadRequest))
		return
	}

	filter := services.ReviewListFilter{
		Status: statuses,
		Pagination: services.Pagination{
			PageSize:  pageSize,
			PageToken: strings.TrimSpace(firstQueryValue(values, "page_token", "pageToken")),
		},
		OrderRef: strings.TrimSpace(firstQueryValue(values, "order_id", "orderId", "order")),
		UserRef:  strings.TrimSpace(firstQueryValue(values, "user_id", "userId", "user")),
	}

	page, err := h.reviews.ListReviews(ctx, filter)
	if err != nil {
		writeReviewError(ctx, w, err)
		return
	}

	items := make([]adminReviewPayload, 0, len(page.Items))
	for _, review := range page.Items {
		items = append(items, buildAdminReviewPayload(review))
	}

	response := adminReviewListResponse{
		Items:         items,
		NextPageToken: strings.TrimSpace(page.NextPageToken),
	}
	writeJSONResponse(w, http.StatusOK, response)
}

func (h *AdminReviewHandlers) moderateReview(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	if h.reviews == nil {
		httpx.WriteError(ctx, w, httpx.NewError("review_service_unavailable", "review service unavailable", http.StatusServiceUnavailable))
		return
	}

	identity, ok := auth.IdentityFromContext(ctx)
	if !ok || identity == nil || strings.TrimSpace(identity.UID) == "" {
		httpx.WriteError(ctx, w, httpx.NewError("unauthenticated", "authentication required", http.StatusUnauthorized))
		return
	}
	if !identity.HasAnyRole(auth.RoleAdmin, auth.RoleStaff) {
		httpx.WriteError(ctx, w, httpx.NewError("insufficient_role", "admin or staff role required", http.StatusForbidden))
		return
	}

	reviewID := strings.TrimSpace(chi.URLParam(r, "reviewID"))
	if reviewID == "" {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "review id is required", http.StatusBadRequest))
		return
	}

	body, err := readLimitedBody(r, maxAdminReviewBodySize)
	if err != nil {
		switch {
		case errors.Is(err, errEmptyBody):
			httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "request body is required", http.StatusBadRequest))
		case errors.Is(err, errBodyTooLarge):
			httpx.WriteError(ctx, w, httpx.NewError("payload_too_large", "request body exceeds allowed size", http.StatusRequestEntityTooLarge))
		default:
			httpx.WriteError(ctx, w, httpx.NewError("invalid_request", err.Error(), http.StatusBadRequest))
		}
		return
	}

	var payload adminModerateReviewRequest
	if err := json.Unmarshal(body, &payload); err != nil {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "invalid JSON payload", http.StatusBadRequest))
		return
	}

	action := strings.ToLower(strings.TrimSpace(payload.Action))
	if action == "" {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "action is required", http.StatusBadRequest))
		return
	}

	var status services.ReviewStatus
	switch action {
	case "approve":
		status = services.ReviewStatus(domain.ReviewStatusApproved)
	case "reject":
		status = services.ReviewStatus(domain.ReviewStatusRejected)
	default:
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "action must be approve or reject", http.StatusBadRequest))
		return
	}

	reason := strings.TrimSpace(payload.Reason)

	var previousStatus services.ReviewStatus
	if page, err := h.reviews.ListReviews(ctx, services.ReviewListFilter{
		ReviewID: reviewID,
		Pagination: services.Pagination{
			PageSize: 1,
		},
	}); err == nil && len(page.Items) > 0 {
		previousStatus = page.Items[0].Status
	}

	review, err := h.reviews.Moderate(ctx, services.ModerateReviewCommand{
		ReviewID: reviewID,
		ActorID:  strings.TrimSpace(identity.UID),
		Status:   status,
	})
	if err != nil {
		writeReviewError(ctx, w, err)
		return
	}

	h.recordModerationAudit(ctx, identity, review, action, reason, previousStatus)

	response := adminReviewResponse{
		Review: buildAdminReviewPayload(review),
	}
	writeJSONResponse(w, http.StatusOK, response)
}

func (h *AdminReviewHandlers) storeReviewReply(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	if h.reviews == nil {
		httpx.WriteError(ctx, w, httpx.NewError("review_service_unavailable", "review service unavailable", http.StatusServiceUnavailable))
		return
	}

	identity, ok := auth.IdentityFromContext(ctx)
	if !ok || identity == nil || strings.TrimSpace(identity.UID) == "" {
		httpx.WriteError(ctx, w, httpx.NewError("unauthenticated", "authentication required", http.StatusUnauthorized))
		return
	}
	if !identity.HasAnyRole(auth.RoleAdmin, auth.RoleStaff) {
		httpx.WriteError(ctx, w, httpx.NewError("insufficient_role", "admin or staff role required", http.StatusForbidden))
		return
	}

	reviewID := strings.TrimSpace(chi.URLParam(r, "reviewID"))
	if reviewID == "" {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "review id is required", http.StatusBadRequest))
		return
	}

	body, err := readLimitedBody(r, maxAdminReviewBodySize)
	if err != nil {
		switch {
		case errors.Is(err, errEmptyBody):
			httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "request body is required", http.StatusBadRequest))
		case errors.Is(err, errBodyTooLarge):
			httpx.WriteError(ctx, w, httpx.NewError("payload_too_large", "request body exceeds allowed size", http.StatusRequestEntityTooLarge))
		default:
			httpx.WriteError(ctx, w, httpx.NewError("invalid_request", err.Error(), http.StatusBadRequest))
		}
		return
	}

	var payload adminStoreReplyRequest
	if err := json.Unmarshal(body, &payload); err != nil {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "invalid JSON payload", http.StatusBadRequest))
		return
	}

	visible := true
	if payload.Visible != nil {
		visible = *payload.Visible
	}

	message := strings.TrimSpace(payload.Message)
	if message == "" {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "message is required", http.StatusBadRequest))
		return
	}

	review, err := h.reviews.StoreReply(ctx, services.StoreReviewReplyCommand{
		ReviewID: reviewID,
		ActorID:  strings.TrimSpace(identity.UID),
		Message:  message,
		Visible:  visible,
	})
	if err != nil {
		writeReviewError(ctx, w, err)
		return
	}

	h.recordReplyAudit(ctx, identity, review, visible)

	response := adminReviewResponse{
		Review: buildAdminReviewPayload(review),
	}
	writeJSONResponse(w, http.StatusOK, response)
}

func (h *AdminReviewHandlers) recordModerationAudit(ctx context.Context, identity *auth.Identity, review services.Review, action string, reason string, previous services.ReviewStatus) {
	if h.audit == nil {
		return
	}

	actor := ""
	if identity != nil {
		actor = strings.TrimSpace(identity.UID)
	}

	metadata := map[string]any{
		"reviewId": review.ID,
		"orderId":  review.OrderRef,
		"userId":   review.UserRef,
		"action":   action,
		"status":   string(review.Status),
	}
	if reason != "" {
		metadata["reason"] = reason
	}
	if previous != "" {
		metadata["previousStatus"] = string(previous)
	}

	diff := make(map[string]services.AuditLogDiff)
	if previous != "" && previous != review.Status {
		diff["status"] = services.AuditLogDiff{
			Before: string(previous),
			After:  string(review.Status),
		}
	}

	record := services.AuditLogRecord{
		Actor:      actor,
		ActorType:  adminReviewActorType(identity),
		Action:     "review.moderate",
		TargetRef:  fmt.Sprintf("/reviews/%s", strings.TrimSpace(review.ID)),
		OccurredAt: h.now(),
		Metadata:   metadata,
	}
	if len(diff) > 0 {
		record.Diff = diff
	}

	h.audit.Record(ctx, record)
}

func (h *AdminReviewHandlers) recordReplyAudit(ctx context.Context, identity *auth.Identity, review services.Review, visible bool) {
	if h.audit == nil {
		return
	}

	actor := ""
	if identity != nil {
		actor = strings.TrimSpace(identity.UID)
	}

	metadata := map[string]any{
		"reviewId": review.ID,
		"orderId":  review.OrderRef,
		"userId":   review.UserRef,
		"visible":  visible,
	}
	if review.Reply != nil {
		metadata["messageLength"] = len(strings.TrimSpace(review.Reply.Message))
	}

	record := services.AuditLogRecord{
		Actor:      actor,
		ActorType:  adminReviewActorType(identity),
		Action:     "review.reply.store",
		TargetRef:  fmt.Sprintf("/reviews/%s/reply", strings.TrimSpace(review.ID)),
		OccurredAt: h.now(),
		Metadata:   metadata,
	}
	h.audit.Record(ctx, record)
}

func (h *AdminReviewHandlers) now() time.Time {
	if h != nil && h.clock != nil {
		return h.clock()
	}
	return time.Now().UTC()
}

type adminModerateReviewRequest struct {
	Action string `json:"action"`
	Reason string `json:"reason"`
}

type adminStoreReplyRequest struct {
	Message string `json:"message"`
	Visible *bool  `json:"visible"`
}

type adminReviewResponse struct {
	Review adminReviewPayload `json:"review"`
}

type adminReviewListResponse struct {
	Items         []adminReviewPayload `json:"items"`
	NextPageToken string               `json:"next_page_token,omitempty"`
}

type adminReviewPayload struct {
	ID          string                   `json:"id"`
	OrderID     string                   `json:"order_id"`
	UserID      string                   `json:"user_id"`
	Rating      int                      `json:"rating"`
	Comment     string                   `json:"comment"`
	Status      string                   `json:"status"`
	ModeratedBy *string                  `json:"moderated_by,omitempty"`
	ModeratedAt string                   `json:"moderated_at,omitempty"`
	Reply       *adminReviewReplyPayload `json:"reply,omitempty"`
	CreatedAt   string                   `json:"created_at"`
	UpdatedAt   string                   `json:"updated_at"`
}

type adminReviewReplyPayload struct {
	Message   string `json:"message"`
	AuthorID  string `json:"author_id"`
	Visible   bool   `json:"visible"`
	CreatedAt string `json:"created_at"`
	UpdatedAt string `json:"updated_at"`
}

func buildAdminReviewPayload(review services.Review) adminReviewPayload {
	payload := adminReviewPayload{
		ID:        strings.TrimSpace(review.ID),
		OrderID:   strings.TrimSpace(review.OrderRef),
		UserID:    strings.TrimSpace(review.UserRef),
		Rating:    review.Rating,
		Comment:   strings.TrimSpace(review.Comment),
		Status:    string(review.Status),
		CreatedAt: formatTime(review.CreatedAt),
		UpdatedAt: formatTime(review.UpdatedAt),
	}

	if review.ModeratedBy != nil {
		payload.ModeratedBy = cloneStringPointer(review.ModeratedBy)
	}
	if review.ModeratedAt != nil {
		payload.ModeratedAt = formatTime(*review.ModeratedAt)
	}

	if review.Reply != nil {
		payload.Reply = &adminReviewReplyPayload{
			Message:   strings.TrimSpace(review.Reply.Message),
			AuthorID:  strings.TrimSpace(review.Reply.AuthorRef),
			Visible:   review.Reply.Visible,
			CreatedAt: formatTime(review.Reply.CreatedAt),
			UpdatedAt: formatTime(review.Reply.UpdatedAt),
		}
	}

	return payload
}

func parseAdminReviewStatuses(values url.Values) ([]services.ReviewStatus, error) {
	rawValues := append([]string(nil), values["moderation"]...)

	if len(rawValues) == 0 {
		return nil, nil
	}

	seen := make(map[services.ReviewStatus]struct{})
	statuses := make([]services.ReviewStatus, 0, len(rawValues))

	for _, raw := range rawValues {
		parts := strings.Split(raw, ",")
		for _, part := range parts {
			value := strings.ToLower(strings.TrimSpace(part))
			if value == "" {
				continue
			}
			var status services.ReviewStatus
			switch value {
			case "pending":
				status = services.ReviewStatus(domain.ReviewStatusPending)
			case "approved":
				status = services.ReviewStatus(domain.ReviewStatusApproved)
			case "rejected":
				status = services.ReviewStatus(domain.ReviewStatusRejected)
			default:
				return nil, fmt.Errorf("unsupported moderation status %q", part)
			}
			if _, exists := seen[status]; !exists {
				seen[status] = struct{}{}
				statuses = append(statuses, status)
			}
		}
	}

	return statuses, nil
}

func firstQueryValue(values url.Values, keys ...string) string {
	for _, key := range keys {
		for _, candidate := range values[key] {
			if trimmed := strings.TrimSpace(candidate); trimmed != "" {
				return trimmed
			}
		}
	}
	return ""
}

func adminReviewActorType(identity *auth.Identity) string {
	if identity == nil {
		return ""
	}
	switch {
	case identity.HasRole(auth.RoleAdmin):
		return "admin"
	case identity.HasRole(auth.RoleStaff):
		return "staff"
	default:
		return "user"
	}
}
