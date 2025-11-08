package textutil

import "strings"

// NormalizePhone strips whitespace and formatting characters keeping leading '+' and digits only.
func NormalizePhone(value string) string {
	value = strings.TrimSpace(value)
	if value == "" {
		return ""
	}
	var builder strings.Builder
	for i, r := range value {
		switch {
		case r >= '0' && r <= '9':
			builder.WriteRune(r)
		case r == '+' && i == 0:
			builder.WriteRune(r)
		}
	}
	return builder.String()
}
