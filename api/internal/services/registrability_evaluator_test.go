package services

import (
	"context"
	"testing"
	"time"
)

func TestNewHeuristicRegistrabilityEvaluatorDefaultsClock(t *testing.T) {
	evaluator := NewHeuristicRegistrabilityEvaluator(nil)
	if evaluator == nil {
		t.Fatalf("expected evaluator instance")
	}

	assessment, err := evaluator.Check(context.Background(), RegistrabilityCheckPayload{Name: "Sato"})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !assessment.Passed {
		t.Fatalf("expected assessment to pass by default")
	}
	if assessment.ExpiresAt == nil {
		t.Fatalf("expected expiry timestamp to be set")
	}
}

func TestHeuristicRegistrabilityEvaluatorDisallowedSymbols(t *testing.T) {
	now := time.Date(2024, 10, 1, 9, 30, 0, 0, time.UTC)
	evaluator := NewHeuristicRegistrabilityEvaluator(func() time.Time { return now })

	payload := RegistrabilityCheckPayload{
		Name:      "  !  ",
		TextLines: []string{"Line1", "Line2"},
	}

	assessment, err := evaluator.Check(context.Background(), payload)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if assessment.Passed {
		t.Fatalf("expected assessment to fail")
	}
	if assessment.Status != "fail" {
		t.Fatalf("expected fail status, got %s", assessment.Status)
	}
	if score := assessment.Score; score == nil || *score >= 1 {
		t.Fatalf("expected score penalty, got %+v", score)
	}
	if len(assessment.Reasons) == 0 {
		t.Fatalf("expected failure reasons to be populated")
	}
	if assessment.ExpiresAt == nil {
		t.Fatalf("expected expiry timestamp")
	} else if !assessment.ExpiresAt.Equal(now.Add(12 * time.Hour)) {
		t.Fatalf("expected expiry 12h from now, got %s", assessment.ExpiresAt)
	}

	metadata := assessment.Metadata
	lines, ok := metadata["lines"].([]string)
	if !ok {
		t.Fatalf("expected lines metadata to be []string, got %T", metadata["lines"])
	}
	if len(lines) != 2 || lines[0] != "Line1" || lines[1] != "Line2" {
		t.Fatalf("unexpected metadata lines: %+v", lines)
	}
	if metadata["disallowedCharacters"] != 1 {
		t.Fatalf("expected 1 disallowed character, got %v", metadata["disallowedCharacters"])
	}
	if metadata["nameLength"] != 1 {
		t.Fatalf("expected trimmed length 1, got %v", metadata["nameLength"])
	}
	if metadata["method"] != "heuristic" {
		t.Fatalf("expected heuristic method metadata")
	}
}

func TestHeuristicRegistrabilityEvaluatorBlankLinesDowngradeStatus(t *testing.T) {
	evaluator := NewHeuristicRegistrabilityEvaluator(func() time.Time { return time.Unix(0, 0) })

	payload := RegistrabilityCheckPayload{
		Name:      "Valid",
		TextLines: []string{"Line1", "   ", "Line2"},
	}

	assessment, err := evaluator.Check(context.Background(), payload)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if assessment.Status != "review" {
		t.Fatalf("expected review status due to blank lines, got %s", assessment.Status)
	}
	if assessment.Passed {
		t.Fatalf("expected assessment to fail due to blank lines")
	}
	if len(assessment.Reasons) == 0 {
		t.Fatalf("expected reasons to include blank line warning")
	}

	lines, _ := assessment.Metadata["lines"].([]string)
	if len(lines) != 2 {
		t.Fatalf("expected trimmed lines, got %+v", lines)
	}
}

func TestHeuristicRegistrabilityEvaluatorShortAndLongNames(t *testing.T) {
	now := time.Date(2024, 10, 1, 10, 0, 0, 0, time.UTC)
	evaluator := NewHeuristicRegistrabilityEvaluator(func() time.Time { return now })

	cases := []struct {
		name     string
		payload  RegistrabilityCheckPayload
		expected string
	}{
		{
			name:     "too short",
			payload:  RegistrabilityCheckPayload{Name: "A"},
			expected: "review",
		},
		{
			name: "too long",
			payload: RegistrabilityCheckPayload{
				Name: "VeryLongFamilyName",
			},
			expected: "review",
		},
	}

	for _, tc := range cases {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			assessment, err := evaluator.Check(context.Background(), tc.payload)
			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}
			if assessment.Status != tc.expected {
				t.Fatalf("expected status %s, got %s", tc.expected, assessment.Status)
			}
			if assessment.Passed {
				t.Fatalf("expected failure for case %s", tc.name)
			}
			if assessment.Score == nil || *assessment.Score >= 1 {
				t.Fatalf("expected reduced score for case %s", tc.name)
			}
		})
	}
}

func TestHeuristicRegistrabilityEvaluatorInvalidInput(t *testing.T) {
	evaluator := NewHeuristicRegistrabilityEvaluator(time.Now)
	if _, err := evaluator.Check(context.Background(), RegistrabilityCheckPayload{}); err != ErrRegistrabilityInvalidInput {
		t.Fatalf("expected invalid input error, got %v", err)
	}
}
