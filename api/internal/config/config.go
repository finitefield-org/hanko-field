package config

import (
	"errors"
	"fmt"
	"os"
	"strings"
)

const defaultPort = "3050"

type Config struct {
	Addr                string
	FirestoreProjectID  string
	StorageAssetsBucket string
	StripeWebhookSecret string
}

func Load() (Config, error) {
	port := strings.TrimSpace(os.Getenv("API_SERVER_PORT"))
	if port == "" {
		port = strings.TrimSpace(os.Getenv("PORT"))
	}
	if port == "" {
		port = defaultPort
	}

	projectID := firstNonEmpty(
		os.Getenv("API_FIRESTORE_PROJECT_ID"),
		os.Getenv("FIRESTORE_PROJECT_ID"),
		os.Getenv("API_FIREBASE_PROJECT_ID"),
		os.Getenv("FIREBASE_PROJECT_ID"),
		os.Getenv("GOOGLE_CLOUD_PROJECT"),
	)
	if projectID == "" {
		return Config{}, errors.New("missing Firestore project id: set API_FIRESTORE_PROJECT_ID or FIRESTORE_PROJECT_ID")
	}

	assetsBucket := firstNonEmpty(os.Getenv("API_STORAGE_ASSETS_BUCKET"), "local-assets")

	cfg := Config{
		Addr:                fmt.Sprintf(":%s", port),
		FirestoreProjectID:  projectID,
		StorageAssetsBucket: assetsBucket,
		StripeWebhookSecret: strings.TrimSpace(os.Getenv("API_PSP_STRIPE_WEBHOOK_SECRET")),
	}

	return cfg, nil
}

func firstNonEmpty(values ...string) string {
	for _, v := range values {
		trimmed := strings.TrimSpace(v)
		if trimmed != "" {
			return trimmed
		}
	}
	return ""
}
