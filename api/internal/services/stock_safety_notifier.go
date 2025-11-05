package services

import "context"

type noopStockSafetyNotifier struct{}

// NewNoopStockSafetyNotifier constructs a StockSafetyNotifier that drops all notifications.
func NewNoopStockSafetyNotifier() StockSafetyNotifier {
	return noopStockSafetyNotifier{}
}

// NotifyStockSafety implements StockSafetyNotifier.
func (noopStockSafetyNotifier) NotifyStockSafety(context.Context, StockSafetyNotification) error {
	return nil
}

var _ StockSafetyNotifier = (*noopStockSafetyNotifier)(nil)
