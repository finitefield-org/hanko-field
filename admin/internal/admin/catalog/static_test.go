package catalog

import (
	"context"
	"testing"
)

func TestStaticServiceFiltersByStatus(t *testing.T) {
	svc := NewStaticService()
	result, err := svc.ListAssets(context.Background(), "", ListQuery{
		Kind:     KindTemplates,
		Statuses: []Status{StatusDraft},
	})
	if err != nil {
		t.Fatalf("ListAssets returned error: %v", err)
	}
	if len(result.Items) != 1 {
		t.Fatalf("expected 1 draft template, got %d", len(result.Items))
	}
	if result.Items[0].ID != "tmpl-minimal-stamp" {
		t.Fatalf("unexpected item ID: %s", result.Items[0].ID)
	}
}

func TestStaticServiceSelectsDefaultDetail(t *testing.T) {
	svc := NewStaticService()
	result, err := svc.ListAssets(context.Background(), "", ListQuery{
		Kind: KindFonts,
	})
	if err != nil {
		t.Fatalf("ListAssets returned error: %v", err)
	}
	if result.SelectedDetail == nil {
		t.Fatal("expected default selected detail")
	}
	if result.SelectedDetail.Item.ID != result.SelectedID {
		t.Fatalf("detail/item mismatch: %s vs %s", result.SelectedDetail.Item.ID, result.SelectedID)
	}
}

func TestStaticServiceTagFiltering(t *testing.T) {
	svc := NewStaticService()
	result, err := svc.ListAssets(context.Background(), "", ListQuery{
		Kind: KindMaterials,
		Tags: []string{"metallic"},
	})
	if err != nil {
		t.Fatalf("ListAssets returned error: %v", err)
	}
	if len(result.Items) != 1 {
		t.Fatalf("expected 1 metallic material, got %d", len(result.Items))
	}
	if result.Items[0].ID != "mat-metallic-gold" {
		t.Fatalf("unexpected material ID: %s", result.Items[0].ID)
	}
}

func TestStaticServiceUpdatedRangeFiltering(t *testing.T) {
	svc := NewStaticService()
	result, err := svc.ListAssets(context.Background(), "", ListQuery{
		Kind:         KindTemplates,
		UpdatedRange: "24h",
	})
	if err != nil {
		t.Fatalf("ListAssets returned error: %v", err)
	}
	if len(result.Items) != 2 {
		t.Fatalf("expected 2 templates updated within 24h, got %d", len(result.Items))
	}
	for _, item := range result.Items {
		if item.ID == "tmpl-minimal-stamp" {
			t.Fatalf("unexpected draft template included: %s", item.ID)
		}
	}
}

func TestStaticServiceCategoryFiltering(t *testing.T) {
	svc := NewStaticService()
	result, err := svc.ListAssets(context.Background(), "", ListQuery{
		Kind:     KindTemplates,
		Category: "business",
	})
	if err != nil {
		t.Fatalf("ListAssets returned error: %v", err)
	}
	if len(result.Items) != 1 {
		t.Fatalf("expected 1 business template, got %d", len(result.Items))
	}
	if result.Items[0].ID != "tmpl-minimal-stamp" {
		t.Fatalf("unexpected template ID: %s", result.Items[0].ID)
	}
}

func TestStaticServicePagination(t *testing.T) {
	svc := NewStaticService()
	result, err := svc.ListAssets(context.Background(), "", ListQuery{
		Kind:          KindTemplates,
		Page:          2,
		PageSize:      1,
		SortKey:       "updated_at",
		SortDirection: SortDirectionDesc,
	})
	if err != nil {
		t.Fatalf("ListAssets returned error: %v", err)
	}
	if result.Pagination.Page != 2 {
		t.Fatalf("expected page 2, got %d", result.Pagination.Page)
	}
	if len(result.Items) != 1 {
		t.Fatalf("expected 1 item on page 2, got %d", len(result.Items))
	}
	if result.Items[0].ID != "tmpl-collage-story" {
		t.Fatalf("unexpected template on page 2: %s", result.Items[0].ID)
	}
}
