package telemetry

import (
	"crypto/sha256"
	"encoding/hex"
	"log/slog"
	"os"
	"strings"
	"sync"
)

var (
	loggerInit sync.Once
	loggerMu   sync.RWMutex
	baseLogger *slog.Logger
)

// Logger returns the process-wide structured logger, initialising it on first use.
func Logger() *slog.Logger {
	loggerInit.Do(initLogger)
	loggerMu.RLock()
	defer loggerMu.RUnlock()
	return baseLogger
}

// SetLogger allows tests to override the process logger.
func SetLogger(l *slog.Logger) {
	if l == nil {
		return
	}
	loggerInit.Do(initLogger)
	loggerMu.Lock()
	baseLogger = l
	loggerMu.Unlock()
}

func initLogger() {
	level := slog.LevelInfo
	if raw := strings.TrimSpace(os.Getenv("HANKO_LOG_LEVEL")); raw != "" {
		switch strings.ToLower(raw) {
		case "debug":
			level = slog.LevelDebug
		case "warn", "warning":
			level = slog.LevelWarn
		case "error":
			level = slog.LevelError
		case "info":
			level = slog.LevelInfo
		}
	}
	handler := slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: level,
	})
	loggerMu.Lock()
	baseLogger = slog.New(handler)
	loggerMu.Unlock()
}

// With returns a logger augmented with the supplied attributes.
func With(attrs ...any) *slog.Logger {
	return Logger().With(attrs...)
}

// HashUserID produces a deterministic, anonymised hash for a user identifier.
// Only the first 8 bytes of the SHA-256 digest are exposed to keep logs compact.
func HashUserID(id string) string {
	if id == "" {
		return ""
	}
	sum := sha256.Sum256([]byte(id))
	return hex.EncodeToString(sum[:8])
}
