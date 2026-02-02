package ui

import (
	"fmt"
	"net/http"
	"strings"
	"unicode/utf16"
)

func setHXTrigger(w http.ResponseWriter, payload string) {
	w.Header().Set("HX-Trigger", asciiHeaderValue(payload))
}

func asciiHeaderValue(value string) string {
	if value == "" {
		return value
	}

	var builder strings.Builder
	builder.Grow(len(value))
	for _, r := range value {
		if r <= 0x7f {
			builder.WriteByte(byte(r))
			continue
		}
		if r <= 0xffff {
			builder.WriteString(fmt.Sprintf("\\u%04x", r))
			continue
		}
		for _, encoded := range utf16.Encode([]rune{r}) {
			builder.WriteString(fmt.Sprintf("\\u%04x", encoded))
		}
	}
	return builder.String()
}
