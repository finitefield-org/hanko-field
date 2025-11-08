package handlers

import (
	"context"
	"sync"
)

type rateLimitRecord struct {
	endpoint string
	scope    string
}

type recordingRateLimitMetrics struct {
	mu      sync.Mutex
	records []rateLimitRecord
}

func (m *recordingRateLimitMetrics) Record(_ context.Context, endpoint, scope string) {
	if m == nil {
		return
	}
	m.mu.Lock()
	defer m.mu.Unlock()
	m.records = append(m.records, rateLimitRecord{endpoint: endpoint, scope: scope})
}

func (m *recordingRateLimitMetrics) Count() int {
	m.mu.Lock()
	defer m.mu.Unlock()
	return len(m.records)
}

func (m *recordingRateLimitMetrics) Records() []rateLimitRecord {
	m.mu.Lock()
	defer m.mu.Unlock()
	out := make([]rateLimitRecord, len(m.records))
	copy(out, m.records)
	return out
}
