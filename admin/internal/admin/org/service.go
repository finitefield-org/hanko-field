package org

import (
	"context"
	"time"
)

// Service exposes organisation management capabilities (staff membership, role catalog, invitations).
type Service interface {
	// List returns staff members matching the provided query.
	List(ctx context.Context, token string, query MembersQuery) (MembersResult, error)
	// Member retrieves a single staff member by identifier.
	Member(ctx context.Context, token, memberID string) (*Member, error)
	// Invite issues a new staff invitation and returns the pending member record.
	Invite(ctx context.Context, token string, req InviteRequest) (*Member, error)
	// UpdateRoles replaces the role assignments for the specified member.
	UpdateRoles(ctx context.Context, token, memberID string, req UpdateRolesRequest) (*Member, error)
	// Revoke disables the member's access.
	Revoke(ctx context.Context, token, memberID string, req RevokeRequest) error
	// Catalog returns the known role definitions and capability mapping.
	Catalog(ctx context.Context, token string) (RoleCatalog, error)
}

// MembersQuery captures filters and pagination arguments when listing staff members.
type MembersQuery struct {
	Search   string
	Roles    []string
	Statuses []MemberStatus
	Page     int
	PageSize int
}

// MembersResult represents the payload required to render the staff list UI.
type MembersResult struct {
	Members     []Member
	Summary     Summary
	Filters     FilterSummary
	Invite      InvitePolicy
	RoleOptions []RoleOption
}

// MemberStatus enumerates the lifecycle state for a staff account.
type MemberStatus string

const (
	// MemberStatusActive indicates the staff account can sign in.
	MemberStatusActive MemberStatus = "active"
	// MemberStatusInvited indicates the staff account invitation is pending acceptance.
	MemberStatusInvited MemberStatus = "invited"
	// MemberStatusSuspended indicates the staff account has been suspended temporarily.
	MemberStatusSuspended MemberStatus = "suspended"
	// MemberStatusRevoked indicates the staff account has been revoked permanently.
	MemberStatusRevoked MemberStatus = "revoked"
)

// Member represents a single staff account row in the UI.
type Member struct {
	ID            string        `json:"id"`
	Email         string        `json:"email"`
	Name          string        `json:"name"`
	Roles         []string      `json:"roles"`
	Status        MemberStatus  `json:"status"`
	StatusLabel   string        `json:"statusLabel"`
	StatusTone    string        `json:"statusTone"`
	LastActiveAt  *time.Time    `json:"lastActiveAt"`
	InvitedAt     *time.Time    `json:"invitedAt"`
	CreatedAt     time.Time     `json:"createdAt"`
	UpdatedAt     *time.Time    `json:"updatedAt"`
	MFA           MFAState      `json:"mfa"`
	Invitation    *Invitation   `json:"invitation,omitempty"`
	Capabilities  []Capability  `json:"capabilities,omitempty"`
	Notes         []AuditRecord `json:"notes,omitempty"`
	PrimaryRole   string        `json:"primaryRole"`
	PrimaryRoleID string        `json:"primaryRoleId"`
}

// MFAState summarises MFA enrolment for a member.
type MFAState struct {
	Enabled        bool        `json:"enabled"`
	PrimaryMethod  string      `json:"primaryMethod"`
	Methods        []MFAMethod `json:"methods"`
	LastVerifiedAt *time.Time  `json:"lastVerifiedAt"`
}

// MFAMethod describes a configured MFA factor.
type MFAMethod struct {
	Kind      string    `json:"kind"`
	Label     string    `json:"label"`
	CreatedAt time.Time `json:"createdAt"`
	Default   bool      `json:"default"`
}

// Invitation contains metadata for pending invitations.
type Invitation struct {
	Email       string     `json:"email"`
	SentAt      time.Time  `json:"sentAt"`
	ExpiresAt   *time.Time `json:"expiresAt"`
	InvitedBy   string     `json:"invitedBy"`
	Status      string     `json:"status"`
	DeliveryID  string     `json:"deliveryId"`
	DeliveryURL string     `json:"deliveryUrl"`
}

// AuditRecord summarises an audit trail entry associated with the member.
type AuditRecord struct {
	ID        string    `json:"id"`
	Message   string    `json:"message"`
	Actor     string    `json:"actor"`
	CreatedAt time.Time `json:"createdAt"`
	Tone      string    `json:"tone"`
}

// Summary exposes aggregate counts for the current list.
type Summary struct {
	Total     int `json:"total"`
	Active    int `json:"active"`
	Invited   int `json:"invited"`
	Suspended int `json:"suspended"`
	Revoked   int `json:"revoked"`
}

// FilterSummary pre-computes filter option metadata (counts, labels).
type FilterSummary struct {
	Roles    []FilterOption `json:"roles"`
	Statuses []FilterOption `json:"statuses"`
}

// FilterOption represents a selectable filter choice.
type FilterOption struct {
	Value string `json:"value"`
	Label string `json:"label"`
	Count int    `json:"count,omitempty"`
}

// InvitePolicy describes quota and availability information for new invitations.
type InvitePolicy struct {
	Allowed          bool   `json:"allowed"`
	Remaining        int    `json:"remaining"`
	DomainConstraint string `json:"domainConstraint"`
	Message          string `json:"message"`
}

// InviteRequest captures input fields when inviting a new staff member.
type InviteRequest struct {
	Email      string   `json:"email"`
	Name       string   `json:"name,omitempty"`
	Roles      []string `json:"roles"`
	SendEmail  bool     `json:"sendEmail"`
	Note       string   `json:"note,omitempty"`
	ActorID    string   `json:"actorId"`
	ActorEmail string   `json:"actorEmail"`
}

// UpdateRolesRequest encapsulates role mutation fields.
type UpdateRolesRequest struct {
	Roles      []string `json:"roles"`
	Note       string   `json:"note,omitempty"`
	ActorID    string   `json:"actorId"`
	ActorEmail string   `json:"actorEmail"`
}

// RevokeRequest encapsulates access revocation metadata.
type RevokeRequest struct {
	Reason         string `json:"reason"`
	Note           string `json:"note,omitempty"`
	RevokeSessions bool   `json:"revokeSessions"`
	NotifyUser     bool   `json:"notifyUser"`
	ActorID        string `json:"actorId"`
	ActorEmail     string `json:"actorEmail"`
}

// RoleCatalog returns role definitions leveraged by the UI.
type RoleCatalog struct {
	Roles []RoleDefinition `json:"roles"`
}

// RoleDefinition describes a role and its associated capabilities.
type RoleDefinition struct {
	Key          string       `json:"key"`
	Label        string       `json:"label"`
	Description  string       `json:"description"`
	Capabilities []Capability `json:"capabilities"`
	Members      int          `json:"members"`
	LastUpdated  *time.Time   `json:"lastUpdated"`
}

// RoleOption represents a selectable role in forms.
type RoleOption struct {
	Key          string       `json:"key"`
	Label        string       `json:"label"`
	Description  string       `json:"description"`
	Recommended  bool         `json:"recommended"`
	Capabilities []Capability `json:"capabilities"`
}

// Capability summarises a single RBAC capability.
type Capability struct {
	Key         string `json:"key"`
	Label       string `json:"label"`
	Description string `json:"description"`
}

var (
	// ErrNotConfigured indicates the org service dependency has not been provided.
	ErrNotConfigured = &Error{Code: "org_not_configured", Message: "org service not configured"}
)

// Error represents a domain-specific error from the org service.
type Error struct {
	Code    string
	Message string
}

// Error implements the error interface.
func (e *Error) Error() string {
	if e == nil {
		return ""
	}
	if e.Code == "" {
		return e.Message
	}
	if e.Message == "" {
		return e.Code
	}
	return e.Code + ": " + e.Message
}
