package org

import (
	"context"
	"io"
	"strings"

	"github.com/a-h/templ"

	"finitefield.org/hanko-admin/internal/admin/templates/helpers"
	"finitefield.org/hanko-admin/internal/admin/templates/layouts"
)

// StaffRoleOption describes a selectable role within modal forms.
type StaffRoleOption struct {
	Key         string
	Label       string
	Description string
	Checked     bool
}

// StaffInviteModalPayload contains data for the invite modal.
type StaffInviteModalPayload struct {
	Action      string
	CSRFToken   string
	Values      StaffInviteFormValues
	RoleOptions []StaffRoleOption
	Error       string
}

// StaffInviteFormValues captures posted form values to preserve state on validation errors.
type StaffInviteFormValues struct {
	Email     string
	Name      string
	Roles     []string
	SendEmail bool
	Note      string
}

// StaffEditModalPayload contains data for the role edit modal.
type StaffEditModalPayload struct {
	Action      string
	CSRFToken   string
	MemberName  string
	MemberEmail string
	RoleOptions []StaffRoleOption
	Note        string
	Error       string
}

// StaffRevokeModalPayload contains data for the revocation modal.
type StaffRevokeModalPayload struct {
	Action         string
	CSRFToken      string
	MemberName     string
	MemberEmail    string
	Reason         string
	Note           string
	RevokeSessions bool
	NotifyUser     bool
	Error          string
}

// StaffInviteModal renders the invite modal component.
func StaffInviteModal(data StaffInviteModalPayload) templ.Component {
	body := templ.ComponentFunc(func(ctx context.Context, w io.Writer) error {
		if _, err := io.WriteString(w, `<form hx-post="`+templ.EscapeString(data.Action)+`" hx-target="#modal" hx-swap="innerHTML" class="space-y-5">`); err != nil {
			return err
		}
		if _, err := io.WriteString(w, `<input type="hidden" name="csrf_token" value="`+templ.EscapeString(data.CSRFToken)+`" />`); err != nil {
			return err
		}
		if strings.TrimSpace(data.Error) != "" {
			if _, err := io.WriteString(w, `<div class="rounded-md border border-danger-200 bg-danger-50 px-3 py-2 text-sm text-danger-700">`+templ.EscapeString(data.Error)+`</div>`); err != nil {
				return err
			}
		}
		if _, err := io.WriteString(w, `<div class="space-y-4">`); err != nil {
			return err
		}

		if err := renderInputField(w, "email", "メールアドレス", "email", data.Values.Email, true, "招待メールを送信するアドレスを入力してください。"); err != nil {
			return err
		}
		if err := renderInputField(w, "name", "氏名", "text", data.Values.Name, false, "任意。サイドバーや監査ログに表示されます。"); err != nil {
			return err
		}

		if err := renderRoleChecklist(w, data.RoleOptions, data.Values.Roles); err != nil {
			return err
		}

		if err := renderTextareaField(w, "note", "監査メモ", data.Values.Note, "変更理由やコンテキストを記録します。監査ログに残ります。"); err != nil {
			return err
		}

		if _, err := io.WriteString(w, `<label class="flex items-center gap-2 text-sm text-slate-700"><input type="checkbox" name="sendEmail" value="1"`); err != nil {
			return err
		}
		if data.Values.SendEmail {
			if _, err := io.WriteString(w, ` checked`); err != nil {
				return err
			}
		}
		if _, err := io.WriteString(w, ` class="h-4 w-4 rounded border-slate-300 text-brand-600 focus:ring-brand-500" />招待メールを送信</label>`); err != nil {
			return err
		}

		if _, err := io.WriteString(w, `</div>`); err != nil {
			return err
		}
		if _, err := io.WriteString(w, `<div class="flex items-center justify-end gap-3">`); err != nil {
			return err
		}
		if _, err := io.WriteString(w, `<button type="submit" class="`+helpers.ButtonClass("primary", "md", false, false)+`">招待を送信</button>`); err != nil {
			return err
		}
		if _, err := io.WriteString(w, `</div></form>`); err != nil {
			return err
		}
		return nil
	})
	return layouts.Modal("スタッフを招待", body)
}

// StaffEditModal renders the role edit modal component.
func StaffEditModal(data StaffEditModalPayload) templ.Component {
	title := "ロールを更新"
	if strings.TrimSpace(data.MemberName) != "" {
		title = "ロールを更新：" + data.MemberName
	}
	body := templ.ComponentFunc(func(ctx context.Context, w io.Writer) error {
		if _, err := io.WriteString(w, `<form hx-post="`+templ.EscapeString(data.Action)+`" hx-target="#modal" hx-swap="innerHTML" class="space-y-5">`); err != nil {
			return err
		}
		if _, err := io.WriteString(w, `<input type="hidden" name="csrf_token" value="`+templ.EscapeString(data.CSRFToken)+`" />`); err != nil {
			return err
		}
		if strings.TrimSpace(data.Error) != "" {
			if _, err := io.WriteString(w, `<div class="rounded-md border border-danger-200 bg-danger-50 px-3 py-2 text-sm text-danger-700">`+templ.EscapeString(data.Error)+`</div>`); err != nil {
				return err
			}
		}

		if strings.TrimSpace(data.MemberEmail) != "" {
			if _, err := io.WriteString(w, `<p class="text-sm text-slate-600">`+templ.EscapeString(data.MemberEmail)+`</p>`); err != nil {
				return err
			}
		}

		if err := renderRoleChecklist(w, data.RoleOptions, nil); err != nil {
			return err
		}
		if err := renderTextareaField(w, "note", "監査メモ", data.Note, "この変更の理由を簡潔に記載してください。"); err != nil {
			return err
		}

		if _, err := io.WriteString(w, `<div class="flex items-center justify-end gap-3"><button type="submit" class="`+helpers.ButtonClass("primary", "md", false, false)+`">ロールを保存</button></div>`); err != nil {
			return err
		}
		if _, err := io.WriteString(w, `</form>`); err != nil {
			return err
		}
		return nil
	})
	return layouts.Modal(title, body)
}

// StaffRevokeModal renders the access revocation confirmation modal.
func StaffRevokeModal(data StaffRevokeModalPayload) templ.Component {
	title := "アクセスを停止"
	if strings.TrimSpace(data.MemberName) != "" {
		title = "アクセス停止：" + data.MemberName
	}
	body := templ.ComponentFunc(func(ctx context.Context, w io.Writer) error {
		if _, err := io.WriteString(w, `<form hx-post="`+templ.EscapeString(data.Action)+`" hx-target="#modal" hx-swap="innerHTML" class="space-y-5">`); err != nil {
			return err
		}
		if _, err := io.WriteString(w, `<input type="hidden" name="csrf_token" value="`+templ.EscapeString(data.CSRFToken)+`" />`); err != nil {
			return err
		}
		if strings.TrimSpace(data.Error) != "" {
			if _, err := io.WriteString(w, `<div class="rounded-md border border-danger-200 bg-danger-50 px-3 py-2 text-sm text-danger-700">`+templ.EscapeString(data.Error)+`</div>`); err != nil {
				return err
			}
		}
		if strings.TrimSpace(data.MemberEmail) != "" {
			if _, err := io.WriteString(w, `<p class="text-sm text-slate-600">`+templ.EscapeString(data.MemberEmail)+`</p>`); err != nil {
				return err
			}
		}
		if err := renderInputField(w, "reason", "理由", "text", data.Reason, true, "監査ログに記録されます。"); err != nil {
			return err
		}
		if err := renderTextareaField(w, "note", "追加メモ", data.Note, "任意。サポートチーム向けに補足を残せます。"); err != nil {
			return err
		}

		if _, err := io.WriteString(w, `<label class="flex items-center gap-2 text-sm text-slate-700"><input type="checkbox" name="revokeSessions" value="1"`); err != nil {
			return err
		}
		if data.RevokeSessions {
			if _, err := io.WriteString(w, ` checked`); err != nil {
				return err
			}
		}
		if _, err := io.WriteString(w, ` class="h-4 w-4 rounded border-slate-300 text-brand-600 focus:ring-brand-500" />既存セッションを即時失効させる</label>`); err != nil {
			return err
		}

		if _, err := io.WriteString(w, `<label class="flex items-center gap-2 text-sm text-slate-700"><input type="checkbox" name="notifyUser" value="1"`); err != nil {
			return err
		}
		if data.NotifyUser {
			if _, err := io.WriteString(w, ` checked`); err != nil {
				return err
			}
		}
		if _, err := io.WriteString(w, ` class="h-4 w-4 rounded border-slate-300 text-brand-600 focus:ring-brand-500" />通知メールを送信</label>`); err != nil {
			return err
		}

		if _, err := io.WriteString(w, `<div class="flex items-center justify-end gap-3">`); err != nil {
			return err
		}
		if _, err := io.WriteString(w, `<button type="submit" class="`+helpers.ButtonClass("danger", "md", false, false)+`">アクセスを停止</button>`); err != nil {
			return err
		}
		if _, err := io.WriteString(w, `</div></form>`); err != nil {
			return err
		}
		return nil
	})
	return layouts.Modal(title, body)
}

func renderInputField(w io.Writer, name, label, typ, value string, required bool, help string) error {
	if _, err := io.WriteString(w, `<div class="flex flex-col gap-2"><label class="text-xs font-semibold uppercase tracking-wide text-slate-500" for="`+templ.EscapeString(name)+`">`+templ.EscapeString(label)); err != nil {
		return err
	}
	if required {
		if _, err := io.WriteString(w, `<span class="ml-1 text-brand-600">*</span>`); err != nil {
			return err
		}
	}
	if _, err := io.WriteString(w, `</label><input id="`+templ.EscapeString(name)+`" name="`+templ.EscapeString(name)+`" type="`+templ.EscapeString(typ)+`" value="`+templ.EscapeString(value)+`" class="rounded-lg border border-slate-300 px-3 py-2 text-sm text-slate-700 shadow-sm focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200"`); err != nil {
		return err
	}
	if required {
		if _, err := io.WriteString(w, ` required`); err != nil {
			return err
		}
	}
	if _, err := io.WriteString(w, ` />`); err != nil {
		return err
	}
	if strings.TrimSpace(help) != "" {
		if _, err := io.WriteString(w, `<p class="text-xs text-slate-500">`+templ.EscapeString(help)+`</p>`); err != nil {
			return err
		}
	}
	if _, err := io.WriteString(w, `</div>`); err != nil {
		return err
	}
	return nil
}

func renderTextareaField(w io.Writer, name, label, value, help string) error {
	if _, err := io.WriteString(w, `<div class="flex flex-col gap-2"><label class="text-xs font-semibold uppercase tracking-wide text-slate-500" for="`+templ.EscapeString(name)+`">`+templ.EscapeString(label)+`</label><textarea id="`+templ.EscapeString(name)+`" name="`+templ.EscapeString(name)+`" rows="3" class="rounded-lg border border-slate-300 px-3 py-2 text-sm text-slate-700 shadow-sm focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200">`+templ.EscapeString(value)+`</textarea>`); err != nil {
		return err
	}
	if strings.TrimSpace(help) != "" {
		if _, err := io.WriteString(w, `<p class="text-xs text-slate-500">`+templ.EscapeString(help)+`</p>`); err != nil {
			return err
		}
	}
	if _, err := io.WriteString(w, `</div>`); err != nil {
		return err
	}
	return nil
}

func renderRoleChecklist(w io.Writer, options []StaffRoleOption, selected []string) error {
	if len(options) == 0 {
		if _, err := io.WriteString(w, `<div class="rounded-md border border-amber-200 bg-amber-50 px-3 py-2 text-xs text-amber-700">選択可能なロールがありません。RBAC 設定を確認してください。</div>`); err != nil {
			return err
		}
		return nil
	}
	selectedSet := make(map[string]struct{}, len(selected))
	for _, key := range selected {
		selectedSet[strings.TrimSpace(key)] = struct{}{}
	}
	if _, err := io.WriteString(w, `<fieldset class="space-y-3"><legend class="text-xs font-semibold uppercase tracking-wide text-slate-500">ロール</legend>`); err != nil {
		return err
	}
	for _, option := range options {
		checked := option.Checked
		if _, ok := selectedSet[option.Key]; ok {
			checked = true
		}
		if _, err := io.WriteString(w, `<label class="flex items-start gap-3 rounded-lg border border-slate-200 px-3 py-2 text-sm text-slate-700 transition hover:border-brand-300"><input type="checkbox" name="roles" value="`+templ.EscapeString(option.Key)+`"`); err != nil {
			return err
		}
		if checked {
			if _, err := io.WriteString(w, ` checked`); err != nil {
				return err
			}
		}
		if _, err := io.WriteString(w, ` class="mt-1 h-4 w-4 rounded border-slate-300 text-brand-600 focus:ring-brand-500" /><div><p class="font-medium text-slate-900">`+templ.EscapeString(option.Label)+`</p>`); err != nil {
			return err
		}
		if strings.TrimSpace(option.Description) != "" {
			if _, err := io.WriteString(w, `<p class="text-xs text-slate-500">`+templ.EscapeString(option.Description)+`</p>`); err != nil {
				return err
			}
		}
		if _, err := io.WriteString(w, `</div></label>`); err != nil {
			return err
		}
	}
	if _, err := io.WriteString(w, `</fieldset>`); err != nil {
		return err
	}
	return nil
}
