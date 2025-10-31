package services

import (
	"context"
	"errors"
	"testing"
	"time"

	domain "github.com/hanko-field/api/internal/domain"
	"github.com/hanko-field/api/internal/repositories"
)

func TestNewProductionQueueService_RequiresRepository(t *testing.T) {
	_, err := NewProductionQueueService(ProductionQueueServiceDeps{})
	if !errors.Is(err, ErrProductionQueueRepositoryMissing) {
		t.Fatalf("expected ErrProductionQueueRepositoryMissing, got %v", err)
	}
}

func TestProductionQueueService_CreateQueue_NormalizesAndAudits(t *testing.T) {
	now := time.Date(2024, 4, 8, 10, 0, 0, 0, time.UTC)
	repo := &stubProductionQueueRepository{}
	repo.insertResult = domain.ProductionQueue{
		ID:          "pqu_01hyncp1f0a23",
		Name:        "Engraving",
		Capacity:    15,
		WorkCenters: []string{"Station A", "Station B"},
		Priority:    domain.ProductionQueuePriorityRush,
		Status:      domain.ProductionQueueStatusActive,
		Notes:       "handles express",
		Metadata:    map[string]any{"region": "tokyo"},
		CreatedAt:   now,
		UpdatedAt:   now,
	}
	audit := &captureQueueAuditService{}

	svc, err := NewProductionQueueService(ProductionQueueServiceDeps{
		Repository:  repo,
		Audit:       audit,
		Clock:       func() time.Time { return now },
		IDGenerator: func() string { return "01HYNCP1F0A23" },
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	input := UpsertProductionQueueCommand{
		ActorID: " admin-1 ",
		Queue: ProductionQueue{
			Name:        "  Engraving ",
			Capacity:    15,
			WorkCenters: []string{" Station A ", "station a", "Station B"},
			Priority:    "RUSH",
			Status:      "Active",
			Notes:       " handles express ",
			Metadata:    map[string]any{"region": "tokyo"},
		},
	}
	result, err := svc.CreateQueue(context.Background(), input)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if result.ID != "pqu_01hyncp1f0a23" {
		t.Fatalf("expected id normalised, got %q", result.ID)
	}
	if repo.insertQueue.ID != "pqu_01hyncp1f0a23" {
		t.Fatalf("expected repository received id pqu_01hyncp1f0a23, got %q", repo.insertQueue.ID)
	}
	if repo.insertQueue.Name != "Engraving" {
		t.Fatalf("expected trimmed name, got %q", repo.insertQueue.Name)
	}
	if len(repo.insertQueue.WorkCenters) != 2 {
		t.Fatalf("expected deduped work centers, got %v", repo.insertQueue.WorkCenters)
	}
	if repo.insertQueue.WorkCenters[0] != "Station A" || repo.insertQueue.WorkCenters[1] != "Station B" {
		t.Fatalf("unexpected work centers %v", repo.insertQueue.WorkCenters)
	}
	if repo.insertQueue.Priority != domain.ProductionQueuePriorityRush {
		t.Fatalf("expected rush priority, got %q", repo.insertQueue.Priority)
	}
	if repo.insertQueue.Status != domain.ProductionQueueStatusActive {
		t.Fatalf("expected active status, got %q", repo.insertQueue.Status)
	}
	if repo.insertQueue.CreatedAt != now || repo.insertQueue.UpdatedAt != now {
		t.Fatalf("expected timestamps normalised, got %v %v", repo.insertQueue.CreatedAt, repo.insertQueue.UpdatedAt)
	}
	if repo.insertQueue.Notes != "handles express" {
		t.Fatalf("expected trimmed notes, got %q", repo.insertQueue.Notes)
	}
	if repo.insertQueue.Metadata["region"] != "tokyo" {
		t.Fatalf("expected metadata preserved, got %v", repo.insertQueue.Metadata)
	}

	if len(audit.records) != 1 {
		t.Fatalf("expected 1 audit record, got %d", len(audit.records))
	}
	record := audit.records[0]
	if record.Action != productionQueueActionCreate {
		t.Fatalf("expected audit action create, got %q", record.Action)
	}
	if record.TargetRef != "/production-queues/pqu_01hyncp1f0a23" {
		t.Fatalf("expected target ref, got %q", record.TargetRef)
	}
	if record.Actor != "admin-1" {
		t.Fatalf("expected actor trimmed, got %q", record.Actor)
	}
	if record.Metadata["status"] != "active" {
		t.Fatalf("expected metadata status active, got %v", record.Metadata["status"])
	}
	if _, ok := record.Diff["name"]; !ok {
		t.Fatalf("expected diff for name")
	}
}

func TestProductionQueueService_CreateQueue_InvalidPriority(t *testing.T) {
	repo := &stubProductionQueueRepository{}
	svc, err := NewProductionQueueService(ProductionQueueServiceDeps{
		Repository: repo,
		Clock:      time.Now,
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	_, err = svc.CreateQueue(context.Background(), UpsertProductionQueueCommand{
		ActorID: "admin",
		Queue: ProductionQueue{
			Name:     "Queue",
			Priority: "vip",
		},
	})
	if !errors.Is(err, ErrProductionQueueInvalid) {
		t.Fatalf("expected ErrProductionQueueInvalid, got %v", err)
	}
}

func TestProductionQueueService_UpdateQueue_PreservesCreatedAt(t *testing.T) {
	now := time.Date(2024, 4, 8, 11, 0, 0, 0, time.UTC)
	existing := domain.ProductionQueue{
		ID:          "pqu_existing",
		Name:        "Original",
		Capacity:    10,
		WorkCenters: []string{"Station X"},
		Priority:    domain.ProductionQueuePriorityNormal,
		Status:      domain.ProductionQueueStatusActive,
		Notes:       "initial",
		Metadata:    map[string]any{"region": "tokyo"},
		CreatedAt:   now.Add(-24 * time.Hour),
		UpdatedAt:   now.Add(-24 * time.Hour),
	}
	repo := &stubProductionQueueRepository{
		getQueue: existing,
	}
	repo.updateResult = domain.ProductionQueue{
		ID:          "pqu_existing",
		Name:        "Updated",
		Capacity:    12,
		WorkCenters: []string{"Station Y"},
		Priority:    domain.ProductionQueuePriorityRush,
		Status:      domain.ProductionQueueStatusPaused,
		Notes:       "updated note",
		Metadata:    map[string]any{"region": "osaka"},
		CreatedAt:   existing.CreatedAt,
		UpdatedAt:   now,
	}
	audit := &captureQueueAuditService{}
	svc, err := NewProductionQueueService(ProductionQueueServiceDeps{
		Repository: repo,
		Audit:      audit,
		Clock:      func() time.Time { return now },
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	cmd := UpsertProductionQueueCommand{
		QueueID: "pqu_existing",
		ActorID: "staff-1",
		Queue: ProductionQueue{
			Name:        "Updated",
			Capacity:    12,
			WorkCenters: []string{"Station Y"},
			Priority:    "rush",
			Status:      "paused",
			Notes:       "updated note",
			Metadata:    map[string]any{"region": "osaka"},
		},
	}
	result, err := svc.UpdateQueue(context.Background(), cmd)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if repo.updateQueue.ID != "pqu_existing" {
		t.Fatalf("expected update to keep id, got %q", repo.updateQueue.ID)
	}
	if repo.updateQueue.CreatedAt != existing.CreatedAt {
		t.Fatalf("expected createdAt preserved, got %v", repo.updateQueue.CreatedAt)
	}
	if repo.updateQueue.UpdatedAt != now {
		t.Fatalf("expected updatedAt set, got %v", repo.updateQueue.UpdatedAt)
	}
	if !repo.updateExpected.Equal(existing.UpdatedAt) {
		t.Fatalf("expected optimistic locking timestamp %v, got %v", existing.UpdatedAt, repo.updateExpected)
	}
	if repo.updateQueue.Priority != domain.ProductionQueuePriorityRush {
		t.Fatalf("expected priority rush, got %q", repo.updateQueue.Priority)
	}
	if result.Name != "Updated" || result.Metadata["region"] != "osaka" {
		t.Fatalf("unexpected update result %+v", result)
	}
	if len(audit.records) != 1 {
		t.Fatalf("expected audit record")
	}
	if _, ok := audit.records[0].Diff["priority"]; !ok {
		t.Fatalf("expected diff priority recorded")
	}
}

func TestProductionQueueService_DeleteQueue_PreventsActiveAssignments(t *testing.T) {
	repo := &stubProductionQueueRepository{
		getQueue:       domain.ProductionQueue{ID: "pqu_busy", Name: "Busy Queue"},
		hasAssignments: true,
	}
	svc, err := NewProductionQueueService(ProductionQueueServiceDeps{
		Repository: repo,
		Clock:      time.Now,
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	err = svc.DeleteQueue(context.Background(), DeleteProductionQueueCommand{
		QueueID: "pqu_busy",
		ActorID: "admin",
	})
	if !errors.Is(err, ErrProductionQueueHasAssignments) {
		t.Fatalf("expected ErrProductionQueueHasAssignments, got %v", err)
	}
	if repo.deletedID != "" {
		t.Fatalf("delete should not be called when assignments exist")
	}
}

func TestProductionQueueService_DeleteQueue_Success(t *testing.T) {
	now := time.Date(2024, 4, 8, 11, 30, 0, 0, time.UTC)
	repo := &stubProductionQueueRepository{
		getQueue: domain.ProductionQueue{ID: "pqu_done", Name: "Done Queue"},
	}
	audit := &captureQueueAuditService{}
	svc, err := NewProductionQueueService(ProductionQueueServiceDeps{
		Repository: repo,
		Audit:      audit,
		Clock:      func() time.Time { return now },
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if err := svc.DeleteQueue(context.Background(), DeleteProductionQueueCommand{
		QueueID: "pqu_done",
		ActorID: "admin",
	}); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if repo.deletedID != "pqu_done" {
		t.Fatalf("expected repository delete called with id, got %q", repo.deletedID)
	}
	if len(audit.records) != 1 {
		t.Fatalf("expected delete audit record")
	}
	if audit.records[0].Action != productionQueueActionDelete {
		t.Fatalf("expected delete action, got %q", audit.records[0].Action)
	}
}

func TestProductionQueueService_ListQueues_NormalizesFilter(t *testing.T) {
	repo := &stubProductionQueueRepository{
		listResult: domain.CursorPage[domain.ProductionQueue]{
			Items: []domain.ProductionQueue{
				{ID: "pqu_1", Name: "Queue 1"},
			},
			NextPageToken: "token",
		},
	}
	svc, err := NewProductionQueueService(ProductionQueueServiceDeps{
		Repository: repo,
		Clock:      time.Now,
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	page, err := svc.ListQueues(context.Background(), ProductionQueueListFilter{
		Status:     []string{" Active ", "active"},
		Priorities: []string{" RUSH "},
		Pagination: Pagination{PageSize: 25, PageToken: " token "},
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(repo.listFilter.Status) != 1 || repo.listFilter.Status[0] != "active" {
		t.Fatalf("expected normalised status, got %v", repo.listFilter.Status)
	}
	if len(repo.listFilter.Priorities) != 1 || repo.listFilter.Priorities[0] != "rush" {
		t.Fatalf("expected normalised priorities, got %v", repo.listFilter.Priorities)
	}
	if repo.listFilter.Pagination.PageToken != "token" {
		t.Fatalf("expected trimmed page token, got %q", repo.listFilter.Pagination.PageToken)
	}
	if len(page.Items) != 1 || page.Items[0].ID != "pqu_1" {
		t.Fatalf("unexpected page results %+v", page.Items)
	}
	if page.NextPageToken != "token" {
		t.Fatalf("expected next page token propagated")
	}
}

func TestProductionQueueService_UpdateQueue_NotFound(t *testing.T) {
	repo := &stubProductionQueueRepository{
		getErr: stubQueueRepoError{notFound: true},
	}
	svc, err := NewProductionQueueService(ProductionQueueServiceDeps{
		Repository: repo,
		Clock:      time.Now,
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	_, err = svc.UpdateQueue(context.Background(), UpsertProductionQueueCommand{
		QueueID: "missing",
		ActorID: "admin",
		Queue:   ProductionQueue{Name: "Missing"},
	})
	if !errors.Is(err, ErrProductionQueueNotFound) {
		t.Fatalf("expected ErrProductionQueueNotFound, got %v", err)
	}
}

func TestProductionQueueService_QueueWIPSummary_Normalizes(t *testing.T) {
	generated := time.Date(2024, 4, 8, 15, 30, 0, 0, time.FixedZone("JST", 9*3600))
	repo := &stubProductionQueueRepository{
		wipResult: domain.ProductionQueueWIPSummary{
			QueueID: " pqu_metrics ",
			StatusCounts: map[string]int{
				"Waiting":      5,
				"in-progress":  3,
				"blocked":      -2,
				"Extra Stage ": 2,
				"":             7,
			},
			Total:          6,
			AverageAge:     45*time.Minute + 30*time.Second,
			OldestAge:      2 * time.Hour,
			SLABreachCount: 4,
			GeneratedAt:    generated,
		},
	}
	svc, err := NewProductionQueueService(ProductionQueueServiceDeps{
		Repository: repo,
		Clock:      time.Now,
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	summary, err := svc.QueueWIPSummary(context.Background(), " pqu_metrics ")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if repo.wipRequestedID != "pqu_metrics" {
		t.Fatalf("expected queue id trimmed, got %q", repo.wipRequestedID)
	}
	if summary.QueueID != "pqu_metrics" {
		t.Fatalf("expected queue id propagated, got %q", summary.QueueID)
	}
	if summary.Total != 10 {
		t.Fatalf("expected total derived from counts, got %d", summary.Total)
	}
	if summary.StatusCounts["waiting"] != 5 {
		t.Fatalf("expected waiting count 5, got %d", summary.StatusCounts["waiting"])
	}
	if summary.StatusCounts["in_progress"] != 3 {
		t.Fatalf("expected in_progress count 3, got %d", summary.StatusCounts["in_progress"])
	}
	if count, exists := summary.StatusCounts["blocked"]; !exists || count != 0 {
		t.Fatalf("expected blocked status with zero count, got %v", summary.StatusCounts["blocked"])
	}
	if summary.StatusCounts["extra_stage"] != 2 {
		t.Fatalf("expected extra_stage count 2, got %d", summary.StatusCounts["extra_stage"])
	}
	if summary.AverageAge != 45*time.Minute+30*time.Second {
		t.Fatalf("unexpected average age %v", summary.AverageAge)
	}
	if summary.OldestAge != 2*time.Hour {
		t.Fatalf("unexpected oldest age %v", summary.OldestAge)
	}
	if summary.SLABreachCount != 4 {
		t.Fatalf("expected SLA breach count 4, got %d", summary.SLABreachCount)
	}
	if !summary.GeneratedAt.Equal(generated.UTC()) {
		t.Fatalf("expected generated timestamp normalized to UTC, got %v", summary.GeneratedAt)
	}
}

func TestProductionQueueService_QueueWIPSummary_PreservesZeroValues(t *testing.T) {
	repo := &stubProductionQueueRepository{
		wipResult: domain.ProductionQueueWIPSummary{
			StatusCounts: map[string]int{
				"waiting": 0,
			},
			Total:          0,
			AverageAge:     0,
			OldestAge:      -5 * time.Minute,
			SLABreachCount: 0,
		},
	}
	svc, err := NewProductionQueueService(ProductionQueueServiceDeps{
		Repository: repo,
		Clock:      time.Now,
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	summary, err := svc.QueueWIPSummary(context.Background(), " pqu_zero ")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if repo.wipRequestedID != "pqu_zero" {
		t.Fatalf("expected trimmed queue id, got %q", repo.wipRequestedID)
	}
	if summary.QueueID != "pqu_zero" {
		t.Fatalf("expected queue id pqu_zero, got %q", summary.QueueID)
	}
	if count, ok := summary.StatusCounts["waiting"]; !ok || count != 0 {
		t.Fatalf("expected waiting count 0, got %v", summary.StatusCounts)
	}
	if summary.Total != 0 {
		t.Fatalf("expected total 0, got %d", summary.Total)
	}
	if summary.AverageAge != 0 {
		t.Fatalf("expected average age 0, got %v", summary.AverageAge)
	}
	if summary.OldestAge != 0 {
		t.Fatalf("expected oldest age clamped to 0, got %v", summary.OldestAge)
	}
	if summary.SLABreachCount != 0 {
		t.Fatalf("expected SLA breach count 0, got %d", summary.SLABreachCount)
	}
	if !summary.GeneratedAt.IsZero() {
		t.Fatalf("expected generated at zero value, got %v", summary.GeneratedAt)
	}
}

func TestProductionQueueService_QueueWIPSummary_ErrorMapping(t *testing.T) {
	repo := &stubProductionQueueRepository{
		wipErr: stubQueueRepoError{notFound: true},
	}
	svc, err := NewProductionQueueService(ProductionQueueServiceDeps{
		Repository: repo,
		Clock:      time.Now,
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	_, err = svc.QueueWIPSummary(context.Background(), "missing")
	if !errors.Is(err, ErrProductionQueueNotFound) {
		t.Fatalf("expected ErrProductionQueueNotFound, got %v", err)
	}
}

func TestProductionQueueService_QueueWIPSummary_InvalidID(t *testing.T) {
	repo := &stubProductionQueueRepository{}
	svc, err := NewProductionQueueService(ProductionQueueServiceDeps{
		Repository: repo,
		Clock:      time.Now,
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	_, err = svc.QueueWIPSummary(context.Background(), "   ")
	if !errors.Is(err, ErrProductionQueueInvalid) {
		t.Fatalf("expected ErrProductionQueueInvalid, got %v", err)
	}
}

type stubProductionQueueRepository struct {
	listFilter     repositories.ProductionQueueListFilter
	listResult     domain.CursorPage[domain.ProductionQueue]
	listErr        error
	getRequestedID string
	getQueue       domain.ProductionQueue
	getErr         error
	insertQueue    domain.ProductionQueue
	insertResult   domain.ProductionQueue
	insertErr      error
	updateQueue    domain.ProductionQueue
	updateExpected time.Time
	updateResult   domain.ProductionQueue
	updateErr      error
	deletedID      string
	deleteErr      error
	hasQueriedID   string
	hasAssignments bool
	hasErr         error
	wipRequestedID string
	wipResult      domain.ProductionQueueWIPSummary
	wipErr         error
}

func (s *stubProductionQueueRepository) List(_ context.Context, filter repositories.ProductionQueueListFilter) (domain.CursorPage[domain.ProductionQueue], error) {
	s.listFilter = filter
	if s.listErr != nil {
		return domain.CursorPage[domain.ProductionQueue]{}, s.listErr
	}
	return s.listResult, nil
}

func (s *stubProductionQueueRepository) Get(_ context.Context, queueID string) (domain.ProductionQueue, error) {
	s.getRequestedID = queueID
	if s.getErr != nil {
		return domain.ProductionQueue{}, s.getErr
	}
	return s.getQueue, nil
}

func (s *stubProductionQueueRepository) Insert(_ context.Context, queue domain.ProductionQueue) (domain.ProductionQueue, error) {
	s.insertQueue = queue
	if s.insertErr != nil {
		return domain.ProductionQueue{}, s.insertErr
	}
	if s.insertResult.ID != "" {
		return s.insertResult, nil
	}
	return queue, nil
}

func (s *stubProductionQueueRepository) Update(_ context.Context, queue domain.ProductionQueue, expectedUpdatedAt time.Time) (domain.ProductionQueue, error) {
	s.updateQueue = queue
	s.updateExpected = expectedUpdatedAt
	if s.updateErr != nil {
		return domain.ProductionQueue{}, s.updateErr
	}
	if s.updateResult.ID != "" {
		return s.updateResult, nil
	}
	return queue, nil
}

func (s *stubProductionQueueRepository) Delete(_ context.Context, queueID string) error {
	s.deletedID = queueID
	return s.deleteErr
}

func (s *stubProductionQueueRepository) HasActiveAssignments(_ context.Context, queueID string) (bool, error) {
	s.hasQueriedID = queueID
	if s.hasErr != nil {
		return false, s.hasErr
	}
	return s.hasAssignments, nil
}

func (s *stubProductionQueueRepository) QueueWIPSummary(_ context.Context, queueID string) (domain.ProductionQueueWIPSummary, error) {
	s.wipRequestedID = queueID
	if s.wipErr != nil {
		return domain.ProductionQueueWIPSummary{}, s.wipErr
	}
	return s.wipResult, nil
}

type stubQueueRepoError struct {
	notFound    bool
	conflict    bool
	unavailable bool
}

func (e stubQueueRepoError) Error() string { return "repository error" }
func (e stubQueueRepoError) IsNotFound() bool {
	return e.notFound
}
func (e stubQueueRepoError) IsConflict() bool {
	return e.conflict
}
func (e stubQueueRepoError) IsUnavailable() bool {
	return e.unavailable
}

type captureQueueAuditService struct {
	records []AuditLogRecord
}

func (c *captureQueueAuditService) Record(_ context.Context, record AuditLogRecord) {
	c.records = append(c.records, record)
}

func (c *captureQueueAuditService) List(context.Context, AuditLogFilter) (domain.CursorPage[AuditLogEntry], error) {
	return domain.CursorPage[AuditLogEntry]{}, nil
}
