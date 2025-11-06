package jobs

import "errors"

// PermanentError indicates the message should not be retried. The runner will
// acknowledge the message while recording the failure outcome.
type PermanentError struct {
	Err error
}

// Error satisfies the error interface.
func (e *PermanentError) Error() string {
	if e == nil || e.Err == nil {
		return ""
	}
	return e.Err.Error()
}

// Unwrap exposes the underlying error.
func (e *PermanentError) Unwrap() error {
	if e == nil {
		return nil
	}
	return e.Err
}

// Permanent wraps the supplied error to signal the message should not be retried.
func Permanent(err error) error {
	if err == nil {
		return nil
	}
	return &PermanentError{Err: err}
}

// IsPermanent reports whether the error signals the message is non-retryable.
func IsPermanent(err error) bool {
	var p *PermanentError
	return errors.As(err, &p)
}
