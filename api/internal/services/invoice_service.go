package services

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"sync"
	"time"

	"github.com/oklog/ulid/v2"

	domain "github.com/hanko-field/api/internal/domain"
	"github.com/hanko-field/api/internal/platform/storage"
	"github.com/hanko-field/api/internal/repositories"
)

const (
	defaultInvoiceBatchLimit = 50
	maxInvoiceBatchLimit     = 200
	defaultInvoiceWorkers    = 5
)

var (
	// ErrInvoiceInvalidInput indicates required fields were missing or invalid.
	ErrInvoiceInvalidInput = errors.New("invoice: invalid input")
	// ErrInvoiceConflict indicates an invoice already exists for the order.
	ErrInvoiceConflict = errors.New("invoice: conflict")
	// ErrInvoiceOrderNotFound indicates the order could not be located.
	ErrInvoiceOrderNotFound = errors.New("invoice: order not found")
	// ErrInvoiceRepositoryUnavailable indicates the backing repository is unavailable.
	ErrInvoiceRepositoryUnavailable = errors.New("invoice: repository unavailable")
	// ErrInvoiceGenerationFailed indicates invoice document rendering failed.
	ErrInvoiceGenerationFailed = errors.New("invoice: generation failed")
)

// InvoiceStorage persists rendered invoice documents and returns an asset reference.
type InvoiceStorage interface {
	StoreInvoice(ctx context.Context, object string, content []byte, metadata map[string]string) (string, error)
}

// InvoiceDocumentRenderer renders invoice PDFs for storage.
type InvoiceDocumentRenderer interface {
	RenderInvoice(ctx context.Context, order domain.Order, invoice domain.Invoice) ([]byte, error)
}

// InvoiceServiceDeps bundles collaborators required to construct an invoice service.
type InvoiceServiceDeps struct {
	Orders      repositories.OrderRepository
	Invoices    repositories.InvoiceRepository
	Batches     repositories.InvoiceBatchRepository
	Counters    CounterService
	Storage     InvoiceStorage
	Renderer    InvoiceDocumentRenderer
	UnitOfWork  repositories.UnitOfWork
	Clock       func() time.Time
	IDGenerator func() string
	Logger      func(ctx context.Context, event string, fields map[string]any)
}

type invoiceService struct {
	orders   repositories.OrderRepository
	invoices repositories.InvoiceRepository
	batches  repositories.InvoiceBatchRepository
	counters CounterService
	storage  InvoiceStorage
	renderer InvoiceDocumentRenderer
	uow      repositories.UnitOfWork
	now      func() time.Time
	newID    func() string
	log      func(context.Context, string, map[string]any)
}

// NewInvoiceService constructs an InvoiceService with the provided dependencies.
func NewInvoiceService(deps InvoiceServiceDeps) (InvoiceService, error) {
	if deps.Orders == nil {
		return nil, errors.New("invoice service: orders repository is required")
	}
	if deps.Invoices == nil {
		return nil, errors.New("invoice service: invoices repository is required")
	}
	if deps.Batches == nil {
		return nil, errors.New("invoice service: batch repository is required")
	}
	if deps.Counters == nil {
		return nil, errors.New("invoice service: counter service is required")
	}
	if deps.Storage == nil {
		return nil, errors.New("invoice service: storage is required")
	}
	if deps.Renderer == nil {
		return nil, errors.New("invoice service: renderer is required")
	}

	clock := deps.Clock
	if clock == nil {
		clock = time.Now
	}
	idGen := deps.IDGenerator
	if idGen == nil {
		idGen = func() string { return ulid.Make().String() }
	}
	logger := deps.Logger
	if logger == nil {
		logger = func(context.Context, string, map[string]any) {}
	}

	return &invoiceService{
		orders:   deps.Orders,
		invoices: deps.Invoices,
		batches:  deps.Batches,
		counters: deps.Counters,
		storage:  deps.Storage,
		renderer: deps.Renderer,
		uow:      deps.UnitOfWork,
		now: func() time.Time {
			return clock().UTC()
		},
		newID: idGen,
		log:   logger,
	}, nil
}

func (s *invoiceService) IssueInvoices(ctx context.Context, cmd IssueInvoicesCommand) (IssueInvoicesResult, error) {
	if ctx == nil {
		return IssueInvoicesResult{}, fmt.Errorf("%w: context is required", ErrInvoiceInvalidInput)
	}

	actorID := strings.TrimSpace(cmd.ActorID)
	if actorID == "" {
		return IssueInvoicesResult{}, fmt.Errorf("%w: actor id is required", ErrInvoiceInvalidInput)
	}
	notes := strings.TrimSpace(cmd.Notes)

	orderIDs := uniqueStrings(cmd.OrderIDs)
	filterStatuses := trimStrings(cmd.Filter.Statuses)
	hasFilters := len(filterStatuses) > 0 || cmd.Filter.PlacedRange.From != nil || cmd.Filter.PlacedRange.To != nil
	if len(orderIDs) == 0 && !hasFilters {
		return IssueInvoicesResult{}, fmt.Errorf("%w: supply order ids or filters", ErrInvoiceInvalidInput)
	}

	limit := cmd.Limit
	if limit <= 0 {
		limit = defaultInvoiceBatchLimit
	}
	if limit > maxInvoiceBatchLimit {
		limit = maxInvoiceBatchLimit
	}

	targetOrders, err := s.resolveOrders(ctx, orderIDs, filterStatuses, cmd.Filter.PlacedRange, limit)
	if err != nil {
		return IssueInvoicesResult{}, err
	}
	if len(targetOrders) == 0 {
		return IssueInvoicesResult{}, fmt.Errorf("%w: no orders matched filters", ErrInvoiceInvalidInput)
	}

	jobID := s.newID()
	issued, failures := s.processOrders(ctx, targetOrders, actorID, notes)

	now := s.now()
	status := domain.InvoiceBatchJobStatusSucceeded
	if len(failures) > 0 {
		status = domain.InvoiceBatchJobStatusFailed
	}

	orderRefs := make([]string, 0, len(targetOrders))
	for _, order := range targetOrders {
		orderRefs = append(orderRefs, order.ID)
	}

	metadata := buildMetadata(notes)
	if len(failures) > 0 {
		failureMeta := make([]map[string]any, len(failures))
		for i, failure := range failures {
			failureMeta[i] = map[string]any{
				"orderId": failure.OrderID,
				"error":   failure.Error,
			}
		}
		if metadata == nil {
			metadata = make(map[string]any)
		}
		metadata["failures"] = failureMeta
	}

	job := domain.InvoiceBatchJob{
		ID:          jobID,
		RequestedBy: actorID,
		Status:      status,
		OrderIDs:    orderRefs,
		Filters:     s.buildFilterSnapshot(filterStatuses, cmd.Filter.PlacedRange),
		Metadata:    metadata,
		Summary: domain.InvoiceBatchSummary{
			TotalOrders: len(targetOrders),
			Issued:      len(targetOrders),
			Failed:      len(failures),
		},
		CreatedAt: now,
		UpdatedAt: now,
	}
	job.Summary.Issued = len(issued)

	if _, err := s.batches.Insert(ctx, job); err != nil {
		return IssueInvoicesResult{}, s.mapRepositoryError(err)
	}

	s.log(ctx, "invoice.batch.completed", map[string]any{
		"jobId":       job.ID,
		"orders":      len(targetOrders),
		"requestedBy": actorID,
		"failures":    len(failures),
	})

	return IssueInvoicesResult{
		JobID:   job.ID,
		Issued:  issued,
		Summary: job.Summary,
		Failed:  failures,
	}, nil
}

func (s *invoiceService) processOrders(ctx context.Context, orders []domain.Order, actorID, notes string) ([]IssuedInvoice, []InvoiceFailure) {
	if len(orders) == 0 {
		return nil, nil
	}

	concurrency := defaultInvoiceWorkers
	if len(orders) < concurrency {
		concurrency = len(orders)
	}

	type result struct {
		orderID string
		issued  *IssuedInvoice
		err     error
	}

	jobs := make(chan domain.Order)
	results := make(chan result, concurrency)

	var wg sync.WaitGroup
	wg.Add(concurrency)
	for i := 0; i < concurrency; i++ {
		go func() {
			defer wg.Done()
			for order := range jobs {
				if ctx.Err() != nil {
					results <- result{orderID: order.ID, err: ctx.Err()}
					continue
				}
				issued, err := s.issueForOrder(ctx, order, actorID, notes)
				if err != nil {
					results <- result{orderID: order.ID, err: err}
					continue
				}
				issuedCopy := issued
				results <- result{orderID: order.ID, issued: &issuedCopy}
			}
		}()
	}

	go func() {
		wg.Wait()
		close(results)
	}()

	go func() {
		for _, order := range orders {
			jobs <- order
		}
		close(jobs)
	}()

	issued := make([]IssuedInvoice, 0, len(orders))
	failures := make([]InvoiceFailure, 0)
	for res := range results {
		if res.err != nil {
			failures = append(failures, InvoiceFailure{
				OrderID: res.orderID,
				Error:   res.err.Error(),
			})
			s.log(ctx, "invoice.issue.failed", map[string]any{
				"orderId": res.orderID,
				"error":   res.err.Error(),
			})
			continue
		}
		if res.issued != nil {
			issued = append(issued, *res.issued)
		}
	}

	return issued, failures
}

func (s *invoiceService) resolveOrders(ctx context.Context, ids []string, statuses []string, placed domain.RangeQuery[time.Time], limit int) ([]domain.Order, error) {
	if len(ids) > 0 {
		return s.lookupOrdersByID(ctx, ids)
	}
	return s.lookupOrdersByFilter(ctx, statuses, placed, limit)
}

func (s *invoiceService) lookupOrdersByID(ctx context.Context, ids []string) ([]domain.Order, error) {
	orders := make([]domain.Order, 0, len(ids))
	for _, id := range ids {
		order, err := s.orders.FindByID(ctx, id)
		if err != nil {
			if isRepoNotFound(err) {
				return nil, fmt.Errorf("%w: %s", ErrInvoiceOrderNotFound, id)
			}
			if isRepoUnavailable(err) {
				return nil, fmt.Errorf("%w: %v", ErrInvoiceRepositoryUnavailable, err)
			}
			return nil, err
		}
		orders = append(orders, order)
	}
	return orders, nil
}

func (s *invoiceService) lookupOrdersByFilter(ctx context.Context, statuses []string, placed domain.RangeQuery[time.Time], limit int) ([]domain.Order, error) {
	orders := make([]domain.Order, 0, limit)
	pageToken := ""
	remaining := limit
	for remaining > 0 {
		pageSize := remaining
		if pageSize > maxInvoiceBatchLimit {
			pageSize = maxInvoiceBatchLimit
		}

		filter := repositories.OrderListFilter{
			Status:     statuses,
			DateRange:  placed,
			SortBy:     repositories.OrderSortCreatedAt,
			SortOrder:  domain.SortAsc,
			Pagination: domain.Pagination{PageSize: pageSize, PageToken: pageToken},
		}
		page, err := s.orders.List(ctx, filter)
		if err != nil {
			if isRepoUnavailable(err) {
				return nil, fmt.Errorf("%w: %v", ErrInvoiceRepositoryUnavailable, err)
			}
			return nil, err
		}
		if len(page.Items) == 0 {
			break
		}
		for _, order := range page.Items {
			orders = append(orders, order)
			remaining--
			if remaining == 0 {
				break
			}
		}
		if remaining == 0 || strings.TrimSpace(page.NextPageToken) == "" {
			break
		}
		pageToken = page.NextPageToken
	}
	return orders, nil
}

func (s *invoiceService) issueForOrder(ctx context.Context, order domain.Order, actorID, notes string) (IssuedInvoice, error) {
	var issued IssuedInvoice
	err := s.runInTx(ctx, func(txCtx context.Context) error {
		existing, err := s.invoices.FindByOrderID(txCtx, order.ID)
		if err != nil {
			if isRepoUnavailable(err) {
				return fmt.Errorf("%w: %v", ErrInvoiceRepositoryUnavailable, err)
			}
			return err
		}
		if len(existing) > 0 {
			return fmt.Errorf("%w: invoice already exists for order %s", ErrInvoiceConflict, order.ID)
		}

		number, err := s.counters.NextInvoiceNumber(txCtx)
		if err != nil {
			return err
		}
		now := s.now()

		invoice := domain.Invoice{
			ID:            s.newID(),
			InvoiceNumber: number,
			OrderRef:      fmt.Sprintf("/orders/%s", order.ID),
			Status:        domain.InvoiceStatusIssued,
			Currency:      order.Currency,
			Amount:        order.Totals.Total,
			Metadata:      buildMetadata(notes),
			CreatedAt:     now,
			UpdatedAt:     now,
		}

		payload, err := s.renderer.RenderInvoice(txCtx, order, invoice)
		if err != nil {
			return fmt.Errorf("%w: %v", ErrInvoiceGenerationFailed, err)
		}

		objectPath, err := storage.BuildObjectPath(storage.PurposeReceipt, storage.PathParams{
			OrderID:       order.ID,
			InvoiceNumber: invoice.InvoiceNumber,
		})
		if err != nil {
			return fmt.Errorf("%w: %v", ErrInvoiceGenerationFailed, err)
		}

		assetRef, err := s.storage.StoreInvoice(txCtx, objectPath, payload, map[string]string{
			"invoiceNumber": invoice.InvoiceNumber,
			"orderId":       order.ID,
		})
		if err != nil {
			if isRepoUnavailable(err) {
				return fmt.Errorf("%w: %v", ErrInvoiceRepositoryUnavailable, err)
			}
			return err
		}
		if ref := strings.TrimSpace(assetRef); ref != "" {
			refCopy := ref
			invoice.PDFAssetRef = &refCopy
		}

		saved, err := s.invoices.Insert(txCtx, invoice)
		if err != nil {
			return s.mapRepositoryError(err)
		}

		orderCopy := cloneOrder(order)
		if orderCopy.Metadata == nil {
			orderCopy.Metadata = make(map[string]any)
		}
		orderCopy.Metadata["invoiceNumber"] = saved.InvoiceNumber
		orderCopy.Metadata["invoiceStatus"] = string(saved.Status)
		if trimmed := strings.TrimSpace(assetRef); trimmed != "" {
			orderCopy.Metadata["invoiceAssetRef"] = trimmed
		}
		orderCopy.Metadata["invoiceIssuedAt"] = now.Format(time.RFC3339Nano)
		if notes != "" {
			orderCopy.Metadata["invoiceNotes"] = notes
		}
		orderCopy.UpdatedAt = now
		if strings.TrimSpace(actorID) != "" {
			actor := strings.TrimSpace(actorID)
			orderCopy.Audit.UpdatedBy = &actor
		}

		if err := s.orders.Update(txCtx, orderCopy); err != nil {
			return s.mapRepositoryError(err)
		}

		issued = IssuedInvoice{
			OrderID:       order.ID,
			InvoiceNumber: saved.InvoiceNumber,
			PDFAssetRef:   assetRef,
		}
		return nil
	})
	if err != nil {
		return IssuedInvoice{}, err
	}
	return issued, nil
}

func (s *invoiceService) buildFilterSnapshot(statuses []string, placed domain.RangeQuery[time.Time]) map[string]any {
	result := make(map[string]any)
	if len(statuses) > 0 {
		result["statuses"] = append([]string(nil), statuses...)
	}
	if placed.From != nil {
		result["placedFrom"] = placed.From.UTC().Format(time.RFC3339Nano)
	}
	if placed.To != nil {
		result["placedTo"] = placed.To.UTC().Format(time.RFC3339Nano)
	}
	if len(result) == 0 {
		return nil
	}
	return result
}

func (s *invoiceService) runInTx(ctx context.Context, fn func(ctx context.Context) error) error {
	if s.uow != nil {
		return s.uow.RunInTx(ctx, fn)
	}
	return fn(ctx)
}

func (s *invoiceService) mapRepositoryError(err error) error {
	if err == nil {
		return nil
	}
	var repoErr repositories.RepositoryError
	if errors.As(err, &repoErr) {
		switch {
		case repoErr.IsNotFound():
			return fmt.Errorf("%w: %v", ErrInvoiceOrderNotFound, err)
		case repoErr.IsConflict():
			return fmt.Errorf("%w: %v", ErrInvoiceConflict, err)
		case repoErr.IsUnavailable():
			return fmt.Errorf("%w: %v", ErrInvoiceRepositoryUnavailable, err)
		}
	}
	return err
}

func uniqueStrings(values []string) []string {
	if len(values) == 0 {
		return nil
	}
	seen := make(map[string]struct{}, len(values))
	result := make([]string, 0, len(values))
	for _, value := range values {
		value = strings.TrimSpace(value)
		if value == "" {
			continue
		}
		if _, ok := seen[value]; ok {
			continue
		}
		seen[value] = struct{}{}
		result = append(result, value)
	}
	return result
}

func trimStrings(values []string) []string {
	if len(values) == 0 {
		return nil
	}
	result := make([]string, 0, len(values))
	for _, value := range values {
		value = strings.TrimSpace(value)
		if value != "" {
			result = append(result, value)
		}
	}
	return result
}

func buildMetadata(notes string) map[string]any {
	notes = strings.TrimSpace(notes)
	if notes == "" {
		return nil
	}
	return map[string]any{
		"notes": notes,
	}
}

func cloneOrder(order domain.Order) domain.Order {
	copy := order
	if order.Metadata != nil {
		meta := make(map[string]any, len(order.Metadata))
		for k, v := range order.Metadata {
			meta[k] = v
		}
		copy.Metadata = meta
	}
	return copy
}

func isRepoUnavailable(err error) bool {
	var repoErr repositories.RepositoryError
	if errors.As(err, &repoErr) {
		return repoErr.IsUnavailable()
	}
	return false
}
