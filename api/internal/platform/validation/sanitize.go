package validation

import (
	"errors"
	"fmt"
	"net/url"
	"path/filepath"
	"regexp"
	"strings"
	"unicode"
)

var (
	scriptTagPattern     = regexp.MustCompile(`(?i)<\s*/?\s*script`)
	sqlBooleanPattern    = regexp.MustCompile(`(?i)(?:'|")\s*(?:or|and)\s+1\s*=\s*1`)
	sqlUnionPattern      = regexp.MustCompile(`(?i)union\s+select`)
	sqlCommentPattern    = regexp.MustCompile(`;\s*--`)
	pathTraversalPattern = regexp.MustCompile(`\.\./|\.\.\\`)
	slugPattern          = regexp.MustCompile(`^[a-z0-9]+(?:-[a-z0-9]+)*$`)
)

var (
	// ErrScriptInjection indicates HTML/script content was detected in input.
	ErrScriptInjection = errors.New("validation: script tag detected")
	// ErrSQLInjection indicates SQL-like payloads were detected in input.
	ErrSQLInjection = errors.New("validation: sql-like pattern detected")
	// ErrPathTraversal indicates directory traversal markers were detected.
	ErrPathTraversal = errors.New("validation: path traversal detected")
)

const (
	defaultMaxPlainTextLength  = 1024
	defaultMaxIdentifierLength = 160
	defaultMaxFileNameLength   = 96
	defaultMaxSlugLength       = 120
	defaultMaxQueryValueLength = 512
)

// SanitizePlainText trims the input, strips control characters (excluding
// whitespace), and enforces an optional length limit.
func SanitizePlainText(value string, limit int) string {
	trimmed := strings.TrimSpace(value)
	if trimmed == "" {
		return ""
	}
	var builder strings.Builder
	builder.Grow(len(trimmed))
	for _, r := range trimmed {
		if unicode.IsControl(r) && r != '\n' && r != '\r' && r != '\t' {
			continue
		}
		builder.WriteRune(r)
	}
	sanitized := strings.TrimSpace(builder.String())
	if limit <= 0 {
		limit = defaultMaxPlainTextLength
	}
	if len(sanitized) > limit {
		sanitized = sanitized[:limit]
	}
	return sanitized
}

// NormalizeSlug lowercases and validates slug values against a conservative pattern.
func NormalizeSlug(raw string, maxLen int) (string, error) {
	trimmed := strings.TrimSpace(strings.ToLower(raw))
	if trimmed == "" {
		return "", errors.New("slug is required")
	}
	if maxLen <= 0 {
		maxLen = defaultMaxSlugLength
	}
	if len(trimmed) > maxLen {
		trimmed = trimmed[:maxLen]
	}
	if !slugPattern.MatchString(trimmed) {
		return "", fmt.Errorf("slug may only contain lowercase letters, numbers, and hyphens")
	}
	return trimmed, nil
}

// SanitizeFileName strips path separators, limits length, and enforces ASCII-safe characters.
func SanitizeFileName(raw string, maxLen int) (string, error) {
	trimmed := strings.TrimSpace(raw)
	if trimmed == "" {
		return "", errors.New("file name is required")
	}
	if pathTraversalPattern.MatchString(trimmed) {
		return "", ErrPathTraversal
	}
	base := filepath.Base(trimmed)
	var builder strings.Builder
	builder.Grow(len(base))
	for _, r := range base {
		switch {
		case r >= 'a' && r <= 'z':
			builder.WriteRune(r)
		case r >= 'A' && r <= 'Z':
			builder.WriteRune(r)
		case r >= '0' && r <= '9':
			builder.WriteRune(r)
		case r == '.' || r == '-' || r == '_' || r == ' ':
			builder.WriteRune(r)
		default:
			// skip other runes
		}
	}
	sanitized := strings.TrimSpace(builder.String())
	if sanitized == "" {
		return "", errors.New("file name does not contain valid characters")
	}
	if maxLen <= 0 {
		maxLen = defaultMaxFileNameLength
	}
	if len(sanitized) > maxLen {
		sanitized = sanitized[:maxLen]
	}
	return sanitized, nil
}

// ValidateIdentifier ensures identifiers contain only safe characters within the configured limit.
func ValidateIdentifier(name, value string, maxLen int) (string, error) {
	trimmed := strings.TrimSpace(value)
	if trimmed == "" {
		return "", fmt.Errorf("%s is required", name)
	}
	if maxLen <= 0 {
		maxLen = defaultMaxIdentifierLength
	}
	if len(trimmed) > maxLen {
		return "", fmt.Errorf("%s exceeds %d characters", name, maxLen)
	}
	for _, r := range trimmed {
		switch {
		case r >= 'a' && r <= 'z':
		case r >= 'A' && r <= 'Z':
		case r >= '0' && r <= '9':
		case r == '-' || r == '_' || r == '.' || r == ':' || r == '@':
		default:
			return "", fmt.Errorf("%s contains invalid characters", name)
		}
	}
	return trimmed, nil
}

// ValidateSearchQuery sanitizes search queries and rejects common injection payloads.
func ValidateSearchQuery(raw string, maxLen int) (string, error) {
	sanitized := SanitizePlainText(raw, maxLen)
	if sanitized == "" {
		return "", errors.New("search query is required")
	}
	if err := DetectInjection(sanitized); err != nil {
		return "", err
	}
	return sanitized, nil
}

// DetectInjection inspects input for common attack payloads.
func DetectInjection(value string) error {
	if scriptTagPattern.MatchString(value) {
		return ErrScriptInjection
	}
	if pathTraversalPattern.MatchString(value) {
		return ErrPathTraversal
	}
	lower := strings.ToLower(value)
	if sqlUnionPattern.MatchString(lower) || sqlBooleanPattern.MatchString(lower) || sqlCommentPattern.MatchString(lower) {
		return ErrSQLInjection
	}
	return nil
}

// SanitizePathParam cleans a path parameter and rejects suspicious payloads.
func SanitizePathParam(name, value string, limit int) (string, error) {
	sanitized := SanitizePlainText(value, limit)
	if sanitized == "" {
		return sanitized, nil
	}
	if err := DetectInjection(sanitized); err != nil {
		return "", fmt.Errorf("%s rejected: %w", name, err)
	}
	return sanitized, nil
}

// SanitizeQueryValues cleans query parameters and rejects suspicious payloads.
func SanitizeQueryValues(values url.Values, limit int) (url.Values, error) {
	if len(values) == 0 {
		return values, nil
	}
	if limit <= 0 {
		limit = defaultMaxQueryValueLength
	}
	sanitized := make(url.Values, len(values))
	for key, arr := range values {
		cleanKey := SanitizePlainText(key, 64)
		if cleanKey == "" {
			continue
		}
		dest := make([]string, 0, len(arr))
		for _, raw := range arr {
			cleaned := SanitizePlainText(raw, limit)
			if cleaned == "" {
				continue
			}
			if err := DetectInjection(cleaned); err != nil {
				return nil, fmt.Errorf("%s rejected: %w", cleanKey, err)
			}
			dest = append(dest, cleaned)
		}
		if len(dest) > 0 {
			sanitized[cleanKey] = dest
		}
	}
	return sanitized, nil
}
