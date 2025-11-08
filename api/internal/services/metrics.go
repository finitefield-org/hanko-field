package services

import "context"

// QueueDepthRecorder captures queue depth snapshots for observability.
type QueueDepthRecorder interface {
	RecordQueueDepth(ctx context.Context, queueID string, total int, statusCounts map[string]int)
}

// QueueDepthRecorderFunc adapts ordinary functions to QueueDepthRecorder.
type QueueDepthRecorderFunc func(ctx context.Context, queueID string, total int, statusCounts map[string]int)

// RecordQueueDepth invokes the wrapped function when non-nil.
func (f QueueDepthRecorderFunc) RecordQueueDepth(ctx context.Context, queueID string, total int, statusCounts map[string]int) {
	if f == nil {
		return
	}
	f(ctx, queueID, total, statusCounts)
}
