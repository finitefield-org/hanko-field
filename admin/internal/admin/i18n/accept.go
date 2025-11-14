package i18n

import (
	"strings"

	"golang.org/x/text/language"
)

// MatchAcceptLanguage resolves the best matching locale for the provided Accept-Language header.
func MatchAcceptLanguage(header string) string {
	header = strings.TrimSpace(header)
	if header == "" {
		return Default().Canonicalize("")
	}
	tags, _, err := language.ParseAcceptLanguage(header)
	if err != nil || len(tags) == 0 {
		return Default().Canonicalize("")
	}
	matcher := Default().matcher
	matched, _, _ := matcher.Match(tags...)
	return strings.ToLower(matched.String())
}
