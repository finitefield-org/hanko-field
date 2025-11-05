package handlers

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"

	domain "github.com/hanko-field/api/internal/domain"
	"github.com/hanko-field/api/internal/services"
)

func TestAIWorkerWebhook_Success(t *testing.T) {
	completedAt := time.Date(2025, 3, 10, 7, 30, 0, 0, time.UTC)
	var capturedCmd services.CompleteAISuggestionCommand
	dispatcher := &stubAIJobDispatcher{
		completeFn: func(_ context.Context, cmd services.CompleteAISuggestionCommand) (services.CompleteAISuggestionResult, error) {
			capturedCmd = cmd
			payload := cloneMap(cmd.Suggestion.Payload)
			return services.CompleteAISuggestionResult{
				Job: domain.AIJob{
					ID: cmd.JobID,
					Payload: map[string]any{
						"designId":    "dsg_1",
						"requestedBy": "user_123",
						"method":      "balance",
						"model":       "glyph-balancer@001",
					},
					CompletedAt: &completedAt,
				},
				Suggestion: &services.AISuggestion{
					ID:        cmd.Suggestion.ID,
					DesignID:  "dsg_1",
					Method:    "balance",
					Status:    "proposed",
					Payload:   payload,
					CreatedAt: completedAt,
					UpdatedAt: completedAt,
				},
			}, nil
		},
	}
	notifier := &captureAISuggestionNotifier{}
	handler := NewAIWorkerWebhookHandlers(dispatcher, notifier, WithAIWorkerWebhookClock(func() time.Time { return completedAt }))
	router := chi.NewRouter()
	handler.Routes(router)

	body := `{"jobId":"aj_123","suggestionId":"as_456","designId":"dsg_1","method":"balance","status":"succeeded","outputs":{"score":0.93},"metadata":{"worker":"alpha"},"suggestion":{"status":"proposed","payload":{"preview":{"previewUrl":"https://cdn.example/preview.png"}}}}`
	req := httptest.NewRequest(http.MethodPost, "/ai/worker", strings.NewReader(body))
	res := httptest.NewRecorder()
	router.ServeHTTP(res, req)

	if res.Code != http.StatusAccepted {
		t.Fatalf("expected status 202, got %d", res.Code)
	}
	if capturedCmd.JobID != "aj_123" {
		t.Fatalf("expected job id aj_123, got %s", capturedCmd.JobID)
	}
	if capturedCmd.Suggestion.ID != "as_456" {
		t.Fatalf("expected suggestion id as_456, got %s", capturedCmd.Suggestion.ID)
	}
	if capturedCmd.Suggestion.DesignID != "dsg_1" {
		t.Fatalf("expected design id dsg_1, got %s", capturedCmd.Suggestion.DesignID)
	}
	if capturedCmd.Suggestion.Method != "balance" {
		t.Fatalf("expected method balance, got %s", capturedCmd.Suggestion.Method)
	}
	if capturedCmd.Suggestion.Payload == nil {
		t.Fatal("expected suggestion payload to be populated")
	}
	if capturedCmd.Outputs == nil || capturedCmd.Outputs["score"].(float64) != 0.93 {
		t.Fatalf("expected outputs score 0.93, got %#v", capturedCmd.Outputs)
	}
	if capturedCmd.Metadata == nil || capturedCmd.Metadata["worker"] != "alpha" {
		t.Fatalf("expected metadata worker alpha, got %#v", capturedCmd.Metadata)
	}

	if len(notifier.notifications) != 1 {
		t.Fatalf("expected notifier to receive one notification, got %d", len(notifier.notifications))
	}
	notification := notifier.notifications[0]
	if notification.JobID != "aj_123" {
		t.Fatalf("expected notification job id aj_123, got %s", notification.JobID)
	}
	if notification.SuggestionID != "as_456" {
		t.Fatalf("expected notification suggestion id as_456, got %s", notification.SuggestionID)
	}
	if notification.UserID != "user_123" {
		t.Fatalf("expected notification user user_123, got %s", notification.UserID)
	}
	if notification.Model != "glyph-balancer@001" {
		t.Fatalf("expected model glyph-balancer@001, got %s", notification.Model)
	}
	if !notification.ReadyAt.Equal(completedAt) {
		t.Fatalf("expected ReadyAt %s, got %s", completedAt, notification.ReadyAt)
	}
	preview, ok := notification.Suggestion.Payload["preview"].(map[string]any)
	if !ok || preview["previewUrl"].(string) != "https://cdn.example/preview.png" {
		t.Fatalf("expected preview url preserved, got %#v", notification.Suggestion.Payload)
	}
	if notification.Outputs == nil || notification.Outputs["score"].(float64) != 0.93 {
		t.Fatalf("expected notification outputs score, got %#v", notification.Outputs)
	}
}

func TestAIWorkerWebhook_FailedRequiresError(t *testing.T) {
	dispatcher := &stubAIJobDispatcher{}
	handler := NewAIWorkerWebhookHandlers(dispatcher, nil)
	router := chi.NewRouter()
	handler.Routes(router)

	body := `{"jobId":"aj_789","status":"failed"}`
	req := httptest.NewRequest(http.MethodPost, "/ai/worker", strings.NewReader(body))
	res := httptest.NewRecorder()
	router.ServeHTTP(res, req)

	if res.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", res.Code)
	}
}

func TestAIWorkerWebhook_InvalidStatus(t *testing.T) {
	dispatcher := &stubAIJobDispatcher{}
	handler := NewAIWorkerWebhookHandlers(dispatcher, nil)
	router := chi.NewRouter()
	handler.Routes(router)

	body := `{"jobId":"aj_789","status":"processing"}`
	req := httptest.NewRequest(http.MethodPost, "/ai/worker", strings.NewReader(body))
	res := httptest.NewRecorder()
	router.ServeHTTP(res, req)

	if res.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", res.Code)
	}
}

func TestAIWorkerWebhook_ServiceJobNotFound(t *testing.T) {
	dispatcher := &stubAIJobDispatcher{
		completeFn: func(context.Context, services.CompleteAISuggestionCommand) (services.CompleteAISuggestionResult, error) {
			return services.CompleteAISuggestionResult{}, services.ErrAIJobNotFound
		},
	}
	handler := NewAIWorkerWebhookHandlers(dispatcher, nil)
	router := chi.NewRouter()
	handler.Routes(router)

	body := `{"jobId":"aj_789","status":"failed","error":{"code":"timeout","message":"worker timeout"}}`
	req := httptest.NewRequest(http.MethodPost, "/ai/worker", strings.NewReader(body))
	res := httptest.NewRecorder()
	router.ServeHTTP(res, req)

	if res.Code != http.StatusAccepted {
		t.Fatalf("expected 202 for missing job, got %d", res.Code)
	}
}

func TestAIWorkerWebhook_NotifierErrorLogs(t *testing.T) {
	completedAt := time.Date(2025, 3, 11, 8, 15, 0, 0, time.UTC)
	dispatcher := &stubAIJobDispatcher{
		completeFn: func(_ context.Context, cmd services.CompleteAISuggestionCommand) (services.CompleteAISuggestionResult, error) {
			return services.CompleteAISuggestionResult{
				Job: domain.AIJob{
					ID:          cmd.JobID,
					Payload:     map[string]any{"designId": "dsg_1"},
					CompletedAt: &completedAt,
				},
				Suggestion: &services.AISuggestion{ID: cmd.Suggestion.ID, DesignID: "dsg_1"},
			}, nil
		},
	}
	notifier := &captureAISuggestionNotifier{err: errors.New("notify failed")}
	var logged []string
	handler := NewAIWorkerWebhookHandlers(dispatcher, notifier, WithAIWorkerWebhookClock(func() time.Time { return completedAt }), WithAIWorkerWebhookLogger(func(_ context.Context, event string, _ map[string]any) {
		logged = append(logged, event)
	}))
	router := chi.NewRouter()
	handler.Routes(router)

	body := `{"jobId":"aj_999","suggestionId":"as_999","designId":"dsg_1","status":"succeeded"}`
	req := httptest.NewRequest(http.MethodPost, "/ai/worker", strings.NewReader(body))
	res := httptest.NewRecorder()
	router.ServeHTTP(res, req)

	if res.Code != http.StatusAccepted {
		t.Fatalf("expected 202, got %d", res.Code)
	}
	if len(notifier.notifications) != 1 {
		t.Fatalf("expected notifier invoked once, got %d", len(notifier.notifications))
	}
	if len(logged) == 0 || logged[0] != "webhook.ai.notification_failed" {
		t.Fatalf("expected notification failure logged, got %#v", logged)
	}
}

type stubAIJobDispatcher struct {
	completeFn func(context.Context, services.CompleteAISuggestionCommand) (services.CompleteAISuggestionResult, error)
}

func (s *stubAIJobDispatcher) QueueAISuggestion(context.Context, services.QueueAISuggestionCommand) (services.QueueAISuggestionResult, error) {
	return services.QueueAISuggestionResult{}, errors.New("not implemented")
}

func (s *stubAIJobDispatcher) GetAIJob(context.Context, string) (domain.AIJob, error) {
	return domain.AIJob{}, errors.New("not implemented")
}

func (s *stubAIJobDispatcher) CompleteAISuggestion(ctx context.Context, cmd services.CompleteAISuggestionCommand) (services.CompleteAISuggestionResult, error) {
	if s.completeFn != nil {
		return s.completeFn(ctx, cmd)
	}
	return services.CompleteAISuggestionResult{}, nil
}

func (s *stubAIJobDispatcher) GetSuggestion(context.Context, string, string) (services.AISuggestion, error) {
	return services.AISuggestion{}, errors.New("not implemented")
}

func (s *stubAIJobDispatcher) EnqueueRegistrabilityCheck(context.Context, services.RegistrabilityJobPayload) (string, error) {
	return "", errors.New("not implemented")
}

func (s *stubAIJobDispatcher) EnqueueStockCleanup(context.Context, services.StockCleanupPayload) error {
	return errors.New("not implemented")
}

type captureAISuggestionNotifier struct {
	notifications []services.AISuggestionNotification
	err           error
}

func (n *captureAISuggestionNotifier) NotifySuggestionReady(_ context.Context, notification services.AISuggestionNotification) error {
	n.notifications = append(n.notifications, notification)
	return n.err
}

var _ services.BackgroundJobDispatcher = (*stubAIJobDispatcher)(nil)
var _ services.AISuggestionNotifier = (*captureAISuggestionNotifier)(nil)
