package invoice

import (
	"context"
	"testing"

	"go.uber.org/zap"

	"github.com/hanko-field/api/internal/jobs"
	"github.com/hanko-field/api/internal/services"
)

func TestProcessorServiceMissing(t *testing.T) {
	processor := NewProcessor(nil, zap.NewNop())
	err := processor.Process(context.Background(), jobs.Message{
		ID:   "msg1",
		Data: []byte(`{"actorId":"staff"}`),
	})
	if err == nil {
		t.Fatal("expected error for missing service")
	}
	if !jobs.IsPermanent(err) {
		t.Fatalf("expected permanent error, got %v", err)
	}
}

func TestProcessorInvokesService(t *testing.T) {
	stub := &stubInvoiceService{}
	processor := NewProcessor(stub, zap.NewNop())
	if err := processor.Process(context.Background(), jobs.Message{
		ID:   "msg2",
		Data: []byte(`{"actorId":"staff","orderIds":["order_1"]}`),
	}); err != nil {
		t.Fatalf("Process: %v", err)
	}
	if stub.lastCmd.ActorID != "staff" {
		t.Fatalf("expected actorId staff, got %q", stub.lastCmd.ActorID)
	}
	if len(stub.lastCmd.OrderIDs) != 1 || stub.lastCmd.OrderIDs[0] != "order_1" {
		t.Fatalf("unexpected order ids: %+v", stub.lastCmd.OrderIDs)
	}
}

type stubInvoiceService struct {
	lastCmd services.IssueInvoicesCommand
}

func (s *stubInvoiceService) IssueInvoice(context.Context, services.IssueInvoiceCommand) (services.IssuedInvoice, error) {
	return services.IssuedInvoice{}, nil
}

func (s *stubInvoiceService) IssueInvoices(ctx context.Context, cmd services.IssueInvoicesCommand) (services.IssueInvoicesResult, error) {
	s.lastCmd = cmd
	return services.IssueInvoicesResult{JobID: "job_1"}, nil
}
