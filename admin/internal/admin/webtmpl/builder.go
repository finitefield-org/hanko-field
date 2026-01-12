package webtmpl

import (
	"context"

	"finitefield.org/hanko-admin/internal/admin/httpserver/middleware"
	"finitefield.org/hanko-admin/internal/admin/navigation"
	"finitefield.org/hanko-admin/internal/admin/rbac"
	"finitefield.org/hanko-admin/internal/admin/templates/helpers"
)

const feedbackTrackerURL = "https://github.com/finitefield/hanko-field/issues"

// BuildBaseView prepares shared layout data for admin pages.
func BuildBaseView(ctx context.Context, title string, crumbs []Breadcrumb) BaseView {
	basePath := helpers.BasePath(ctx)
	requestPath := helpers.RequestPath(ctx)
	menu := navigation.BuildMenu(basePath)
	user, _ := middleware.UserFromContext(ctx)
	locale := helpers.LocaleCode(ctx)
	return BaseView{
		Title:           title,
		Locale:          locale,
		CSRFToken:       middleware.CSRFTokenFromContext(ctx),
		BasePath:        basePath,
		ContentClass:    "max-w-6xl px-4 py-6 sm:px-6 lg:px-8",
		ContentTemplate: "",
		Breadcrumbs: BreadcrumbsView{
			Items: crumbs,
		},
		Sidebar: SidebarView{
			Locale:       locale,
			RequestPath:  requestPath,
			Groups:       menu,
			Capabilities: buildCapabilities(user),
		},
		Topbar: TopbarView{
			Locale:           locale,
			BasePath:         basePath,
			Environment:      middleware.EnvironmentFromContext(ctx),
			SupportedLocales: middleware.SupportedLocalesFromContext(ctx),
			User:             user,
			CSRFToken:        middleware.CSRFTokenFromContext(ctx),
			Capabilities:     buildCapabilities(user),
		},
		FeedbackTrackerURL: feedbackTrackerURL,
	}
}

func buildCapabilities(user *middleware.User) map[string]bool {
	if user == nil {
		return nil
	}
	caps := rbac.CapabilitiesForRoles(user.Roles)
	result := make(map[string]bool, len(caps))
	for cap := range caps {
		result[string(cap)] = true
	}
	return result
}
