package observability

import (
	"context"
	"os"
	"strings"

	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
)

const defaultLogLevel = "info"

// loggerContextKey guards request-scoped loggers attached to a context.
type loggerContextKey struct{}

var (
	ctxLoggerKey loggerContextKey
	noopLogger   = zap.NewNop()
)

// NewLogger returns a production-ready zap logger that writes structured JSON.
func NewLogger() (*zap.Logger, error) {
	level := zap.NewAtomicLevel()
	if err := level.UnmarshalText([]byte(strings.ToLower(strings.TrimSpace(os.Getenv("LOG_LEVEL"))))); err != nil {
		_ = level.UnmarshalText([]byte(defaultLogLevel))
	}

	encoderCfg := zapcore.EncoderConfig{
		MessageKey: "message",
		TimeKey:    "timestamp",
		LevelKey:   "severity",
		EncodeTime: zapcore.RFC3339NanoTimeEncoder,
		EncodeLevel: func(level zapcore.Level, enc zapcore.PrimitiveArrayEncoder) {
			enc.AppendString(strings.ToUpper(level.String()))
		},
		CallerKey:     "caller",
		StacktraceKey: "stacktrace",
	}

	cfg := zap.Config{
		Level:             level,
		Encoding:          "json",
		EncoderConfig:     encoderCfg,
		OutputPaths:       []string{"stdout"},
		ErrorOutputPaths:  []string{"stderr"},
		DisableCaller:     false,
		DisableStacktrace: true,
	}

	return cfg.Build()
}

// WithLogger attaches the provided logger to the context.
func WithLogger(ctx context.Context, logger *zap.Logger) context.Context {
	if ctx == nil {
		ctx = context.Background()
	}
	if logger == nil {
		logger = noopLogger
	}
	return context.WithValue(ctx, ctxLoggerKey, logger)
}

// Logger retrieves the request-scoped logger from context or returns a no-op logger.
func Logger(ctx context.Context) *zap.Logger {
	if ctx == nil {
		return noopLogger
	}
	if logger, ok := ctx.Value(ctxLoggerKey).(*zap.Logger); ok && logger != nil {
		return logger
	}
	return noopLogger
}

// PrintfAdapter adapts zap to interfaces that expect fmt.Printf semantics.
type PrintfAdapter struct {
	logger *zap.SugaredLogger
}

// NewPrintfAdapter creates a PrintfAdapter backed by the supplied logger.
func NewPrintfAdapter(logger *zap.Logger) PrintfAdapter {
	if logger == nil {
		logger = noopLogger
	}
	return PrintfAdapter{logger: logger.Sugar()}
}

// Printf implements fmt.Printf-style logging for legacy interfaces.
func (a PrintfAdapter) Printf(format string, args ...any) {
	a.logger.Infof(format, args...)
}

// WithRequestFields augments the logger with well-known request metadata fields.
func WithRequestFields(logger *zap.Logger, fields ...zap.Field) *zap.Logger {
	if logger == nil {
		logger = noopLogger
	}
	return logger.With(fields...)
}
