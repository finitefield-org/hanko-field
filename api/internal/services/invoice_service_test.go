package services

import (
	"context"
	"errors"
	"testing"
	"time"

	domain "github.com/hanko-field/api/internal/domain"
	"github.com/hanko-field/api/internal/repositories"
)

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
	if len(job.OrderIDs) != 2 || job.OrderIDs[0] != "order_1" {
		t.Fatalf("expected order ids tracked, got %v", job.OrderIDs)
	}
	if note, ok := job.Metadata["notes"].(string); !ok || note != "send asap" {
		t.Fatalf("expected job metadata notes, got %v", job.Metadata["notes"])
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
	if val, ok := batchRepo.inserted[0].Filters["placedFrom"].(string); !ok || val == "" {
		t.Fatalf("expected filter snapshot stored, got %v", batchRepo.inserted[0].Filters["placedFrom"])
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
}

func (s *stubInvoiceStorage) StoreInvoice(_ context.Context, object string, _ []byte, _ map[string]string) (string, error) {
	s.storedObjects = append(s.storedObjects, object)
	return "/assets/" + object, nil
}

type stubInvoiceRenderer struct {
	calls []string
}

func (s *stubInvoiceRenderer) RenderInvoice(context.Context, domain.Order, domain.Invoice) ([]byte, error) {
	return []byte("pdf"), nil
}
