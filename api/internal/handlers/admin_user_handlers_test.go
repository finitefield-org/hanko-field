package handlers

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"
	domain "github.com/hanko-field/api/internal/domain"
	"github.com/hanko-field/api/internal/platform/auth"
	"github.com/hanko-field/api/internal/repositories"
	"github.com/hanko-field/api/internal/services"
)

func TestAdminUserHandlers_SearchUsers_AdminSeesPII(t *testing.T) {
	service := &stubAdminUserService{
		searchFn: func(ctx context.Context, filter services.UserSearchFilter) (domain.CursorPage[services.UserAdminSummary], error) {
			if filter.Query != "alice" {
				t.Fatalf("expected query alice, got %s", filter.Query)
			}
			return domain.CursorPage[services.UserAdminSummary]{
				Items: []services.UserAdminSummary{
					{
						Profile: services.UserProfile{
							ID:           "user-1",
							DisplayName:  "Alice Admin",
							Email:        "alice@example.com",
							PhoneNumber:  "+819012345678",
							Roles:        []string{"user"},
							IsActive:     true,
							CreatedAt:    time.Date(2024, 5, 10, 8, 0, 0, 0, time.UTC),
							UpdatedAt:    time.Date(2024, 5, 20, 8, 0, 0, 0, time.UTC),
							LastSyncTime: time.Date(2024, 5, 20, 8, 0, 0, 0, time.UTC),
						},
					},
				},
			}, nil
		},
	}

	handler := NewAdminUserHandlers(nil, service, nil, nil)
	req := httptest.NewRequest(http.MethodGet, "/users?query=alice", nil)
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{
		UID:   "admin-user",
		Roles: []string{auth.RoleAdmin},
	}))
	rec := httptest.NewRecorder()

	handler.searchUsers(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", rec.Code)
	}

	var payload adminUserSearchResponse
	if err := json.NewDecoder(rec.Body).Decode(&payload); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if len(payload.Items) != 1 {
		t.Fatalf("expected 1 item, got %d", len(payload.Items))
	}
	item := payload.Items[0]
	if item.Profile.Email != "alice@example.com" {
		t.Fatalf("expected unmasked email, got %s", item.Profile.Email)
	}
	if item.Profile.PhoneNumber != "+819012345678" {
		t.Fatalf("expected unmasked phone, got %s", item.Profile.PhoneNumber)
	}
}

func TestAdminUserHandlers_SearchUsers_StaffMaskedPII(t *testing.T) {
	service := &stubAdminUserService{
		searchFn: func(ctx context.Context, filter services.UserSearchFilter) (domain.CursorPage[services.UserAdminSummary], error) {
			return domain.CursorPage[services.UserAdminSummary]{
				Items: []services.UserAdminSummary{
					{
						Profile: services.UserProfile{
							ID:          "user-2",
							DisplayName: "Bob Staff",
							Email:       "bob.staff@example.com",
							PhoneNumber: "+81-90-0000-1111",
							IsActive:    true,
						},
						Flags: []string{"inactive"},
					},
				},
			}, nil
		},
	}

	handler := NewAdminUserHandlers(nil, service, nil, nil)
	req := httptest.NewRequest(http.MethodGet, "/users?query=bob", nil)
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{
		UID:   "staff-user",
		Roles: []string{auth.RoleStaff},
	}))
	rec := httptest.NewRecorder()

	handler.searchUsers(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", rec.Code)
	}

	var payload adminUserSearchResponse
	if err := json.NewDecoder(rec.Body).Decode(&payload); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	item := payload.Items[0]
	if strings.Contains(item.Profile.Email, "bob") {
		t.Fatalf("expected masked email, got %s", item.Profile.Email)
	}
	if strings.Contains(item.Profile.PhoneNumber, "1111") == false {
		t.Fatalf("expected masked phone to include last digits, got %s", item.Profile.PhoneNumber)
	}
}

func TestAdminUserHandlers_GetUserDetail_BuildsSummary(t *testing.T) {
	now := time.Date(2024, 8, 1, 9, 0, 0, 0, time.UTC)
	service := &stubAdminUserService{
		detailFn: func(ctx context.Context, userID string) (services.UserAdminDetail, error) {
			if userID != "user-detail" {
				t.Fatalf("expected user-detail id, got %s", userID)
			}
			lastLogin := now.Add(-2 * time.Hour)
			lastRefresh := now.Add(-1 * time.Hour)
			return services.UserAdminDetail{
				Profile: services.UserProfile{
					ID:           "user-detail",
					DisplayName:  "Detail D",
					Email:        "detail@example.com",
					PhoneNumber:  "+81-90-1234-5678",
					Roles:        []string{"user"},
					IsActive:     false,
					ProviderData: []domain.AuthProvider{{ProviderID: "google.com", UID: "google-uid", Email: "detail@example.com"}},
					CreatedAt:    now.Add(-48 * time.Hour),
					UpdatedAt:    now.Add(-4 * time.Hour),
				},
				Flags:         []string{"inactive"},
				LastLoginAt:   &lastLogin,
				LastRefreshAt: &lastRefresh,
				EmailVerified: true,
				AuthDisabled:  true,
			}, nil
		},
	}

	orderService := &stubAdminOrderService{
		listFn: func(ctx context.Context, filter services.OrderListFilter) (domain.CursorPage[services.Order], error) {
			if filter.UserID != "user-detail" {
				t.Fatalf("expected user-detail order filter, got %s", filter.UserID)
			}
			return domain.CursorPage[services.Order]{
				Items: []services.Order{
					{
						ID:          "order-1",
						OrderNumber: "HF-001",
						Status:      domain.OrderStatusPaid,
						Currency:    "JPY",
						Totals:      services.OrderTotals{Total: 12000},
						CreatedAt:   now.Add(-3 * time.Hour),
						UpdatedAt:   now.Add(-2 * time.Hour),
						PlacedAt:    ptrTime(now.Add(-3 * time.Hour)),
					},
					{
						ID:          "order-2",
						OrderNumber: "HF-000",
						Status:      domain.OrderStatusCompleted,
						Currency:    "JPY",
						Totals:      services.OrderTotals{Total: 8000},
						CreatedAt:   now.Add(-24 * time.Hour),
						UpdatedAt:   now.Add(-20 * time.Hour),
						PlacedAt:    ptrTime(now.Add(-24 * time.Hour)),
					},
				},
				NextPageToken: "",
			}, nil
		},
	}

	handler := NewAdminUserHandlers(nil, service, orderService, nil)
	handler.clock = func() time.Time { return now }

	req := httptest.NewRequest(http.MethodGet, "/users/user-detail", nil)
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{
		UID:   "staff-user",
		Roles: []string{auth.RoleStaff},
	}))
	routeCtx := chi.NewRouteContext()
	routeCtx.URLParams.Add("userID", "user-detail")
	req = req.WithContext(context.WithValue(req.Context(), chi.RouteCtxKey, routeCtx))
	rec := httptest.NewRecorder()

	handler.getUserDetail(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", rec.Code)
	}

	var payload adminUserDetailResponse
	if err := json.NewDecoder(rec.Body).Decode(&payload); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if payload.Profile.ID != "user-detail" {
		t.Fatalf("unexpected profile id %s", payload.Profile.ID)
	}
	if payload.Profile.Email == "detail@example.com" {
		t.Fatalf("expected masked email for staff, got %s", payload.Profile.Email)
	}
	if payload.EmailVerified != true || payload.AuthDisabled != true {
		t.Fatalf("expected auth state true/true, got %v/%v", payload.EmailVerified, payload.AuthDisabled)
	}
	if payload.Orders.TotalCount != 2 {
		t.Fatalf("expected total orders 2, got %d", payload.Orders.TotalCount)
	}
	if payload.Orders.OpenCount != 1 {
		t.Fatalf("expected open count 1, got %d", payload.Orders.OpenCount)
	}
	if payload.Orders.LastOrder == nil || payload.Orders.LastOrder.ID != "order-1" {
		t.Fatalf("expected last order order-1, got %+v", payload.Orders.LastOrder)
	}
	if len(payload.Providers) != 1 || payload.Providers[0].ProviderID != "google.com" {
		t.Fatalf("expected provider google.com, got %+v", payload.Providers)
	}
}

func TestAdminUserHandlers_GetUserDetail_NotFound(t *testing.T) {
	service := &stubAdminUserService{
		detailFn: func(ctx context.Context, userID string) (services.UserAdminDetail, error) {
			return services.UserAdminDetail{}, notFoundRepoError{}
		},
	}
	handler := NewAdminUserHandlers(nil, service, nil, nil)
	req := httptest.NewRequest(http.MethodGet, "/users/missing", nil)
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{
		UID:   "admin",
		Roles: []string{auth.RoleAdmin},
	}))
	routeCtx := chi.NewRouteContext()
	routeCtx.URLParams.Add("userID", "missing")
	req = req.WithContext(context.WithValue(req.Context(), chi.RouteCtxKey, routeCtx))
	rec := httptest.NewRecorder()

	handler.getUserDetail(rec, req)

	if rec.Code != http.StatusNotFound {
		t.Fatalf("expected status 404, got %d", rec.Code)
	}
}

func TestAdminUserHandlers_DeactivateAndMask_Success(t *testing.T) {
	var captured services.DeactivateAndMaskCommand
	service := &stubAdminUserService{
		deactivateFn: func(ctx context.Context, cmd services.DeactivateAndMaskCommand) (services.UserProfile, error) {
			captured = cmd
			return services.UserProfile{
				ID:          "user-5",
				DisplayName: "Masked User",
				Email:       "masked+user-5@hanko-field.invalid",
				IsActive:    false,
			}, nil
		},
	}
	handler := NewAdminUserHandlers(nil, service, nil, nil)

	req := httptest.NewRequest(http.MethodPost, "/users/user-5:deactivate-and-mask", strings.NewReader(`{"reason":"gdpr"}`))
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{
		UID:   "admin-1",
		Roles: []string{auth.RoleAdmin},
	}))
	routeCtx := chi.NewRouteContext()
	routeCtx.URLParams.Add("userID", "user-5")
	req = req.WithContext(context.WithValue(req.Context(), chi.RouteCtxKey, routeCtx))
	rec := httptest.NewRecorder()

	handler.deactivateAndMaskUser(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", rec.Code)
	}

	if captured.UserID != "user-5" || captured.ActorID != "admin-1" || captured.Reason != "gdpr" {
		t.Fatalf("unexpected command capture %+v", captured)
	}

	var payload adminUserDeactivateResponse
	if err := json.NewDecoder(rec.Body).Decode(&payload); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if payload.Profile.ID != "user-5" {
		t.Fatalf("unexpected profile id %s", payload.Profile.ID)
	}
	if payload.Profile.Email != "masked+user-5@hanko-field.invalid" {
		t.Fatalf("expected masked email to be returned, got %s", payload.Profile.Email)
	}
}

func TestAdminUserHandlers_DeactivateAndMask_StaffForbidden(t *testing.T) {
	called := false
	service := &stubAdminUserService{
		deactivateFn: func(ctx context.Context, cmd services.DeactivateAndMaskCommand) (services.UserProfile, error) {
			called = true
			return services.UserProfile{}, nil
		},
	}
	handler := NewAdminUserHandlers(nil, service, nil, nil)

	req := httptest.NewRequest(http.MethodPost, "/users/user-6:deactivate-and-mask", strings.NewReader(`{"reason":"gdpr"}`))
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{
		UID:   "staff-1",
		Roles: []string{auth.RoleStaff},
	}))
	routeCtx := chi.NewRouteContext()
	routeCtx.URLParams.Add("userID", "user-6")
	req = req.WithContext(context.WithValue(req.Context(), chi.RouteCtxKey, routeCtx))
	rec := httptest.NewRecorder()

	handler.deactivateAndMaskUser(rec, req)

	if rec.Code != http.StatusForbidden {
		t.Fatalf("expected status 403, got %d", rec.Code)
	}
	if called {
		t.Fatalf("expected service not to be called for staff identity")
	}
}

func TestAdminUserHandlers_DeactivateAndMask_InvalidJSON(t *testing.T) {
	service := &stubAdminUserService{
		deactivateFn: func(ctx context.Context, cmd services.DeactivateAndMaskCommand) (services.UserProfile, error) {
			t.Fatalf("service should not be invoked on invalid payload")
			return services.UserProfile{}, nil
		},
	}
	handler := NewAdminUserHandlers(nil, service, nil, nil)

	req := httptest.NewRequest(http.MethodPost, "/users/user-7:deactivate-and-mask", strings.NewReader(`{"reason":123}`))
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{
		UID:   "admin-1",
		Roles: []string{auth.RoleAdmin},
	}))
	routeCtx := chi.NewRouteContext()
	routeCtx.URLParams.Add("userID", "user-7")
	req = req.WithContext(context.WithValue(req.Context(), chi.RouteCtxKey, routeCtx))
	rec := httptest.NewRecorder()

	handler.deactivateAndMaskUser(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected status 400 for invalid payload, got %d", rec.Code)
	}
}

type stubAdminUserService struct {
	searchFn     func(context.Context, services.UserSearchFilter) (domain.CursorPage[services.UserAdminSummary], error)
	detailFn     func(context.Context, string) (services.UserAdminDetail, error)
	deactivateFn func(context.Context, services.DeactivateAndMaskCommand) (services.UserProfile, error)
}

func (s *stubAdminUserService) SearchProfiles(ctx context.Context, filter services.UserSearchFilter) (domain.CursorPage[services.UserAdminSummary], error) {
	if s != nil && s.searchFn != nil {
		return s.searchFn(ctx, filter)
	}
	return domain.CursorPage[services.UserAdminSummary]{}, nil
}

func (s *stubAdminUserService) GetAdminDetail(ctx context.Context, userID string) (services.UserAdminDetail, error) {
	if s != nil && s.detailFn != nil {
		return s.detailFn(ctx, userID)
	}
	return services.UserAdminDetail{}, nil
}

func (s *stubAdminUserService) DeactivateAndMask(ctx context.Context, cmd services.DeactivateAndMaskCommand) (services.UserProfile, error) {
	if s != nil && s.deactivateFn != nil {
		return s.deactivateFn(ctx, cmd)
	}
	return services.UserProfile{}, nil
}

// Remaining UserService interface methods are unused in these tests.
func (s *stubAdminUserService) GetProfile(context.Context, string) (services.UserProfile, error) {
	return services.UserProfile{}, nil
}

func (s *stubAdminUserService) GetByUID(context.Context, string) (services.UserProfile, error) {
	return services.UserProfile{}, nil
}

func (s *stubAdminUserService) UpdateProfile(context.Context, services.UpdateProfileCommand) (services.UserProfile, error) {
	return services.UserProfile{}, nil
}

func (s *stubAdminUserService) MaskProfile(context.Context, services.MaskProfileCommand) (services.UserProfile, error) {
	return services.UserProfile{}, nil
}

func (s *stubAdminUserService) SetUserActive(context.Context, services.SetUserActiveCommand) (services.UserProfile, error) {
	return services.UserProfile{}, nil
}

func (s *stubAdminUserService) ListAddresses(context.Context, string) ([]services.Address, error) {
	return nil, nil
}

func (s *stubAdminUserService) UpsertAddress(context.Context, services.UpsertAddressCommand) (services.Address, error) {
	return services.Address{}, nil
}

func (s *stubAdminUserService) DeleteAddress(context.Context, services.DeleteAddressCommand) error {
	return nil
}

func (s *stubAdminUserService) ListPaymentMethods(context.Context, string) ([]services.PaymentMethod, error) {
	return nil, nil
}

func (s *stubAdminUserService) AddPaymentMethod(context.Context, services.AddPaymentMethodCommand) (services.PaymentMethod, error) {
	return services.PaymentMethod{}, nil
}

func (s *stubAdminUserService) RemovePaymentMethod(context.Context, services.RemovePaymentMethodCommand) error {
	return nil
}

func (s *stubAdminUserService) ListFavorites(context.Context, string, services.Pagination) (domain.CursorPage[services.FavoriteDesign], error) {
	return domain.CursorPage[services.FavoriteDesign]{}, nil
}

func (s *stubAdminUserService) ToggleFavorite(context.Context, services.ToggleFavoriteCommand) error {
	return nil
}

type stubAdminOrderService struct {
	listFn func(context.Context, services.OrderListFilter) (domain.CursorPage[services.Order], error)
}

func (s *stubAdminOrderService) ListOrders(ctx context.Context, filter services.OrderListFilter) (domain.CursorPage[services.Order], error) {
	if s != nil && s.listFn != nil {
		return s.listFn(ctx, filter)
	}
	return domain.CursorPage[services.Order]{}, nil
}

// Remaining OrderService methods are no-ops for these tests.
func (s *stubAdminOrderService) CreateFromCart(context.Context, services.CreateOrderFromCartCommand) (services.Order, error) {
	return services.Order{}, nil
}

func (s *stubAdminOrderService) GetOrder(context.Context, string, services.OrderReadOptions) (services.Order, error) {
	return services.Order{}, nil
}

func (s *stubAdminOrderService) TransitionStatus(context.Context, services.OrderStatusTransitionCommand) (services.Order, error) {
	return services.Order{}, nil
}

func (s *stubAdminOrderService) Cancel(context.Context, services.CancelOrderCommand) (services.Order, error) {
	return services.Order{}, nil
}

func (s *stubAdminOrderService) AppendProductionEvent(context.Context, services.AppendProductionEventCommand) (services.OrderProductionEvent, error) {
	return services.OrderProductionEvent{}, nil
}

func (s *stubAdminOrderService) AssignOrderToQueue(context.Context, services.AssignOrderToQueueCommand) (services.Order, error) {
	return services.Order{}, nil
}

func (s *stubAdminOrderService) RequestInvoice(context.Context, services.RequestInvoiceCommand) (services.Order, error) {
	return services.Order{}, nil
}

func (s *stubAdminOrderService) CloneForReorder(context.Context, services.CloneForReorderCommand) (services.Order, error) {
	return services.Order{}, nil
}

func ptrTime(t time.Time) *time.Time {
	return &t
}

type notFoundRepoError struct{}

func (notFoundRepoError) Error() string       { return "not found" }
func (notFoundRepoError) IsNotFound() bool    { return true }
func (notFoundRepoError) IsConflict() bool    { return false }
func (notFoundRepoError) IsUnavailable() bool { return false }

var _ repositories.RepositoryError = (*notFoundRepoError)(nil)
