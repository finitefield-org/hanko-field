package services

import (
	"context"
	"errors"
	"testing"
	"time"

	domain "github.com/hanko-field/api/internal/domain"
	"github.com/hanko-field/api/internal/repositories"
)

type stubHealthRepository struct {
	report domain.SystemHealthReport
	err    error
	calls  int
}

func (s *stubHealthRepository) Collect(ctx context.Context) (domain.SystemHealthReport, error) {
	s.calls++
	return s.report, s.err
}

type stubAuditService struct {
	filter AuditLogFilter
	result domain.CursorPage[domain.AuditLogEntry]
	err    error
}

func (s *stubAuditService) Record(context.Context, AuditLogRecord) {}

func (s *stubAuditService) List(ctx context.Context, filter AuditLogFilter) (domain.CursorPage[domain.AuditLogEntry], error) {
	s.filter = filter
	return s.result, s.err
}

type stubCounterService struct {
	scope string
	name  string
	opts  CounterGenerationOptions
	value CounterValue
	err   error
}

func (s *stubCounterService) Next(ctx context.Context, scope, name string, opts CounterGenerationOptions) (CounterValue, error) {
	s.scope = scope
	s.name = name
	s.opts = opts
	return s.value, s.err
}

func (s *stubCounterService) NextOrderNumber(context.Context) (string, error) { return "", nil }

func (s *stubCounterService) NextInvoiceNumber(context.Context) (string, error) { return "", nil }

type stubSystemErrorStore struct {
	filter SystemErrorFilter
	result domain.CursorPage[domain.SystemError]
	err    error
}

func (s *stubSystemErrorStore) ListSystemErrors(ctx context.Context, filter SystemErrorFilter) (domain.CursorPage[domain.SystemError], error) {
	s.filter = filter
	return s.result, s.err
}

type stubSystemTaskStore struct {
	filter SystemTaskFilter
	result domain.CursorPage[domain.SystemTask]
	err    error
}

func (s *stubSystemTaskStore) ListSystemTasks(ctx context.Context, filter SystemTaskFilter) (domain.CursorPage[domain.SystemTask], error) {
	s.filter = filter
	return s.result, s.err
}

func TestSystemServiceHealthReportEnrichesMetadata(t *testing.T) {
	start := time.Date(2024, 1, 1, 0, 0, 0, 0, time.UTC)
	now := start.Add(5 * time.Minute)
	repo := &stubHealthRepository{
		report: domain.SystemHealthReport{
			Checks: map[string]domain.SystemHealthCheck{
				"firestore": {Status: domain.HealthStatusOK},
			},
		},
	}

	svc, err := NewSystemService(SystemServiceDeps{
		HealthRepository: repo,
		Clock:            func() time.Time { return now },
		Build: BuildInfo{
			Version:     "1.2.3",
			CommitSHA:   "abc123",
			Environment: "prod",
			StartedAt:   start,
		},
	})
	if err != nil {
		t.Fatalf("NewSystemService: %v", err)
	}

	report, err := svc.HealthReport(context.Background())
	if err != nil {
		t.Fatalf("HealthReport: %v", err)
	}

	if report.Status != domain.HealthStatusOK {
		t.Fatalf("expected status ok, got %s", report.Status)
	}
	if report.Version != "1.2.3" {
		t.Fatalf("expected version 1.2.3, got %s", report.Version)
	}
	if report.CommitSHA != "abc123" {
		t.Fatalf("expected commit abc123, got %s", report.CommitSHA)
	}
	if report.Environment != "prod" {
		t.Fatalf("expected environment prod, got %s", report.Environment)
	}
	if report.Uptime != now.Sub(start) {
		t.Fatalf("expected uptime %s, got %s", now.Sub(start), report.Uptime)
	}
	if report.GeneratedAt != now {
		t.Fatalf("expected generatedAt %s, got %s", now, report.GeneratedAt)
	}
}

func TestSystemServiceHealthReportErrors(t *testing.T) {
	expected := errors.New("collect failed")
	repo := &stubHealthRepository{err: expected}

	svc, err := NewSystemService(SystemServiceDeps{
		HealthRepository: repo,
	})
	if err != nil {
		t.Fatalf("NewSystemService: %v", err)
	}

	_, err = svc.HealthReport(context.Background())
	if !errors.Is(err, expected) {
		t.Fatalf("expected error %v, got %v", expected, err)
	}
}

func TestNewSystemServiceRequiresRepository(t *testing.T) {
	_, err := NewSystemService(SystemServiceDeps{})
	if err == nil {
		t.Fatalf("expected error when repository missing")
	}
}

func TestSystemServiceDerivesStatusWhenMissing(t *testing.T) {
	repo := &stubHealthRepository{
		report: domain.SystemHealthReport{
			Checks: map[string]domain.SystemHealthCheck{
				"pubsub": {Status: domain.HealthStatusDegraded},
				"secret": {Status: domain.HealthStatusOK},
			},
		},
	}

	svc, err := NewSystemService(SystemServiceDeps{
		HealthRepository: repo,
	})
	if err != nil {
		t.Fatalf("NewSystemService: %v", err)
	}

	report, err := svc.HealthReport(context.Background())
	if err != nil {
		t.Fatalf("HealthReport: %v", err)
	}
	if report.Status != domain.HealthStatusDegraded {
		t.Fatalf("expected status degraded, got %s", report.Status)
	}
}

func TestSystemServiceListAuditLogsDelegates(t *testing.T) {
	repo := &stubHealthRepository{}
	audit := &stubAuditService{
		result: domain.CursorPage[domain.AuditLogEntry]{Items: []domain.AuditLogEntry{{ID: "1"}}},
	}

	svc, err := NewSystemService(SystemServiceDeps{HealthRepository: repo, Audit: audit})
	if err != nil {
		t.Fatalf("NewSystemService: %v", err)
	}

	filter := AuditLogFilter{Actor: "user-1"}
	result, err := svc.ListAuditLogs(context.Background(), filter)
	if err != nil {
		t.Fatalf("ListAuditLogs: %v", err)
	}
	if audit.filter.Actor != "user-1" {
		t.Fatalf("expected actor filter propagated, got %s", audit.filter.Actor)
	}
	if len(result.Items) != 1 || result.Items[0].ID != "1" {
		t.Fatalf("unexpected result: %+v", result.Items)
	}
}

func TestSystemServiceListAuditLogsMissing(t *testing.T) {
	repo := &stubHealthRepository{}
	svc, err := NewSystemService(SystemServiceDeps{HealthRepository: repo})
	if err != nil {
		t.Fatalf("NewSystemService: %v", err)
	}

	_, err = svc.ListAuditLogs(context.Background(), AuditLogFilter{})
	if err == nil {
		t.Fatalf("expected error when audit service missing")
	}
}

func TestSystemServiceNextCounterValueDelegates(t *testing.T) {
	repo := &stubHealthRepository{}
	counters := &stubCounterService{value: CounterValue{Value: 42}}

	svc, err := NewSystemService(SystemServiceDeps{HealthRepository: repo, Counters: counters})
	if err != nil {
		t.Fatalf("NewSystemService: %v", err)
	}

	value, err := svc.NextCounterValue(context.Background(), CounterCommand{CounterID: "orders:2024", Step: 5})
	if err != nil {
		t.Fatalf("NextCounterValue: %v", err)
	}
	if value != 42 {
		t.Fatalf("expected 42, got %d", value)
	}
	if counters.scope != "orders" || counters.name != "2024" {
		t.Fatalf("expected scope orders and name 2024, got %s:%s", counters.scope, counters.name)
	}
	if counters.opts.Step != 5 {
		t.Fatalf("expected step 5, got %d", counters.opts.Step)
	}
}

func TestSystemServiceNextCounterValueMissing(t *testing.T) {
	repo := &stubHealthRepository{}
	svc, err := NewSystemService(SystemServiceDeps{HealthRepository: repo})
	if err != nil {
		t.Fatalf("NewSystemService: %v", err)
	}

	if _, err := svc.NextCounterValue(context.Background(), CounterCommand{CounterID: "orders:2024"}); err == nil {
		t.Fatalf("expected error when counters missing")
	}
}

func TestSystemServiceNextCounterValueInvalidID(t *testing.T) {
	repo := &stubHealthRepository{}
	svc, err := NewSystemService(SystemServiceDeps{HealthRepository: repo, Counters: &stubCounterService{}})
	if err != nil {
		t.Fatalf("NewSystemService: %v", err)
	}

	if _, err := svc.NextCounterValue(context.Background(), CounterCommand{CounterID: "invalid"}); err == nil {
		t.Fatalf("expected error for invalid counter id")
	}
}

func TestSystemServiceListSystemErrorsNormalisesFilter(t *testing.T) {
	repo := &stubHealthRepository{}
	errorStore := &stubSystemErrorStore{
		result: domain.CursorPage[domain.SystemError]{
			Items: []domain.SystemError{{ID: "err_1"}},
		},
	}

	svc, err := NewSystemService(SystemServiceDeps{
		HealthRepository: repo,
		Errors:           errorStore,
	})
	if err != nil {
		t.Fatalf("NewSystemService: %v", err)
	}

	from := time.Date(2024, 1, 1, 10, 0, 0, 0, time.FixedZone("JST", 9*3600))
	to := from.Add(2 * time.Hour)
	filter := SystemErrorFilter{
		Sources:    []string{" Queue.Errors ", ""},
		JobTypes:   []string{" Export.BigQuery "},
		Statuses:   []string{" FAILED ", "failed"},
		Severities: []string{" Critical "},
		Search:     "  export failure  ",
		DateRange: domain.RangeQuery[time.Time]{
			From: &from,
			To:   &to,
		},
		Pagination: Pagination{
			PageSize:  75,
			PageToken: " token ",
		},
	}

	result, err := svc.ListSystemErrors(context.Background(), filter)
	if err != nil {
		t.Fatalf("ListSystemErrors: %v", err)
	}
	if len(result.Items) != 1 || result.Items[0].ID != "err_1" {
		t.Fatalf("unexpected result: %+v", result.Items)
	}

	if got := errorStore.filter.Sources; len(got) != 1 || got[0] != "queue.errors" {
		t.Fatalf("expected normalised sources, got %v", got)
	}
	if got := errorStore.filter.JobTypes; len(got) != 1 || got[0] != "export.bigquery" {
		t.Fatalf("expected normalised job types, got %v", got)
	}
	if got := errorStore.filter.Statuses; len(got) != 1 || got[0] != "failed" {
		t.Fatalf("expected normalised statuses, got %v", got)
	}
	if got := errorStore.filter.Severities; len(got) != 1 || got[0] != "critical" {
		t.Fatalf("expected normalised severities, got %v", got)
	}
	if errorStore.filter.Search != "export failure" {
		t.Fatalf("expected trimmed search, got %q", errorStore.filter.Search)
	}
	if errorStore.filter.DateRange.From == nil || !errorStore.filter.DateRange.From.Equal(from.UTC()) {
		t.Fatalf("expected utc from, got %+v", errorStore.filter.DateRange.From)
	}
	if errorStore.filter.DateRange.To == nil || !errorStore.filter.DateRange.To.Equal(to.UTC()) {
		t.Fatalf("expected utc to, got %+v", errorStore.filter.DateRange.To)
	}
	if errorStore.filter.Pagination.PageToken != "token" {
		t.Fatalf("expected trimmed page token, got %q", errorStore.filter.Pagination.PageToken)
	}
	if errorStore.filter.Pagination.PageSize != 75 {
		t.Fatalf("expected page size 75, got %d", errorStore.filter.Pagination.PageSize)
	}
}

func TestSystemServiceListSystemErrorsMissingStore(t *testing.T) {
	repo := &stubHealthRepository{}
	svc, err := NewSystemService(SystemServiceDeps{HealthRepository: repo})
	if err != nil {
		t.Fatalf("NewSystemService: %v", err)
	}

	_, err = svc.ListSystemErrors(context.Background(), SystemErrorFilter{})
	if err == nil {
		t.Fatalf("expected error when error store missing")
	}
}

func TestSystemServiceListSystemTasksNormalisesFilter(t *testing.T) {
	repo := &stubHealthRepository{}
	taskStore := &stubSystemTaskStore{
		result: domain.CursorPage[domain.SystemTask]{
			Items: []domain.SystemTask{{ID: "task_1"}},
		},
	}

	svc, err := NewSystemService(SystemServiceDeps{
		HealthRepository: repo,
		Tasks:            taskStore,
	})
	if err != nil {
		t.Fatalf("NewSystemService: %v", err)
	}

	from := time.Date(2024, 5, 1, 15, 0, 0, 0, time.FixedZone("PDT", -7*3600))
	filter := SystemTaskFilter{
		Statuses: []SystemTaskStatus{" PENDING ", "unknown", SystemTaskStatusCompleted},
		Kinds:    []string{" Export.BigQuery ", " "},
		DateRange: domain.RangeQuery[time.Time]{
			From: &from,
		},
		RequestedBy: " admin@example.com ",
		Pagination: Pagination{
			PageSize:  25,
			PageToken: " next ",
		},
	}

	result, err := svc.ListSystemTasks(context.Background(), filter)
	if err != nil {
		t.Fatalf("ListSystemTasks: %v", err)
	}
	if len(result.Items) != 1 || result.Items[0].ID != "task_1" {
		t.Fatalf("unexpected result: %+v", result.Items)
	}

	if got := taskStore.filter.Statuses; len(got) != 2 ||
		got[0] != SystemTaskStatusPending || got[1] != SystemTaskStatusCompleted {
		t.Fatalf("expected normalised statuses, got %v", got)
	}
	if got := taskStore.filter.Kinds; len(got) != 1 || got[0] != "export.bigquery" {
		t.Fatalf("expected normalised kinds, got %v", got)
	}
	if taskStore.filter.RequestedBy != "admin@example.com" {
		t.Fatalf("expected trimmed requestedBy, got %q", taskStore.filter.RequestedBy)
	}
	if taskStore.filter.DateRange.From == nil || !taskStore.filter.DateRange.From.Equal(from.UTC()) {
		t.Fatalf("expected utc from, got %+v", taskStore.filter.DateRange.From)
	}
	if taskStore.filter.DateRange.To != nil {
		t.Fatalf("expected nil to, got %+v", taskStore.filter.DateRange.To)
	}
	if taskStore.filter.Pagination.PageToken != "next" {
		t.Fatalf("expected trimmed token, got %q", taskStore.filter.Pagination.PageToken)
	}
	if taskStore.filter.Pagination.PageSize != 25 {
		t.Fatalf("expected page size 25, got %d", taskStore.filter.Pagination.PageSize)
	}
}

func TestSystemServiceListSystemTasksMissingStore(t *testing.T) {
	repo := &stubHealthRepository{}
	svc, err := NewSystemService(SystemServiceDeps{HealthRepository: repo})
	if err != nil {
		t.Fatalf("NewSystemService: %v", err)
	}

	_, err = svc.ListSystemTasks(context.Background(), SystemTaskFilter{})
	if err == nil {
		t.Fatalf("expected error when task store missing")
	}
}

var _ repositories.HealthRepository = (*stubHealthRepository)(nil)
var _ AuditLogService = (*stubAuditService)(nil)
var _ CounterService = (*stubCounterService)(nil)
var _ SystemErrorStore = (*stubSystemErrorStore)(nil)
var _ SystemTaskStore = (*stubSystemTaskStore)(nil)
