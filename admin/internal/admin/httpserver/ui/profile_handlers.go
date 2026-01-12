package ui

import (
	"log"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"

	custommw "finitefield.org/hanko-admin/internal/admin/httpserver/middleware"
	"finitefield.org/hanko-admin/internal/admin/profile"
	profiletpl "finitefield.org/hanko-admin/internal/admin/templates/profile"
	"finitefield.org/hanko-admin/internal/admin/webtmpl"
)

// ProfilePage renders the main profile/security dashboard.
func (h *Handlers) ProfilePage(w http.ResponseWriter, r *http.Request) {
	h.renderProfilePage(w, r)
}

// MFATOTPStart displays the enrollment modal with QR code/secret.
func (h *Handlers) MFATOTPStart(w http.ResponseWriter, r *http.Request) {
	user, ok := custommw.UserFromContext(r.Context())
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	enrollment, err := h.profile.StartTOTPEnrollment(r.Context(), user.Token)
	if err != nil {
		log.Printf("profile: start totp enrollment failed: %v", err)
		http.Error(w, "MFA登録の開始に失敗しました。後ほどお試しください。", http.StatusBadGateway)
		return
	}

	data := profiletpl.TOTPModalData{
		Enrollment: enrollment,
		CSRFToken:  custommw.CSRFTokenFromContext(r.Context()),
	}
	view := webtmpl.ProfileTOTPModalView{
		BasePath: custommw.BasePathFromContext(r.Context()),
		Data:     data,
	}
	if err := dashboardTemplates.Render(w, "profile/totp-modal", view); err != nil {
		http.Error(w, "template render error", http.StatusInternalServerError)
	}
}

// MFATOTPConfirm finalises TOTP enrollment.
func (h *Handlers) MFATOTPConfirm(w http.ResponseWriter, r *http.Request) {
	user, ok := custommw.UserFromContext(r.Context())
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	if err := r.ParseForm(); err != nil {
		http.Error(w, "フォームの解析に失敗しました。", http.StatusBadRequest)
		return
	}
	code := strings.TrimSpace(r.PostFormValue("code"))
	if code == "" {
		enrollment, _ := h.profile.StartTOTPEnrollment(r.Context(), user.Token)
		data := profiletpl.TOTPModalData{
			Enrollment: enrollment,
			CSRFToken:  custommw.CSRFTokenFromContext(r.Context()),
			Error:      "認証コードを入力してください。",
		}
		view := webtmpl.ProfileTOTPModalView{
			BasePath: custommw.BasePathFromContext(r.Context()),
			Data:     data,
		}
		if err := dashboardTemplates.Render(w, "profile/totp-modal", view); err != nil {
			http.Error(w, "template render error", http.StatusInternalServerError)
		}
		return
	}

	state, err := h.profile.ConfirmTOTPEnrollment(r.Context(), user.Token, code)
	if err != nil {
		log.Printf("profile: confirm totp enrollment failed: %v", err)
		enrollment, _ := h.profile.StartTOTPEnrollment(r.Context(), user.Token)
		data := profiletpl.TOTPModalData{
			Enrollment: enrollment,
			CSRFToken:  custommw.CSRFTokenFromContext(r.Context()),
			Error:      "コードが正しくないか、期限切れです。再度お試しください。",
		}
		view := webtmpl.ProfileTOTPModalView{
			BasePath: custommw.BasePathFromContext(r.Context()),
			Data:     data,
		}
		if err := dashboardTemplates.Render(w, "profile/totp-modal", view); err != nil {
			http.Error(w, "template render error", http.StatusInternalServerError)
		}
		return
	}

	payload := profiletpl.MFAUpdateData{
		Security:  state,
		CSRFToken: custommw.CSRFTokenFromContext(r.Context()),
		Message:   "Authenticator アプリを有効化しました。",
	}
	view := webtmpl.ProfileMFAUpdateView{
		BasePath: custommw.BasePathFromContext(r.Context()),
		Data:     payload,
	}
	if err := dashboardTemplates.Render(w, "profile/mfa-update", view); err != nil {
		http.Error(w, "template render error", http.StatusInternalServerError)
	}
}

// EmailMFAEnable toggles email-based MFA.
func (h *Handlers) EmailMFAEnable(w http.ResponseWriter, r *http.Request) {
	user, ok := custommw.UserFromContext(r.Context())
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	state, err := h.profile.EnableEmailMFA(r.Context(), user.Token)
	if err != nil {
		log.Printf("profile: enable email mfa failed: %v", err)
		http.Error(w, "メール認証の有効化に失敗しました。", http.StatusBadGateway)
		return
	}

	payload := profiletpl.MFAUpdateData{
		Security:  state,
		CSRFToken: custommw.CSRFTokenFromContext(r.Context()),
		Message:   "メールによる MFA を有効化しました。",
	}
	view := webtmpl.ProfileMFAUpdateView{
		BasePath: custommw.BasePathFromContext(r.Context()),
		Data:     payload,
	}
	if err := dashboardTemplates.Render(w, "profile/mfa-update", view); err != nil {
		http.Error(w, "template render error", http.StatusInternalServerError)
	}
}

// DisableMFA removes MFA factors.
func (h *Handlers) DisableMFA(w http.ResponseWriter, r *http.Request) {
	user, ok := custommw.UserFromContext(r.Context())
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	state, err := h.profile.DisableMFA(r.Context(), user.Token)
	if err != nil {
		log.Printf("profile: disable mfa failed: %v", err)
		http.Error(w, "MFAの無効化に失敗しました。", http.StatusBadGateway)
		return
	}

	payload := profiletpl.MFAUpdateData{
		Security:  state,
		CSRFToken: custommw.CSRFTokenFromContext(r.Context()),
		Message:   "MFA を無効化しました。",
	}
	view := webtmpl.ProfileMFAUpdateView{
		BasePath: custommw.BasePathFromContext(r.Context()),
		Data:     payload,
	}
	if err := dashboardTemplates.Render(w, "profile/mfa-update", view); err != nil {
		http.Error(w, "template render error", http.StatusInternalServerError)
	}
}

// NewAPIKeyForm renders the creation form modal.
func (h *Handlers) NewAPIKeyForm(w http.ResponseWriter, r *http.Request) {
	data := profiletpl.APIKeyFormData{
		CSRFToken: custommw.CSRFTokenFromContext(r.Context()),
	}
	view := webtmpl.ProfileAPIKeyFormModalView{
		BasePath: custommw.BasePathFromContext(r.Context()),
		Data:     data,
	}
	if err := dashboardTemplates.Render(w, "profile/api-key-form-modal", view); err != nil {
		http.Error(w, "template render error", http.StatusInternalServerError)
	}
}

// CreateAPIKey issues a new key and displays the secret once.
func (h *Handlers) CreateAPIKey(w http.ResponseWriter, r *http.Request) {
	user, ok := custommw.UserFromContext(r.Context())
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	if err := r.ParseForm(); err != nil {
		http.Error(w, "フォームの解析に失敗しました。", http.StatusBadRequest)
		return
	}

	label := strings.TrimSpace(r.PostFormValue("label"))
	if label == "" {
		data := profiletpl.APIKeyFormData{
			CSRFToken: custommw.CSRFTokenFromContext(r.Context()),
			Error:     "APIキーのラベルを入力してください。",
		}
		view := webtmpl.ProfileAPIKeyFormModalView{
			BasePath: custommw.BasePathFromContext(r.Context()),
			Data:     data,
		}
		if err := dashboardTemplates.Render(w, "profile/api-key-form-modal", view); err != nil {
			http.Error(w, "template render error", http.StatusInternalServerError)
		}
		return
	}

	secret, err := h.profile.CreateAPIKey(r.Context(), user.Token, profile.CreateAPIKeyRequest{Label: label})
	if err != nil {
		log.Printf("profile: create api key failed: %v", err)
		data := profiletpl.APIKeyFormData{
			CSRFToken: custommw.CSRFTokenFromContext(r.Context()),
			Error:     "APIキーの発行に失敗しました。時間を置いて再度お試しください。",
			Label:     label,
		}
		view := webtmpl.ProfileAPIKeyFormModalView{
			BasePath: custommw.BasePathFromContext(r.Context()),
			Data:     data,
		}
		if err := dashboardTemplates.Render(w, "profile/api-key-form-modal", view); err != nil {
			http.Error(w, "template render error", http.StatusInternalServerError)
		}
		return
	}

	state, err := h.profile.SecurityOverview(r.Context(), user.Token)
	if err != nil {
		log.Printf("profile: refresh security overview failed: %v", err)
	}

	payload := profiletpl.APIKeyUpdateData{
		Security:  state,
		CSRFToken: custommw.CSRFTokenFromContext(r.Context()),
		Secret:    secret,
		Message:   "新しい API キーを発行しました。シークレットはこの画面でのみ表示されます。",
	}
	view := webtmpl.ProfileAPIKeyUpdateView{
		BasePath: custommw.BasePathFromContext(r.Context()),
		Data:     payload,
	}
	if err := dashboardTemplates.Render(w, "profile/api-key-update", view); err != nil {
		http.Error(w, "template render error", http.StatusInternalServerError)
	}
}

// RevokeAPIKey revokes the selected key.
func (h *Handlers) RevokeAPIKey(w http.ResponseWriter, r *http.Request) {
	user, ok := custommw.UserFromContext(r.Context())
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	keyID := strings.TrimSpace(chi.URLParam(r, "keyID"))
	if keyID == "" {
		http.Error(w, "APIキーが指定されていません。", http.StatusBadRequest)
		return
	}

	state, err := h.profile.RevokeAPIKey(r.Context(), user.Token, keyID)
	if err != nil {
		log.Printf("profile: revoke api key failed: %v", err)
		http.Error(w, "APIキーの失効に失敗しました。", http.StatusBadGateway)
		return
	}

	payload := profiletpl.APIKeyUpdateData{
		Security:  state,
		CSRFToken: custommw.CSRFTokenFromContext(r.Context()),
		Message:   "選択した API キーを失効させました。",
	}
	view := webtmpl.ProfileAPIKeyUpdateView{
		BasePath: custommw.BasePathFromContext(r.Context()),
		Data:     payload,
	}
	if err := dashboardTemplates.Render(w, "profile/api-key-update", view); err != nil {
		http.Error(w, "template render error", http.StatusInternalServerError)
	}
}

// RevokeSession terminates an active session.
func (h *Handlers) RevokeSession(w http.ResponseWriter, r *http.Request) {
	user, ok := custommw.UserFromContext(r.Context())
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	sessionID := strings.TrimSpace(chi.URLParam(r, "sessionID"))
	if sessionID == "" {
		http.Error(w, "セッションが指定されていません。", http.StatusBadRequest)
		return
	}

	state, err := h.profile.RevokeSession(r.Context(), user.Token, sessionID)
	if err != nil {
		log.Printf("profile: revoke session failed: %v", err)
		http.Error(w, "セッションの失効に失敗しました。", http.StatusBadGateway)
		return
	}

	payload := profiletpl.SessionUpdateData{
		Security:  state,
		CSRFToken: custommw.CSRFTokenFromContext(r.Context()),
		Message:   "セッションを失効させました。",
	}
	view := webtmpl.ProfileSessionUpdateView{
		BasePath: custommw.BasePathFromContext(r.Context()),
		Data:     payload,
	}
	if err := dashboardTemplates.Render(w, "profile/session-update", view); err != nil {
		http.Error(w, "template render error", http.StatusInternalServerError)
	}
}
