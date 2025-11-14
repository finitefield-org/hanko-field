package handlers

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"

	domain "github.com/hanko-field/api/internal/domain"
	"github.com/hanko-field/api/internal/platform/auth"
	"github.com/hanko-field/api/internal/platform/httpx"
	"github.com/hanko-field/api/internal/repositories"
	"github.com/hanko-field/api/internal/services"
)

const (
	defaultAdminUserSearchPageSize = 25
	maxAdminUserSearchPageSize     = 100
	adminUserRecentOrdersLimit     = 5
	adminUserOrderPageSize         = 50
	adminUserOrderMaxPages         = 4
	maxAdminUserDeactivateBody     = 4 * 1024
)

// AdminUserHandlers exposes admin endpoints for user search and detail views.
type AdminUserHandlers struct {
	authn  *auth.Authenticator
	users  services.UserService
	orders services.OrderService
	audit  services.AuditLogService
	clock  func() time.Time
}

// NewAdminUserHandlers constructs the handler set for admin user management.
func NewAdminUserHandlers(authn *auth.Authenticator, users services.UserService, orders services.OrderService, audit services.AuditLogService) *AdminUserHandlers {
	return &AdminUserHandlers{
		authn:  authn,
		users:  users,
		orders: orders,
		audit:  audit,
		clock:  time.Now,
	}
}

// Routes registers admin user endpoints.
func (h *AdminUserHandlers) Routes(r chi.Router) {
	if r == nil {
		return
	}
	if h.authn != nil {
		r.Use(h.authn.RequireFirebaseAuth(auth.RoleAdmin, auth.RoleStaff))
	}
	r.Get("/users", h.searchUsers)
	r.Get("/users/{userID}", h.getUserDetail)
	r.Post("/users/{userID}:deactivate-and-mask", h.deactivateAndMaskUser)
}

func (h *AdminUserHandlers) searchUsers(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	if h.users == nil {
		httpx.WriteError(ctx, w, httpx.NewError("user_service_unavailable", "user service unavailable", http.StatusServiceUnavailable))
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
	query := strings.TrimSpace(firstNonEmpty(values.Get("query"), values.Get("q")))
	if query == "" {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "query parameter is required", http.StatusBadRequest))
		return
	}

	pageSize := defaultAdminUserSearchPageSize
	if raw := strings.TrimSpace(firstNonEmpty(values.Get("page_size"), values.Get("pageSize"))); raw != "" {
		size, err := strconv.Atoi(raw)
		if err != nil {
			httpx.WriteError(ctx, w, httpx.NewError("invalid_page_size", "page_size must be an integer", http.StatusBadRequest))
			return
		}
		switch {
		case size <= 0:
			pageSize = defaultAdminUserSearchPageSize
		case size > maxAdminUserSearchPageSize:
			pageSize = maxAdminUserSearchPageSize
		default:
			pageSize = size
		}
	}

	includeInactive, _, boolErr := parseBoolParam(values, "include_inactive", "includeInactive")
	if boolErr != nil {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_include_inactive", boolErr.Error(), http.StatusBadRequest))
		return
	}

	filter := services.UserSearchFilter{
		Query:           query,
		PageSize:        pageSize,
		PageToken:       strings.TrimSpace(firstNonEmpty(values.Get("page_token"), values.Get("pageToken"))),
		IncludeInactive: includeInactive,
	}

	page, err := h.users.SearchProfiles(ctx, filter)
	if err != nil {
		writeAdminUserError(ctx, w, err)
		return
	}

	allowPII := identity.HasRole(auth.RoleAdmin)
	items := make([]adminUserListItem, 0, len(page.Items))
	for _, summary := range page.Items {
		items = append(items, buildAdminUserListItem(summary, allowPII))
	}

	response := adminUserSearchResponse{
		Items:         items,
		NextPageToken: strings.TrimSpace(page.NextPageToken),
	}

	writeJSONResponse(w, http.StatusOK, response)
	h.recordUserAudit(ctx, identity, "admin.user.search", "/users:search", map[string]any{
		"query":        query,
		"result_count": len(items),
		"page_size":    pageSize,
	})
}

func (h *AdminUserHandlers) getUserDetail(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	if h.users == nil {
		httpx.WriteError(ctx, w, httpx.NewError("user_service_unavailable", "user service unavailable", http.StatusServiceUnavailable))
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

	userID := strings.TrimSpace(chi.URLParam(r, "userID"))
	if userID == "" {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "user id is required", http.StatusBadRequest))
		return
	}

	detail, err := h.users.GetAdminDetail(ctx, userID)
	if err != nil {
		writeAdminUserError(ctx, w, err)
		return
	}

	allowPII := identity.HasRole(auth.RoleAdmin)
	profile := buildAdminUserProfile(detail.Profile, allowPII)
	orders, err := h.buildOrdersSummary(ctx, userID)
	if err != nil {
		writeOrderError(ctx, w, err)
		return
	}

	response := adminUserDetailResponse{
		Profile:       profile,
		Flags:         detail.Flags,
		LastLoginAt:   formatTime(pointerTime(detail.LastLoginAt)),
		LastRefreshAt: formatTime(pointerTime(detail.LastRefreshAt)),
		EmailVerified: detail.EmailVerified,
		AuthDisabled:  detail.AuthDisabled,
		Orders:        orders,
		Providers:     buildAdminUserProviders(detail.Profile.ProviderData),
	}

	writeJSONResponse(w, http.StatusOK, response)
	h.recordUserAudit(ctx, identity, "admin.user.view", "/users/"+userID, map[string]any{
		"user_id": userID,
		"flags":   detail.Flags,
	})
}

func (h *AdminUserHandlers) deactivateAndMaskUser(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	if h.users == nil {
		httpx.WriteError(ctx, w, httpx.NewError("user_service_unavailable", "user service unavailable", http.StatusServiceUnavailable))
		return
	}

	identity, ok := auth.IdentityFromContext(ctx)
	if !ok || identity == nil || strings.TrimSpace(identity.UID) == "" {
		httpx.WriteError(ctx, w, httpx.NewError("unauthenticated", "authentication required", http.StatusUnauthorized))
		return
	}
	if !identity.HasRole(auth.RoleAdmin) {
		httpx.WriteError(ctx, w, httpx.NewError("insufficient_role", "admin role required", http.StatusForbidden))
		return
	}

	userID := strings.TrimSpace(chi.URLParam(r, "userID"))
	if userID == "" {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "user id is required", http.StatusBadRequest))
		return
	}

	var payload adminUserDeactivateRequest
	if r.Body != nil {
		defer r.Body.Close()
		raw, err := io.ReadAll(io.LimitReader(r.Body, maxAdminUserDeactivateBody+1))
		if err != nil {
			httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "failed to read request body", http.StatusBadRequest))
			return
		}
		if len(raw) > maxAdminUserDeactivateBody {
			httpx.WriteError(ctx, w, httpx.NewError("request_too_large", "request body too large", http.StatusRequestEntityTooLarge))
			return
		}
		raw = bytes.TrimSpace(raw)
		if len(raw) > 0 {
			if err := json.Unmarshal(raw, &payload); err != nil {
				httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "invalid JSON body", http.StatusBadRequest))
				return
			}
		}
	}

	reason := strings.TrimSpace(payload.Reason)
	profile, err := h.users.DeactivateAndMask(ctx, services.DeactivateAndMaskCommand{
		UserID:  userID,
		ActorID: strings.TrimSpace(identity.UID),
		Reason:  reason,
	})
	if err != nil {
		writeAdminUserError(ctx, w, err)
		return
	}

	response := adminUserDeactivateResponse{
		Profile: buildAdminUserProfile(profile, true),
	}
	writeJSONResponse(w, http.StatusOK, response)

	metadata := map[string]any{
		"user_id": userID,
	}
	if reason != "" {
		metadata["reason"] = reason
	}
	h.recordUserAudit(ctx, identity, "admin.user.deactivate_mask", fmt.Sprintf("/users/%s:deactivate-and-mask", userID), metadata)
}

func (h *AdminUserHandlers) buildOrdersSummary(ctx context.Context, userID string) (adminUserOrdersSummary, error) {
	summary := adminUserOrdersSummary{}
	if h.orders == nil {
		return summary, nil
	}

	pageToken := ""
	pages := 0
	recent := make([]adminUserOrderSummary, 0, adminUserRecentOrdersLimit)
	for {
		if pages >= adminUserOrderMaxPages {
			break
		}
		filter := services.OrderListFilter{
			UserID:    userID,
			SortBy:    services.OrderSortCreatedAt,
			SortOrder: services.SortDesc,
			Pagination: services.Pagination{
				PageSize:  adminUserOrderPageSize,
				PageToken: pageToken,
			},
		}
		page, err := h.orders.ListOrders(ctx, filter)
		if err != nil {
			return adminUserOrdersSummary{}, err
		}
		if len(page.Items) == 0 {
			break
		}

		for _, order := range page.Items {
			summary.TotalCount++
			if isOpenAdminOrderStatus(order.Status) {
				summary.OpenCount++
			}
			converted := buildAdminUserOrderSummary(order)
			if len(recent) < adminUserRecentOrdersLimit {
				recent = append(recent, converted)
			}
		}

		if page.NextPageToken == "" {
			break
		}
		pageToken = page.NextPageToken
		pages++
	}

	summary.Recent = recent
	if len(recent) > 0 {
		first := recent[0]
		summary.LastOrder = &first
	}
	return summary, nil
}

func (h *AdminUserHandlers) recordUserAudit(ctx context.Context, identity *auth.Identity, action string, target string, metadata map[string]any) {
	if h.audit == nil {
		return
	}
	actorID := ""
	actorType := "staff"
	if identity != nil {
		actorID = strings.TrimSpace(identity.UID)
		switch {
		case identity.HasRole(auth.RoleAdmin):
			actorType = "admin"
		case identity.HasRole(auth.RoleStaff):
			actorType = "staff"
		default:
			actorType = "user"
		}
	}

	record := services.AuditLogRecord{
		Actor:      actorID,
		ActorType:  actorType,
		Action:     action,
		TargetRef:  target,
		OccurredAt: h.now(),
		Metadata:   metadata,
	}
	h.audit.Record(ctx, record)
}

func (h *AdminUserHandlers) now() time.Time {
	if h != nil && h.clock != nil {
		return h.clock().UTC()
	}
	return time.Now().UTC()
}

func writeAdminUserError(ctx context.Context, w http.ResponseWriter, err error) {
	if err == nil {
		return
	}
	switch {
	case errors.Is(err, services.ErrUserSearchInvalidQuery):
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", err.Error(), http.StatusBadRequest))
		return
	case errors.Is(err, services.ErrUserSearchUnavailable):
		httpx.WriteError(ctx, w, httpx.NewError("user_search_unavailable", "user search unavailable", http.StatusServiceUnavailable))
		return
	}

	var repoErr repositories.RepositoryError
	if errors.As(err, &repoErr) {
		switch {
		case repoErr.IsNotFound():
			httpx.WriteError(ctx, w, httpx.NewError("user_not_found", "user not found", http.StatusNotFound))
			return
		case repoErr.IsUnavailable():
			httpx.WriteError(ctx, w, httpx.NewError("user_service_unavailable", "user service unavailable", http.StatusServiceUnavailable))
			return
		default:
			httpx.WriteError(ctx, w, httpx.NewError("user_service_error", "user service error", http.StatusInternalServerError))
			return
		}
	}

	httpx.WriteError(ctx, w, httpx.NewError("user_error", "failed to process user request", http.StatusInternalServerError))
}

func buildAdminUserListItem(summary services.UserAdminSummary, allowPII bool) adminUserListItem {
	return adminUserListItem{
		Profile:     buildAdminUserProfile(summary.Profile, allowPII),
		Flags:       append([]string(nil), summary.Flags...),
		LastLoginAt: formatTime(pointerTime(summary.LastLoginAt)),
	}
}

func buildAdminUserProfile(profile services.UserProfile, allowPII bool) adminUserProfile {
	email := strings.TrimSpace(profile.Email)
	phone := strings.TrimSpace(profile.PhoneNumber)

	if !allowPII {
		email = maskEmail(email)
		phone = maskPhone(phone)
	}

	var maskedAt string
	if profile.PiiMaskedAt != nil {
		maskedAt = formatTime(pointerTime(profile.PiiMaskedAt))
	}

	return adminUserProfile{
		ID:                strings.TrimSpace(profile.ID),
		DisplayName:       strings.TrimSpace(profile.DisplayName),
		Email:             email,
		PhoneNumber:       phone,
		Roles:             append([]string(nil), profile.Roles...),
		IsActive:          profile.IsActive,
		PreferredLanguage: strings.TrimSpace(profile.PreferredLanguage),
		Locale:            strings.TrimSpace(profile.Locale),
		PiiMaskedAt:       maskedAt,
		CreatedAt:         formatTime(profile.CreatedAt),
		UpdatedAt:         formatTime(profile.UpdatedAt),
	}
}

func buildAdminUserProviders(providers []domain.AuthProvider) []adminUserProvider {
	if len(providers) == 0 {
		return nil
	}
	items := make([]adminUserProvider, 0, len(providers))
	for _, provider := range providers {
		items = append(items, adminUserProvider{
			ProviderID:  strings.TrimSpace(provider.ProviderID),
			UID:         strings.TrimSpace(provider.UID),
			Email:       strings.TrimSpace(provider.Email),
			DisplayName: strings.TrimSpace(provider.DisplayName),
		})
	}
	return items
}

func buildAdminUserOrderSummary(order services.Order) adminUserOrderSummary {
	return adminUserOrderSummary{
		ID:          strings.TrimSpace(order.ID),
		OrderNumber: strings.TrimSpace(order.OrderNumber),
		Status:      strings.TrimSpace(string(order.Status)),
		Currency:    strings.TrimSpace(order.Currency),
		Total:       order.Totals.Total,
		CreatedAt:   formatTime(order.CreatedAt),
		UpdatedAt:   formatTime(order.UpdatedAt),
		PlacedAt:    formatTime(pointerTime(order.PlacedAt)),
		PaidAt:      formatTime(pointerTime(order.PaidAt)),
	}
}

func isOpenAdminOrderStatus(status services.OrderStatus) bool {
	switch status {
	case services.OrderStatus(domain.OrderStatusCompleted),
		services.OrderStatus(domain.OrderStatusCanceled):
		return false
	default:
		return true
	}
}

func parseBoolParam(values url.Values, keys ...string) (bool, bool, error) {
	for _, key := range keys {
		raw := strings.TrimSpace(values.Get(key))
		if raw == "" {
			continue
		}
		switch strings.ToLower(raw) {
		case "1", "true", "yes", "on":
			return true, true, nil
		case "0", "false", "no", "off":
			return false, true, nil
		default:
			return false, true, fmt.Errorf("invalid boolean value for %s", key)
		}
	}
	return false, false, nil
}

func maskEmail(email string) string {
	email = strings.TrimSpace(email)
	if email == "" {
		return ""
	}
	at := strings.Index(email, "@")
	if at <= 1 {
		return "***"
	}
	local := email[:at]
	domainPart := email[at+1:]
	if len(domainPart) == 0 {
		return local[:1] + "***"
	}
	suffix := ""
	if len(local) > 2 {
		suffix = local[len(local)-1:]
	}
	return local[:1] + "***" + suffix + "@" + domainPart
}

func maskPhone(phone string) string {
	phone = strings.TrimSpace(phone)
	if phone == "" {
		return ""
	}
	if len(phone) <= 4 {
		return "***"
	}
	return "***" + phone[len(phone)-4:]
}

type adminUserSearchResponse struct {
	Items         []adminUserListItem `json:"items"`
	NextPageToken string              `json:"next_page_token,omitempty"`
}

type adminUserListItem struct {
	Profile     adminUserProfile `json:"profile"`
	Flags       []string         `json:"flags,omitempty"`
	LastLoginAt string           `json:"last_login_at,omitempty"`
}

type adminUserDetailResponse struct {
	Profile       adminUserProfile       `json:"profile"`
	Flags         []string               `json:"flags,omitempty"`
	LastLoginAt   string                 `json:"last_login_at,omitempty"`
	LastRefreshAt string                 `json:"last_refresh_at,omitempty"`
	EmailVerified bool                   `json:"email_verified"`
	AuthDisabled  bool                   `json:"auth_disabled"`
	Orders        adminUserOrdersSummary `json:"orders"`
	Providers     []adminUserProvider    `json:"providers,omitempty"`
}

type adminUserDeactivateRequest struct {
	Reason string `json:"reason"`
}

type adminUserDeactivateResponse struct {
	Profile adminUserProfile `json:"profile"`
}

type adminUserProfile struct {
	ID                string   `json:"id"`
	DisplayName       string   `json:"display_name"`
	Email             string   `json:"email,omitempty"`
	PhoneNumber       string   `json:"phone_number,omitempty"`
	Roles             []string `json:"roles,omitempty"`
	IsActive          bool     `json:"is_active"`
	PreferredLanguage string   `json:"preferred_language,omitempty"`
	Locale            string   `json:"locale,omitempty"`
	PiiMaskedAt       string   `json:"pii_masked_at,omitempty"`
	CreatedAt         string   `json:"created_at"`
	UpdatedAt         string   `json:"updated_at,omitempty"`
}

type adminUserOrdersSummary struct {
	TotalCount int                     `json:"total_count"`
	OpenCount  int                     `json:"open_count"`
	LastOrder  *adminUserOrderSummary  `json:"last_order,omitempty"`
	Recent     []adminUserOrderSummary `json:"recent,omitempty"`
}

type adminUserOrderSummary struct {
	ID          string `json:"id"`
	OrderNumber string `json:"order_number"`
	Status      string `json:"status"`
	Currency    string `json:"currency"`
	Total       int64  `json:"total"`
	CreatedAt   string `json:"created_at"`
	UpdatedAt   string `json:"updated_at,omitempty"`
	PlacedAt    string `json:"placed_at,omitempty"`
	PaidAt      string `json:"paid_at,omitempty"`
}

type adminUserProvider struct {
	ProviderID  string `json:"provider_id"`
	UID         string `json:"uid"`
	Email       string `json:"email,omitempty"`
	DisplayName string `json:"display_name,omitempty"`
}
