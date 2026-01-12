package org

import (
	"strings"

	"finitefield.org/hanko-admin/internal/admin/templates/components"
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
	Tabs        components.UnderlineTabsProps
	Staff       *StaffPageContent
	Roles       *RolesPageContent
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
		Tabs:      buildTabs(basePath, TabStaff),
		Staff:     &content,
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
		Tabs:      buildTabs(basePath, TabRoles),
		Roles:     &content,
	}
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
