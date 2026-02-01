package partials

import (
	"context"
	"fmt"
	"html"
	"io"
	"strings"

	"finitefield.org/hanko-admin/internal/admin/httpserver/middleware"
	"finitefield.org/hanko-admin/internal/admin/navigation"
	"finitefield.org/hanko-admin/internal/admin/rbac"
	"finitefield.org/hanko-admin/internal/admin/templates/helpers"
)

type sidebarComponent struct {
	Groups []navigation.MenuGroup
}

// Sidebar renders a minimal sidebar navigation for template tests.
func Sidebar(groups []navigation.MenuGroup) sidebarComponent {
	return sidebarComponent{Groups: groups}
}

// Render writes the sidebar HTML to the provided writer.
func (c sidebarComponent) Render(ctx context.Context, w io.Writer) error {
	groups := visibleMenuGroups(c.Groups, ctx)

	var b strings.Builder
	b.WriteString("<nav>")
	for _, group := range groups {
		b.WriteString("<ul>")
		for _, item := range group.Items {
			active := helpers.NavActive(ctx, item.Pattern, item.MatchPrefix)
			class := helpers.NavClass(active)

			fmt.Fprintf(&b, `<a href="%s" class="%s"`, html.EscapeString(item.Href), html.EscapeString(class))
			if active {
				b.WriteString(` aria-current="page"`)
			}
			b.WriteString(">")
			b.WriteString(html.EscapeString(item.Label))
			if item.BadgeKey != "" {
				fmt.Fprintf(&b, `<span data-nav-badge="%s" data-empty="true">0</span>`, html.EscapeString(item.BadgeKey))
			}
			b.WriteString("</a>")
		}
		b.WriteString("</ul>")
	}
	b.WriteString("</nav>")

	_, err := io.WriteString(w, b.String())
	return err
}

type topbarComponent struct{}

// TopbarActions renders the topbar action cluster.
func TopbarActions() topbarComponent {
	return topbarComponent{}
}

// Render writes the topbar HTML to the provided writer.
func (c topbarComponent) Render(ctx context.Context, w io.Writer) error {
	basePath := helpers.BasePath(ctx)
	env := middleware.EnvironmentFromContext(ctx)
	user, _ := middleware.UserFromContext(ctx)
	roles := []string(nil)
	if user != nil {
		roles = user.Roles
	}

	canSearch := rbac.HasCapability(roles, rbac.CapSearchGlobal)
	canNotifications := rbac.HasCapability(roles, rbac.CapNotificationsFeed)
	canReviews := rbac.HasCapability(roles, rbac.CapReviewsModerate)
	canTasks := rbac.HasCapability(roles, rbac.CapSystemTasks)

	var b strings.Builder
	b.WriteString(`<div data-topbar-actions>`)
	fmt.Fprintf(&b, `<span data-environment-badge><span aria-hidden="true">%s</span></span>`, html.EscapeString(environmentLabel(env)))

	if canSearch {
		fmt.Fprintf(
			&b,
			`<button data-topbar-search-trigger hx-get="%s" data-search-href="%s"></button>`,
			html.EscapeString(topbarRoute(basePath, "/search?overlay=1")),
			html.EscapeString(topbarRoute(basePath, "/search")),
		)
	}

	if canNotifications {
		fmt.Fprintf(&b, `<div data-notifications-root hx-get="%s"></div>`, html.EscapeString(topbarRoute(basePath, "/notifications/badge")))
	}

	if basePath != "" && (canNotifications || canReviews || canTasks) {
		fmt.Fprintf(
			&b,
			`<div data-workload-badges data-workload-endpoint="%s">`,
			html.EscapeString(topbarRoute(basePath, "/notifications/badge")),
		)
		if canReviews {
			b.WriteString(`<span data-workload-badge="reviews" data-empty="true"></span>`)
		}
		if canNotifications {
			b.WriteString(`<span data-workload-badge="alerts" data-empty="true"></span>`)
		}
		if canTasks {
			b.WriteString(`<span data-workload-badge="tasks" data-empty="true"></span>`)
		}
		b.WriteString(`</div>`)
	}

	if basePath != "" {
		csrf := middleware.CSRFTokenFromContext(ctx)
		fmt.Fprintf(
			&b,
			`<div data-user-menu><div class="truncate text-sm">%s</div><form data-user-menu-logout action="%s"><input type="hidden" name="_csrf" value="%s"></form></div>`,
			html.EscapeString(userDisplayName(user)),
			html.EscapeString(topbarRoute(basePath, "/logout")),
			html.EscapeString(csrf),
		)
	}

	b.WriteString(`</div>`)
	_, err := io.WriteString(w, b.String())
	return err
}

func hasVisibleItems(group navigation.MenuGroup, ctx context.Context) bool {
	return len(visibleItems(group, ctx)) > 0
}

func visibleItems(group navigation.MenuGroup, ctx context.Context) []navigation.MenuItem {
	user, ok := middleware.UserFromContext(ctx)
	if !ok || user == nil {
		return nil
	}
	if !rbac.HasCapability(user.Roles, group.Capability) {
		return nil
	}

	items := make([]navigation.MenuItem, 0, len(group.Items))
	for _, item := range group.Items {
		if rbac.HasCapability(user.Roles, item.Capability) {
			items = append(items, item)
		}
	}
	return items
}

func visibleMenuGroups(groups []navigation.MenuGroup, ctx context.Context) []navigation.MenuGroup {
	if len(groups) == 0 {
		return nil
	}
	result := make([]navigation.MenuGroup, 0, len(groups))
	for _, group := range groups {
		items := visibleItems(group, ctx)
		if len(items) == 0 {
			continue
		}
		group.Items = items
		result = append(result, group)
	}
	return result
}

func environmentLabel(env string) string {
	trimmed := strings.TrimSpace(env)
	if trimmed == "" {
		return "DEV"
	}
	switch strings.ToLower(trimmed) {
	case "production", "prod", "live":
		return "PROD"
	case "staging", "stage", "stg":
		return "STG"
	case "development", "dev", "local":
		return "DEV"
	default:
		return strings.ToUpper(trimmed)
	}
}

func topbarRoute(basePath, suffix string) string {
	base := strings.TrimSpace(basePath)
	if base == "" {
		base = "/"
	}
	if !strings.HasPrefix(base, "/") {
		base = "/" + base
	}
	if len(base) > 1 {
		base = strings.TrimRight(base, "/")
	}

	raw := strings.TrimSpace(suffix)
	if raw == "" {
		return base
	}

	query := ""
	if idx := strings.Index(raw, "?"); idx >= 0 {
		query = raw[idx:]
		raw = raw[:idx]
	}

	path := strings.TrimSpace(raw)
	if path == "" || path == "/" {
		if query != "" {
			return base + query
		}
		return base
	}

	if !strings.HasPrefix(path, "/") {
		path = "/" + path
	}

	if base == "/" {
		return normalizeSlashes(path) + query
	}

	return normalizeSlashes(base+path) + query
}

func normalizeSlashes(path string) string {
	if path == "" {
		return "/"
	}
	result := strings.ReplaceAll(path, "//", "/")
	if len(result) > 1 {
		result = strings.TrimRight(result, "/")
		if result == "" {
			return "/"
		}
	}
	return result
}

func userDisplayName(user *middleware.User) string {
	if user == nil {
		return "staff"
	}
	if strings.TrimSpace(user.UID) != "" {
		return user.UID
	}
	if strings.TrimSpace(user.Email) != "" {
		return user.Email
	}
	return "staff"
}
