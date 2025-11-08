package handlers

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"

	domain "github.com/hanko-field/api/internal/domain"
	"github.com/hanko-field/api/internal/platform/httpx"
	"github.com/hanko-field/api/internal/repositories"
	"github.com/hanko-field/api/internal/services"
)

const maxAIWorkerWebhookBodySize int64 = 256 * 1024

const (
	aiWebhookStatusSucceeded = "succeeded"
	aiWebhookStatusFailed    = "failed"
)

// AIWorkerWebhookHandlers coordinates callbacks from the AI worker to persist job outcomes.
type AIWorkerWebhookHandlers struct {
	jobs     services.BackgroundJobDispatcher
	notifier services.AISuggestionNotifier
	maxBody  int64
	now      func() time.Time
	logger   func(ctx context.Context, event string, fields map[string]any)
}

// AIWorkerWebhookOption customises the behaviour of the AI worker webhook handler.
type AIWorkerWebhookOption func(*AIWorkerWebhookHandlers)

// NewAIWorkerWebhookHandlers constructs handlers validating payloads from the AI worker and
// delegating persistence to the background job dispatcher.
func NewAIWorkerWebhookHandlers(jobs services.BackgroundJobDispatcher, notifier services.AISuggestionNotifier, opts ...AIWorkerWebhookOption) *AIWorkerWebhookHandlers {
	handler := &AIWorkerWebhookHandlers{
		jobs:     jobs,
		notifier: notifier,
		maxBody:  maxAIWorkerWebhookBodySize,
		now: func() time.Time {
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

// WithAIWorkerWebhookClock overrides the clock used for timestamp defaults (primarily for tests).
func WithAIWorkerWebhookClock(clock func() time.Time) AIWorkerWebhookOption {
	return func(h *AIWorkerWebhookHandlers) {
		if clock != nil {
			h.now = func() time.Time {
				return clock().UTC()
			}
		}
	}
}

// WithAIWorkerWebhookMaxBody adjusts the maximum accepted request body size.
func WithAIWorkerWebhookMaxBody(limit int64) AIWorkerWebhookOption {
	return func(h *AIWorkerWebhookHandlers) {
		if limit > 0 {
			h.maxBody = limit
		}
	}
}

// WithAIWorkerWebhookLogger configures a logger to capture webhook processing events.
func WithAIWorkerWebhookLogger(logger func(ctx context.Context, event string, fields map[string]any)) AIWorkerWebhookOption {
	return func(h *AIWorkerWebhookHandlers) {
		h.logger = logger
	}
}

// Routes wires webhook endpoints under the provided router.
func (h *AIWorkerWebhookHandlers) Routes(r chi.Router) {
	if r == nil {
		return
	}
	r.Post("/ai/worker", h.handleAIWorker)
}

func (h *AIWorkerWebhookHandlers) handleAIWorker(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	if h.jobs == nil {
		httpx.WriteError(ctx, w, httpx.NewError("service_unavailable", "ai job dispatcher unavailable", http.StatusServiceUnavailable))
		return
	}

	body, err := readLimitedBody(r, h.maxBody)
	if err != nil {
		switch {
		case errors.Is(err, errBodyTooLarge):
			httpx.WriteError(ctx, w, httpx.NewError("payload_too_large", "request body exceeds allowed size", http.StatusRequestEntityTooLarge))
		default:
			httpx.WriteError(ctx, w, httpx.NewError("invalid_request", err.Error(), http.StatusBadRequest))
		}
		return
	}

	req, err := parseAIWorkerWebhookRequest(body)
	if err != nil {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", err.Error(), http.StatusBadRequest))
		return
	}

	if req.JobID == "" {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "jobId is required", http.StatusBadRequest))
		return
	}

	status := normalizeAIWorkerStatus(req.Status)
	if status == "" {
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "status must be succeeded or failed", http.StatusBadRequest))
		return
	}

	outputs := cloneMap(req.Outputs)
	metadata := cloneMap(req.Metadata)
	cmd := services.CompleteAISuggestionCommand{
		JobID:    req.JobID,
		Outputs:  outputs,
		Metadata: metadata,
	}

	if status == aiWebhookStatusFailed {
		if req.Error == nil {
			httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "error details are required when status is failed", http.StatusBadRequest))
			return
		}
		errDetail := buildAIWorkerError(*req.Error)
		if errDetail == nil {
			httpx.WriteError(ctx, w, httpx.NewError("invalid_request", "error.code or error.message is required", http.StatusBadRequest))
			return
		}
		cmd.Error = errDetail
	} else {
		suggestion := buildAISuggestionFromRequest(req)
		cmd.Suggestion = suggestion
	}

	result, err := h.jobs.CompleteAISuggestion(ctx, cmd)
	if err != nil {
		h.writeAIWorkerError(ctx, w, err)
		return
	}

	if status == aiWebhookStatusSucceeded && result.Suggestion != nil {
		h.dispatchNotification(ctx, *result.Suggestion, result.Job, outputs, metadata)
	}

	w.WriteHeader(http.StatusAccepted)
}

func (h *AIWorkerWebhookHandlers) writeAIWorkerError(ctx context.Context, w http.ResponseWriter, err error) {
	switch {
	case err == nil:
		w.WriteHeader(http.StatusAccepted)
	case errors.Is(err, services.ErrAIInvalidInput):
		httpx.WriteError(ctx, w, httpx.NewError("invalid_request", err.Error(), http.StatusBadRequest))
	case errors.Is(err, services.ErrAIJobNotFound), errors.Is(err, services.ErrAISuggestionNotFound):
		w.WriteHeader(http.StatusAccepted)
	default:
		var repoErr repositories.RepositoryError
		if errors.As(err, &repoErr) {
			switch {
			case repoErr.IsUnavailable():
				httpx.WriteError(ctx, w, httpx.NewError("service_unavailable", "storage temporarily unavailable", http.StatusServiceUnavailable))
			default:
				httpx.WriteError(ctx, w, httpx.NewError("webhook_error", err.Error(), http.StatusInternalServerError))
			}
			return
		}
		httpx.WriteError(ctx, w, httpx.NewError("webhook_error", err.Error(), http.StatusInternalServerError))
	}
}

func (h *AIWorkerWebhookHandlers) dispatchNotification(ctx context.Context, suggestion services.AISuggestion, job domain.AIJob, outputs, metadata map[string]any) {
	if h.notifier == nil {
		return
	}
	readyAt := h.now()
	if job.CompletedAt != nil && !job.CompletedAt.IsZero() {
		readyAt = job.CompletedAt.UTC()
	}

	clone := cloneAISuggestion(suggestion)
	notification := services.AISuggestionNotification{
		JobID:        strings.TrimSpace(job.ID),
		DesignID:     strings.TrimSpace(clone.DesignID),
		SuggestionID: strings.TrimSpace(clone.ID),
		Method:       strings.TrimSpace(clone.Method),
		ReadyAt:      readyAt,
		Suggestion:   clone,
		Outputs:      cloneMap(outputs),
	}
	if job.Payload != nil {
		if requestedBy, ok := job.Payload["requestedBy"].(string); ok {
			notification.UserID = strings.TrimSpace(requestedBy)
		}
		if model, ok := job.Payload["model"].(string); ok {
			notification.Model = strings.TrimSpace(model)
		}
	}
	if notification.Method == "" {
		if jobMethod, ok := job.Payload["method"].(string); ok {
			notification.Method = strings.TrimSpace(jobMethod)
		}
	}

	meta := make(map[string]any)
	if len(job.Payload) > 0 {
		meta["job"] = cloneMap(job.Payload)
	}
	if len(metadata) > 0 {
		meta["worker"] = cloneMap(metadata)
	}
	if len(meta) > 0 {
		notification.Metadata = meta
	}

	if err := h.notifier.NotifySuggestionReady(ctx, notification); err != nil {
		h.log(ctx, "webhook.ai.notification_failed", map[string]any{
			"jobId":        notification.JobID,
			"suggestionId": notification.SuggestionID,
			"error":        err.Error(),
		})
	}
}

func (h *AIWorkerWebhookHandlers) log(ctx context.Context, event string, fields map[string]any) {
	if h.logger != nil {
		h.logger(ctx, event, fields)
	}
}

type aiWorkerWebhookRequest struct {
	JobID        string              `json:"jobId"`
	SuggestionID string              `json:"suggestionId"`
	DesignID     string              `json:"designId"`
	Method       string              `json:"method"`
	Model        string              `json:"model"`
	Status       string              `json:"status"`
	Outputs      map[string]any      `json:"outputs"`
	Metadata     map[string]any      `json:"metadata"`
	Error        *aiWorkerError      `json:"error"`
	Suggestion   *aiWorkerSuggestion `json:"suggestion"`
}

type aiWorkerError struct {
	Code      string `json:"code"`
	Message   string `json:"message"`
	Retryable *bool  `json:"retryable"`
}

type aiWorkerSuggestion struct {
	Status    string         `json:"status"`
	Payload   map[string]any `json:"payload"`
	Method    string         `json:"method"`
	CreatedAt string         `json:"createdAt"`
	UpdatedAt string         `json:"updatedAt"`
	ExpiresAt string         `json:"expiresAt"`
}

func parseAIWorkerWebhookRequest(data []byte) (aiWorkerWebhookRequest, error) {
	var req aiWorkerWebhookRequest
	if err := json.Unmarshal(data, &req); err != nil {
		return req, fmt.Errorf("invalid JSON payload: %w", err)
	}
	req.JobID = strings.TrimSpace(req.JobID)
	req.SuggestionID = strings.TrimSpace(req.SuggestionID)
	req.DesignID = strings.TrimSpace(req.DesignID)
	req.Method = strings.TrimSpace(req.Method)
	req.Model = strings.TrimSpace(req.Model)
	req.Status = strings.TrimSpace(req.Status)
	if req.Suggestion != nil {
		req.Suggestion.Status = strings.TrimSpace(req.Suggestion.Status)
		req.Suggestion.Method = strings.TrimSpace(req.Suggestion.Method)
		req.Suggestion.CreatedAt = strings.TrimSpace(req.Suggestion.CreatedAt)
		req.Suggestion.UpdatedAt = strings.TrimSpace(req.Suggestion.UpdatedAt)
		req.Suggestion.ExpiresAt = strings.TrimSpace(req.Suggestion.ExpiresAt)
	}
	return req, nil
}

func normalizeAIWorkerStatus(raw string) string {
	switch strings.ToLower(strings.TrimSpace(raw)) {
	case "succeeded", "success", "completed", "ok":
		return aiWebhookStatusSucceeded
	case "failed", "error", "errored":
		return aiWebhookStatusFailed
	default:
		return ""
	}
}

func buildAIWorkerError(details aiWorkerError) *domain.AIJobError {
	code := strings.TrimSpace(details.Code)
	message := strings.TrimSpace(details.Message)
	if code == "" && message == "" {
		return nil
	}
	retryable := false
	if details.Retryable != nil {
		retryable = *details.Retryable
	}
	if code == "" {
		code = "worker_error"
	}
	return &domain.AIJobError{
		Code:      code,
		Message:   message,
		Retryable: retryable,
	}
}

func buildAISuggestionFromRequest(req aiWorkerWebhookRequest) services.AISuggestion {
	suggestion := services.AISuggestion{}
	suggestion.ID = strings.TrimSpace(req.SuggestionID)
	suggestion.DesignID = strings.TrimSpace(req.DesignID)
	suggestion.Method = strings.TrimSpace(req.Method)

	if req.Suggestion != nil {
		if req.Suggestion.Status != "" {
			suggestion.Status = req.Suggestion.Status
		}
		if len(req.Suggestion.Payload) > 0 {
			suggestion.Payload = cloneMap(req.Suggestion.Payload)
		}
		if parsed, ok := parseAIWorkerTime(req.Suggestion.CreatedAt); ok {
			suggestion.CreatedAt = parsed
		}
		if parsed, ok := parseAIWorkerTime(req.Suggestion.UpdatedAt); ok {
			suggestion.UpdatedAt = parsed
		}
		if parsed, ok := parseAIWorkerTime(req.Suggestion.ExpiresAt); ok {
			suggestion.ExpiresAt = &parsed
		}
		if req.Suggestion.Method != "" {
			suggestion.Method = req.Suggestion.Method
		}
	}

	return suggestion
}

func parseAIWorkerTime(value string) (time.Time, bool) {
	if value == "" {
		return time.Time{}, false
	}
	layouts := []string{
		time.RFC3339Nano,
		time.RFC3339,
	}
	for _, layout := range layouts {
		if parsed, err := time.Parse(layout, value); err == nil {
			return parsed.UTC(), true
		}
	}
	return time.Time{}, false
}

func cloneAISuggestion(s services.AISuggestion) services.AISuggestion {
	clone := s
	if len(s.Payload) > 0 {
		clone.Payload = cloneMap(s.Payload)
	}
	return clone
}
