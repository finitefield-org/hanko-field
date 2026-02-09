package main

import (
	"strings"
	"testing"
)

func resetAdminEnv(t *testing.T) {
	t.Helper()
	keys := []string{
		"ADMIN_HTTP_ADDR",
		"HANKO_ADMIN_MODE",
		"HANKO_ADMIN_ENV",
		"HANKO_ADMIN_LOCALE",
		"HANKO_ADMIN_DEFAULT_LOCALE",
		"HANKO_ADMIN_FIREBASE_PROJECT_ID_DEV",
		"HANKO_ADMIN_FIREBASE_PROJECT_ID_PROD",
		"HANKO_ADMIN_FIREBASE_PROJECT_ID",
		"HANKO_ADMIN_FIREBASE_CREDENTIALS_FILE_DEV",
		"HANKO_ADMIN_FIREBASE_CREDENTIALS_FILE_PROD",
		"HANKO_ADMIN_FIREBASE_CREDENTIALS_FILE",
		"FIRESTORE_PROJECT_ID",
		"FIREBASE_PROJECT_ID",
		"GOOGLE_CLOUD_PROJECT",
		"GOOGLE_APPLICATION_CREDENTIALS",
	}
	for _, key := range keys {
		t.Setenv(key, "")
	}
}

func TestLoadConfig_DefaultMock(t *testing.T) {
	resetAdminEnv(t)

	cfg, err := loadConfig()
	if err != nil {
		t.Fatalf("loadConfig() error = %v", err)
	}

	if cfg.Mode != runModeMock {
		t.Fatalf("mode = %s, want %s", cfg.Mode, runModeMock)
	}
	if cfg.HTTPAddr != ":3051" {
		t.Fatalf("http addr = %s, want :3051", cfg.HTTPAddr)
	}
	if cfg.Locale != "ja" {
		t.Fatalf("locale = %s, want ja", cfg.Locale)
	}
	if cfg.DefaultLocale != "ja" {
		t.Fatalf("default locale = %s, want ja", cfg.DefaultLocale)
	}
}

func TestLoadConfig_InvalidMode(t *testing.T) {
	resetAdminEnv(t)
	t.Setenv("HANKO_ADMIN_MODE", "staging")

	_, err := loadConfig()
	if err == nil {
		t.Fatal("expected error but got nil")
	}
	if !strings.Contains(err.Error(), "invalid HANKO_ADMIN_MODE") {
		t.Fatalf("unexpected error: %v", err)
	}
}

func TestLoadConfig_DevModeRequiresProjectID(t *testing.T) {
	resetAdminEnv(t)
	t.Setenv("HANKO_ADMIN_MODE", "dev")

	_, err := loadConfig()
	if err == nil {
		t.Fatal("expected error but got nil")
	}
	if !strings.Contains(err.Error(), "requires project id") {
		t.Fatalf("unexpected error: %v", err)
	}
}

func TestLoadConfig_DevModeUsesProjectID(t *testing.T) {
	resetAdminEnv(t)
	t.Setenv("HANKO_ADMIN_MODE", "dev")
	t.Setenv("HANKO_ADMIN_FIREBASE_PROJECT_ID_DEV", "hanko-field-dev")
	t.Setenv("GOOGLE_APPLICATION_CREDENTIALS", "/tmp/dev-sa.json")

	cfg, err := loadConfig()
	if err != nil {
		t.Fatalf("loadConfig() error = %v", err)
	}

	if cfg.Mode != runModeDev {
		t.Fatalf("mode = %s, want %s", cfg.Mode, runModeDev)
	}
	if cfg.FirestoreProjectID != "hanko-field-dev" {
		t.Fatalf("project id = %s, want hanko-field-dev", cfg.FirestoreProjectID)
	}
	if cfg.CredentialsFile != "/tmp/dev-sa.json" {
		t.Fatalf("credentials file = %s, want /tmp/dev-sa.json", cfg.CredentialsFile)
	}
}
