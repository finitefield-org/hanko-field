package assets

import (
	"context"
	"errors"
	"fmt"
	"path/filepath"
	"strings"
	"time"
)

// Service exposes the signed URL workflow for asset uploads.
type Service interface {
	// RequestSignedUpload issues a signed upload URL for the provided asset metadata.
	RequestSignedUpload(ctx context.Context, token string, input SignedUploadRequest) (SignedUploadResponse, error)
}

// SignedUploadRequest captures metadata required before issuing a signed upload URL.
type SignedUploadRequest struct {
	Purpose     string
	Kind        string
	MimeType    string
	FileName    string
	Size        int64
	Description string
}

// SignedUploadResponse returns the signed upload URL details.
type SignedUploadResponse struct {
	AssetID   string
	UploadURL string
	Method    string
	Headers   map[string]string
	ExpiresAt time.Time
	PublicURL string
}

// NewStaticService returns a stub implementation useful during early development.
func NewStaticService(baseUploadURL, basePublicURL string) Service {
	return &staticService{
		baseUploadURL: strings.TrimRight(baseUploadURL, "/"),
		basePublicURL: strings.TrimRight(basePublicURL, "/"),
		now:           time.Now,
	}
}

type staticService struct {
	baseUploadURL string
	basePublicURL string
	now           func() time.Time
}

var (
	errPurposeMissing  = errors.New("assets: purpose is required")
	errKindMissing     = errors.New("assets: kind is required")
	errMimeTypeMissing = errors.New("assets: mime type is required")
)

// RequestSignedUpload issues a deterministic signed upload payload suitable for local development.
func (s *staticService) RequestSignedUpload(_ context.Context, _ string, input SignedUploadRequest) (SignedUploadResponse, error) {
	purpose := strings.TrimSpace(input.Purpose)
	if purpose == "" {
		return SignedUploadResponse{}, errPurposeMissing
	}
	kind := strings.TrimSpace(input.Kind)
	if kind == "" {
		if inferred := inferKind(input.MimeType, input.FileName); inferred != "" {
			kind = inferred
		} else {
			return SignedUploadResponse{}, errKindMissing
		}
	}
	mimeType := strings.TrimSpace(input.MimeType)
	if mimeType == "" {
		if inferred := inferMimeType(kind); inferred != "" {
			mimeType = inferred
		} else {
			return SignedUploadResponse{}, errMimeTypeMissing
		}
	}

	id := fmt.Sprintf("%s-%d", sanitizePrefix(purpose, "asset"), s.now().UnixNano())
	fileName := chooseFileName(input.FileName, kind)
	uploadURL := fmt.Sprintf("%s/%s/%s", s.baseUploadURL, purpose, id)
	publicURL := fmt.Sprintf("%s/%s/%s", s.basePublicURL, purpose, fileName)

	headers := map[string]string{
		"Content-Type": mimeType,
	}

	return SignedUploadResponse{
		AssetID:   id,
		UploadURL: uploadURL,
		Method:    "PUT",
		Headers:   headers,
		ExpiresAt: s.now().Add(15 * time.Minute),
		PublicURL: publicURL,
	}, nil
}

func inferKind(mimeType, fileName string) string {
	if mimeType != "" {
		if parts, _, _ := strings.Cut(mimeType, "/"); parts == "image" {
			return "png"
		}
		switch mimeType {
		case "image/svg+xml":
			return "svg"
		case "image/png":
			return "png"
		case "image/jpeg":
			return "jpg"
		case "image/webp":
			return "webp"
		}
	}
	if ext := strings.ToLower(strings.TrimPrefix(filepath.Ext(fileName), ".")); ext != "" {
		switch ext {
		case "svg":
			return "svg"
		case "png":
			return "png"
		case "jpg", "jpeg":
			return "jpg"
		case "webp":
			return "webp"
		}
	}
	return ""
}

func inferMimeType(kind string) string {
	switch strings.ToLower(kind) {
	case "svg":
		return "image/svg+xml"
	case "png":
		return "image/png"
	case "jpg", "jpeg":
		return "image/jpeg"
	case "webp":
		return "image/webp"
	default:
		return ""
	}
}

func chooseFileName(name, kind string) string {
	base := strings.TrimSpace(name)
	if base == "" {
		base = fmt.Sprintf("%s.%s", sanitizePrefix(kind, "asset"), normalizeExt(kind))
	}
	if filepath.Ext(base) == "" {
		base += "." + normalizeExt(kind)
	}
	return strings.ReplaceAll(base, " ", "_")
}

func sanitizePrefix(value, fallback string) string {
	clean := strings.Map(func(r rune) rune {
		switch {
		case r >= 'a' && r <= 'z':
			return r
		case r >= 'A' && r <= 'Z':
			return r + 32
		case r >= '0' && r <= '9':
			return r
		case r == '-', r == '_':
			return r
		default:
			return -1
		}
	}, value)
	clean = strings.Trim(clean, "-_")
	if clean == "" {
		return fallback
	}
	return clean
}

func normalizeExt(kind string) string {
	switch strings.ToLower(kind) {
	case "jpeg":
		return "jpg"
	case "jpg", "svg", "png", "webp":
		return strings.ToLower(kind)
	default:
		return "bin"
	}
}

var _ Service = (*staticService)(nil)
