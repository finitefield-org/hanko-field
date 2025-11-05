package org_test

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"
	"time"

	"github.com/stretchr/testify/require"

	"finitefield.org/hanko-admin/internal/admin/org"
)

func TestHTTPServiceList(t *testing.T) {
	t.Parallel()

	var receivedPath string
	var receivedQuery url.Values
	var receivedAuth string

	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		receivedPath = r.URL.Path
		receivedQuery = r.URL.Query()
		receivedAuth = r.Header.Get("Authorization")

		resp := org.MembersResult{
			Members: []org.Member{
				{
					ID:          "staff-1",
					Email:       "admin@example.com",
					Name:        "Admin",
					Roles:       []string{"admin"},
					Status:      org.MemberStatusActive,
					StatusLabel: "アクティブ",
					CreatedAt:   time.Now(),
				},
			},
			Summary: org.Summary{Total: 1, Active: 1},
			Filters: org.FilterSummary{
				Roles: []org.FilterOption{{Value: "", Label: "すべて"}},
			},
			Invite: org.InvitePolicy{Allowed: true, Remaining: 10},
		}

		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(resp)
	}))
	t.Cleanup(ts.Close)

	svc, err := org.NewHTTPService(ts.URL, ts.Client())
	require.NoError(t, err)

	ctx := context.Background()
	result, err := svc.List(ctx, "token", org.MembersQuery{
		Search:   "admin",
		Roles:    []string{"admin"},
		Statuses: []org.MemberStatus{org.MemberStatusActive},
		Page:     2,
		PageSize: 50,
	})
	require.NoError(t, err)
	require.Equal(t, "/staff/org/members", receivedPath)
	require.Equal(t, "Bearer token", strings.TrimSpace(receivedAuth))
	require.Equal(t, "admin", receivedQuery.Get("q"))
	require.Equal(t, "admin", receivedQuery.Get("role"))
	require.Equal(t, "active", receivedQuery.Get("status"))
	require.Equal(t, "2", receivedQuery.Get("page"))
	require.Equal(t, "50", receivedQuery.Get("pageSize"))
	require.Len(t, result.Members, 1)
}

func TestHTTPServiceInvite(t *testing.T) {
	t.Parallel()

	var payload org.InviteRequest
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		require.Equal(t, http.MethodPost, r.Method)
		require.Equal(t, "/staff/org/invitations", r.URL.Path)
		require.Equal(t, "application/json", r.Header.Get("Content-Type"))

		defer r.Body.Close()
		require.NoError(t, json.NewDecoder(r.Body).Decode(&payload))

		member := org.Member{
			ID:          "staff-new",
			Email:       payload.Email,
			Name:        payload.Name,
			Roles:       payload.Roles,
			Status:      org.MemberStatusInvited,
			StatusLabel: "招待中",
			CreatedAt:   time.Now(),
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		_ = json.NewEncoder(w).Encode(member)
	}))
	t.Cleanup(ts.Close)

	svc, err := org.NewHTTPService(ts.URL, ts.Client())
	require.NoError(t, err)

	member, err := svc.Invite(context.Background(), "token", org.InviteRequest{
		Email:      "new@example.com",
		Name:       "New User",
		Roles:      []string{"support"},
		SendEmail:  true,
		ActorID:    "actor-1",
		ActorEmail: "actor@example.com",
	})
	require.NoError(t, err)
	require.Equal(t, "new@example.com", payload.Email)
	require.True(t, payload.SendEmail)
	require.Equal(t, "support", payload.Roles[0])
	require.Equal(t, org.MemberStatusInvited, member.Status)
}

func TestHTTPServiceUpdateRoles(t *testing.T) {
	t.Parallel()

	var payload org.UpdateRolesRequest
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		require.Equal(t, http.MethodPut, r.Method)
		require.Equal(t, "/staff/org/members/staff-1", r.URL.Path)
		defer r.Body.Close()
		require.NoError(t, json.NewDecoder(r.Body).Decode(&payload))

		member := org.Member{
			ID:          "staff-1",
			Email:       "admin@example.com",
			Roles:       payload.Roles,
			Status:      org.MemberStatusActive,
			StatusLabel: "アクティブ",
			UpdatedAt:   ptr(time.Now()),
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(member)
	}))
	t.Cleanup(ts.Close)

	svc, err := org.NewHTTPService(ts.URL, ts.Client())
	require.NoError(t, err)

	member, err := svc.UpdateRoles(context.Background(), "token", "staff-1", org.UpdateRolesRequest{
		Roles:      []string{"admin", "support"},
		ActorID:    "actor-1",
		ActorEmail: "actor@example.com",
	})
	require.NoError(t, err)
	require.Equal(t, []string{"admin", "support"}, payload.Roles)
	require.Equal(t, "admin", member.Roles[0])
}

func TestHTTPServiceRevoke(t *testing.T) {
	t.Parallel()

	var payload org.RevokeRequest
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		require.Equal(t, http.MethodPost, r.Method)
		require.Equal(t, "/staff/org/members/staff-1:revoke", r.URL.Path)
		defer r.Body.Close()
		require.NoError(t, json.NewDecoder(r.Body).Decode(&payload))
		w.WriteHeader(http.StatusNoContent)
	}))
	t.Cleanup(ts.Close)

	svc, err := org.NewHTTPService(ts.URL, ts.Client())
	require.NoError(t, err)

	err = svc.Revoke(context.Background(), "token", "staff-1", org.RevokeRequest{
		Reason:     "No longer needed",
		NotifyUser: true,
	})
	require.NoError(t, err)
	require.Equal(t, "No longer needed", payload.Reason)
	require.True(t, payload.NotifyUser)
}

func TestHTTPServiceMember(t *testing.T) {
	t.Parallel()

	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		require.Equal(t, "/staff/org/members/staff-1", r.URL.Path)
		member := org.Member{
			ID:          "staff-1",
			Email:       "admin@example.com",
			Status:      org.MemberStatusActive,
			StatusLabel: "アクティブ",
			CreatedAt:   time.Now(),
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(member)
	}))
	t.Cleanup(ts.Close)

	svc, err := org.NewHTTPService(ts.URL, ts.Client())
	require.NoError(t, err)

	member, err := svc.Member(context.Background(), "token", "staff-1")
	require.NoError(t, err)
	require.Equal(t, "admin@example.com", member.Email)
}

func TestHTTPServiceCatalog(t *testing.T) {
	t.Parallel()

	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		require.Equal(t, "/staff/org/roles", r.URL.Path)
		resp := org.RoleCatalog{
			Roles: []org.RoleDefinition{
				{Key: "admin", Label: "管理者"},
			},
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(resp)
	}))
	t.Cleanup(ts.Close)

	svc, err := org.NewHTTPService(ts.URL, ts.Client())
	require.NoError(t, err)

	catalog, err := svc.Catalog(context.Background(), "token")
	require.NoError(t, err)
	require.Equal(t, "admin", catalog.Roles[0].Key)
}

func ptr(t time.Time) *time.Time {
	return &t
}
