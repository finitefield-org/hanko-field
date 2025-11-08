package handlers

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/go-chi/chi/v5"
)

func TestRequestValidationBlocksScriptQueries(t *testing.T) {
	router := NewRouter(WithPublicRoutes(func(r chi.Router) {
		r.Get("/echo", func(w http.ResponseWriter, r *http.Request) {
			w.WriteHeader(http.StatusOK)
		})
	}))

	req := httptest.NewRequest(http.MethodGet, "/api/v1/public/echo?q=<script>alert(1)</script>", nil)
	res := httptest.NewRecorder()
	router.ServeHTTP(res, req)
	if res.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for script payload, got %d", res.Code)
	}
}

func TestRequestValidationBlocksPathTraversal(t *testing.T) {
	router := NewRouter(WithPublicRoutes(func(r chi.Router) {
		r.Get("/items/{itemId}", func(w http.ResponseWriter, r *http.Request) {
			w.WriteHeader(http.StatusOK)
		})
	}))

	req := httptest.NewRequest(http.MethodGet, "/api/v1/public/items/../etc/passwd", nil)
	res := httptest.NewRecorder()
	router.ServeHTTP(res, req)
	if res.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for traversal payload, got %d", res.Code)
	}
}
