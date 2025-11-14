package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strings"

	mw "finitefield.org/hanko-web/internal/middleware"
	"github.com/go-chi/chi/v5"
)

// DesignDuplicateHandler simulates server-side duplication to support interaction demos.
func DesignDuplicateHandler(w http.ResponseWriter, r *http.Request) {
	lang := mw.Lang(r)
	designID := strings.TrimSpace(chi.URLParam(r, "designID"))
	normalized, ok := normalizeDesignID(designID)
	if !ok {
		http.Error(w, "invalid design id", http.StatusBadRequest)
		return
	}
	payload := map[string]any{
		"library:design-duplicated": map[string]any{
			"id":      normalized,
			"message": libraryDuplicateSuccess(lang),
		},
	}
	if raw, err := json.Marshal(payload); err == nil {
		w.Header().Set("HX-Trigger", string(raw))
	}
	w.WriteHeader(http.StatusAccepted)
}

// DesignExportHandler simulates export action completion.
func DesignExportHandler(w http.ResponseWriter, r *http.Request) {
	lang := mw.Lang(r)
	designID := strings.TrimSpace(chi.URLParam(r, "designID"))
	normalized, ok := normalizeDesignID(designID)
	if !ok {
		http.Error(w, "invalid design id", http.StatusBadRequest)
		return
	}
	payload := map[string]any{
		"library:design-exported": map[string]any{
			"id":      normalized,
			"message": libraryExportSuccess(lang),
		},
	}
	if raw, err := json.Marshal(payload); err == nil {
		w.Header().Set("HX-Trigger", string(raw))
	}
	w.WriteHeader(http.StatusAccepted)
}

// DesignBulkExportHandler responds to bulk export interaction.
func DesignBulkExportHandler(w http.ResponseWriter, r *http.Request) {
	lang := mw.Lang(r)
	if err := r.ParseForm(); err != nil {
		http.Error(w, "invalid form", http.StatusBadRequest)
		return
	}
	selected := parseAccountLibrarySelected(r.PostForm["sel"])
	payload := map[string]any{
		"library:bulk-export": map[string]any{
			"count":   len(selected),
			"message": libraryBulkExportSuccess(lang, len(selected)),
		},
	}
	if raw, err := json.Marshal(payload); err == nil {
		w.Header().Set("HX-Trigger", string(raw))
	}
	w.WriteHeader(http.StatusAccepted)
}

// DesignBulkShareHandler responds to bulk share interaction.
func DesignBulkShareHandler(w http.ResponseWriter, r *http.Request) {
	lang := mw.Lang(r)
	if err := r.ParseForm(); err != nil {
		http.Error(w, "invalid form", http.StatusBadRequest)
		return
	}
	selected := parseAccountLibrarySelected(r.PostForm["sel"])
	payload := map[string]any{
		"library:bulk-share": map[string]any{
			"count":   len(selected),
			"message": libraryBulkShareSuccess(lang, len(selected)),
		},
	}
	if raw, err := json.Marshal(payload); err == nil {
		w.Header().Set("HX-Trigger", string(raw))
	}
	w.WriteHeader(http.StatusAccepted)
}

// DesignBulkDeleteHandler responds to bulk delete interaction.
func DesignBulkDeleteHandler(w http.ResponseWriter, r *http.Request) {
	lang := mw.Lang(r)
	if err := r.ParseForm(); err != nil {
		http.Error(w, "invalid form", http.StatusBadRequest)
		return
	}
	selected := parseAccountLibrarySelected(r.PostForm["sel"])
	payload := map[string]any{
		"library:bulk-delete": map[string]any{
			"count":   len(selected),
			"message": libraryBulkDeleteSuccess(lang, len(selected)),
		},
	}
	if raw, err := json.Marshal(payload); err == nil {
		w.Header().Set("HX-Trigger", string(raw))
	}
	w.WriteHeader(http.StatusAccepted)
}

func libraryDuplicateSuccess(lang string) string {
	if lang == "ja" {
		return "デザインを複製しました"
	}
	return "Design duplicated"
}

func libraryExportSuccess(lang string) string {
	if lang == "ja" {
		return "エクスポートを開始しました"
	}
	return "Export queued"
}

func libraryBulkExportSuccess(lang string, count int) string {
	if lang == "ja" {
		return fmt.Sprintf("%d件のエクスポートを準備しました", count)
	}
	return fmt.Sprintf("Queued export for %d designs", count)
}

func libraryBulkShareSuccess(lang string, count int) string {
	if lang == "ja" {
		return fmt.Sprintf("%d件の共有パックを作成しました", count)
	}
	return fmt.Sprintf("Prepared share pack for %d designs", count)
}

func libraryBulkDeleteSuccess(lang string, count int) string {
	if lang == "ja" {
		return fmt.Sprintf("%d件のデザインを削除しました (ダミー)", count)
	}
	return fmt.Sprintf("Deleted %d designs (demo)", count)
}
