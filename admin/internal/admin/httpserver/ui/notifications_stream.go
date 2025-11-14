package ui

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"time"

	custommw "finitefield.org/hanko-admin/internal/admin/httpserver/middleware"
	adminnotifications "finitefield.org/hanko-admin/internal/admin/notifications"
)

const (
	notificationsStreamPollPeriod = 5 * time.Second
	notificationsStreamKeepAlive  = 25 * time.Second
)

type notificationStreamEvent struct {
	Type      string                   `json:"type"`
	Badge     badgeStreamPayload       `json:"badge"`
	LatestID  string                   `json:"latest_id,omitempty"`
	Refresh   bool                     `json:"refresh"`
	Timestamp time.Time                `json:"timestamp"`
	Error     *notificationStreamError `json:"error,omitempty"`
}

type badgeStreamPayload struct {
	Total    int `json:"total"`
	Critical int `json:"critical"`
	Warning  int `json:"warning"`
	Reviews  int `json:"reviews"`
	Tasks    int `json:"tasks"`
}

type notificationStreamError struct {
	Message string `json:"message"`
}

// NotificationsStream establishes an SSE stream for realtime badge updates.
func (h *Handlers) NotificationsStream(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	flusher, ok := w.(http.Flusher)
	if !ok {
		http.Error(w, "streaming unsupported", http.StatusInternalServerError)
		return
	}

	headers := w.Header()
	headers.Set("Content-Type", "text/event-stream")
	headers.Set("Cache-Control", "no-cache")
	headers.Set("Connection", "keep-alive")
	headers.Set("X-Accel-Buffering", "no")

	if _, err := fmt.Fprint(w, "retry: 5000\n\n"); err != nil {
		return
	}
	flusher.Flush()

	lastBadge := badgeStreamPayload{}
	lastID := ""

	sendEvent := func(event string, payload notificationStreamEvent) error {
		data, err := json.Marshal(payload)
		if err != nil {
			return err
		}
		if _, err := fmt.Fprintf(w, "event: %s\n", event); err != nil {
			return err
		}
		if _, err := fmt.Fprintf(w, "data: %s\n\n", data); err != nil {
			return err
		}
		flusher.Flush()
		return nil
	}

	sendError := func(message string) bool {
		errPayload := notificationStreamEvent{
			Type:      "stream_error",
			Timestamp: time.Now().UTC(),
			Error:     &notificationStreamError{Message: message},
		}
		if err := sendEvent("stream_error", errPayload); err != nil {
			return false
		}
		return true
	}

	sendKeepAlive := func() bool {
		if _, err := fmt.Fprint(w, ": keep-alive\n\n"); err != nil {
			return false
		}
		flusher.Flush()
		return true
	}

	emit := func(force bool) bool {
		badgeCount, err := h.notifications.Badge(ctx, user.Token)
		if err != nil {
			log.Printf("notifications stream: badge fetch failed: %v", err)
			_ = sendError("通知の集計取得に失敗しました。再接続します。")
			return false
		}

		feed, err := h.notifications.List(ctx, user.Token, adminnotifications.Query{Limit: 1})
		if err != nil {
			log.Printf("notifications stream: list fetch failed: %v", err)
			_ = sendError("通知の取得に失敗しました。再接続します。")
			return false
		}

		latestID := ""
		if len(feed.Items) > 0 {
			latestID = feed.Items[0].ID
		}

		currentBadge := badgeStreamPayload{
			Total:    badgeCount.Total,
			Critical: badgeCount.Critical,
			Warning:  badgeCount.Warning,
			Reviews:  badgeCount.ReviewsPending,
			Tasks:    badgeCount.TasksPending,
		}

		badgeChanged := currentBadge != lastBadge
		idChanged := latestID != lastID

		refresh := badgeChanged || idChanged

		if !force && !badgeChanged && !idChanged {
			lastBadge = currentBadge
			lastID = latestID
			return true
		}

		payload := notificationStreamEvent{
			Type:      "badge",
			Badge:     currentBadge,
			LatestID:  latestID,
			Refresh:   refresh,
			Timestamp: time.Now().UTC(),
		}

		if err := sendEvent("badge", payload); err != nil {
			return false
		}

		lastBadge = currentBadge
		lastID = latestID
		return true
	}

	if ok := emit(true); !ok {
		return
	}

	updateTicker := time.NewTicker(notificationsStreamPollPeriod)
	defer updateTicker.Stop()

	keepAliveTicker := time.NewTicker(notificationsStreamKeepAlive)
	defer keepAliveTicker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-updateTicker.C:
			if ok := emit(false); !ok {
				return
			}
		case <-keepAliveTicker.C:
			if ok := sendKeepAlive(); !ok {
				return
			}
		}
	}
}
