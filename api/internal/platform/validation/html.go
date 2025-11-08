package validation

import (
	"strings"

	"github.com/microcosm-cc/bluemonday"
)

var (
	guideHTMLPolicy = newGuideHTMLPolicy()
	pageHTMLPolicy  = guideHTMLPolicy
)

// SanitizeGuideHTML cleans guide bodies using a restrictive HTML policy.
func SanitizeGuideHTML(raw string) string {
	return sanitizeHTML(raw, guideHTMLPolicy)
}

// SanitizePageHTML cleans content pages using the same policy as guides.
func SanitizePageHTML(raw string) string {
	return sanitizeHTML(raw, pageHTMLPolicy)
}

// SanitizeHTML applies the provided bluemonday policy, defaulting to UGCPolicy when nil.
func SanitizeHTML(raw string, policy *bluemonday.Policy) string {
	if policy == nil {
		policy = bluemonday.UGCPolicy()
	}
	return sanitizeHTML(raw, policy)
}

func sanitizeHTML(raw string, policy *bluemonday.Policy) string {
	trimmed := strings.TrimSpace(raw)
	if trimmed == "" {
		return ""
	}
	return strings.TrimSpace(policy.Sanitize(trimmed))
}

func newGuideHTMLPolicy() *bluemonday.Policy {
	policy := bluemonday.UGCPolicy()
	policy.AllowElements("figure", "figcaption")
	policy.AllowAttrs("class").OnElements("figure", "figcaption", "p", "span")
	policy.AllowAttrs("loading").OnElements("img")
	policy.RequireNoFollowOnLinks(true)
	return policy
}
