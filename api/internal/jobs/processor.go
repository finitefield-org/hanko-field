package jobs

import "context"

// Processor handles normalized messages delivered by a Runner. The contract is
// that returning nil acknowledges the message, returning any other error causes
// the runner to determine whether the message should be retried or dropped.
type Processor interface {
	Process(ctx context.Context, msg Message) error
}

// ProcessorFunc adapts an ordinary function to a Processor.
type ProcessorFunc func(context.Context, Message) error

// Process implements the Processor interface.
func (f ProcessorFunc) Process(ctx context.Context, msg Message) error {
	return f(ctx, msg)
}
