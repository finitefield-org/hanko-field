package content

import (
	"strings"
	"sync"

	"github.com/microcosm-cc/bluemonday"
)

var (
	sanitizerOnce sync.Once
	htmlSanitizer *bluemonday.Policy
)

// sanitizeMarkup strips disallowed HTML while preserving supported markup for previews.
func sanitizeMarkup(input string) string {
	if strings.TrimSpace(input) == "" {
		return ""
	}

	policy := getSanitizer()
	clean := policy.Sanitize(input)
	return strings.TrimSpace(clean)
}

func getSanitizer() *bluemonday.Policy {
	sanitizerOnce.Do(func() {
		p := bluemonday.UGCPolicy()

		// Permit semantic wrappers used in editor previews.
		p.AllowElements("article", "section", "header", "footer", "div", "span", "figure", "figcaption", "ins", "del", "mark")

		// Preserve layout hooks while still sanitising tag content.
		p.AllowAttrs("class").Globally()
		p.AllowAttrs("id").Globally()
		p.AllowAttrs("role").Globally()
		p.AllowAttrs("aria-label").Globally()
		p.AllowAttrs("data-theme").Globally()

		// Limit anchor targets and references.
		p.AllowAttrs("href", "title", "rel", "target").OnElements("a")

		// Permit safe image attributes.
		p.AllowAttrs("src", "alt", "title", "width", "height", "loading").OnElements("img")

		// Support tables and code blocks often produced by Markdown renderers.
		p.AllowTables()
		p.AllowLists()
		p.AllowElements("pre", "code", "kbd", "samp")

		htmlSanitizer = p
	})
	return htmlSanitizer
}
