package main

import (
	"context"
	"errors"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"hanko-field/api/internal/config"
	"hanko-field/api/internal/httpapi"
	"hanko-field/api/internal/store"
)

func main() {
	ctx := context.Background()

	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("failed to load config: %v", err)
	}

	dataStore, err := store.NewFirestoreStore(ctx, cfg.FirestoreProjectID)
	if err != nil {
		log.Fatalf("failed to initialize Firestore store: %v", err)
	}
	defer func() {
		if err := dataStore.Close(); err != nil {
			log.Printf("failed to close Firestore client: %v", err)
		}
	}()

	httpServer := &http.Server{
		Addr: cfg.Addr,
		Handler: httpapi.New(dataStore, httpapi.Options{
			StorageAssetsBucket: cfg.StorageAssetsBucket,
			StripeWebhookSecret: cfg.StripeWebhookSecret,
			Logger:              log.Default(),
		}).Handler(),
		ReadHeaderTimeout: 5 * time.Second,
	}

	go func() {
		log.Printf("hanko api listening on http://localhost%s", cfg.Addr)
		if err := httpServer.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatalf("server error: %v", err)
		}
	}()

	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, os.Interrupt, syscall.SIGTERM)
	<-sigCh

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := httpServer.Shutdown(shutdownCtx); err != nil {
		log.Printf("failed to shutdown server: %v", err)
	}
}
