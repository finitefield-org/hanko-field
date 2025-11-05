package services

import "context"

type noopAISuggestionNotifier struct{}

// NewNoopAISuggestionNotifier constructs a notifier that drops all notifications. Useful for
// environments where notification delivery is optional.
func NewNoopAISuggestionNotifier() AISuggestionNotifier {
	return noopAISuggestionNotifier{}
}

// NotifySuggestionReady implements AISuggestionNotifier.
func (noopAISuggestionNotifier) NotifySuggestionReady(context.Context, AISuggestionNotification) error {
	return nil
}
