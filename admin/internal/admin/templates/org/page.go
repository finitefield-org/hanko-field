package org

import (
	"context"
	"io"
	"strings"

	"github.com/a-h/templ"

	"finitefield.org/hanko-admin/internal/admin/templates/components"
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

// PageData encapsulates the payload required to render the organisation placeholders.
type PageData struct {
	Title       string
	Description string
	AccessNote  string
	Breadcrumbs []partials.Breadcrumb
	BasePath    string
	ActiveTab   Tab
	Body        templ.Component
}

// Index returns the full page component.
func Index(data PageData) templ.Component {
	return layouts.Base(data.Title, data.Breadcrumbs, pageBody(data))
}

// BuildStaffPageData assembles the placeholder data for the staff page.
func BuildStaffPageData(basePath string) PageData {
	return PageData{
		Title:       "スタッフ管理",
		Description: "バックエンドのスタッフ API が整備されるまで、Firebase Authentication コンソールでスタッフアカウントを管理します。",
		AccessNote:  "このセクションは管理者ロール（CapStaffManage）のみアクセスできます。",
		Breadcrumbs: []partials.Breadcrumb{
			{Label: "システム"},
			{Label: "スタッフ管理"},
		},
		BasePath:  basePath,
		ActiveTab: TabStaff,
		Body:      staffBody(),
	}
}

// BuildRolesPageData assembles the placeholder data for the roles page.
func BuildRolesPageData(basePath string) PageData {
	return PageData{
		Title:       "ロール定義",
		Description: "RBAC 構成は Firebase カスタムクレームと `internal/admin/rbac/rbac.go` のマッピングで管理します。",
		AccessNote:  "このセクションは管理者ロール（CapStaffManage）のみアクセスできます。",
		Breadcrumbs: []partials.Breadcrumb{
			{Label: "システム"},
			{Label: "ロール定義"},
		},
		BasePath:  basePath,
		ActiveTab: TabRoles,
		Body:      rolesBody(),
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

func staffBody() templ.Component {
	const firebaseConsoleURL = "https://console.firebase.google.com/"

	return templ.ComponentFunc(func(ctx context.Context, w io.Writer) error {
		if _, err := io.WriteString(w, `<div class="space-y-4">`); err != nil {
			return err
		}
		if err := components.Card("Firebase Console でスタッフを管理", templ.ComponentFunc(func(ctx context.Context, w io.Writer) error {
			if _, err := io.WriteString(w, `<p class="text-sm text-slate-600">バックエンド統合前は Firebase Authentication のユーザー管理画面からスタッフの招待・無効化・パスワードリセットを実施してください。</p>`); err != nil {
				return err
			}
			if _, err := io.WriteString(w, `<ol class="mt-4 list-decimal space-y-2 pl-6 text-sm text-slate-600">`); err != nil {
				return err
			}
			if _, err := io.WriteString(w, `<li>Firebase Console で対象プロジェクトを選択します。</li>`); err != nil {
				return err
			}
			if _, err := io.WriteString(w, `<li>「Authentication → Users」からスタッフメールアドレスを招待または管理します。</li>`); err != nil {
				return err
			}
			if _, err := io.WriteString(w, `<li>必要に応じて「Last sign-in」「MFA enrollment」などの監査情報を参照し、運用ログに転記します。</li>`); err != nil {
				return err
			}
			if _, err := io.WriteString(w, `</ol>`); err != nil {
				return err
			}
			if _, err := io.WriteString(w, `<p class="mt-4 text-xs text-slate-500">※ Firebase 側でスタッフを無効化／削除した場合、次回ログイン時に管理画面へのアクセスも拒否されます。</p>`); err != nil {
				return err
			}
			if _, err := io.WriteString(w, `<div class="mt-5">`); err != nil {
				return err
			}
			if err := components.ButtonWith("Firebase Console を開く", components.ButtonOptions{
				Variant: "primary",
				Href:    firebaseConsoleURL,
				Attrs: templ.Attributes{
					"target": "_blank",
					"rel":    "noopener noreferrer",
				},
			}).Render(ctx, w); err != nil {
				return err
			}
			if _, err := io.WriteString(w, `</div>`); err != nil {
				return err
			}
			return nil
		})).Render(ctx, w); err != nil {
			return err
		}
		if err := components.Card("今後の対応", templ.ComponentFunc(func(ctx context.Context, w io.Writer) error {
			if _, err := io.WriteString(w, `<ul class="list-disc space-y-2 pl-5 text-sm text-slate-600">`); err != nil {
				return err
			}
			if _, err := io.WriteString(w, `<li>Firestore / Cloud Run 側にスタッフ API が用意され次第、このページに一覧と招待フローを実装します。</li>`); err != nil {
				return err
			}
			if _, err := io.WriteString(w, `<li>RBAC で必要なプロフィール情報（最終ログイン、MFA 状態など）をプロキシ API から取得できるよう調整します。</li>`); err != nil {
				return err
			}
			if _, err := io.WriteString(w, `<li>追跡タスク: <code class="rounded bg-slate-100 px-1 py-0.5 text-xs">doc/admin/tasks/058-build-staff-role-management-pages-admin-org-staff-admin-org-roles-or-placeholder-hooking-i.md</code></li>`); err != nil {
				return err
			}
			if _, err := io.WriteString(w, `</ul>`); err != nil {
				return err
			}
			return nil
		})).Render(ctx, w); err != nil {
			return err
		}
		if _, err := io.WriteString(w, `</div>`); err != nil {
			return err
		}
		return nil
	})
}

func rolesBody() templ.Component {
	return templ.ComponentFunc(func(ctx context.Context, w io.Writer) error {
		if _, err := io.WriteString(w, `<div class="space-y-4">`); err != nil {
			return err
		}
		if err := components.Card("ロール割り当ての更新手順", templ.ComponentFunc(func(ctx context.Context, w io.Writer) error {
			if _, err := io.WriteString(w, `<p class="text-sm text-slate-600">現在の RBAC は Firebase Authentication のカスタムクレーム <code class="rounded bg-slate-100 px-1 py-0.5 text-xs">roles</code> とバックエンドの検証ロジックで制御しています。</p>`); err != nil {
				return err
			}
			if _, err := io.WriteString(w, `<ol class="mt-4 list-decimal space-y-2 pl-6 text-sm text-slate-600">`); err != nil {
				return err
			}
			if _, err := io.WriteString(w, `<li>Firebase Console → Authentication → Users で対象スタッフを開きます。</li>`); err != nil {
				return err
			}
			if _, err := io.WriteString(w, `<li>「Edit user」から Custom claims を編集し、<code class="rounded bg-slate-100 px-1 py-0.5 text-xs">{"roles":["admin","ops",...]}</code> の形でロールを設定します。</li>`); err != nil {
				return err
			}
			if _, err := io.WriteString(w, `<li>変更後はスタッフに再ログインを依頼し、管理画面での権限を確認します。</li>`); err != nil {
				return err
			}
			if _, err := io.WriteString(w, `</ol>`); err != nil {
				return err
			}
			if _, err := io.WriteString(w, `<p class="mt-4 text-xs text-slate-500">権限テーブルは <code class="rounded bg-slate-100 px-1 py-0.5 text-xs">internal/admin/rbac/rbac.go</code> に定義されています。新しいロールや機能を追加する際はこのファイルを更新してください。</p>`); err != nil {
				return err
			}
			return nil
		})).Render(ctx, w); err != nil {
			return err
		}
		if err := components.Card("TODO: パーミッションマトリクス", templ.ComponentFunc(func(ctx context.Context, w io.Writer) error {
			if _, err := io.WriteString(w, `<p class="text-sm text-slate-600">バックエンド API が公開されたら、ロール一覧と権限マトリクスを表示する UI をこのページに追加します。</p>`); err != nil {
				return err
			}
			if _, err := io.WriteString(w, `<ul class="mt-3 list-disc space-y-2 pl-5 text-sm text-slate-600">`); err != nil {
				return err
			}
			if _, err := io.WriteString(w, `<li>ロール別の Capabilities 表示と編集モーダルを実装。</li>`); err != nil {
				return err
			}
			if _, err := io.WriteString(w, `<li>変更履歴を監査ログに送信し、ActivityStream に表示。</li>`); err != nil {
				return err
			}
			if _, err := io.WriteString(w, `<li>権限更新は Firebase Admin SDK 経由でカスタムクレームを差し替える。</li>`); err != nil {
				return err
			}
			if _, err := io.WriteString(w, `</ul>`); err != nil {
				return err
			}
			return nil
		})).Render(ctx, w); err != nil {
			return err
		}
		if _, err := io.WriteString(w, `</div>`); err != nil {
			return err
		}
		return nil
	})
}
