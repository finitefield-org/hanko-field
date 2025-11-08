package services

import (
	"context"

	domain "github.com/hanko-field/api/internal/domain"
)

// noopSystemErrorStore provides an empty implementation used until a concrete
// failure log backend is wired in.
type noopSystemErrorStore struct{}

// NewNoopSystemErrorStore constructs a SystemErrorStore returning empty pages.
func NewNoopSystemErrorStore() SystemErrorStore {
	return noopSystemErrorStore{}
}

func (noopSystemErrorStore) ListSystemErrors(ctx context.Context, filter SystemErrorFilter) (domain.CursorPage[domain.SystemError], error) {
	return domain.CursorPage[domain.SystemError]{
		Items:         []domain.SystemError{},
		NextPageToken: "",
	}, nil
}

// noopSystemTaskStore provides an empty implementation used until a concrete
// task tracking backend is integrated.
type noopSystemTaskStore struct{}

// NewNoopSystemTaskStore constructs a SystemTaskStore returning empty pages.
func NewNoopSystemTaskStore() SystemTaskStore {
	return noopSystemTaskStore{}
}

func (noopSystemTaskStore) ListSystemTasks(ctx context.Context, filter SystemTaskFilter) (domain.CursorPage[domain.SystemTask], error) {
	return domain.CursorPage[domain.SystemTask]{
		Items:         []domain.SystemTask{},
		NextPageToken: "",
	}, nil
}
