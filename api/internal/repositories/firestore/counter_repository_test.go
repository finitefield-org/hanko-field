package firestore

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/hanko-field/api/internal/internaltest/firestoretest"
	pfirestore "github.com/hanko-field/api/internal/platform/firestore"
	"github.com/hanko-field/api/internal/repositories"
)

func TestCounterRepositoryNextAndConfigureWithEmulator(t *testing.T) {
	cfg, cleanup := firestoretest.StartEmulator(t, "counter-unit")
	defer cleanup()

	provider := pfirestore.NewProvider(cfg)
	t.Cleanup(func() { _ = provider.Close(context.Background()) })

	repo, err := NewCounterRepository(provider)
	if err != nil {
		t.Fatalf("create counter repository: %v", err)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()

	v1, err := repo.Next(ctx, "orders:global", 0)
	if err != nil {
		t.Fatalf("next initial: %v", err)
	}
	if v1 != 1 {
		t.Fatalf("expected first counter value 1, got %d", v1)
	}

	v2, err := repo.Next(ctx, "orders:global", 0)
	if err != nil {
		t.Fatalf("next reuse step: %v", err)
	}
	if v2 != 2 {
		t.Fatalf("expected subsequent value 2, got %d", v2)
	}

	step := int64(5)
	if err := repo.Configure(ctx, "orders:global", repositories.CounterConfig{Step: step}); err != nil {
		t.Fatalf("configure step: %v", err)
	}

	v3, err := repo.Next(ctx, "orders:global", 0)
	if err != nil {
		t.Fatalf("next after configure: %v", err)
	}
	if expected := v2 + step; v3 != expected {
		t.Fatalf("expected counter to use configured step %d, got %d", expected, v3)
	}
}

func TestCounterRepositoryRespectsBounds(t *testing.T) {
	cfg, cleanup := firestoretest.StartEmulator(t, "counter-bounded")
	defer cleanup()

	provider := pfirestore.NewProvider(cfg)
	t.Cleanup(func() { _ = provider.Close(context.Background()) })

	repo, err := NewCounterRepository(provider)
	if err != nil {
		t.Fatalf("create counter repository: %v", err)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()

	max := int64(6)
	initial := int64(2)
	step := int64(2)
	if err := repo.Configure(ctx, "invoices:regional", repositories.CounterConfig{
		InitialValue: &initial,
		MaxValue:     &max,
		Step:         step,
	}); err != nil {
		t.Fatalf("configure bounded counter: %v", err)
	}

	v1, err := repo.Next(ctx, "invoices:regional", 0)
	if err != nil {
		t.Fatalf("next bounded first: %v", err)
	}
	if v1 != initial+step {
		t.Fatalf("expected initial+step=%d, got %d", initial+step, v1)
	}

	v2, err := repo.Next(ctx, "invoices:regional", 0)
	if err != nil {
		t.Fatalf("next bounded second: %v", err)
	}
	if v2 != v1+step {
		t.Fatalf("expected second increment %d, got %d", v1+step, v2)
	}

	_, err = repo.Next(ctx, "invoices:regional", 0)
	if err == nil {
		t.Fatalf("expected bounded counter to exhaust")
	}
	var counterErr *repositories.CounterError
	if !errors.As(err, &counterErr) {
		t.Fatalf("expected counter error, got %T %v", err, err)
	}
	if counterErr.Code != repositories.CounterErrorExhausted {
		t.Fatalf("expected exhausted code, got %q", counterErr.Code)
	}
}

func TestCounterRepositoryValidatesInput(t *testing.T) {
	repo := &CounterRepository{}
	if _, err := repo.Next(context.Background(), "   ", 1); err == nil {
		t.Fatalf("expected error for blank counter id")
	}
	if _, err := repo.Next(context.Background(), "orders", -1); err == nil {
		t.Fatalf("expected error for negative step")
	}
	if err := repo.Configure(context.Background(), "   ", repositories.CounterConfig{}); err == nil {
		t.Fatalf("expected error for blank id during configure")
	}
}
