package services

import "errors"

var (
	// ErrPromotionRepositoryMissing indicates the promotion repository dependency is absent.
	ErrPromotionRepositoryMissing = errors.New("promotion service: repository is not configured")
	// ErrPromotionInvalidInput indicates the caller supplied invalid promotion data.
	ErrPromotionInvalidInput = errors.New("promotion service: invalid input")
	// ErrPromotionInvalidCode signals the supplied promotion code is missing or invalid.
	ErrPromotionInvalidCode = errors.New("promotion service: invalid promotion code")
	// ErrPromotionNotFound indicates no promotion exists for the provided code.
	ErrPromotionNotFound = errors.New("promotion service: promotion not found")
	// ErrPromotionConflict indicates the promotion already exists or conflicts with an existing record.
	ErrPromotionConflict = errors.New("promotion service: promotion conflict")
	// ErrPromotionUnavailable indicates the promotion exists but is not exposed to the public channel.
	ErrPromotionUnavailable = errors.New("promotion service: promotion unavailable")
	// ErrPromotionUsageLimitReached signals the promotion has reached its global usage limit.
	ErrPromotionUsageLimitReached = errors.New("promotion service: usage limit reached")
	// ErrPromotionUserLimitReached signals the requesting user has exhausted their allowance.
	ErrPromotionUserLimitReached = errors.New("promotion service: user usage limit reached")
	// ErrPromotionUsageBlocked indicates the user's usage has been blocked by staff.
	ErrPromotionUsageBlocked = errors.New("promotion service: usage blocked")
	// ErrPromotionInactive indicates the promotion is not yet active.
	ErrPromotionInactive = errors.New("promotion service: promotion inactive")
	// ErrPromotionExpired indicates the promotion has passed its end date.
	ErrPromotionExpired = errors.New("promotion service: promotion expired")
	// ErrPromotionImmutableChange indicates immutable fields were modified after the promotion started.
	ErrPromotionImmutableChange = errors.New("promotion service: immutable fields locked")
	// ErrPromotionOperationUnsupported marks operations that have not been implemented yet.
	ErrPromotionOperationUnsupported = errors.New("promotion service: operation unsupported")
)
