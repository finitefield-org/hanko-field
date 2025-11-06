package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"os/signal"
	"strings"
	"syscall"

	"go.uber.org/zap"

	jobsexport "github.com/hanko-field/api/internal/jobs/export"
	"github.com/hanko-field/api/internal/jobs/runtime"
	"github.com/hanko-field/api/internal/platform/observability"
)

func main() {
	var (
		projectID      = flag.String("project", envOrDefault("JOB_PROJECT_ID", ""), "GCP project ID")
		subscriptionID = flag.String("subscription", envOrDefault("JOB_EXPORT_SUBSCRIPTION", ""), "Pub/Sub subscription ID for export jobs")
		workerName     = flag.String("worker", envOrDefault("JOB_WORKER_NAME", "export-worker"), "Worker name used for logging/metrics")
		skipCheck      = flag.Bool("skip-subscription-check", envBool("JOB_SKIP_SUBSCRIPTION_CHECK"), "Skip subscription existence validation")
	)
	flag.Parse()

	logger, err := observability.NewLogger()
	if err != nil {
		fmt.Fprintf(os.Stderr, "failed to initialise logger: %v\n", err)
		os.Exit(1)
	}
	defer func() {
		_ = logger.Sync()
	}()

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	handler := initExportHandler(ctx, logger.Named("export.handler"))
	processor := jobsexport.NewProcessor(handler, logger.Named("export.processor"))
	opts := runtime.Options{
		ProjectID:                  *projectID,
		SubscriptionID:             *subscriptionID,
		WorkerName:                 *workerName,
		Processor:                  processor,
		Logger:                     logger.Named("export.runner"),
		SkipSubscriptionValidation: *skipCheck,
	}

	if err := runtime.Run(ctx, opts); err != nil {
		logger.Fatal("export worker terminated with error", zap.Error(err))
	}
}

func envOrDefault(env, fallback string) string {
	if value := strings.TrimSpace(os.Getenv(env)); value != "" {
		return value
	}
	return fallback
}

func envBool(env string) bool {
	value := strings.TrimSpace(os.Getenv(env))
	switch strings.ToLower(value) {
	case "1", "true", "yes", "y", "on":
		return true
	default:
		return false
	}
}

func initExportHandler(ctx context.Context, logger *zap.Logger) jobsexport.Handler {
	if logger == nil {
		logger = zap.NewNop()
	}
	logger.Fatal("export worker: handler wiring not configured; ensure initExportHandler provides a real implementation before deploying")
	return nil
}
