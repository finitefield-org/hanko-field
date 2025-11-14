package handlers

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"

	domain "github.com/hanko-field/api/internal/domain"
	"github.com/hanko-field/api/internal/platform/auth"
	"github.com/hanko-field/api/internal/services"
)

func TestAdminReviewHandlers_ListReviews_Success(t *testing.T) {
	var capturedFilter services.ReviewListFilter
	service := &stubAdminReviewService{
		listFunc: func(ctx context.Context, filter services.ReviewListFilter) (domain.CursorPage[services.Review], error) {
			capturedFilter = filter
			approvedAt := time.Date(2024, 6, 1, 12, 0, 0, 0, time.UTC)
			return domain.CursorPage[services.Review]{
				Items: []services.Review{
					{
						ID:       "rev_123",
						OrderRef: "order-1",
						UserRef:  "user-1",
						Rating:   5,
						Comment:  "Excellent product",
						Status:   domain.ReviewStatusPending,
						ModeratedBy: func() *string {
							v := "staff-1"
							return &v
						}(),
						ModeratedAt: &approvedAt,
						Reply: &services.ReviewReply{
							Message:   "Thanks!",
							AuthorRef: "staff-1",
							Visible:   true,
							CreatedAt: approvedAt,
							UpdatedAt: approvedAt,
						},
						CreatedAt: approvedAt.Add(-time.Hour),
						UpdatedAt: approvedAt,
					},
				},
				NextPageToken: " next-token ",
			}, nil
		},
	}

	handler := NewAdminReviewHandlers(nil, service, nil)
	req := httptest.NewRequest(http.MethodGet, "/reviews?moderation=pending&order_id=order-1&user_id=user-1&page_size=25&page_token=%20token%20", nil)
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{
		UID:   "staff-1",
		Roles: []string{auth.RoleStaff},
	}))
	rec := httptest.NewRecorder()

	handler.listReviews(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", rec.Code)
	}

	var payload adminReviewListResponse
	if err := json.NewDecoder(rec.Body).Decode(&payload); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if len(payload.Items) != 1 {
		t.Fatalf("expected one review item, got %d", len(payload.Items))
	}
	if payload.NextPageToken != "next-token" {
		t.Fatalf("expected trimmed next page token next-token, got %q", payload.NextPageToken)
	}

	review := payload.Items[0]
	if review.ID != "rev_123" || review.Status != "pending" {
		t.Fatalf("unexpected review payload: %#v", review)
	}
	if review.Reply == nil || review.Reply.Message != "Thanks!" || !review.Reply.Visible {
		t.Fatalf("expected reply with visibility, got %#v", review.Reply)
	}

	if capturedFilter.OrderRef != "order-1" {
		t.Fatalf("expected order filter order-1, got %q", capturedFilter.OrderRef)
	}
	if capturedFilter.UserRef != "user-1" {
		t.Fatalf("expected user filter user-1, got %q", capturedFilter.UserRef)
	}
	if capturedFilter.Pagination.PageSize != 25 {
		t.Fatalf("expected page size 25, got %d", capturedFilter.Pagination.PageSize)
	}
	if capturedFilter.Pagination.PageToken != "token" {
		t.Fatalf("expected trimmed page token token, got %q", capturedFilter.Pagination.PageToken)
	}
	if len(capturedFilter.Status) != 1 || capturedFilter.Status[0] != services.ReviewStatus(domain.ReviewStatusPending) {
		t.Fatalf("expected status filter pending, got %#v", capturedFilter.Status)
	}
}

func TestAdminReviewHandlers_ListReviews_InvalidStatus(t *testing.T) {
	handler := NewAdminReviewHandlers(nil, &stubAdminReviewService{}, nil)
	req := httptest.NewRequest(http.MethodGet, "/reviews?moderation=invalid", nil)
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{
		UID:   "admin-1",
		Roles: []string{auth.RoleAdmin},
	}))
	rec := httptest.NewRecorder()

	handler.listReviews(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected status 400, got %d", rec.Code)
	}
}

func TestAdminReviewHandlers_ModerateReview_Approve(t *testing.T) {
	now := time.Date(2024, 6, 2, 9, 30, 0, 0, time.UTC)
	var capturedCmd services.ModerateReviewCommand
	service := &stubAdminReviewService{
		listFunc: func(ctx context.Context, filter services.ReviewListFilter) (domain.CursorPage[services.Review], error) {
			return domain.CursorPage[services.Review]{
				Items: []services.Review{
					{
						ID:     "rev_42",
						Status: domain.ReviewStatusPending,
					},
				},
			}, nil
		},
		moderateFunc: func(ctx context.Context, cmd services.ModerateReviewCommand) (services.Review, error) {
			capturedCmd = cmd
			moderatedAt := now
			return services.Review{
				ID:       "rev_42",
				OrderRef: "order-9",
				UserRef:  "user-9",
				Status:   domain.ReviewStatusApproved,
				Comment:  "Looks good",
				ModeratedBy: func() *string {
					v := "staff-7"
					return &v
				}(),
				ModeratedAt: &moderatedAt,
				CreatedAt:   now.Add(-2 * time.Hour),
				UpdatedAt:   now,
			}, nil
		},
	}
	audit := &captureReviewAuditService{}
	handler := NewAdminReviewHandlers(nil, service, audit, WithAdminReviewClock(func() time.Time { return now }))

	body := `{"action":"approve","reason":"  fits policy "}`
	req := httptest.NewRequest(http.MethodPut, "/reviews/rev_42:moderate", bytes.NewBufferString(body))
	req.Header.Set("Content-Type", "application/json")
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{
		UID:   "staff-7",
		Roles: []string{auth.RoleStaff},
	}))
	routeCtx := chi.NewRouteContext()
	routeCtx.URLParams.Add("reviewID", "rev_42")
	req = req.WithContext(context.WithValue(req.Context(), chi.RouteCtxKey, routeCtx))
	rec := httptest.NewRecorder()

	handler.moderateReview(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", rec.Code)
	}

	if capturedCmd.ReviewID != "rev_42" {
		t.Fatalf("expected review id rev_42, got %q", capturedCmd.ReviewID)
	}
	if capturedCmd.ActorID != "staff-7" {
		t.Fatalf("expected actor staff-7, got %q", capturedCmd.ActorID)
	}
	if capturedCmd.Status != services.ReviewStatus(domain.ReviewStatusApproved) {
		t.Fatalf("expected status approve, got %q", capturedCmd.Status)
	}

	var payload adminReviewResponse
	if err := json.NewDecoder(rec.Body).Decode(&payload); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if payload.Review.Status != "approved" {
		t.Fatalf("expected approved status in payload, got %q", payload.Review.Status)
	}

	if len(audit.records) != 1 {
		t.Fatalf("expected one audit record, got %d", len(audit.records))
	}
	record := audit.records[0]
	if record.Action != "review.moderate" {
		t.Fatalf("expected audit action review.moderate, got %q", record.Action)
	}
	if record.Actor != "staff-7" || record.ActorType != "staff" {
		t.Fatalf("expected staff actor, got actor=%q type=%q", record.Actor, record.ActorType)
	}
	if record.OccurredAt != now {
		t.Fatalf("expected occurred at %s, got %s", now, record.OccurredAt)
	}
	if record.Metadata["reason"] != "fits policy" {
		t.Fatalf("expected trimmed reason fits policy, got %#v", record.Metadata["reason"])
	}
	diff, ok := record.Diff["status"]
	if !ok {
		t.Fatalf("expected status diff recorded, got %#v", record.Diff)
	}
	if diff.Before != string(domain.ReviewStatusPending) || diff.After != string(domain.ReviewStatusApproved) {
		t.Fatalf("unexpected diff: %#v", diff)
	}
}

func TestAdminReviewHandlers_ModerateReview_InvalidAction(t *testing.T) {
	handler := NewAdminReviewHandlers(nil, &stubAdminReviewService{}, nil)
	req := httptest.NewRequest(http.MethodPut, "/reviews/rev_1:moderate", bytes.NewBufferString(`{"action":"hold"}`))
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{
		UID:   "admin-1",
		Roles: []string{auth.RoleAdmin},
	}))
	routeCtx := chi.NewRouteContext()
	routeCtx.URLParams.Add("reviewID", "rev_1")
	req = req.WithContext(context.WithValue(req.Context(), chi.RouteCtxKey, routeCtx))
	rec := httptest.NewRecorder()

	handler.moderateReview(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected status 400, got %d", rec.Code)
	}
}

func TestAdminReviewHandlers_ModerateReview_InvalidStateError(t *testing.T) {
	service := &stubAdminReviewService{
		moderateFunc: func(ctx context.Context, cmd services.ModerateReviewCommand) (services.Review, error) {
			return services.Review{}, services.ErrReviewInvalidState
		},
	}
	handler := NewAdminReviewHandlers(nil, service, nil)

	req := httptest.NewRequest(http.MethodPut, "/reviews/rev_1:moderate", bytes.NewBufferString(`{"action":"reject"}`))
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{
		UID:   "admin-1",
		Roles: []string{auth.RoleAdmin},
	}))
	routeCtx := chi.NewRouteContext()
	routeCtx.URLParams.Add("reviewID", "rev_1")
	req = req.WithContext(context.WithValue(req.Context(), chi.RouteCtxKey, routeCtx))
	rec := httptest.NewRecorder()

	handler.moderateReview(rec, req)

	if rec.Code != http.StatusConflict {
		t.Fatalf("expected status 409, got %d", rec.Code)
	}
}

func TestAdminReviewHandlers_StoreReply_Success(t *testing.T) {
	var capturedCmd services.StoreReviewReplyCommand
	service := &stubAdminReviewService{
		storeReplyFunc: func(ctx context.Context, cmd services.StoreReviewReplyCommand) (services.Review, error) {
			capturedCmd = cmd
			now := time.Date(2024, 6, 3, 14, 0, 0, 0, time.UTC)
			return services.Review{
				ID:        "rev_55",
				OrderRef:  "order-55",
				UserRef:   "user-99",
				Status:    domain.ReviewStatusApproved,
				Comment:   "Nice seal",
				CreatedAt: now.Add(-2 * time.Hour),
				UpdatedAt: now,
				Reply: &services.ReviewReply{
					Message:   "Thank you!",
					AuthorRef: "admin-3",
					Visible:   false,
					CreatedAt: now,
					UpdatedAt: now,
				},
			}, nil
		},
	}
	audit := &captureReviewAuditService{}
	handler := NewAdminReviewHandlers(nil, service, audit)

	req := httptest.NewRequest(http.MethodPost, "/reviews/rev_55:store-reply", bytes.NewBufferString(`{"message":"  Thank you!  ","visible":false}`))
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{
		UID:   "admin-3",
		Roles: []string{auth.RoleAdmin},
	}))
	routeCtx := chi.NewRouteContext()
	routeCtx.URLParams.Add("reviewID", "rev_55")
	req = req.WithContext(context.WithValue(req.Context(), chi.RouteCtxKey, routeCtx))
	rec := httptest.NewRecorder()

	handler.storeReviewReply(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", rec.Code)
	}

	if capturedCmd.ReviewID != "rev_55" {
		t.Fatalf("expected review id rev_55, got %q", capturedCmd.ReviewID)
	}
	if capturedCmd.ActorID != "admin-3" {
		t.Fatalf("expected actor admin-3, got %q", capturedCmd.ActorID)
	}
	if capturedCmd.Visible {
		t.Fatalf("expected visible flag false, got true")
	}
	if capturedCmd.Message != "Thank you!" {
		t.Fatalf("expected trimmed message, got %q", capturedCmd.Message)
	}

	var payload adminReviewResponse
	if err := json.NewDecoder(rec.Body).Decode(&payload); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if payload.Review.Reply == nil || payload.Review.Reply.Visible {
		t.Fatalf("expected reply with visible false, got %#v", payload.Review.Reply)
	}

	if len(audit.records) != 1 {
		t.Fatalf("expected one audit record, got %d", len(audit.records))
	}
	record := audit.records[0]
	if record.Action != "review.reply.store" {
		t.Fatalf("expected audit action review.reply.store, got %q", record.Action)
	}
	if record.Metadata["visible"] != false {
		t.Fatalf("expected visible false in metadata, got %#v", record.Metadata["visible"])
	}
	if record.Metadata["messageLength"] != 10 {
		t.Fatalf("expected message length 10, got %#v", record.Metadata["messageLength"])
	}
}

func TestAdminReviewHandlers_StoreReply_EmptyMessage(t *testing.T) {
	handler := NewAdminReviewHandlers(nil, &stubAdminReviewService{}, nil)
	req := httptest.NewRequest(http.MethodPost, "/reviews/rev_55:store-reply", bytes.NewBufferString(`{"message":"   "}`))
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{
		UID:   "staff-1",
		Roles: []string{auth.RoleStaff},
	}))
	routeCtx := chi.NewRouteContext()
	routeCtx.URLParams.Add("reviewID", "rev_55")
	req = req.WithContext(context.WithValue(req.Context(), chi.RouteCtxKey, routeCtx))
	rec := httptest.NewRecorder()

	handler.storeReviewReply(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected status 400, got %d", rec.Code)
	}
}

func TestAdminReviewHandlers_StoreReply_InvalidState(t *testing.T) {
	service := &stubAdminReviewService{
		storeReplyFunc: func(ctx context.Context, cmd services.StoreReviewReplyCommand) (services.Review, error) {
			return services.Review{}, services.ErrReviewInvalidState
		},
	}
	handler := NewAdminReviewHandlers(nil, service, nil)

	req := httptest.NewRequest(http.MethodPost, "/reviews/rev_99:store-reply", bytes.NewBufferString(`{"message":"Hello"}`))
	req = req.WithContext(auth.WithIdentity(req.Context(), &auth.Identity{
		UID:   "staff-1",
		Roles: []string{auth.RoleStaff},
	}))
	routeCtx := chi.NewRouteContext()
	routeCtx.URLParams.Add("reviewID", "rev_99")
	req = req.WithContext(context.WithValue(req.Context(), chi.RouteCtxKey, routeCtx))
	rec := httptest.NewRecorder()

	handler.storeReviewReply(rec, req)

	if rec.Code != http.StatusConflict {
		t.Fatalf("expected status 409, got %d", rec.Code)
	}
}

type stubAdminReviewService struct {
	createFunc     func(ctx context.Context, cmd services.CreateReviewCommand) (services.Review, error)
	getByOrderFunc func(ctx context.Context, cmd services.GetReviewByOrderCommand) (services.Review, error)
	listByUserFunc func(ctx context.Context, cmd services.ListUserReviewsCommand) (domain.CursorPage[services.Review], error)
	listFunc       func(ctx context.Context, filter services.ReviewListFilter) (domain.CursorPage[services.Review], error)
	moderateFunc   func(ctx context.Context, cmd services.ModerateReviewCommand) (services.Review, error)
	storeReplyFunc func(ctx context.Context, cmd services.StoreReviewReplyCommand) (services.Review, error)
}

func (s *stubAdminReviewService) Create(ctx context.Context, cmd services.CreateReviewCommand) (services.Review, error) {
	if s.createFunc != nil {
		return s.createFunc(ctx, cmd)
	}
	return services.Review{}, nil
}

func (s *stubAdminReviewService) GetByOrder(ctx context.Context, cmd services.GetReviewByOrderCommand) (services.Review, error) {
	if s.getByOrderFunc != nil {
		return s.getByOrderFunc(ctx, cmd)
	}
	return services.Review{}, nil
}

func (s *stubAdminReviewService) ListByUser(ctx context.Context, cmd services.ListUserReviewsCommand) (domain.CursorPage[services.Review], error) {
	if s.listByUserFunc != nil {
		return s.listByUserFunc(ctx, cmd)
	}
	return domain.CursorPage[services.Review]{}, nil
}

func (s *stubAdminReviewService) ListReviews(ctx context.Context, filter services.ReviewListFilter) (domain.CursorPage[services.Review], error) {
	if s.listFunc != nil {
		return s.listFunc(ctx, filter)
	}
	return domain.CursorPage[services.Review]{}, nil
}

func (s *stubAdminReviewService) Moderate(ctx context.Context, cmd services.ModerateReviewCommand) (services.Review, error) {
	if s.moderateFunc != nil {
		return s.moderateFunc(ctx, cmd)
	}
	return services.Review{}, nil
}

func (s *stubAdminReviewService) StoreReply(ctx context.Context, cmd services.StoreReviewReplyCommand) (services.Review, error) {
	if s.storeReplyFunc != nil {
		return s.storeReplyFunc(ctx, cmd)
	}
	return services.Review{}, nil
}

type captureReviewAuditService struct {
	records []services.AuditLogRecord
}

func (c *captureReviewAuditService) Record(_ context.Context, record services.AuditLogRecord) {
	c.records = append(c.records, record)
}

func (c *captureReviewAuditService) List(context.Context, services.AuditLogFilter) (domain.CursorPage[domain.AuditLogEntry], error) {
	return domain.CursorPage[domain.AuditLogEntry]{}, nil
}
