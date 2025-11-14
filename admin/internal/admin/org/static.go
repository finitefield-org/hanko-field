package org

import (
	"context"
	"strings"
	"sync"
	"time"
)

// StaticService provides an in-memory implementation of Service suitable for local development.
type StaticService struct {
	mu      sync.RWMutex
	members map[string]Member
	order   []string
	roles   []RoleDefinition
	invites InvitePolicy
}

// NewStaticService seeds a StaticService with representative staff data.
func NewStaticService() *StaticService {
	now := time.Now()
	members := map[string]Member{
		"staff-admin": {
			ID:           "staff-admin",
			Email:        "admin@example.com",
			Name:         "Admin User",
			Roles:        []string{"admin"},
			Status:       MemberStatusActive,
			StatusLabel:  "アクティブ",
			StatusTone:   "success",
			CreatedAt:    now.Add(-120 * time.Hour),
			LastActiveAt: ptrTime(now.Add(-2 * time.Hour)),
			MFA: MFAState{
				Enabled:       true,
				PrimaryMethod: "totp",
				Methods: []MFAMethod{
					{Kind: "totp", Label: "Authenticator App", CreatedAt: now.Add(-100 * time.Hour), Default: true},
				},
			},
			PrimaryRole: "admin",
		},
		"staff-ops": {
			ID:           "staff-ops",
			Email:        "operations@example.com",
			Name:         "Operations Lead",
			Roles:        []string{"ops"},
			Status:       MemberStatusActive,
			StatusLabel:  "アクティブ",
			StatusTone:   "success",
			CreatedAt:    now.Add(-240 * time.Hour),
			LastActiveAt: ptrTime(now.Add(-6 * time.Hour)),
			MFA: MFAState{
				Enabled:       false,
				PrimaryMethod: "",
				Methods:       nil,
			},
			PrimaryRole: "ops",
		},
		"staff-support": {
			ID:          "staff-support",
			Email:       "support@example.com",
			Name:        "Support Agent",
			Roles:       []string{"support"},
			Status:      MemberStatusInvited,
			StatusLabel: "招待中",
			StatusTone:  "warning",
			CreatedAt:   now.Add(-48 * time.Hour),
			InvitedAt:   ptrTime(now.Add(-24 * time.Hour)),
			Invitation: &Invitation{
				Email:     "support@example.com",
				SentAt:    now.Add(-24 * time.Hour),
				InvitedBy: "admin@example.com",
				Status:    "pending",
			},
			PrimaryRole: "support",
		},
	}

	order := []string{"staff-admin", "staff-ops", "staff-support"}

	roles := []RoleDefinition{
		{
			Key:         "admin",
			Label:       "管理者",
			Description: "全ての機能へのアクセスと設定変更が可能です。",
			Members:     1,
			LastUpdated: ptrTime(now.Add(-72 * time.Hour)),
			Capabilities: []Capability{
				{Key: "dashboard.view", Label: "ダッシュボード", Description: "全体指標の参照"},
				{Key: "org.staff", Label: "スタッフ管理", Description: "スタッフの招待や権限更新"},
			},
		},
		{
			Key:         "ops",
			Label:       "オペレーション",
			Description: "出荷・生産キューの管理、在庫調整などを担当します。",
			Members:     1,
			LastUpdated: ptrTime(now.Add(-96 * time.Hour)),
			Capabilities: []Capability{
				{Key: "production.queues", Label: "生産キュー", Description: "生産キューの閲覧・調整"},
				{Key: "shipments.monitor", Label: "配送モニタリング", Description: "配送ステータスの追跡"},
			},
		},
		{
			Key:         "support",
			Label:       "カスタマーサポート",
			Description: "顧客情報、注文状況の確認やサポート対応を行います。",
			Members:     0,
			LastUpdated: ptrTime(now.Add(-120 * time.Hour)),
			Capabilities: []Capability{
				{Key: "orders.detail", Label: "注文詳細", Description: "注文詳細の表示"},
				{Key: "customers.view", Label: "顧客情報", Description: "顧客プロフィールの閲覧"},
			},
		},
	}

	invites := InvitePolicy{
		Allowed:          true,
		Remaining:        5,
		DomainConstraint: "@example.com",
		Message:          "社用メールアドレス（@example.com）のみ招待可能です。",
	}

	return &StaticService{
		members: members,
		order:   order,
		roles:   roles,
		invites: invites,
	}
}

// List returns a filtered snapshot of staff members.
func (s *StaticService) List(ctx context.Context, token string, query MembersQuery) (MembersResult, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	var rows []Member
	roleFilter := normalizeSlice(query.Roles)
	statusFilter := normalizeStatusSlice(query.Statuses)
	search := strings.ToLower(strings.TrimSpace(query.Search))

	for _, id := range s.order {
		member, ok := s.members[id]
		if !ok {
			continue
		}
		if len(roleFilter) > 0 && !intersects(normalizeSlice(member.Roles), roleFilter) {
			continue
		}
		if len(statusFilter) > 0 {
			if _, ok := statusFilter[strings.ToLower(string(member.Status))]; !ok {
				continue
			}
		}
		if search != "" {
			if !strings.Contains(strings.ToLower(member.Email), search) && !strings.Contains(strings.ToLower(member.Name), search) {
				continue
			}
		}
		rows = append(rows, member)
	}

	summary := Summary{
		Total: len(rows),
	}
	for _, member := range s.members {
		switch member.Status {
		case MemberStatusActive:
			summary.Active++
		case MemberStatusInvited:
			summary.Invited++
		case MemberStatusSuspended:
			summary.Suspended++
		case MemberStatusRevoked:
			summary.Revoked++
		}
	}

	filterSummary := FilterSummary{
		Roles: []FilterOption{
			{Value: "", Label: "すべて"},
		},
		Statuses: []FilterOption{
			{Value: "", Label: "すべての状態"},
			{Value: string(MemberStatusActive), Label: "アクティブ", Count: summary.Active},
			{Value: string(MemberStatusInvited), Label: "招待中", Count: summary.Invited},
			{Value: string(MemberStatusSuspended), Label: "一時停止", Count: summary.Suspended},
			{Value: string(MemberStatusRevoked), Label: "アクセス停止", Count: summary.Revoked},
		},
	}
	for _, role := range s.roles {
		filterSummary.Roles = append(filterSummary.Roles, FilterOption{
			Value: role.Key,
			Label: role.Label,
			Count: role.Members,
		})
	}

	roleOptions := make([]RoleOption, 0, len(s.roles))
	for _, role := range s.roles {
		roleOptions = append(roleOptions, RoleOption{
			Key:          role.Key,
			Label:        role.Label,
			Description:  role.Description,
			Recommended:  role.Key == "admin",
			Capabilities: append([]Capability(nil), role.Capabilities...),
		})
	}

	return MembersResult{
		Members:     rows,
		Summary:     summary,
		Filters:     filterSummary,
		Invite:      s.invites,
		RoleOptions: roleOptions,
	}, nil
}

// Invite creates a placeholder pending member entry.
func (s *StaticService) Invite(ctx context.Context, token string, req InviteRequest) (*Member, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	id := "staff-" + strings.NewReplacer("@", "-", ".", "-").Replace(strings.ToLower(strings.TrimSpace(req.Email)))
	if id == "" {
		id = "staff-" + time.Now().Format("20060102150405")
	}
	if _, exists := s.members[id]; exists {
		id = id + "-new"
	}

	now := time.Now()
	member := Member{
		ID:          id,
		Email:       strings.TrimSpace(req.Email),
		Name:        strings.TrimSpace(req.Name),
		Roles:       append([]string(nil), req.Roles...),
		Status:      MemberStatusInvited,
		StatusLabel: "招待中",
		StatusTone:  "warning",
		CreatedAt:   now,
		InvitedAt:   &now,
		Invitation: &Invitation{
			Email:     strings.TrimSpace(req.Email),
			SentAt:    now,
			InvitedBy: strings.TrimSpace(req.ActorEmail),
			Status:    "pending",
		},
		PrimaryRole: firstRole(req.Roles),
	}

	s.members[id] = member
	s.order = append([]string{id}, s.order...)

	if s.invites.Remaining > 0 {
		s.invites.Remaining--
	}

	return &member, nil
}

// Member returns a single member by ID.
func (s *StaticService) Member(ctx context.Context, token, memberID string) (*Member, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	member, ok := s.members[memberID]
	if !ok {
		return nil, &Error{Code: "not_found", Message: "member not found"}
	}
	// Return a copy to avoid callers mutating internal state.
	copyMember := member
	return &copyMember, nil
}

// UpdateRoles updates the roles assigned to a member.
func (s *StaticService) UpdateRoles(ctx context.Context, token, memberID string, req UpdateRolesRequest) (*Member, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	member, ok := s.members[memberID]
	if !ok {
		return nil, &Error{Code: "not_found", Message: "member not found"}
	}

	member.Roles = append([]string(nil), req.Roles...)
	member.PrimaryRole = firstRole(req.Roles)
	now := time.Now()
	member.UpdatedAt = &now
	member.Status = MemberStatusActive
	member.StatusLabel = "アクティブ"
	member.StatusTone = "success"

	s.members[memberID] = member
	return &member, nil
}

// Revoke marks a member as revoked.
func (s *StaticService) Revoke(ctx context.Context, token, memberID string, req RevokeRequest) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	member, ok := s.members[memberID]
	if !ok {
		return &Error{Code: "not_found", Message: "member not found"}
	}
	member.Status = MemberStatusRevoked
	member.StatusLabel = "アクセス停止"
	member.StatusTone = "danger"
	now := time.Now()
	member.UpdatedAt = &now
	member.MFA.Enabled = false
	member.Invitation = nil
	s.members[memberID] = member
	return nil
}

// Catalog returns the static role definitions.
func (s *StaticService) Catalog(ctx context.Context, token string) (RoleCatalog, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	roles := make([]RoleDefinition, len(s.roles))
	copy(roles, s.roles)
	return RoleCatalog{Roles: roles}, nil
}

func normalizeSlice(values []string) map[string]struct{} {
	if len(values) == 0 {
		return nil
	}
	result := make(map[string]struct{}, len(values))
	for _, v := range values {
		v = strings.ToLower(strings.TrimSpace(v))
		if v == "" {
			continue
		}
		result[v] = struct{}{}
	}
	return result
}

func normalizeStatusSlice(values []MemberStatus) map[string]struct{} {
	if len(values) == 0 {
		return nil
	}
	result := make(map[string]struct{}, len(values))
	for _, v := range values {
		val := strings.ToLower(strings.TrimSpace(string(v)))
		if val == "" {
			continue
		}
		result[val] = struct{}{}
	}
	return result
}

func intersects(a, b map[string]struct{}) bool {
	if len(a) == 0 || len(b) == 0 {
		return len(b) == 0
	}
	for key := range a {
		if _, ok := b[key]; ok {
			return true
		}
	}
	return false
}

func ptrTime(t time.Time) *time.Time {
	return &t
}

func firstRole(roles []string) string {
	if len(roles) == 0 {
		return ""
	}
	return strings.TrimSpace(roles[0])
}
