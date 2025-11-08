package webhook

import (
	"context"
	"errors"
	"strings"
	"sync"
	"time"
)

// ReplayStore tracks recently seen webhook signatures to prevent replays.
type ReplayStore interface {
	Record(ctx context.Context, key string, expiry time.Time) (bool, error)
}

// ReplayStoreOption customises the behaviour of an in-memory replay store.
type ReplayStoreOption func(*InMemoryReplayStore)

// WithReplayClock overrides the clock used by the replay store (primarily for tests).
func WithReplayClock(clock func() time.Time) ReplayStoreOption {
	return func(store *InMemoryReplayStore) {
		if clock != nil {
			store.now = clock
		}
	}
}

// InMemoryReplayStore keeps replay entries in-process for a limited duration.
type InMemoryReplayStore struct {
	mu      sync.Mutex
	now     func() time.Time
	records map[string]time.Time
}

// NewInMemoryReplayStore builds an in-memory replay store.
func NewInMemoryReplayStore(opts ...ReplayStoreOption) *InMemoryReplayStore {
	store := &InMemoryReplayStore{
		now:     time.Now,
		records: make(map[string]time.Time),
	}
	for _, opt := range opts {
		if opt != nil {
			opt(store)
		}
	}
	return store
}

// Record stores the key until expiry, returning false when the key already exists.
func (s *InMemoryReplayStore) Record(_ context.Context, key string, expiry time.Time) (bool, error) {
	if s == nil {
		return false, errors.New("webhook: replay store not configured")
	}
	key = strings.TrimSpace(key)
	if key == "" {
		return false, errors.New("webhook: key is required")
	}

	now := s.now()
	s.mu.Lock()
	defer s.mu.Unlock()

	s.pruneExpiredLocked(now)
	if expiry.Before(now) {
		return false, errors.New("webhook: expiry is in the past")
	}
	if existing, ok := s.records[key]; ok && existing.After(now) {
		return false, nil
	}
	s.records[key] = expiry
	return true, nil
}

func (s *InMemoryReplayStore) pruneExpiredLocked(now time.Time) {
	if len(s.records) == 0 {
		return
	}
	for key, expires := range s.records {
		if now.After(expires) {
			delete(s.records, key)
		}
	}
}
