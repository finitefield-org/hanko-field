package ui

import (
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/a-h/templ"
	"github.com/go-chi/chi/v5"

	custommw "finitefield.org/hanko-admin/internal/admin/httpserver/middleware"
	adminorg "finitefield.org/hanko-admin/internal/admin/org"
	"finitefield.org/hanko-admin/internal/admin/templates/helpers"
	orgtpl "finitefield.org/hanko-admin/internal/admin/templates/org"
)

const staffRefreshEvent = "org:staff:refresh"

// OrgStaffPage renders the staff management page with filters, table, and invite CTA.
func (h *Handlers) OrgStaffPage(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	request := buildStaffRequest(r)
	list, err := h.org.List(ctx, user.Token, request.query)
	if err != nil {
		log.Printf("org: list staff failed: %v", err)
	}

	basePath := custommw.BasePathFromContext(ctx)
	content := buildStaffPageContent(basePath, request, list, err != nil)
	page := orgtpl.BuildStaffPageData(basePath, content)

	templ.Handler(orgtpl.Index(page)).ServeHTTP(w, r)
}

// OrgStaffTable renders the staff table fragment for htmx updates.
func (h *Handlers) OrgStaffTable(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	request := buildStaffRequest(r)
	list, err := h.org.List(ctx, user.Token, request.query)
	if err != nil {
		log.Printf("org: list staff (fragment) failed: %v", err)
	}

	basePath := custommw.BasePathFromContext(ctx)
	content := buildStaffPageContent(basePath, request, list, err != nil)
	table := content.Table

	if canonical := canonicalStaffURL(basePath, request); canonical != "" {
		w.Header().Set("HX-Push-Url", canonical)
	}

	templ.Handler(orgtpl.StaffTableFragment(table)).ServeHTTP(w, r)
}

// OrgStaffInviteModal renders the invite modal.
func (h *Handlers) OrgStaffInviteModal(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	basePath := custommw.BasePathFromContext(ctx)
	catalog, err := h.org.Catalog(ctx, user.Token)
	if err != nil {
		log.Printf("org: fetch role catalog for invite failed: %v", err)
		http.Error(w, "ロール一覧の取得に失敗しました。", http.StatusBadGateway)
		return
	}

	payload := orgtpl.StaffInviteModalPayload{
		Action:    joinBasePath(basePath, "/org/staff/invite"),
		CSRFToken: custommw.CSRFTokenFromContext(ctx),
		Values: orgtpl.StaffInviteFormValues{
			SendEmail: true,
		},
		RoleOptions: buildRoleOptions(catalog.Roles, nil),
	}

	templ.Handler(orgtpl.StaffInviteModal(payload)).ServeHTTP(w, r)
}

// OrgStaffInviteSubmit handles invite submissions.
func (h *Handlers) OrgStaffInviteSubmit(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	if err := r.ParseForm(); err != nil {
		http.Error(w, "リクエストの解析に失敗しました。", http.StatusBadRequest)
		return
	}

	email := strings.TrimSpace(r.PostForm.Get("email"))
	if email == "" {
		h.renderInviteModalWithError(w, r, "メールアドレスを入力してください。", nil)
		return
	}

	name := strings.TrimSpace(r.PostForm.Get("name"))
	roles := r.PostForm["roles"]
	sendEmail := isChecked(r.PostForm.Get("sendEmail"))
	note := strings.TrimSpace(r.PostForm.Get("note"))

	req := adminorg.InviteRequest{
		Email:      email,
		Name:       name,
		Roles:      uniqueStrings(roles),
		SendEmail:  sendEmail,
		Note:       note,
		ActorID:    user.UID,
		ActorEmail: user.Email,
	}

	member, err := h.org.Invite(ctx, user.Token, req)
	if err != nil {
		log.Printf("org: invite staff failed: %v", err)
		h.renderInviteModalWithError(w, r, "招待に失敗しました。時間を置いて再度お試しください。", &req)
		return
	}

	triggerStaffRefresh(w, fmt.Sprintf("%s を招待しました。", safeDisplayName(member)), "success")
	w.WriteHeader(http.StatusNoContent)
}

// OrgStaffEditModal renders the role edit modal.
func (h *Handlers) OrgStaffEditModal(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	memberID := strings.TrimSpace(chi.URLParam(r, "memberID"))
	if memberID == "" {
		http.Error(w, "memberID is required", http.StatusBadRequest)
		return
	}

	member, err := h.org.Member(ctx, user.Token, memberID)
	if err != nil {
		handleOrgMemberError(w, err)
		return
	}

	catalog, err := h.org.Catalog(ctx, user.Token)
	if err != nil {
		log.Printf("org: fetch role catalog for edit failed: %v", err)
		http.Error(w, "ロール一覧の取得に失敗しました。", http.StatusBadGateway)
		return
	}

	basePath := custommw.BasePathFromContext(ctx)
	payload := orgtpl.StaffEditModalPayload{
		Action:      joinBasePath(basePath, fmt.Sprintf("/org/staff/%s:update", url.PathEscape(member.ID))),
		CSRFToken:   custommw.CSRFTokenFromContext(ctx),
		MemberName:  safeDisplayName(member),
		MemberEmail: strings.TrimSpace(member.Email),
		RoleOptions: buildRoleOptions(catalog.Roles, member.Roles),
	}

	templ.Handler(orgtpl.StaffEditModal(payload)).ServeHTTP(w, r)
}

// OrgStaffUpdateSubmit handles role update submissions.
func (h *Handlers) OrgStaffUpdateSubmit(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	memberID := strings.TrimSpace(chi.URLParam(r, "memberID"))
	if memberID == "" {
		http.Error(w, "memberID is required", http.StatusBadRequest)
		return
	}
	if err := r.ParseForm(); err != nil {
		http.Error(w, "リクエストの解析に失敗しました。", http.StatusBadRequest)
		return
	}

	roles := uniqueStrings(r.PostForm["roles"])
	note := strings.TrimSpace(r.PostForm.Get("note"))

	req := adminorg.UpdateRolesRequest{
		Roles:      roles,
		Note:       note,
		ActorID:    user.UID,
		ActorEmail: user.Email,
	}

	member, err := h.org.UpdateRoles(ctx, user.Token, memberID, req)
	if err != nil {
		log.Printf("org: update roles failed: %v", err)
		h.renderEditModalWithError(w, r, memberID, "ロールの更新に失敗しました。時間を置いて再度お試しください。")
		return
	}

	triggerStaffRefresh(w, fmt.Sprintf("%s のロールを更新しました。", safeDisplayName(member)), "success")
	w.WriteHeader(http.StatusNoContent)
}

// OrgStaffRevokeModal renders the access revocation modal.
func (h *Handlers) OrgStaffRevokeModal(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	memberID := strings.TrimSpace(chi.URLParam(r, "memberID"))
	if memberID == "" {
		http.Error(w, "memberID is required", http.StatusBadRequest)
		return
	}

	member, err := h.org.Member(ctx, user.Token, memberID)
	if err != nil {
		handleOrgMemberError(w, err)
		return
	}

	basePath := custommw.BasePathFromContext(ctx)
	payload := orgtpl.StaffRevokeModalPayload{
		Action:      joinBasePath(basePath, fmt.Sprintf("/org/staff/%s:revoke", url.PathEscape(member.ID))),
		CSRFToken:   custommw.CSRFTokenFromContext(ctx),
		MemberName:  safeDisplayName(member),
		MemberEmail: strings.TrimSpace(member.Email),
		Reason:      "アクセス不要になったため",
		NotifyUser:  true,
	}

	templ.Handler(orgtpl.StaffRevokeModal(payload)).ServeHTTP(w, r)
}

// OrgStaffRevokeSubmit handles revocation submissions.
func (h *Handlers) OrgStaffRevokeSubmit(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	memberID := strings.TrimSpace(chi.URLParam(r, "memberID"))
	if memberID == "" {
		http.Error(w, "memberID is required", http.StatusBadRequest)
		return
	}
	if err := r.ParseForm(); err != nil {
		http.Error(w, "リクエストの解析に失敗しました。", http.StatusBadRequest)
		return
	}

	reason := strings.TrimSpace(r.PostForm.Get("reason"))
	if reason == "" {
		h.renderRevokeModalWithError(w, r, memberID, "アクセス停止の理由を入力してください。")
		return
	}

	note := strings.TrimSpace(r.PostForm.Get("note"))
	revokeSessions := isChecked(r.PostForm.Get("revokeSessions"))
	notifyUser := isChecked(r.PostForm.Get("notifyUser"))

	req := adminorg.RevokeRequest{
		Reason:         reason,
		Note:           note,
		RevokeSessions: revokeSessions,
		NotifyUser:     notifyUser,
		ActorID:        user.UID,
		ActorEmail:     user.Email,
	}

	if err := h.org.Revoke(ctx, user.Token, memberID, req); err != nil {
		log.Printf("org: revoke access failed: %v", err)
		h.renderRevokeModalWithError(w, r, memberID, "アクセス停止に失敗しました。時間を置いて再度お試しください。")
		return
	}

	triggerStaffRefresh(w, "アクセスを停止しました。", "warning")
	w.WriteHeader(http.StatusNoContent)
}

// OrgRolesPage renders the roles catalog.
func (h *Handlers) OrgRolesPage(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	basePath := custommw.BasePathFromContext(ctx)
	content := orgtpl.RolesPageContent{}

	catalog, err := h.org.Catalog(ctx, user.Token)
	if err != nil {
		log.Printf("org: fetch role catalog failed: %v", err)
		content.Error = "ロール定義の取得に失敗しました。"
	} else {
		content.Roles = buildRoleCards(catalog.Roles)
	}

	page := orgtpl.BuildRolesPageData(basePath, content)
	templ.Handler(orgtpl.Index(page)).ServeHTTP(w, r)
}

func buildStaffRequest(r *http.Request) staffRequest {
	values := r.URL.Query()
	raw := values.Encode()

	search := strings.TrimSpace(values.Get("q"))
	role := strings.TrimSpace(values.Get("role"))
	status := strings.TrimSpace(values.Get("status"))

	query := adminorg.MembersQuery{
		Search: search,
	}
	if role != "" {
		query.Roles = []string{role}
	}
	if status != "" {
		query.Statuses = []adminorg.MemberStatus{adminorg.MemberStatus(strings.ToLower(status))}
	}

	return staffRequest{
		query:  query,
		raw:    raw,
		search: search,
		role:   role,
		status: status,
	}
}

type staffRequest struct {
	query  adminorg.MembersQuery
	raw    string
	search string
	role   string
	status string
}

func buildStaffPageContent(basePath string, req staffRequest, result adminorg.MembersResult, failed bool) orgtpl.StaffPageContent {
	roleLabels := make(map[string]string, len(result.RoleOptions))
	for _, opt := range result.RoleOptions {
		roleLabels[strings.TrimSpace(opt.Key)] = strings.TrimSpace(opt.Label)
	}

	rows := make([]orgtpl.StaffRow, 0, len(result.Members))
	for _, member := range result.Members {
		rows = append(rows, buildStaffRow(basePath, member, roleLabels))
	}

	filters := orgtpl.StaffFilters{
		Search:         req.search,
		SelectedRole:   req.role,
		SelectedStatus: req.status,
		Action:         joinBasePath(basePath, "/org/staff/table"),
		ResetURL:       joinBasePath(basePath, "/org/staff"),
		RawQuery:       req.raw,
		RoleOptions:    buildFilterOptions(result.Filters.Roles, req.role),
		StatusOptions:  buildFilterOptions(result.Filters.Statuses, req.status),
	}

	summary := orgtpl.StaffSummary{
		Total:     result.Summary.Total,
		Active:    result.Summary.Active,
		Invited:   result.Summary.Invited,
		Suspended: result.Summary.Suspended,
		Revoked:   result.Summary.Revoked,
	}

	invite := orgtpl.StaffInvite{
		Allowed:        result.Invite.Allowed,
		Remaining:      result.Invite.Remaining,
		Message:        strings.TrimSpace(result.Invite.Message),
		ModalURL:       joinBasePath(basePath, "/org/staff/modal/invite"),
		DisabledReason: strings.TrimSpace(result.Invite.Message),
	}

	table := orgtpl.StaffTable{
		FragmentPath: joinBasePath(basePath, "/org/staff/table"),
		RawQuery:     req.raw,
		Rows:         rows,
		Total:        result.Summary.Total,
		EmptyMessage: "",
		RefreshEvent: staffRefreshEvent,
	}

	content := orgtpl.StaffPageContent{
		BasePath: basePath,
		Summary:  summary,
		Filters:  filters,
		Table:    table,
		Invite:   invite,
	}
	if failed {
		content.Error = "スタッフリストの取得に失敗しました。時間を置いて再度お試しください。"
	}
	return content
}

func buildStaffRow(basePath string, member adminorg.Member, roleLabels map[string]string) orgtpl.StaffRow {
	roles := make([]orgtpl.StaffRoleBadge, 0, len(member.Roles))
	for _, role := range member.Roles {
		label := roleLabels[strings.TrimSpace(role)]
		if label == "" {
			label = strings.ToUpper(strings.TrimSpace(role))
		}
		roles = append(roles, orgtpl.StaffRoleBadge{Label: label})
	}

	lastActiveRelative := "未ログイン"
	lastActiveExact := ""
	if member.LastActiveAt != nil && !member.LastActiveAt.IsZero() {
		lastActiveRelative = helpersRelative(*member.LastActiveAt)
		lastActiveExact = helpersDatetime(*member.LastActiveAt)
	}

	mfaStatus := "未設定"
	if member.MFA.Enabled {
		if member.MFA.PrimaryMethod != "" {
			mfaStatus = "有効 (" + strings.ToUpper(member.MFA.PrimaryMethod) + ")"
		} else {
			mfaStatus = "有効"
		}
	}

	inviteLabel := ""
	inviteTooltip := ""
	if member.Invitation != nil {
		inviteLabel = "招待送信済み"
		if member.Invitation.ExpiresAt != nil && !member.Invitation.ExpiresAt.IsZero() {
			inviteTooltip = "有効期限: " + helpersDatetime(*member.Invitation.ExpiresAt)
		} else if !member.Invitation.SentAt.IsZero() {
			inviteTooltip = "送信: " + helpersDatetime(member.Invitation.SentAt)
		}
	}

	return orgtpl.StaffRow{
		ID:                 member.ID,
		Name:               safeDisplayName(&member),
		Email:              strings.TrimSpace(member.Email),
		Roles:              roles,
		StatusLabel:        fallback(member.StatusLabel, fmt.Sprintf("%s", strings.Title(string(member.Status)))),
		StatusTone:         fallback(member.StatusTone, "info"),
		LastActiveRelative: lastActiveRelative,
		LastActiveExact:    lastActiveExact,
		MFAStatus:          mfaStatus,
		MFAEnabled:         member.MFA.Enabled,
		InvitationLabel:    inviteLabel,
		InvitationTooltip:  inviteTooltip,
		Actions: orgtpl.StaffRowActions{
			EditURL:   joinBasePath(basePath, fmt.Sprintf("/org/staff/%s/modal/edit", url.PathEscape(member.ID))),
			RevokeURL: joinBasePath(basePath, fmt.Sprintf("/org/staff/%s/modal/revoke", url.PathEscape(member.ID))),
		},
	}
}

func buildFilterOptions(options []adminorg.FilterOption, selected string) []orgtpl.StaffFilterOption {
	out := make([]orgtpl.StaffFilterOption, 0, len(options))
	for _, option := range options {
		value := strings.TrimSpace(option.Value)
		opt := orgtpl.StaffFilterOption{
			Value:    value,
			Label:    strings.TrimSpace(option.Label),
			Count:    option.Count,
			Selected: value == selected,
		}
		out = append(out, opt)
	}
	return out
}

func buildRoleOptions(defs []adminorg.RoleDefinition, selected []string) []orgtpl.StaffRoleOption {
	selectedSet := make(map[string]struct{}, len(selected))
	for _, key := range selected {
		selectedSet[strings.TrimSpace(key)] = struct{}{}
	}

	options := make([]orgtpl.StaffRoleOption, 0, len(defs))
	for _, def := range defs {
		key := strings.TrimSpace(def.Key)
		options = append(options, orgtpl.StaffRoleOption{
			Key:         key,
			Label:       strings.TrimSpace(def.Label),
			Description: strings.TrimSpace(def.Description),
			Checked:     containsKey(selectedSet, key),
		})
	}
	return options
}

func buildRoleCards(defs []adminorg.RoleDefinition) []orgtpl.RoleCard {
	cards := make([]orgtpl.RoleCard, 0, len(defs))
	for _, def := range defs {
		lastUpdatedText := ""
		lastUpdatedHint := ""
		if def.LastUpdated != nil && !def.LastUpdated.IsZero() {
			lastUpdatedText = helpersRelative(*def.LastUpdated)
			lastUpdatedHint = helpersDatetime(*def.LastUpdated)
		}

		caps := make([]orgtpl.RoleCapability, 0, len(def.Capabilities))
		for _, cap := range def.Capabilities {
			caps = append(caps, orgtpl.RoleCapability{
				Label:       strings.TrimSpace(cap.Label),
				Description: strings.TrimSpace(cap.Description),
			})
		}

		cards = append(cards, orgtpl.RoleCard{
			Key:             strings.TrimSpace(def.Key),
			Label:           strings.TrimSpace(def.Label),
			Description:     strings.TrimSpace(def.Description),
			Members:         def.Members,
			LastUpdatedText: lastUpdatedText,
			LastUpdatedHint: lastUpdatedHint,
			Capabilities:    caps,
		})
	}
	return cards
}

func (h *Handlers) renderInviteModalWithError(w http.ResponseWriter, r *http.Request, message string, fallback *adminorg.InviteRequest) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	catalog, err := h.org.Catalog(ctx, user.Token)
	if err != nil {
		log.Printf("org: fetch role catalog (invite error render) failed: %v", err)
		http.Error(w, "ロール一覧の取得に失敗しました。", http.StatusBadGateway)
		return
	}

	basePath := custommw.BasePathFromContext(ctx)
	values := orgtpl.StaffInviteFormValues{
		SendEmail: true,
	}
	if fallback != nil {
		values.Email = fallback.Email
		values.Name = fallback.Name
		values.Roles = fallback.Roles
		values.Note = fallback.Note
		values.SendEmail = fallback.SendEmail
	}

	payload := orgtpl.StaffInviteModalPayload{
		Action:      joinBasePath(basePath, "/org/staff/invite"),
		CSRFToken:   custommw.CSRFTokenFromContext(ctx),
		Values:      values,
		RoleOptions: buildRoleOptions(catalog.Roles, values.Roles),
		Error:       message,
	}

	templ.Handler(orgtpl.StaffInviteModal(payload)).ServeHTTP(w, r)
}

func (h *Handlers) renderEditModalWithError(w http.ResponseWriter, r *http.Request, memberID, message string) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	member, err := h.org.Member(ctx, user.Token, memberID)
	if err != nil {
		handleOrgMemberError(w, err)
		return
	}

	catalog, err := h.org.Catalog(ctx, user.Token)
	if err != nil {
		log.Printf("org: fetch role catalog (edit error render) failed: %v", err)
		http.Error(w, "ロール一覧の取得に失敗しました。", http.StatusBadGateway)
		return
	}

	basePath := custommw.BasePathFromContext(ctx)
	payload := orgtpl.StaffEditModalPayload{
		Action:      joinBasePath(basePath, fmt.Sprintf("/org/staff/%s:update", url.PathEscape(member.ID))),
		CSRFToken:   custommw.CSRFTokenFromContext(ctx),
		MemberName:  safeDisplayName(member),
		MemberEmail: strings.TrimSpace(member.Email),
		RoleOptions: buildRoleOptions(catalog.Roles, member.Roles),
		Error:       message,
	}

	templ.Handler(orgtpl.StaffEditModal(payload)).ServeHTTP(w, r)
}

func (h *Handlers) renderRevokeModalWithError(w http.ResponseWriter, r *http.Request, memberID, message string) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	member, err := h.org.Member(ctx, user.Token, memberID)
	if err != nil {
		handleOrgMemberError(w, err)
		return
	}

	basePath := custommw.BasePathFromContext(ctx)
	payload := orgtpl.StaffRevokeModalPayload{
		Action:         joinBasePath(basePath, fmt.Sprintf("/org/staff/%s:revoke", url.PathEscape(member.ID))),
		CSRFToken:      custommw.CSRFTokenFromContext(ctx),
		MemberName:     safeDisplayName(member),
		MemberEmail:    strings.TrimSpace(member.Email),
		Reason:         strings.TrimSpace(r.PostForm.Get("reason")),
		Note:           strings.TrimSpace(r.PostForm.Get("note")),
		RevokeSessions: isChecked(r.PostForm.Get("revokeSessions")),
		NotifyUser:     isChecked(r.PostForm.Get("notifyUser")),
		Error:          message,
	}

	templ.Handler(orgtpl.StaffRevokeModal(payload)).ServeHTTP(w, r)
}

func triggerStaffRefresh(w http.ResponseWriter, message, tone string) {
	payload := map[string]any{
		"toast": map[string]string{
			"message": strings.TrimSpace(message),
			"tone":    strings.TrimSpace(tone),
		},
		"modal:close":     true,
		staffRefreshEvent: true,
	}
	if data, err := json.Marshal(payload); err == nil {
		w.Header().Set("HX-Trigger", string(data))
	} else {
		log.Printf("org: marshal HX-Trigger payload failed: %v", err)
	}
}

func canonicalStaffURL(basePath string, req staffRequest) string {
	values := url.Values{}
	if req.search != "" {
		values.Set("q", req.search)
	}
	if req.role != "" {
		values.Set("role", req.role)
	}
	if req.status != "" {
		values.Set("status", req.status)
	}
	if len(values) == 0 {
		return joinBasePath(basePath, "/org/staff")
	}
	return joinBasePath(basePath, "/org/staff") + "?" + values.Encode()
}

func isChecked(raw string) bool {
	val := strings.ToLower(strings.TrimSpace(raw))
	switch val {
	case "1", "true", "on", "yes":
		return true
	default:
		return false
	}
}

func uniqueStrings(values []string) []string {
	if len(values) == 0 {
		return nil
	}
	seen := make(map[string]struct{}, len(values))
	out := make([]string, 0, len(values))
	for _, v := range values {
		v = strings.TrimSpace(v)
		if v == "" {
			continue
		}
		if _, ok := seen[v]; ok {
			continue
		}
		seen[v] = struct{}{}
		out = append(out, v)
	}
	return out
}

func safeDisplayName(member *adminorg.Member) string {
	if member == nil {
		return "スタッフ"
	}
	name := strings.TrimSpace(member.Name)
	if name != "" {
		return name
	}
	email := strings.TrimSpace(member.Email)
	if email != "" {
		return email
	}
	return "スタッフ"
}

func fallback(value, fallback string) string {
	if strings.TrimSpace(value) != "" {
		return strings.TrimSpace(value)
	}
	return strings.TrimSpace(fallback)
}

func containsKey(set map[string]struct{}, key string) bool {
	_, ok := set[strings.TrimSpace(key)]
	return ok
}

func helpersRelative(ts time.Time) string {
	return strings.TrimSpace(helpers.Relative(ts))
}

func helpersDatetime(ts time.Time) string {
	return strings.TrimSpace(helpers.Date(ts, "2006-01-02 15:04 MST"))
}

func handleOrgMemberError(w http.ResponseWriter, err error) {
	var orgErr *adminorg.Error
	if errors.As(err, &orgErr) && orgErr != nil && strings.EqualFold(orgErr.Code, "not_found") {
		http.Error(w, "指定されたスタッフが見つかりません。", http.StatusNotFound)
		return
	}
	log.Printf("org: member lookup failed: %v", err)
	http.Error(w, "スタッフ情報の取得に失敗しました。", http.StatusBadGateway)
}
