package org

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"path"
	"strconv"
	"strings"

	"finitefield.org/hanko-admin/internal/admin/observability"
)

// HTTPClient describes the subset of http.Client used by HTTPService.
type HTTPClient interface {
	Do(*http.Request) (*http.Response, error)
}

// HTTPService implements Service backed by REST endpoints exposed by the backend API.
type HTTPService struct {
	base   *url.URL
	client HTTPClient
}

// NewHTTPService constructs a Service that talks to the backend organisation/staff API.
func NewHTTPService(baseURL string, client HTTPClient) (*HTTPService, error) {
	if strings.TrimSpace(baseURL) == "" {
		return nil, errors.New("org: base URL is required")
	}
	parsed, err := url.Parse(baseURL)
	if err != nil {
		return nil, fmt.Errorf("org: parse base URL: %w", err)
	}
	if client == nil {
		client = http.DefaultClient
	}
	return &HTTPService{
		base:   parsed,
		client: client,
	}, nil
}

// List retrieves staff members based on the provided query.
func (s *HTTPService) List(ctx context.Context, token string, query MembersQuery) (MembersResult, error) {
	endpoint := "/staff/org/members"
	values := url.Values{}
	if strings.TrimSpace(query.Search) != "" {
		values.Set("q", strings.TrimSpace(query.Search))
	}
	for _, role := range query.Roles {
		role = strings.TrimSpace(role)
		if role == "" {
			continue
		}
		values.Add("role", role)
	}
	for _, status := range query.Statuses {
		if status == "" {
			continue
		}
		values.Add("status", string(status))
	}
	if query.Page > 0 {
		values.Set("page", strconv.Itoa(query.Page))
	}
	if query.PageSize > 0 {
		values.Set("pageSize", strconv.Itoa(query.PageSize))
	}
	req, err := s.newRequest(ctx, http.MethodGet, endpoint, values, token)
	if err != nil {
		return MembersResult{}, err
	}

	resp, err := s.do(req)
	if err != nil {
		return MembersResult{}, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return MembersResult{}, s.errorFromResponse(resp)
	}

	var payload MembersResult
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		return MembersResult{}, fmt.Errorf("org: decode members: %w", err)
	}
	return payload, nil
}

// Invite issues a new staff invitation.
func (s *HTTPService) Invite(ctx context.Context, token string, reqBody InviteRequest) (*Member, error) {
	req, err := s.newJSONRequest(ctx, http.MethodPost, "/staff/org/invitations", reqBody, token)
	if err != nil {
		return nil, err
	}
	resp, err := s.do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusCreated && resp.StatusCode != http.StatusOK {
		return nil, s.errorFromResponse(resp)
	}

	var member Member
	if err := json.NewDecoder(resp.Body).Decode(&member); err != nil {
		return nil, fmt.Errorf("org: decode invitation response: %w", err)
	}
	return &member, nil
}

// Member fetches a single staff member.
func (s *HTTPService) Member(ctx context.Context, token, memberID string) (*Member, error) {
	escaped := path.Join("/staff/org/members", url.PathEscape(strings.TrimSpace(memberID)))
	req, err := s.newRequest(ctx, http.MethodGet, escaped, nil, token)
	if err != nil {
		return nil, err
	}
	resp, err := s.do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, s.errorFromResponse(resp)
	}

	var member Member
	if err := json.NewDecoder(resp.Body).Decode(&member); err != nil {
		return nil, fmt.Errorf("org: decode member: %w", err)
	}
	return &member, nil
}

// UpdateRoles replaces role assignments for the specified member.
func (s *HTTPService) UpdateRoles(ctx context.Context, token, memberID string, reqBody UpdateRolesRequest) (*Member, error) {
	escaped := path.Join("/staff/org/members", url.PathEscape(strings.TrimSpace(memberID)))
	req, err := s.newJSONRequest(ctx, http.MethodPut, escaped, reqBody, token)
	if err != nil {
		return nil, err
	}
	resp, err := s.do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, s.errorFromResponse(resp)
	}

	var member Member
	if err := json.NewDecoder(resp.Body).Decode(&member); err != nil {
		return nil, fmt.Errorf("org: decode member update response: %w", err)
	}
	return &member, nil
}

// Revoke disables the member's access across the system.
func (s *HTTPService) Revoke(ctx context.Context, token, memberID string, reqBody RevokeRequest) error {
	endpoint := path.Join("/staff/org/members", url.PathEscape(strings.TrimSpace(memberID))) + ":revoke"
	req, err := s.newJSONRequest(ctx, http.MethodPost, endpoint, reqBody, token)
	if err != nil {
		return err
	}
	resp, err := s.do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusNoContent && resp.StatusCode != http.StatusOK {
		return s.errorFromResponse(resp)
	}
	return nil
}

// Catalog retrieves the current role definitions and capabilities.
func (s *HTTPService) Catalog(ctx context.Context, token string) (RoleCatalog, error) {
	req, err := s.newRequest(ctx, http.MethodGet, "/staff/org/roles", nil, token)
	if err != nil {
		return RoleCatalog{}, err
	}
	resp, err := s.do(req)
	if err != nil {
		return RoleCatalog{}, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return RoleCatalog{}, s.errorFromResponse(resp)
	}

	var catalog RoleCatalog
	if err := json.NewDecoder(resp.Body).Decode(&catalog); err != nil {
		return RoleCatalog{}, fmt.Errorf("org: decode role catalog: %w", err)
	}
	return catalog, nil
}

func (s *HTTPService) newRequest(ctx context.Context, method, endpoint string, query url.Values, token string) (*http.Request, error) {
	fullURL := s.resolve(endpoint)
	if len(query) > 0 {
		if strings.Contains(fullURL, "?") {
			fullURL += "&" + query.Encode()
		} else {
			fullURL += "?" + query.Encode()
		}
	}
	req, err := http.NewRequestWithContext(ctx, method, fullURL, nil)
	if err != nil {
		return nil, fmt.Errorf("org: create request: %w", err)
	}
	if strings.TrimSpace(token) != "" {
		req.Header.Set("Authorization", "Bearer "+strings.TrimSpace(token))
	}
	req.Header.Set("Accept", "application/json")
	observability.PropagateTraceHeaders(ctx, req)
	return req, nil
}

func (s *HTTPService) newJSONRequest(ctx context.Context, method, endpoint string, payload any, token string) (*http.Request, error) {
	var buf bytes.Buffer
	if payload != nil {
		enc := json.NewEncoder(&buf)
		enc.SetEscapeHTML(false)
		if err := enc.Encode(payload); err != nil {
			return nil, fmt.Errorf("org: encode payload: %w", err)
		}
	}
	req, err := s.newRequest(ctx, method, endpoint, nil, token)
	if err != nil {
		return nil, err
	}
	req.Body = io.NopCloser(&buf)
	req.ContentLength = int64(buf.Len())
	req.Header.Set("Content-Type", "application/json")
	return req, nil
}

func (s *HTTPService) do(req *http.Request) (*http.Response, error) {
	resp, err := s.client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("org: request failed: %w", err)
	}
	return resp, nil
}

func (s *HTTPService) resolve(endpoint string) string {
	if endpoint == "" {
		return s.base.String()
	}
	if strings.HasPrefix(endpoint, "http://") || strings.HasPrefix(endpoint, "https://") {
		return endpoint
	}
	trimmed := strings.TrimSpace(endpoint)
	ref, err := url.Parse(trimmed)
	if err != nil {
		ref = &url.URL{Path: trimmed}
	}
	if ref.IsAbs() {
		return ref.String()
	}
	baseCopy := *s.base
	refPath := ref.Path
	if refPath != "" {
		if strings.HasPrefix(refPath, "/") {
			refPath = strings.TrimPrefix(refPath, "/")
		}
		basePath := strings.TrimRight(baseCopy.Path, "/")
		if basePath == "" || basePath == "/" {
			baseCopy.Path = "/" + refPath
		} else {
			baseCopy.Path = basePath + "/" + refPath
		}
	}
	if ref.RawQuery != "" {
		baseCopy.RawQuery = ref.RawQuery
	} else {
		baseCopy.RawQuery = ""
	}
	baseCopy.Fragment = ref.Fragment
	return baseCopy.String()
}

func (s *HTTPService) errorFromResponse(resp *http.Response) error {
	body, _ := io.ReadAll(io.LimitReader(resp.Body, 1<<16))
	_ = resp.Body.Close()

	type errorPayload struct {
		Code    string `json:"code"`
		Message string `json:"message"`
	}
	var payload errorPayload
	if len(body) > 0 {
		if err := json.Unmarshal(body, &payload); err == nil && strings.TrimSpace(payload.Message) != "" {
			return &Error{Code: strings.TrimSpace(payload.Code), Message: strings.TrimSpace(payload.Message)}
		}
	}
	if len(body) > 0 {
		return fmt.Errorf("org: backend error (%d): %s", resp.StatusCode, strings.TrimSpace(string(body)))
	}
	return fmt.Errorf("org: backend error (%d): %s", resp.StatusCode, http.StatusText(resp.StatusCode))
}
