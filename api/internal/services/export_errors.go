package services

import "errors"

var (
	// ErrExportInvalidInput indicates required fields were missing or invalid.
	ErrExportInvalidInput = errors.New("export: invalid input")
	// ErrExportConflict indicates an equivalent export task already exists.
	ErrExportConflict = errors.New("export: conflict")
	// ErrExportUnavailable indicates the export subsystem is unavailable.
	ErrExportUnavailable = errors.New("export: service unavailable")
)
