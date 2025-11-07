package services

import (
	"context"
	"errors"
	"fmt"
	"reflect"
	"strings"
	"time"

	"github.com/oklog/ulid/v2"

	domain "github.com/hanko-field/api/internal/domain"
	"github.com/hanko-field/api/internal/repositories"
)

const (
	productionQueueIDPrefix        = "pqu_"
	productionQueueActorType       = "staff"
	productionQueueTargetPrefix    = "/production-queues/"
	productionQueueActionCreate    = "production_queue.create"
	productionQueueActionUpdate    = "production_queue.update"
	productionQueueActionDelete    = "production_queue.delete"
	defaultProductionQueueStatus   = domain.ProductionQueueStatusActive
	defaultProductionQueuePriority = domain.ProductionQueuePriorityNormal
)

var (
	// ErrProductionQueueRepositoryMissing signals the repository dependency is absent.
	ErrProductionQueueRepositoryMissing = errors.New("production queue service: repository is not configured")
	// ErrProductionQueueRepositoryUnavailable indicates the repository is temporarily unavailable.
	ErrProductionQueueRepositoryUnavailable = errors.New("production queue service: repository unavailable")
	// ErrProductionQueueInvalid captures validation failures for queue payloads.
	ErrProductionQueueInvalid = errors.New("production queue service: invalid queue input")
	// ErrProductionQueueNotFound indicates the target queue does not exist.
	ErrProductionQueueNotFound = errors.New("production queue service: queue not found")
	// ErrProductionQueueConflict indicates an ID conflict or uniqueness violation.
	ErrProductionQueueConflict = errors.New("production queue service: queue conflict")
	// ErrProductionQueueHasAssignments prevents deletion when active work items remain.
	ErrProductionQueueHasAssignments = errors.New("production queue service: queue has active assignments")
)

// ProductionQueueServiceDeps bundles constructor dependencies for the production queue service.
type ProductionQueueServiceDeps struct {
	Repository   repositories.ProductionQueueRepository
	Audit        AuditLogService
	Clock        func() time.Time
	IDGenerator  func() string
	QueueMetrics QueueDepthRecorder
}

type productionQueueService struct {
	repo    repositories.ProductionQueueRepository
	audit   AuditLogService
	clock   func() time.Time
	idGen   func() string
	metrics QueueDepthRecorder
}

// NewProductionQueueService constructs a ProductionQueueService backed by the provided repository.
func NewProductionQueueService(deps ProductionQueueServiceDeps) (ProductionQueueService, error) {
	if deps.Repository == nil {
		return nil, ErrProductionQueueRepositoryMissing
	}
	clock := deps.Clock
	if clock == nil {
		clock = time.Now
	}
	idGen := deps.IDGenerator
	if idGen == nil {
		idGen = func() string { return ulid.Make().String() }
	}
	return &productionQueueService{
		repo:    deps.Repository,
		audit:   deps.Audit,
		clock:   func() time.Time { return clock().UTC() },
		idGen:   idGen,
		metrics: deps.QueueMetrics,
	}, nil
}

func (s *productionQueueService) ListQueues(ctx context.Context, filter ProductionQueueListFilter) (domain.CursorPage[ProductionQueue], error) {
	if s.repo == nil {
		return domain.CursorPage[ProductionQueue]{}, ErrProductionQueueRepositoryMissing
	}
	repoFilter := repositories.ProductionQueueListFilter{
		Status:     normalizeQueueFilterValues(filter.Status),
		Priorities: normalizeQueueFilterValues(filter.Priorities),
		Pagination: domain.Pagination{
			PageSize:  filter.Pagination.PageSize,
			PageToken: strings.TrimSpace(filter.Pagination.PageToken),
		},
	}
	page, err := s.repo.List(ctx, repoFilter)
	if err != nil {
		return domain.CursorPage[ProductionQueue]{}, translateQueueRepositoryError(err)
	}
	return domain.CursorPage[ProductionQueue]{
		Items:         convertQueueSlice(page.Items),
		NextPageToken: page.NextPageToken,
	}, nil
}

func (s *productionQueueService) GetQueue(ctx context.Context, queueID string) (ProductionQueue, error) {
	if s.repo == nil {
		return ProductionQueue{}, ErrProductionQueueRepositoryMissing
	}
	queueID = strings.TrimSpace(queueID)
	if queueID == "" {
		return ProductionQueue{}, fmt.Errorf("%w: queue id is required", ErrProductionQueueInvalid)
	}
	queue, err := s.repo.Get(ctx, queueID)
	if err != nil {
		return ProductionQueue{}, translateQueueRepositoryError(err)
	}
	return queue, nil
}

func (s *productionQueueService) CreateQueue(ctx context.Context, cmd UpsertProductionQueueCommand) (ProductionQueue, error) {
	if s.repo == nil {
		return ProductionQueue{}, ErrProductionQueueRepositoryMissing
	}
	actorID := strings.TrimSpace(cmd.ActorID)
	if actorID == "" {
		return ProductionQueue{}, fmt.Errorf("%w: actor id is required", ErrProductionQueueInvalid)
	}
	now := s.clock()
	queueInput := cmd.Queue
	if strings.TrimSpace(queueInput.ID) == "" {
		queueInput.ID = strings.TrimSpace(cmd.QueueID)
	}
	queue, err := s.normalizeQueue(queueInput, now, nil, true)
	if err != nil {
		return ProductionQueue{}, err
	}
	saved, err := s.repo.Insert(ctx, queue)
	if err != nil {
		return ProductionQueue{}, translateQueueRepositoryError(err)
	}
	s.recordAudit(ctx, productionQueueActionCreate, domain.ProductionQueue{}, saved, actorID, now)
	return saved, nil
}

func (s *productionQueueService) UpdateQueue(ctx context.Context, cmd UpsertProductionQueueCommand) (ProductionQueue, error) {
	if s.repo == nil {
		return ProductionQueue{}, ErrProductionQueueRepositoryMissing
	}
	actorID := strings.TrimSpace(cmd.ActorID)
	if actorID == "" {
		return ProductionQueue{}, fmt.Errorf("%w: actor id is required", ErrProductionQueueInvalid)
	}
	queueID := strings.TrimSpace(cmd.QueueID)
	if queueID == "" {
		queueID = strings.TrimSpace(cmd.Queue.ID)
	}
	if queueID == "" {
		return ProductionQueue{}, fmt.Errorf("%w: queue id is required", ErrProductionQueueInvalid)
	}
	existing, err := s.repo.Get(ctx, queueID)
	if err != nil {
		return ProductionQueue{}, translateQueueRepositoryError(err)
	}
	now := s.clock()
	queueInput := cmd.Queue
	if strings.TrimSpace(queueInput.ID) == "" {
		queueInput.ID = queueID
	}
	queue, err := s.normalizeQueue(queueInput, now, &existing, false)
	if err != nil {
		return ProductionQueue{}, err
	}
	saved, err := s.repo.Update(ctx, queue, existing.UpdatedAt)
	if err != nil {
		return ProductionQueue{}, translateQueueRepositoryError(err)
	}
	s.recordAudit(ctx, productionQueueActionUpdate, existing, saved, actorID, now)
	return saved, nil
}

func (s *productionQueueService) DeleteQueue(ctx context.Context, cmd DeleteProductionQueueCommand) error {
	if s.repo == nil {
		return ErrProductionQueueRepositoryMissing
	}
	queueID := strings.TrimSpace(cmd.QueueID)
	if queueID == "" {
		return fmt.Errorf("%w: queue id is required", ErrProductionQueueInvalid)
	}
	existing, err := s.repo.Get(ctx, queueID)
	if err != nil {
		return translateQueueRepositoryError(err)
	}
	hasAssignments, err := s.repo.HasActiveAssignments(ctx, queueID)
	if err != nil {
		return translateQueueRepositoryError(err)
	}
	if hasAssignments {
		return ErrProductionQueueHasAssignments
	}
	if err := s.repo.Delete(ctx, queueID); err != nil {
		return translateQueueRepositoryError(err)
	}
	now := s.clock()
	s.recordAudit(ctx, productionQueueActionDelete, existing, domain.ProductionQueue{}, strings.TrimSpace(cmd.ActorID), now)
	return nil
}

func (s *productionQueueService) QueueWIPSummary(ctx context.Context, queueID string) (ProductionQueueWIPSummary, error) {
	if s.repo == nil {
		return ProductionQueueWIPSummary{}, ErrProductionQueueRepositoryMissing
	}
	queueID = strings.TrimSpace(queueID)
	if queueID == "" {
		return ProductionQueueWIPSummary{}, fmt.Errorf("%w: queue id is required", ErrProductionQueueInvalid)
	}
	summary, err := s.repo.QueueWIPSummary(ctx, queueID)
	if err != nil {
		return ProductionQueueWIPSummary{}, translateQueueRepositoryError(err)
	}
	result := normalizeQueueWIPSummary(summary, queueID)
	if s.metrics != nil {
		s.metrics.RecordQueueDepth(ctx, result.QueueID, result.Total, result.StatusCounts)
	}
	return result, nil
}

// QueueMetricsRecorder exposes the recorder used for queue depth instrumentation.
func (s *productionQueueService) QueueMetricsRecorder() QueueDepthRecorder {
	if s == nil {
		return nil
	}
	return s.metrics
}

func (s *productionQueueService) normalizeQueue(input ProductionQueue, now time.Time, existing *domain.ProductionQueue, isCreate bool) (domain.ProductionQueue, error) {
	var queue domain.ProductionQueue
	queue.Metadata = normalizeQueueMetadata(input.Metadata)

	id := strings.TrimSpace(input.ID)
	if id == "" && existing != nil {
		id = strings.TrimSpace(existing.ID)
	}
	if id == "" {
		if !isCreate {
			return domain.ProductionQueue{}, fmt.Errorf("%w: queue id is required", ErrProductionQueueInvalid)
		}
		generated := strings.ToLower(strings.TrimSpace(s.idGen()))
		if generated == "" {
			return domain.ProductionQueue{}, fmt.Errorf("%w: could not generate identifier", ErrProductionQueueInvalid)
		}
		id = productionQueueIDPrefix + generated
	}
	queue.ID = id

	name := strings.TrimSpace(input.Name)
	if name == "" && existing != nil {
		name = strings.TrimSpace(existing.Name)
	}
	if name == "" {
		return domain.ProductionQueue{}, fmt.Errorf("%w: name is required", ErrProductionQueueInvalid)
	}
	queue.Name = name

	if input.Capacity < 0 {
		return domain.ProductionQueue{}, fmt.Errorf("%w: capacity cannot be negative", ErrProductionQueueInvalid)
	}
	queue.Capacity = input.Capacity
	queue.WorkCenters = normalizeWorkCenters(input.WorkCenters)

	priority, err := normalizeQueuePriority(input.Priority)
	if err != nil {
		return domain.ProductionQueue{}, err
	}
	queue.Priority = priority

	status, err := normalizeQueueStatus(input.Status)
	if err != nil {
		return domain.ProductionQueue{}, err
	}
	queue.Status = status
	queue.Notes = strings.TrimSpace(input.Notes)

	if existing != nil && !existing.CreatedAt.IsZero() {
		queue.CreatedAt = existing.CreatedAt
	} else if !input.CreatedAt.IsZero() {
		queue.CreatedAt = input.CreatedAt.UTC()
	} else {
		queue.CreatedAt = now
	}
	queue.UpdatedAt = now

	return queue, nil
}

func (s *productionQueueService) recordAudit(ctx context.Context, action string, before, after domain.ProductionQueue, actorID string, occurredAt time.Time) {
	if s.audit == nil {
		return
	}
	actorID = strings.TrimSpace(actorID)
	targetID := pickFirstNonEmpty(after.ID, before.ID)
	targetRef := productionQueueTargetPrefix + targetID
	metadata := map[string]any{
		"queueId":  targetID,
		"name":     pickFirstNonEmpty(after.Name, before.Name),
		"status":   pickFirstNonEmpty(after.Status, before.Status),
		"priority": pickFirstNonEmpty(after.Priority, before.Priority),
	}
	if metadata["queueId"] == "" {
		delete(metadata, "queueId")
	}
	s.audit.Record(ctx, AuditLogRecord{
		Actor:      actorID,
		ActorType:  productionQueueActorType,
		Action:     action,
		TargetRef:  targetRef,
		Severity:   "info",
		OccurredAt: occurredAt,
		Metadata:   metadata,
		Diff:       buildQueueDiff(before, after),
	})
}

func normalizeWorkCenters(workCenters []string) []string {
	if len(workCenters) == 0 {
		return nil
	}
	seen := make(map[string]struct{}, len(workCenters))
	result := make([]string, 0, len(workCenters))
	for _, center := range workCenters {
		trimmed := strings.TrimSpace(center)
		if trimmed == "" {
			continue
		}
		key := strings.ToLower(trimmed)
		if _, exists := seen[key]; exists {
			continue
		}
		seen[key] = struct{}{}
		result = append(result, trimmed)
	}
	if len(result) == 0 {
		return nil
	}
	return result
}

func normalizeQueuePriority(priority string) (string, error) {
	value := strings.ToLower(strings.TrimSpace(priority))
	if value == "" {
		return defaultProductionQueuePriority, nil
	}
	switch value {
	case domain.ProductionQueuePriorityNormal, domain.ProductionQueuePriorityRush:
		return value, nil
	default:
		return "", fmt.Errorf("%w: unsupported priority %q", ErrProductionQueueInvalid, priority)
	}
}

func normalizeQueueStatus(status string) (string, error) {
	value := strings.ToLower(strings.TrimSpace(status))
	if value == "" {
		return defaultProductionQueueStatus, nil
	}
	switch value {
	case domain.ProductionQueueStatusActive, domain.ProductionQueueStatusPaused, domain.ProductionQueueStatusArchived:
		return value, nil
	default:
		return "", fmt.Errorf("%w: unsupported status %q", ErrProductionQueueInvalid, status)
	}
}

func normalizeQueueFilterValues(values []string) []string {
	if len(values) == 0 {
		return nil
	}
	seen := make(map[string]struct{}, len(values))
	result := make([]string, 0, len(values))
	for _, value := range values {
		trimmed := strings.ToLower(strings.TrimSpace(value))
		if trimmed == "" {
			continue
		}
		if _, exists := seen[trimmed]; exists {
			continue
		}
		seen[trimmed] = struct{}{}
		result = append(result, trimmed)
	}
	if len(result) == 0 {
		return nil
	}
	return result
}

func normalizeQueueMetadata(meta map[string]any) map[string]any {
	if len(meta) == 0 {
		return nil
	}
	result := make(map[string]any, len(meta))
	for key, value := range meta {
		trimmedKey := strings.TrimSpace(key)
		if trimmedKey == "" {
			continue
		}
		result[trimmedKey] = value
	}
	if len(result) == 0 {
		return nil
	}
	return result
}

func buildQueueDiff(before, after domain.ProductionQueue) map[string]AuditLogDiff {
	diff := make(map[string]AuditLogDiff)
	compare := func(field string, beforeVal, afterVal any) {
		if reflect.DeepEqual(beforeVal, afterVal) {
			return
		}
		diff[field] = AuditLogDiff{
			Before: beforeVal,
			After:  afterVal,
		}
	}
	compare("name", strings.TrimSpace(before.Name), strings.TrimSpace(after.Name))
	compare("capacity", before.Capacity, after.Capacity)
	compare("workCenters", normalizeWorkCenters(before.WorkCenters), normalizeWorkCenters(after.WorkCenters))
	compare("priority", strings.TrimSpace(before.Priority), strings.TrimSpace(after.Priority))
	compare("status", strings.TrimSpace(before.Status), strings.TrimSpace(after.Status))
	compare("notes", strings.TrimSpace(before.Notes), strings.TrimSpace(after.Notes))
	if !reflect.DeepEqual(normalizeQueueMetadata(before.Metadata), normalizeQueueMetadata(after.Metadata)) {
		diff["metadata"] = AuditLogDiff{
			Before: normalizeQueueMetadata(before.Metadata),
			After:  normalizeQueueMetadata(after.Metadata),
		}
	}
	return diff
}

func translateQueueRepositoryError(err error) error {
	if err == nil {
		return nil
	}
	var repoErr repositories.RepositoryError
	if errors.As(err, &repoErr) {
		switch {
		case repoErr.IsNotFound():
			return ErrProductionQueueNotFound
		case repoErr.IsConflict():
			return ErrProductionQueueConflict
		case repoErr.IsUnavailable():
			return ErrProductionQueueRepositoryUnavailable
		}
	}
	return err
}

func convertQueueSlice(items []domain.ProductionQueue) []ProductionQueue {
	if len(items) == 0 {
		return nil
	}
	result := make([]ProductionQueue, len(items))
	copy(result, items)
	return result
}

func normalizeQueueWIPSummary(summary domain.ProductionQueueWIPSummary, fallbackID string) ProductionQueueWIPSummary {
	result := ProductionQueueWIPSummary{
		QueueID: strings.TrimSpace(summary.QueueID),
		Total:   summary.Total,
	}
	if result.QueueID == "" {
		result.QueueID = strings.TrimSpace(fallbackID)
	}

	if summary.StatusCounts != nil {
		normalized := make(map[string]int, len(summary.StatusCounts))
		totalFromCounts := 0
		hadCounts := false
		for key, value := range summary.StatusCounts {
			trimmedKey := strings.TrimSpace(key)
			if trimmedKey == "" {
				continue
			}
			statusKey := strings.ToLower(trimmedKey)
			statusKey = strings.ReplaceAll(statusKey, " ", "_")
			statusKey = strings.ReplaceAll(statusKey, "-", "_")
			if value < 0 {
				value = 0
			}
			normalized[statusKey] = normalized[statusKey] + value
			totalFromCounts += value
			hadCounts = true
		}
		if hadCounts {
			result.StatusCounts = normalized
			result.Total = totalFromCounts
		}
	}

	if result.Total < 0 {
		result.Total = 0
	}

	if summary.AverageAge < 0 {
		result.AverageAge = 0
	} else {
		result.AverageAge = summary.AverageAge
	}
	if summary.OldestAge < 0 {
		result.OldestAge = 0
	} else {
		result.OldestAge = summary.OldestAge
	}
	if summary.SLABreachCount < 0 {
		result.SLABreachCount = 0
	} else {
		result.SLABreachCount = summary.SLABreachCount
	}
	if !summary.GeneratedAt.IsZero() {
		result.GeneratedAt = summary.GeneratedAt.UTC()
	}
	return result
}

func pickFirstNonEmpty(values ...string) string {
	for _, value := range values {
		if trimmed := strings.TrimSpace(value); trimmed != "" {
			return trimmed
		}
	}
	return ""
}
