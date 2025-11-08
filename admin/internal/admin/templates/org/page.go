package org

import (
	"context"
	"fmt"
	"io"
	"strings"

	"github.com/a-h/templ"

	"finitefield.org/hanko-admin/internal/admin/templates/components"
	"finitefield.org/hanko-admin/internal/admin/templates/helpers"
	"finitefield.org/hanko-admin/internal/admin/templates/layouts"
	"finitefield.org/hanko-admin/internal/admin/templates/partials"
)

// Tab identifies the active sub-page within the organisation settings.
type Tab string

const (
	// TabStaff represents the staff list view.
	TabStaff Tab = "staff"
	// TabRoles represents the role definition matrix view.
	TabRoles Tab = "roles"
)

// PageData encapsulates the payload required to render the organisation pages.
type PageData struct {
	Title       string
	Description string
	AccessNote  string
	Breadcrumbs []partials.Breadcrumb
	BasePath    string
	ActiveTab   Tab
	Body        templ.Component
}

// StaffPageContent contains the data required to render the staff management experience.
type StaffPageContent struct {
	BasePath string
	Summary  StaffSummary
	Filters  StaffFilters
	Table    StaffTable
	Invite   StaffInvite
	Error    string
}

// StaffSummary aggregates headline metrics for the staff list.
type StaffSummary struct {
	Total     int
	Active    int
	Invited   int
	Suspended int
	Revoked   int
}

// StaffFilters describes the filter form state for the staff list.
type StaffFilters struct {
	Search         string
	SelectedRole   string
	SelectedStatus string
	RoleOptions    []StaffFilterOption
	StatusOptions  []StaffFilterOption
	Action         string
	ResetURL       string
	RawQuery       string
}

// StaffFilterOption represents a selectable filter choice.
type StaffFilterOption struct {
	Value    string
	Label    string
	Selected bool
	Count    int
}

// StaffInvite captures invitation CTA state.
type StaffInvite struct {
	Allowed        bool
	Remaining      int
	Message        string
	ModalURL       string
	DisabledReason string
}

// StaffTable captures the table fragment payload.
type StaffTable struct {
	FragmentPath string
	RawQuery     string
	Rows         []StaffRow
	Total        int
	EmptyMessage string
	RefreshEvent string
}

// StaffRow represents a single staff member row.
type StaffRow struct {
	ID                 string
	Name               string
	Email              string
	Roles              []StaffRoleBadge
	StatusLabel        string
	StatusTone         string
	LastActiveRelative string
	LastActiveExact    string
	MFAStatus          string
	MFAEnabled         bool
	InvitationLabel    string
	InvitationTooltip  string
	Actions            StaffRowActions
}

// StaffRoleBadge renders a badge per role.
type StaffRoleBadge struct {
	Label string
}

// StaffRowActions provides modal triggers for a row.
type StaffRowActions struct {
	EditURL   string
	RevokeURL string
	ResendURL string
}

// RolesPageContent describes the payload for the roles overview.
type RolesPageContent struct {
	Roles []RoleCard
	Error string
}

// RoleCard summarises a role definition.
type RoleCard struct {
	Key             string
	Label           string
	Description     string
	Members         int
	LastUpdatedText string
	LastUpdatedHint string
	Capabilities    []RoleCapability
}

// RoleCapability lists an individual capability within a role.
type RoleCapability struct {
	Label       string
	Description string
}

// Index returns the full page component.
func Index(data PageData) templ.Component {
	return layouts.Base(data.Title, data.Breadcrumbs, pageBody(data))
}

// BuildStaffPageData assembles the data for the staff page.
func BuildStaffPageData(basePath string, content StaffPageContent) PageData {
	if content.BasePath == "" {
		content.BasePath = basePath
	}
	return PageData{
		Title:       "スタッフ管理",
		Description: "スタッフへのロール割り当て、招待、アクセス停止を行います。変更は即時に反映され、監査ログにも記録されます。",
		AccessNote:  "このセクションは管理者ロール（CapStaffManage）のみアクセスできます。",
		Breadcrumbs: []partials.Breadcrumb{
			{Label: "システム"},
			{Label: "スタッフ管理"},
		},
		BasePath:  basePath,
		ActiveTab: TabStaff,
		Body:      staffBody(content),
	}
}

// BuildRolesPageData assembles the data for the roles page.
func BuildRolesPageData(basePath string, content RolesPageContent) PageData {
	return PageData{
		Title:       "ロール定義",
		Description: "各ロールが保持する機能権限の一覧です。ロールの変更は RBAC 設定と監査プロセスに基づき管理されます。",
		AccessNote:  "このセクションは管理者ロール（CapStaffManage）のみアクセスできます。",
		Breadcrumbs: []partials.Breadcrumb{
			{Label: "システム"},
			{Label: "ロール定義"},
		},
		BasePath:  basePath,
		ActiveTab: TabRoles,
		Body:      rolesBody(content),
	}
}

func pageBody(data PageData) templ.Component {
	tabs := buildTabs(data.BasePath, data.ActiveTab)
	return templ.ComponentFunc(func(ctx context.Context, w io.Writer) error {
		if _, err := io.WriteString(w, `<div class="space-y-6" data-org-root>`); err != nil {
			return err
		}
		if _, err := io.WriteString(w, `<section class="rounded-2xl bg-white px-6 py-6 shadow-sm ring-1 ring-slate-200">`); err != nil {
			return err
		}
		if _, err := io.WriteString(w, `<div class="flex flex-col gap-4">`); err != nil {
			return err
		}
		if _, err := io.WriteString(w, `<div class="flex flex-col gap-2">`); err != nil {
			return err
		}
		if _, err := io.WriteString(w, `<h1 class="text-2xl font-semibold text-slate-900">`+templ.EscapeString(data.Title)+`</h1>`); err != nil {
			return err
		}
		if strings.TrimSpace(data.Description) != "" {
			if _, err := io.WriteString(w, `<p class="text-sm text-slate-600">`+templ.EscapeString(data.Description)+`</p>`); err != nil {
				return err
			}
		}
		if strings.TrimSpace(data.AccessNote) != "" {
			if _, err := io.WriteString(w, `<div class="inline-flex items-center gap-2 rounded-md border border-amber-200 bg-amber-50 px-3 py-2 text-xs font-semibold text-amber-700">`); err != nil {
				return err
			}
			if _, err := io.WriteString(w, `<span aria-hidden="true">⚠️</span>`); err != nil {
				return err
			}
			if _, err := io.WriteString(w, `<span>`+templ.EscapeString(data.AccessNote)+`</span></div>`); err != nil {
				return err
			}
		}
		if _, err := io.WriteString(w, `</div>`); err != nil {
			return err
		}
		if _, err := io.WriteString(w, `<div class="mt-4">`); err != nil {
			return err
		}
		if err := components.UnderlineTabs(tabs).Render(ctx, w); err != nil {
			return err
		}
		if _, err := io.WriteString(w, `</div>`); err != nil {
			return err
		}
		if data.Body != nil {
			if _, err := io.WriteString(w, `<div class="mt-6">`); err != nil {
				return err
			}
			if err := data.Body.Render(ctx, w); err != nil {
				return err
			}
			if _, err := io.WriteString(w, `</div>`); err != nil {
				return err
			}
		}
		if _, err := io.WriteString(w, `</div></section></div>`); err != nil {
			return err
		}
		return nil
	})
}

func buildTabs(base string, active Tab) components.UnderlineTabsProps {
	return components.UnderlineTabsProps{
		Tabs: []components.UnderlineTab{
			{
				ID:     "staff",
				Label:  "スタッフ",
				Href:   joinBase(base, "/org/staff"),
				Active: active == TabStaff,
			},
			{
				ID:     "roles",
				Label:  "ロール",
				Href:   joinBase(base, "/org/roles"),
				Active: active == TabRoles,
			},
		},
	}
}

func joinBase(base, suffix string) string {
	base = strings.TrimSpace(base)
	if base == "" || base == "/" {
		base = ""
	}
	if !strings.HasPrefix(suffix, "/") {
		suffix = "/" + suffix
	}
	path := base + suffix
	for strings.Contains(path, "//") {
		path = strings.ReplaceAll(path, "//", "/")
	}
	if !strings.HasPrefix(path, "/") {
		path = "/" + path
	}
	return path
}

func staffBody(content StaffPageContent) templ.Component {
	return templ.ComponentFunc(func(ctx context.Context, w io.Writer) error {
		if _, err := io.WriteString(w, `<div class="space-y-6" data-org-staff>`); err != nil {
			return err
		}

		// Summary & invite actions.
		if _, err := io.WriteString(w, `<div class="flex flex-col gap-6 lg:flex-row lg:items-start lg:justify-between">`); err != nil {
			return err
		}
		if _, err := io.WriteString(w, `<div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-4 lg:flex-1">`); err != nil {
			return err
		}
		if err := renderSummaryCard(w, "総スタッフ", content.Summary.Total, "info"); err != nil {
			return err
		}
		if err := renderSummaryCard(w, "アクティブ", content.Summary.Active, "success"); err != nil {
			return err
		}
		if err := renderSummaryCard(w, "招待中", content.Summary.Invited, "warning"); err != nil {
			return err
		}
		if err := renderSummaryCard(w, "アクセス停止", content.Summary.Revoked, "danger"); err != nil {
			return err
		}
		if _, err := io.WriteString(w, `</div>`); err != nil {
			return err
		}

		if _, err := io.WriteString(w, `<div class="flex flex-col items-stretch gap-3 lg:w-64">`); err != nil {
			return err
		}
		if content.Invite.Allowed {
			if err := components.ButtonWith("スタッフを招待", components.ButtonOptions{
				Variant: "primary",
				Attrs: templ.Attributes{
					"hx-get":    content.Invite.ModalURL,
					"hx-target": "#modal",
					"hx-swap":   "innerHTML",
				},
			}).Render(ctx, w); err != nil {
				return err
			}
			if content.Invite.Remaining > 0 {
				if _, err := io.WriteString(w, `<p class="text-xs text-slate-500">残り `+templ.EscapeString(fmt.Sprintf("%d 招待", content.Invite.Remaining))+`</p>`); err != nil {
					return err
				}
			}
			if strings.TrimSpace(content.Invite.Message) != "" {
				if _, err := io.WriteString(w, `<p class="text-xs text-slate-500">`+templ.EscapeString(content.Invite.Message)+`</p>`); err != nil {
					return err
				}
			}
		} else {
			if err := components.ButtonWith("招待不可", components.ButtonOptions{
				Variant:  "secondary",
				Disabled: true,
			}).Render(ctx, w); err != nil {
				return err
			}
			if strings.TrimSpace(content.Invite.DisabledReason) != "" {
				if _, err := io.WriteString(w, `<p class="text-xs text-slate-500">`+templ.EscapeString(content.Invite.DisabledReason)+`</p>`); err != nil {
					return err
				}
			}
		}
		if _, err := io.WriteString(w, `</div>`); err != nil {
			return err
		}
		if _, err := io.WriteString(w, `</div>`); err != nil {
			return err
		}

		// Error banner if present.
		if strings.TrimSpace(content.Error) != "" {
			if _, err := io.WriteString(w, `<div class="rounded-md border border-danger-200 bg-danger-50 px-4 py-3 text-sm text-danger-700">`+templ.EscapeString(content.Error)+`</div>`); err != nil {
				return err
			}
		}

		// Filters.
		if err := renderStaffFilters(ctx, w, content.Filters); err != nil {
			return err
		}

		// Table.
		if err := renderStaffTable(ctx, w, content.Table); err != nil {
			return err
		}

		if _, err := io.WriteString(w, `</div>`); err != nil {
			return err
		}
		return nil
	})
}

func renderSummaryCard(w io.Writer, label string, value int, tone string) error {
	if _, err := io.WriteString(w, `<div class="rounded-xl border border-slate-200 bg-slate-50 px-4 py-3 shadow-sm">`); err != nil {
		return err
	}
	if _, err := io.WriteString(w, `<p class="text-xs font-semibold uppercase tracking-wide text-slate-500">`+templ.EscapeString(label)+`</p>`); err != nil {
		return err
	}
	if _, err := io.WriteString(w, `<p class="mt-1 text-2xl font-semibold text-slate-900">`); err != nil {
		return err
	}
	if _, err := io.WriteString(w, templ.EscapeString(fmt.Sprintf("%d", value))); err != nil {
		return err
	}
	if _, err := io.WriteString(w, `</p>`); err != nil {
		return err
	}
	if tone == "danger" && value > 0 {
		if _, err := io.WriteString(w, `<p class="mt-2 text-xs text-danger-600">アクセス停止の確認が必要です。</p>`); err != nil {
			return err
		}
	} else if tone == "warning" && value > 0 {
		if _, err := io.WriteString(w, `<p class="mt-2 text-xs text-amber-600">招待の期限切れに注意してください。</p>`); err != nil {
			return err
		}
	}
	if _, err := io.WriteString(w, `</div>`); err != nil {
		return err
	}
	return nil
}

func renderStaffFilters(ctx context.Context, w io.Writer, filters StaffFilters) error {
	if _, err := io.WriteString(w, `<form class="rounded-xl border border-slate-200 bg-white px-4 py-4 shadow-sm" method="get"`); err != nil {
		return err
	}
	if filters.Action != "" {
		if _, err := io.WriteString(w, ` hx-get="`+templ.EscapeString(helpers.BuildURL(filters.Action, ""))+`"`); err != nil {
			return err
		}
	}
	if _, err := io.WriteString(w, ` hx-target="#org-staff-table" hx-swap="outerHTML" hx-push-url="true">`); err != nil {
		return err
	}

	if _, err := io.WriteString(w, `<div class="flex flex-col gap-4 md:flex-row md:items-end md:justify-between">`); err != nil {
		return err
	}
	if _, err := io.WriteString(w, `<div class="flex flex-col gap-2">`); err != nil {
		return err
	}
	if _, err := io.WriteString(w, `<label for="org-staff-search" class="text-xs font-semibold uppercase tracking-wide text-slate-500">検索</label>`); err != nil {
		return err
	}
	if _, err := io.WriteString(w, `<input id="org-staff-search" name="q" type="search" class="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-700 shadow-sm focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200" placeholder="氏名・メールアドレスで検索" value="`+templ.EscapeString(filters.Search)+`" />`); err != nil {
		return err
	}
	if _, err := io.WriteString(w, `</div>`); err != nil {
		return err
	}

	if _, err := io.WriteString(w, `<div class="flex flex-wrap gap-4">`); err != nil {
		return err
	}
	if err := renderSelect(w, "role", "ロール", filters.RoleOptions); err != nil {
		return err
	}
	if err := renderSelect(w, "status", "ステータス", filters.StatusOptions); err != nil {
		return err
	}
	if _, err := io.WriteString(w, `</div>`); err != nil {
		return err
	}

	if _, err := io.WriteString(w, `<div class="flex items-center gap-3 md:self-end">`); err != nil {
		return err
	}
	if err := components.ButtonWith("適用", components.ButtonOptions{
		Type:    "submit",
		Variant: "primary",
		Size:    "sm",
	}).Render(ctx, w); err != nil {
		return err
	}
	if filters.ResetURL != "" {
		if _, err := io.WriteString(w, `<a class="text-sm text-slate-600 hover:text-brand-600" href="`+templ.EscapeString(filters.ResetURL)+`">リセット</a>`); err != nil {
			return err
		}
	}
	if _, err := io.WriteString(w, `</div>`); err != nil {
		return err
	}

	if _, err := io.WriteString(w, `</div>`); err != nil {
		return err
	}
	if _, err := io.WriteString(w, `</form>`); err != nil {
		return err
	}
	return nil
}

func renderSelect(w io.Writer, name, label string, options []StaffFilterOption) error {
	if _, err := io.WriteString(w, `<div class="flex flex-col gap-2">`); err != nil {
		return err
	}
	if _, err := io.WriteString(w, `<label class="text-xs font-semibold uppercase tracking-wide text-slate-500" for="org-filter-`+templ.EscapeString(name)+`">`+templ.EscapeString(label)+`</label>`); err != nil {
		return err
	}
	if _, err := io.WriteString(w, `<select id="org-filter-`+templ.EscapeString(name)+`" name="`+templ.EscapeString(name)+`" class="min-w-[160px] rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-700 shadow-sm focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200">`); err != nil {
		return err
	}
	for _, option := range options {
		if _, err := io.WriteString(w, `<option value="`+templ.EscapeString(option.Value)+`"`); err != nil {
			return err
		}
		if option.Selected {
			if _, err := io.WriteString(w, ` selected`); err != nil {
				return err
			}
		}
		if _, err := io.WriteString(w, `>`); err != nil {
			return err
		}
		label := option.Label
		if option.Count > 0 {
			label = fmt.Sprintf("%s (%d)", label, option.Count)
		}
		if _, err := io.WriteString(w, templ.EscapeString(label)+`</option>`); err != nil {
			return err
		}
	}
	if _, err := io.WriteString(w, `</select></div>`); err != nil {
		return err
	}
	return nil
}

func renderStaffTable(ctx context.Context, w io.Writer, table StaffTable) error {
	if _, err := io.WriteString(w, `<div id="org-staff-table" class="rounded-xl border border-slate-200 bg-white shadow-sm" data-org-staff-table`); err != nil {
		return err
	}
	if table.FragmentPath != "" {
		if _, err := io.WriteString(w, ` hx-get="`+templ.EscapeString(helpers.BuildURL(table.FragmentPath, table.RawQuery))+`"`); err != nil {
			return err
		}
	}
	if table.RefreshEvent != "" {
		if _, err := io.WriteString(w, ` hx-trigger="load, `+templ.EscapeString(table.RefreshEvent)+` from:body"`); err != nil {
			return err
		}
	} else {
		if _, err := io.WriteString(w, ` hx-trigger="load"`); err != nil {
			return err
		}
	}
	if _, err := io.WriteString(w, ` hx-target="this" hx-swap="outerHTML">`); err != nil {
		return err
	}

	if _, err := io.WriteString(w, `<div class="overflow-x-auto">`); err != nil {
		return err
	}
	if _, err := io.WriteString(w, `<table class="min-w-full divide-y divide-slate-200">`); err != nil {
		return err
	}
	if _, err := io.WriteString(w, `<thead class="bg-slate-50">`); err != nil {
		return err
	}
	if _, err := io.WriteString(w, `<tr><th class="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wide text-slate-500">スタッフ</th>`); err != nil {
		return err
	}
	if _, err := io.WriteString(w, `<th class="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wide text-slate-500">ロール</th>`); err != nil {
		return err
	}
	if _, err := io.WriteString(w, `<th class="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wide text-slate-500">最終アクティブ</th>`); err != nil {
		return err
	}
	if _, err := io.WriteString(w, `<th class="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wide text-slate-500">MFA</th>`); err != nil {
		return err
	}
	if _, err := io.WriteString(w, `<th class="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wide text-slate-500">ステータス</th>`); err != nil {
		return err
	}
	if _, err := io.WriteString(w, `<th class="px-3 py-3"></th></tr></thead>`); err != nil {
		return err
	}
	if _, err := io.WriteString(w, `<tbody class="divide-y divide-slate-200 bg-white">`); err != nil {
		return err
	}
	if len(table.Rows) == 0 {
		if _, err := io.WriteString(w, `<tr><td colspan="6" class="px-6 py-12 text-center text-sm text-slate-500">`+templ.EscapeString(emptyMessage(table.EmptyMessage))+`</td></tr>`); err != nil {
			return err
		}
	} else {
		for _, row := range table.Rows {
			if _, err := io.WriteString(w, `<tr> <td class="px-6 py-4 align-top">`); err != nil {
				return err
			}
			if _, err := io.WriteString(w, `<p class="text-sm font-semibold text-slate-900">`+templ.EscapeString(row.Name)+`</p>`); err != nil {
				return err
			}
			if _, err := io.WriteString(w, `<p class="text-xs text-slate-500">`+templ.EscapeString(row.Email)+`</p>`); err != nil {
				return err
			}
			if row.InvitationLabel != "" {
				if _, err := io.WriteString(w, `<p class="mt-1 text-xs text-amber-600" title="`+templ.EscapeString(row.InvitationTooltip)+`">`+templ.EscapeString(row.InvitationLabel)+`</p>`); err != nil {
					return err
				}
			}
			if _, err := io.WriteString(w, `</td>`); err != nil {
				return err
			}

			if _, err := io.WriteString(w, `<td class="px-6 py-4 align-top">`); err != nil {
				return err
			}
			if len(row.Roles) == 0 {
				if _, err := io.WriteString(w, `<span class="text-xs text-slate-400">未割り当て</span>`); err != nil {
					return err
				}
			} else {
				if _, err := io.WriteString(w, `<div class="flex flex-wrap gap-2">`); err != nil {
					return err
				}
				for _, badge := range row.Roles {
					if _, err := io.WriteString(w, `<span class="inline-flex items-center rounded-md bg-slate-100 px-2 py-1 text-xs font-medium text-slate-700">`+templ.EscapeString(badge.Label)+`</span>`); err != nil {
						return err
					}
				}
				if _, err := io.WriteString(w, `</div>`); err != nil {
					return err
				}
			}
			if _, err := io.WriteString(w, `</td>`); err != nil {
				return err
			}

			if _, err := io.WriteString(w, `<td class="px-6 py-4 align-top text-sm text-slate-600" title="`+templ.EscapeString(row.LastActiveExact)+`">`+templ.EscapeString(row.LastActiveRelative)+`</td>`); err != nil {
				return err
			}
			mfaClass := "text-xs font-semibold text-slate-600"
			if !row.MFAEnabled {
				mfaClass = "text-xs font-semibold text-amber-600"
			}
			if _, err := io.WriteString(w, `<td class="px-6 py-4 align-top"><span class="`+mfaClass+`">`+templ.EscapeString(row.MFAStatus)+`</span></td>`); err != nil {
				return err
			}
			if _, err := io.WriteString(w, `<td class="px-6 py-4 align-top"><span class="`+helpers.BadgeClass(row.StatusTone)+`">`+templ.EscapeString(row.StatusLabel)+`</span></td>`); err != nil {
				return err
			}

			if _, err := io.WriteString(w, `<td class="px-3 py-4 align-top text-right">`); err != nil {
				return err
			}
			if row.Actions.EditURL != "" {
				if err := components.ButtonWith("ロールを編集", components.ButtonOptions{
					Variant: "ghost",
					Size:    "xs",
					Attrs: templ.Attributes{
						"hx-get":    row.Actions.EditURL,
						"hx-target": "#modal",
						"hx-swap":   "innerHTML",
					},
				}).Render(ctx, w); err != nil {
					return err
				}
			}
			if row.Actions.RevokeURL != "" {
				if err := components.ButtonWith("アクセスを停止", components.ButtonOptions{
					Variant: "ghost",
					Size:    "xs",
					Attrs: templ.Attributes{
						"hx-get":    row.Actions.RevokeURL,
						"hx-target": "#modal",
						"hx-swap":   "innerHTML",
					},
				}).Render(ctx, w); err != nil {
					return err
				}
			}
			if _, err := io.WriteString(w, `</td></tr>`); err != nil {
				return err
			}
		}
	}

	if _, err := io.WriteString(w, `</tbody></table></div></div>`); err != nil {
		return err
	}
	if _, err := io.WriteString(w, `</div>`); err != nil {
		return err
	}
	return nil
}

func rolesBody(content RolesPageContent) templ.Component {
	return templ.ComponentFunc(func(ctx context.Context, w io.Writer) error {
		if _, err := io.WriteString(w, `<div class="space-y-4">`); err != nil {
			return err
		}
		if strings.TrimSpace(content.Error) != "" {
			if _, err := io.WriteString(w, `<div class="rounded-md border border-danger-200 bg-danger-50 px-4 py-3 text-sm text-danger-700">`+templ.EscapeString(content.Error)+`</div>`); err != nil {
				return err
			}
		}
		if len(content.Roles) == 0 {
			if _, err := io.WriteString(w, `<div class="rounded-xl border border-slate-200 bg-white px-6 py-12 text-center text-sm text-slate-500 shadow-sm">ロール定義が見つかりません。バックエンドの RBAC 設定を確認してください。</div>`); err != nil {
				return err
			}
		} else {
			if _, err := io.WriteString(w, `<div class="grid gap-4 lg:grid-cols-2">`); err != nil {
				return err
			}
			for _, role := range content.Roles {
				if _, err := io.WriteString(w, `<article class="flex flex-col gap-3 rounded-xl border border-slate-200 bg-white px-5 py-5 shadow-sm">`); err != nil {
					return err
				}
				if _, err := io.WriteString(w, `<div class="flex items-start justify-between gap-3">`); err != nil {
					return err
				}
				if _, err := io.WriteString(w, `<div><h3 class="text-lg font-semibold text-slate-900">`+templ.EscapeString(role.Label)+`</h3>`); err != nil {
					return err
				}
				if strings.TrimSpace(role.Description) != "" {
					if _, err := io.WriteString(w, `<p class="text-sm text-slate-600">`+templ.EscapeString(role.Description)+`</p>`); err != nil {
						return err
					}
				}
				if _, err := io.WriteString(w, `</div>`); err != nil {
					return err
				}
				if _, err := io.WriteString(w, `<span class="rounded-md bg-slate-100 px-2 py-1 text-xs font-medium text-slate-600">`+templ.EscapeString(fmt.Sprintf("%d 名", role.Members))+`</span></div>`); err != nil {
					return err
				}
				if role.LastUpdatedText != "" {
					if _, err := io.WriteString(w, `<p class="text-xs text-slate-400" title="`+templ.EscapeString(role.LastUpdatedHint)+`">`+templ.EscapeString(role.LastUpdatedText)+`</p>`); err != nil {
						return err
					}
				}
				if len(role.Capabilities) > 0 {
					if _, err := io.WriteString(w, `<ul class="space-y-2 text-sm text-slate-600">`); err != nil {
						return err
					}
					for _, cap := range role.Capabilities {
						if _, err := io.WriteString(w, `<li class="flex items-start gap-2"><span class="mt-1 text-brand-500">•</span><div><p class="font-medium text-slate-800">`+templ.EscapeString(cap.Label)+`</p>`); err != nil {
							return err
						}
						if strings.TrimSpace(cap.Description) != "" {
							if _, err := io.WriteString(w, `<p class="text-xs text-slate-500">`+templ.EscapeString(cap.Description)+`</p>`); err != nil {
								return err
							}
						}
						if _, err := io.WriteString(w, `</div></li>`); err != nil {
							return err
						}
					}
					if _, err := io.WriteString(w, `</ul>`); err != nil {
						return err
					}
				}
				if _, err := io.WriteString(w, `</article>`); err != nil {
					return err
				}
			}
			if _, err := io.WriteString(w, `</div>`); err != nil {
				return err
			}
		}
		if _, err := io.WriteString(w, `</div>`); err != nil {
			return err
		}
		return nil
	})
}

func emptyMessage(msg string) string {
	if strings.TrimSpace(msg) != "" {
		return msg
	}
	return "条件に一致するスタッフが存在しません。フィルタを調整してください。"
}

// StaffTableFragment renders only the staff table; used for htmx updates.
func StaffTableFragment(data StaffTable) templ.Component {
	return templ.ComponentFunc(func(ctx context.Context, w io.Writer) error {
		return renderStaffTable(ctx, w, data)
	})
}
