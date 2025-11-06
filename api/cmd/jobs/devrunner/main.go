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

	"github.com/hanko-field/api/internal/jobs"
	"github.com/hanko-field/api/internal/jobs/ai"
	jobsexport "github.com/hanko-field/api/internal/jobs/export"
	"github.com/hanko-field/api/internal/jobs/invoice"
	"github.com/hanko-field/api/internal/jobs/runtime"
	"github.com/hanko-field/api/internal/platform/observability"
)

func main() {
	var (
		projectID      = flag.String("project", envOrDefault("JOB_PROJECT_ID", "local-project"), "GCP project ID / emulator project ID")
		subscriptionID = flag.String("subscription", envOrDefault("JOB_SUBSCRIPTION", ""), "Pub/Sub subscription ID")
		workerType     = flag.String("worker-type", envOrDefault("JOB_WORKER_TYPE", "ai"), "Worker type (ai|invoice|export)")
		workerName     = flag.String("worker", envOrDefault("JOB_WORKER_NAME", ""), "Worker name override")
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

	processor, name, err := buildProcessor(*workerType, logger)
	if err != nil {
		logger.Fatal("invalid worker configuration", zap.Error(err))
	}

	if strings.TrimSpace(*workerName) == "" {
		workerName = &name
	}

	if strings.TrimSpace(*subscriptionID) == "" {
		logger.Fatal("subscription id is required for dev runner")
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	opts := runtime.Options{
		ProjectID:                  *projectID,
		SubscriptionID:             *subscriptionID,
		WorkerName:                 *workerName,
		Processor:                  processor,
		Logger:                     logger.Named("dev.runner"),
		SkipSubscriptionValidation: *skipCheck,
	}

	if err := runtime.Run(ctx, opts); err != nil {
		logger.Fatal("dev runner terminated with error", zap.Error(err))
	}
}

func buildProcessor(workerType string, logger *zap.Logger) (jobs.Processor, string, error) {
	switch strings.ToLower(strings.TrimSpace(workerType)) {
	case "ai", "ai-worker", "aiworker":
		return ai.NewProcessor(nil, logger.Named("ai.processor")), "ai-dev-worker", nil
	case "invoice", "invoice-worker":
		return invoice.NewProcessor(nil, logger.Named("invoice.processor")), "invoice-dev-worker", nil
	case "export", "export-worker":
		return jobsexport.NewProcessor(nil, logger.Named("export.processor")), "export-dev-worker", nil
	default:
		return nil, "", fmt.Errorf("unsupported worker type %q", workerType)
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
