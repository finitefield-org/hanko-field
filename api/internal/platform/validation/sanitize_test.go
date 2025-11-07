package validation

import (
	"net/url"
	"testing"
)

func TestDetectInjectionScript(t *testing.T) {
	if err := DetectInjection("<script>alert('x')</script>"); err != ErrScriptInjection {
		t.Fatalf("expected ErrScriptInjection, got %v", err)
	}
}

func TestSanitizeFileNameRejectsTraversal(t *testing.T) {
	if _, err := SanitizeFileName("../etc/passwd", 0); err != ErrPathTraversal {
		t.Fatalf("expected ErrPathTraversal, got %v", err)
	}
}

func TestValidateSearchQueryRejectsSQL(t *testing.T) {
	_, err := ValidateSearchQuery("' OR 1=1 --", 64)
	if err == nil {
		t.Fatalf("expected error, got nil")
	}
	if err != ErrSQLInjection {
		t.Fatalf("expected ErrSQLInjection, got %v", err)
	}
}

func TestSanitizeQueryValuesRejectsScript(t *testing.T) {
	values := url.Values{"q": []string{" <script>alert(1)</script> "}}
	if _, err := SanitizeQueryValues(values, 32); err == nil {
		t.Fatalf("expected error for script query")
	}
}
