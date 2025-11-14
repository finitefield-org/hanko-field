package webhook

import (
	"errors"
	"net"
	"net/http"
	"strings"
)

// ExtractClientIP returns the first public IP address from X-Forwarded-For or RemoteAddr.
func ExtractClientIP(r *http.Request) (net.IP, error) {
	if r == nil {
		return nil, errors.New("webhook: request nil")
	}
	if forwarded := r.Header.Get("X-Forwarded-For"); forwarded != "" {
		parts := strings.Split(forwarded, ",")
		for _, part := range parts {
			if ip := net.ParseIP(strings.TrimSpace(part)); ip != nil {
				return ip, nil
			}
		}
	}
	addr := strings.TrimSpace(r.RemoteAddr)
	if addr == "" {
		return nil, errors.New("webhook: remote addr missing")
	}
	if host, _, err := net.SplitHostPort(addr); err == nil {
		addr = host
	}
	ip := net.ParseIP(addr)
	if ip == nil {
		return nil, errors.New("webhook: invalid remote addr")
	}
	return ip, nil
}
