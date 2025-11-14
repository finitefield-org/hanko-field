package middleware

import (
	"fmt"
	"net/http"
	"runtime/debug"
)

// PanicHandler renders a response after a recovered panic.
type PanicHandler func(http.ResponseWriter, *http.Request, error)

// Recoverer wraps the next handler with panic recovery and delegates to the provided handler.
func Recoverer(handler PanicHandler) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			defer func() {
				if rec := recover(); rec != nil {
					var err error
					switch e := rec.(type) {
					case error:
						err = e
					default:
						err = fmt.Errorf("%v", e)
					}
					stack := debug.Stack()
					ContextLogger(r.Context()).Error("panic recovered", "error", err, "stack", string(stack))
					w.Header().Set("Connection", "close")
					if handler != nil {
						handler(w, r, err)
						return
					}
					http.Error(w, http.StatusText(http.StatusInternalServerError), http.StatusInternalServerError)
				}
			}()
			next.ServeHTTP(w, r)
		})
	}
}
