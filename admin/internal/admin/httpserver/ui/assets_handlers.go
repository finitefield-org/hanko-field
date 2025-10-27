package ui

import (
	"encoding/json"
	"log"
	"net/http"
	"strings"
	"time"

	adminassets "finitefield.org/hanko-admin/internal/admin/assets"
	custommw "finitefield.org/hanko-admin/internal/admin/httpserver/middleware"
)

type signedUploadRequest struct {
	Purpose  string `json:"purpose"`
	Kind     string `json:"kind,omitempty"`
	MimeType string `json:"mimeType,omitempty"`
	FileName string `json:"fileName,omitempty"`
	Size     int64  `json:"size,omitempty"`
	Note     string `json:"note,omitempty"`
}

type signedUploadResponse struct {
	AssetID   string            `json:"assetId"`
	UploadURL string            `json:"uploadUrl"`
	Method    string            `json:"method"`
	Headers   map[string]string `json:"headers,omitempty"`
	ExpiresAt string            `json:"expiresAt"`
	PublicURL string            `json:"publicUrl,omitempty"`
}

// AssetsSignedUpload issues a signed upload payload for frontend asset uploads.
func (h *Handlers) AssetsSignedUpload(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	user, ok := custommw.UserFromContext(ctx)
	if !ok || user == nil {
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}

	defer r.Body.Close()
	var req signedUploadRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "無効なリクエスト形式です。", http.StatusBadRequest)
		return
	}

	purpose := strings.TrimSpace(req.Purpose)
	if purpose == "" {
		http.Error(w, "purpose を指定してください。", http.StatusBadRequest)
		return
	}

	input := adminassets.SignedUploadRequest{
		Purpose:     purpose,
		Kind:        strings.TrimSpace(req.Kind),
		MimeType:    strings.TrimSpace(req.MimeType),
		FileName:    strings.TrimSpace(req.FileName),
		Size:        req.Size,
		Description: strings.TrimSpace(req.Note),
	}

	result, err := h.assets.RequestSignedUpload(ctx, user.Token, input)
	if err != nil {
		log.Printf("assets: signed upload failed: %v", err)
		http.Error(w, "アップロードURLの取得に失敗しました。", http.StatusBadRequest)
		return
	}

	method := strings.TrimSpace(result.Method)
	if method == "" {
		method = http.MethodPut
	}

	resp := signedUploadResponse{
		AssetID:   result.AssetID,
		UploadURL: result.UploadURL,
		Method:    method,
		Headers:   result.Headers,
		ExpiresAt: result.ExpiresAt.UTC().Format(time.RFC3339),
		PublicURL: result.PublicURL,
	}

	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	if err := json.NewEncoder(w).Encode(resp); err != nil {
		log.Printf("assets: encode response failed: %v", err)
	}
}
