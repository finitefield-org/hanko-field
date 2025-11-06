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

	"github.com/hanko-field/api/internal/jobs/ai"
	"github.com/hanko-field/api/internal/jobs/runtime"
	"github.com/hanko-field/api/internal/platform/observability"
)

func main() {
	var (
		projectID      = flag.String("project", envOrDefault("JOB_PROJECT_ID", ""), "GCP project ID")
		subscriptionID = flag.String("subscription", envOrDefault("JOB_AI_SUBSCRIPTION", ""), "Pub/Sub subscription ID for AI jobs")
		workerName     = flag.String("worker", envOrDefault("JOB_WORKER_NAME", "ai-worker"), "Worker name used for logging/metrics")
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

	executor := initAIExecutor(ctx, logger.Named("ai.executor"))
	processor := ai.NewProcessor(executor, logger.Named("ai.processor"))
	opts := runtime.Options{
		ProjectID:                  *projectID,
		SubscriptionID:             *subscriptionID,
		WorkerName:                 *workerName,
		Processor:                  processor,
		Logger:                     logger.Named("ai.runner"),
		SkipSubscriptionValidation: *skipCheck,
	}

	if err := runtime.Run(ctx, opts); err != nil {
		logger.Fatal("ai worker terminated with error", zap.Error(err))
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

func initAIExecutor(ctx context.Context, logger *zap.Logger) ai.Executor {
	if logger == nil {
		logger = zap.NewNop()
	}
	logger.Fatal("ai worker: executor wiring not configured; ensure initAIExecutor provides a real implementation before deploying")
	return nil
}
