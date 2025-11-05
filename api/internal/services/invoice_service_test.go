package services

import (
	"context"
	"errors"
	"strings"
	"testing"
	"time"

	domain "github.com/hanko-field/api/internal/domain"
	"github.com/hanko-field/api/internal/repositories"
)

func TestInvoiceServiceIssueInvoice_Success(t *testing.T) {
	ctx := context.Background()
	now := time.Date(2025, 4, 2, 15, 30, 0, 0, time.UTC)

	var updated domain.Order
	orderRepo := &stubOrderRepo{
		findFn: func(_ context.Context, id string) (domain.Order, error) {
			if id != "order_42" {
				t.Fatalf("unexpected order id lookup %s", id)
			}
			return domain.Order{
				ID:       "order_42",
				Currency: "JPY",
				Totals:   domain.OrderTotals{Total: 7800},
				Metadata: map[string]any{},
			}, nil
		},
		updateFn: func(_ context.Context, order domain.Order) error {
			updated = order
			return nil
		},
	}
	invoiceRepo := &stubInvoiceRepo{}
	counter := &stubInvoiceCounterService{invoiceNumbers: []string{"INV-202504-000042"}}
	storage := &stubInvoiceStorage{}
	renderer := &stubInvoiceRenderer{}
	batchRepo := &stubInvoiceBatchRepo{}

	service, err := NewInvoiceService(InvoiceServiceDeps{
		Orders:      orderRepo,
		Invoices:    invoiceRepo,
		Batches:     batchRepo,
		Counters:    counter,
		Storage:     storage,
		Renderer:    renderer,
		UnitOfWork:  &stubUnitOfWork{},
		Clock:       func() time.Time { return now },
		IDGenerator: func() string { return "inv_single" },
	})
	if err != nil {
		t.Fatalf("NewInvoiceService: %v", err)
	}

	issued, err := service.IssueInvoice(ctx, IssueInvoiceCommand{
		OrderRef: " /orders/order_42 ",
		ActorID:  " system ",
		Notes:    " send pdf ",
	})
	if err != nil {
		t.Fatalf("IssueInvoice: %v", err)
	}

	if issued.OrderID != "order_42" {
		t.Fatalf("expected order id order_42, got %q", issued.OrderID)
	}
	if issued.InvoiceNumber != "INV-202504-000042" {
		t.Fatalf("expected invoice number INV-202504-000042, got %q", issued.InvoiceNumber)
	}
	if issued.PDFAssetRef == "" {
		t.Fatalf("expected pdf asset ref, got empty")
	}

	if counter.invoiceCalls != 1 {
		t.Fatalf("expected counter called once, got %d", counter.invoiceCalls)
	}
	if len(invoiceRepo.inserted) != 1 {
		t.Fatalf("expected one invoice inserted, got %d", len(invoiceRepo.inserted))
	}
	if invoiceRepo.inserted[0].OrderRef != "/orders/order_42" {
		t.Fatalf("expected order ref /orders/order_42, got %q", invoiceRepo.inserted[0].OrderRef)
	}
	if note, ok := invoiceRepo.inserted[0].Metadata["notes"].(string); !ok || note != "send pdf" {
		t.Fatalf("expected notes stored, got %v", invoiceRepo.inserted[0].Metadata["notes"])
	}
	if len(storage.storedObjects) != 1 {
		t.Fatalf("expected single stored pdf, got %d", len(storage.storedObjects))
	}
	if updated.ID != "order_42" {
		t.Fatalf("expected order_42 updated, got %q", updated.ID)
	}
	if num, ok := updated.Metadata["invoiceNumber"].(string); !ok || num != "INV-202504-000042" {
		t.Fatalf("expected order metadata invoice number updated, got %v", updated.Metadata["invoiceNumber"])
	}
	if ref, ok := updated.Metadata["invoiceAssetRef"].(string); !ok || ref == "" {
		t.Fatalf("expected order metadata invoice asset ref, got %v", updated.Metadata["invoiceAssetRef"])
	}
	if updated.Audit.UpdatedBy == nil || *updated.Audit.UpdatedBy != "system" {
		t.Fatalf("expected audit updated by system, got %v", updated.Audit.UpdatedBy)
	}
}

func TestInvoiceServiceIssueInvoice_OrderNotFound(t *testing.T) {
	ctx := context.Background()
	orderRepo := &stubOrderRepo{
		findFn: func(_ context.Context, id string) (domain.Order, error) {
			return domain.Order{}, repoError{message: "missing", notFound: true}
		},
	}
	invoiceRepo := &stubInvoiceRepo{}
	counter := &stubInvoiceCounterService{invoiceNumbers: []string{"INV-1"}}
	storage := &stubInvoiceStorage{}
	renderer := &stubInvoiceRenderer{}
	batchRepo := &stubInvoiceBatchRepo{}

	service, err := NewInvoiceService(InvoiceServiceDeps{
		Orders:     orderRepo,
		Invoices:   invoiceRepo,
		Batches:    batchRepo,
		Counters:   counter,
		Storage:    storage,
		Renderer:   renderer,
		UnitOfWork: &stubUnitOfWork{},
	})
	if err != nil {
		t.Fatalf("NewInvoiceService: %v", err)
	}

	_, err = service.IssueInvoice(ctx, IssueInvoiceCommand{
		OrderID: "not_found",
		ActorID: "system",
	})
	if !errors.Is(err, ErrInvoiceOrderNotFound) {
		t.Fatalf("expected ErrInvoiceOrderNotFound, got %v", err)
	}
}

func TestInvoiceServiceIssueInvoice_InvalidInput(t *testing.T) {
	ctx := context.Background()
	orderRepo := &stubOrderRepo{}
	invoiceRepo := &stubInvoiceRepo{}
	counter := &stubInvoiceCounterService{invoiceNumbers: []string{"INV-1"}}
	storage := &stubInvoiceStorage{}
	renderer := &stubInvoiceRenderer{}
	batchRepo := &stubInvoiceBatchRepo{}

	service, err := NewInvoiceService(InvoiceServiceDeps{
		Orders:     orderRepo,
		Invoices:   invoiceRepo,
		Batches:    batchRepo,
		Counters:   counter,
		Storage:    storage,
		Renderer:   renderer,
		UnitOfWork: &stubUnitOfWork{},
	})
	if err != nil {
		t.Fatalf("NewInvoiceService: %v", err)
	}

	_, err = service.IssueInvoice(ctx, IssueInvoiceCommand{
		ActorID: "system",
	})
	if !errors.Is(err, ErrInvoiceInvalidInput) {
		t.Fatalf("expected invalid input error for missing order id, got %v", err)
	}

	_, err = service.IssueInvoice(ctx, IssueInvoiceCommand{
		OrderRef: "/orders/order_99",
	})
	if !errors.Is(err, ErrInvoiceInvalidInput) {
		t.Fatalf("expected invalid input error for missing actor id, got %v", err)
	}
}

func TestInvoiceServiceIssueInvoices_WithOrderIDs(t *testing.T) {
	ctx := context.Background()
	now := time.Date(2025, 5, 1, 10, 0, 0, 0, time.UTC)

	orderSamples := map[string]domain.Order{
		"order_1": {
			ID:       "order_1",
			Currency: "JPY",
			Totals:   domain.OrderTotals{Total: 12000},
			Metadata: map[string]any{},
		},
		"order_2": {
			ID:       "order_2",
			Currency: "JPY",
			Totals:   domain.OrderTotals{Total: 3400},
			Metadata: map[string]any{},
		},
	}

	var updated []domain.Order
	orderRepo := &stubOrderRepo{
		findFn: func(_ context.Context, id string) (domain.Order, error) {
			if order, ok := orderSamples[id]; ok {
				return order, nil
			}
			return domain.Order{}, errors.New("not found")
		},
		updateFn: func(_ context.Context, order domain.Order) error {
			updated = append(updated, order)
			return nil
		},
	}
	invoiceRepo := &stubInvoiceRepo{}
	batchRepo := &stubInvoiceBatchRepo{}
	counter := &stubInvoiceCounterService{invoiceNumbers: []string{"INV-202505-000001", "INV-202505-000002"}}
	storage := &stubInvoiceStorage{}
	renderer := &stubInvoiceRenderer{}

	idSeq := []string{"job_001", "inv_a", "inv_b"}
	idIdx := 0
	idGen := func() string {
		defer func() { idIdx++ }()
		return idSeq[idIdx]
	}

	service, err := NewInvoiceService(InvoiceServiceDeps{
		Orders:      orderRepo,
		Invoices:    invoiceRepo,
		Batches:     batchRepo,
		Counters:    counter,
		Storage:     storage,
		Renderer:    renderer,
		UnitOfWork:  &stubUnitOfWork{},
		Clock:       func() time.Time { return now },
		IDGenerator: idGen,
	})
	if err != nil {
		t.Fatalf("NewInvoiceService: %v", err)
	}

	result, err := service.IssueInvoices(ctx, IssueInvoicesCommand{
		OrderIDs: []string{" order_1 ", "order_2", "order_1"},
		ActorID:  " admin ",
		Notes:    " send asap ",
	})
	if err != nil {
		t.Fatalf("IssueInvoices: %v", err)
	}

	if result.JobID != "job_001" {
		t.Fatalf("expected job id job_001, got %q", result.JobID)
	}
	if len(result.Issued) != 2 {
		t.Fatalf("expected 2 issued invoices, got %d", len(result.Issued))
	}
	if len(result.Failed) != 0 {
		t.Fatalf("expected no failures, got %v", result.Failed)
	}
	if result.Summary.TotalOrders != 2 || result.Summary.Issued != 2 || result.Summary.Failed != 0 {
		t.Fatalf("unexpected summary: %+v", result.Summary)
	}

	if counter.invoiceCalls != 2 {
		t.Fatalf("expected counter invoked twice, got %d", counter.invoiceCalls)
	}

	if len(storage.storedObjects) != 2 {
		t.Fatalf("expected 2 stored objects, got %d", len(storage.storedObjects))
	}
	expectedPath := "assets/orders/order_1/invoices/INV-202505-000001.pdf"
	if storage.storedObjects[0] != expectedPath {
		t.Fatalf("expected storage path %q, got %q", expectedPath, storage.storedObjects[0])
	}

	if len(invoiceRepo.inserted) != 2 {
		t.Fatalf("expected 2 inserted invoices, got %d", len(invoiceRepo.inserted))
	}
	if invoiceRepo.inserted[0].OrderRef != "/orders/order_1" {
		t.Fatalf("expected order ref /orders/order_1, got %q", invoiceRepo.inserted[0].OrderRef)
	}
	if note, ok := invoiceRepo.inserted[0].Metadata["notes"].(string); !ok || note != "send asap" {
		t.Fatalf("expected notes normalized, got %v", invoiceRepo.inserted[0].Metadata["notes"])
	}

	if len(updated) != 2 {
		t.Fatalf("expected 2 updated orders, got %d", len(updated))
	}
	if num, ok := updated[0].Metadata["invoiceNumber"].(string); !ok || num != "INV-202505-000001" {
		t.Fatalf("expected metadata invoice number set, got %v", updated[0].Metadata["invoiceNumber"])
	}
	if ref, ok := updated[0].Metadata["invoiceAssetRef"].(string); !ok || ref == "" {
		t.Fatalf("expected invoice asset ref set, got %v", updated[0].Metadata["invoiceAssetRef"])
	}
	if note, ok := updated[0].Metadata["invoiceNotes"].(string); !ok || note != "send asap" {
		t.Fatalf("expected notes persisted, got %v", updated[0].Metadata["invoiceNotes"])
	}

	if len(batchRepo.inserted) != 1 {
		t.Fatalf("expected 1 batch job inserted, got %d", len(batchRepo.inserted))
	}
	job := batchRepo.inserted[0]
	if job.ID != "job_001" {
		t.Fatalf("expected job id job_001, got %q", job.ID)
	}
	if job.Status != domain.InvoiceBatchJobStatusSucceeded {
		t.Fatalf("expected job status succeeded, got %s", job.Status)
	}
	if len(job.OrderIDs) != 2 || job.OrderIDs[0] != "order_1" {
		t.Fatalf("expected order ids tracked, got %v", job.OrderIDs)
	}
	if note, ok := job.Metadata["notes"].(string); !ok || note != "send asap" {
		t.Fatalf("expected job metadata notes, got %v", job.Metadata["notes"])
	}
	if _, ok := job.Metadata["failures"]; ok {
		t.Fatalf("did not expect failures metadata, got %v", job.Metadata["failures"])
	}
}

func TestInvoiceServiceIssueInvoices_FilterLimit(t *testing.T) {
	ctx := context.Background()
	now := time.Date(2025, 6, 1, 9, 0, 0, 0, time.UTC)

	listCalls := 0
	orderRepo := &stubOrderRepo{
		listFn: func(_ context.Context, filter repositories.OrderListFilter) (domain.CursorPage[domain.Order], error) {
			listCalls++
			if len(filter.Status) != 1 || filter.Status[0] != "paid" {
				t.Fatalf("expected status filter trimmed, got %v", filter.Status)
			}
			if filter.Pagination.PageSize != 1 {
				t.Fatalf("expected page size respected, got %d", filter.Pagination.PageSize)
			}
			if filter.SortBy != repositories.OrderSortCreatedAt {
				t.Fatalf("expected sort by created at")
			}
			orders := []domain.Order{
				{ID: "order_3", Currency: "JPY", Totals: domain.OrderTotals{Total: 4500}},
			}
			return domain.CursorPage[domain.Order]{Items: orders}, nil
		},
		updateFn: func(context.Context, domain.Order) error { return nil },
		findFn:   func(context.Context, string) (domain.Order, error) { return domain.Order{}, errors.New("unsupported") },
	}
	invoiceRepo := &stubInvoiceRepo{}
	batchRepo := &stubInvoiceBatchRepo{}
	counter := &stubInvoiceCounterService{invoiceNumbers: []string{"INV-202506-000001"}}
	storage := &stubInvoiceStorage{}
	renderer := &stubInvoiceRenderer{}

	idSeq := []string{"job_100", "inv_c"}
	idIdx := 0
	idGen := func() string {
		defer func() { idIdx++ }()
		return idSeq[idIdx]
	}

	service, err := NewInvoiceService(InvoiceServiceDeps{
		Orders:      orderRepo,
		Invoices:    invoiceRepo,
		Batches:     batchRepo,
		Counters:    counter,
		Storage:     storage,
		Renderer:    renderer,
		UnitOfWork:  &stubUnitOfWork{},
		Clock:       func() time.Time { return now },
		IDGenerator: idGen,
	})
	if err != nil {
		t.Fatalf("NewInvoiceService: %v", err)
	}

	from := now.Add(-24 * time.Hour)
	to := now
	result, err := service.IssueInvoices(ctx, IssueInvoicesCommand{
		Filter: InvoiceBatchFilter{
			Statuses:    []string{" paid "},
			PlacedRange: domain.RangeQuery[time.Time]{From: &from, To: &to},
		},
		ActorID: "staff",
		Limit:   1,
	})
	if err != nil {
		t.Fatalf("IssueInvoices: %v", err)
	}

	if listCalls != 1 {
		t.Fatalf("expected single list call, got %d", listCalls)
	}
	if result.JobID != "job_100" {
		t.Fatalf("expected job id job_100, got %q", result.JobID)
	}
	if result.Summary.TotalOrders != 1 {
		t.Fatalf("expected summary total 1, got %d", result.Summary.TotalOrders)
	}
	if len(result.Failed) != 0 {
		t.Fatalf("expected no failures, got %v", result.Failed)
	}
	if val, ok := batchRepo.inserted[0].Filters["placedFrom"].(string); !ok || val == "" {
		t.Fatalf("expected filter snapshot stored, got %v", batchRepo.inserted[0].Filters["placedFrom"])
	}
	if batchRepo.inserted[0].Status != domain.InvoiceBatchJobStatusSucceeded {
		t.Fatalf("expected succeeded status, got %s", batchRepo.inserted[0].Status)
	}
}

func TestInvoiceServiceIssueInvoices_PartialFailures(t *testing.T) {
	ctx := context.Background()
	now := time.Date(2025, 7, 1, 9, 0, 0, 0, time.UTC)

	orderSamples := map[string]domain.Order{
		"order_ok": {
			ID:       "order_ok",
			Currency: "JPY",
			Totals:   domain.OrderTotals{Total: 5000},
			Metadata: map[string]any{},
		},
		"order_fail": {
			ID:       "order_fail",
			Currency: "JPY",
			Totals:   domain.OrderTotals{Total: 2500},
			Metadata: map[string]any{},
		},
	}

	var updated []domain.Order
	orderRepo := &stubOrderRepo{
		findFn: func(_ context.Context, id string) (domain.Order, error) {
			if order, ok := orderSamples[id]; ok {
				return order, nil
			}
			return domain.Order{}, errors.New("not found")
		},
		updateFn: func(_ context.Context, order domain.Order) error {
			updated = append(updated, order)
			return nil
		},
	}
	invoiceRepo := &stubInvoiceRepo{}
	batchRepo := &stubInvoiceBatchRepo{}
	counter := &stubInvoiceCounterService{invoiceNumbers: []string{"INV-202507-000001", "INV-202507-000002"}}
	storage := &stubInvoiceStorage{
		failures: map[string]error{
			"order_fail": errors.New("storage unavailable"),
		},
	}
	renderer := &stubInvoiceRenderer{}

	idSeq := []string{"job_partial", "inv_ok", "inv_fail"}
	idIdx := 0
	idGen := func() string {
		defer func() { idIdx++ }()
		return idSeq[idIdx]
	}

	service, err := NewInvoiceService(InvoiceServiceDeps{
		Orders:      orderRepo,
		Invoices:    invoiceRepo,
		Batches:     batchRepo,
		Counters:    counter,
		Storage:     storage,
		Renderer:    renderer,
		UnitOfWork:  &stubUnitOfWork{},
		Clock:       func() time.Time { return now },
		IDGenerator: idGen,
	})
	if err != nil {
		t.Fatalf("NewInvoiceService: %v", err)
	}

	result, err := service.IssueInvoices(ctx, IssueInvoicesCommand{
		OrderIDs: []string{"order_ok", "order_fail"},
		ActorID:  "ops",
	})
	if err != nil {
		t.Fatalf("IssueInvoices: %v", err)
	}
	if len(result.Issued) != 1 || result.Issued[0].OrderID != "order_ok" {
		t.Fatalf("expected one issued invoice for order_ok, got %+v", result.Issued)
	}
	if len(result.Failed) != 1 || result.Failed[0].OrderID != "order_fail" {
		t.Fatalf("expected one failure for order_fail, got %+v", result.Failed)
	}
	if result.Summary.Issued != 1 || result.Summary.Failed != 1 {
		t.Fatalf("unexpected summary %+v", result.Summary)
	}
	if len(invoiceRepo.inserted) != 1 {
		t.Fatalf("expected one invoice inserted, got %d", len(invoiceRepo.inserted))
	}
	if len(updated) != 1 || updated[0].ID != "order_ok" {
		t.Fatalf("expected only order_ok updated, got %+v", updated)
	}
	if batchRepo.inserted[0].Status != domain.InvoiceBatchJobStatusFailed {
		t.Fatalf("expected job status failed, got %s", batchRepo.inserted[0].Status)
	}
	failuresMeta, ok := batchRepo.inserted[0].Metadata["failures"].([]map[string]any)
	if !ok || len(failuresMeta) != 1 {
		t.Fatalf("expected failures metadata recorded, got %v", batchRepo.inserted[0].Metadata["failures"])
	}
	if val, ok := failuresMeta[0]["orderId"]; !ok || val != "order_fail" {
		t.Fatalf("expected failure order id recorded, got %v", failuresMeta)
	}
}

type stubInvoiceRepo struct {
	inserted []domain.Invoice
	findFn   func(context.Context, string) ([]domain.Invoice, error)
	insertFn func(context.Context, domain.Invoice) (domain.Invoice, error)
}

func (s *stubInvoiceRepo) Insert(ctx context.Context, invoice domain.Invoice) (domain.Invoice, error) {
	if s.insertFn != nil {
		return s.insertFn(ctx, invoice)
	}
	s.inserted = append(s.inserted, invoice)
	return invoice, nil
}

func (s *stubInvoiceRepo) FindByOrderID(ctx context.Context, orderID string) ([]domain.Invoice, error) {
	if s.findFn != nil {
		return s.findFn(ctx, orderID)
	}
	return nil, nil
}

type stubInvoiceBatchRepo struct {
	inserted []domain.InvoiceBatchJob
}

func (s *stubInvoiceBatchRepo) Insert(ctx context.Context, job domain.InvoiceBatchJob) (domain.InvoiceBatchJob, error) {
	s.inserted = append(s.inserted, job)
	return job, nil
}

type stubInvoiceCounterService struct {
	invoiceNumbers []string
	invoiceCalls   int
}

func (s *stubInvoiceCounterService) Next(context.Context, string, string, CounterGenerationOptions) (CounterValue, error) {
	return CounterValue{}, nil
}

func (s *stubInvoiceCounterService) NextOrderNumber(context.Context) (string, error) {
	return "", nil
}

func (s *stubInvoiceCounterService) NextInvoiceNumber(context.Context) (string, error) {
	if s.invoiceCalls >= len(s.invoiceNumbers) {
		return "", errors.New("no more invoice numbers")
	}
	value := s.invoiceNumbers[s.invoiceCalls]
	s.invoiceCalls++
	return value, nil
}

type stubInvoiceStorage struct {
	storedObjects []string
	failures      map[string]error
}

func (s *stubInvoiceStorage) StoreInvoice(_ context.Context, object string, _ []byte, _ map[string]string) (string, error) {
	if s.failures != nil {
		if orderID := extractOrderID(object); orderID != "" {
			if err := s.failures[orderID]; err != nil {
				return "", err
			}
		}
	}
	s.storedObjects = append(s.storedObjects, object)
	return "/assets/" + object, nil
}

func extractOrderID(object string) string {
	segments := strings.Split(object, "/")
	for i := 0; i < len(segments); i++ {
		if segments[i] == "orders" && i+1 < len(segments) {
			return segments[i+1]
		}
	}
	return ""
}

type stubInvoiceRenderer struct {
	calls []string
}

func (s *stubInvoiceRenderer) RenderInvoice(context.Context, domain.Order, domain.Invoice) ([]byte, error) {
	return []byte("pdf"), nil
}
