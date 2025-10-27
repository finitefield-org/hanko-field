package ui

import (
	"testing"

	admincatalog "finitefield.org/hanko-admin/internal/admin/catalog"
)

func TestCatalogValuesFromDetailUsesProperties(t *testing.T) {
	detail := admincatalog.ItemDetail{
		Item: admincatalog.Item{
			Name:            "Premium Kit",
			Identifier:      "PRD-PREMIUM",
			Status:          admincatalog.StatusPublished,
			Category:        "seasonal_bundle",
			PrimaryColor:    "#FF0000",
			PreviewAssetID:  "asset-preview-001",
			PreviewFileName: "preview.png",
		},
		Description: "Seasonal bundle product.",
		Owner: admincatalog.OwnerInfo{
			Name:  "Kana Fujii",
			Email: "kana@example.com",
		},
		PreviewURL:      "https://cdn.example.com/preview.png",
		PreviewAssetID:  "asset-preview-001",
		PreviewFileName: "preview.png",
		SVGPath:         "designs/sample.svg",
		SVGAssetID:      "asset-svg-001",
		SVGFileName:     "sample.svg",
		Properties: map[string]string{
			"price":      "6200",
			"leadTime":   "3",
			"photoURLs":  "https://cdn.example.com/preview.png\nhttps://cdn.example.com/detail.png",
			"currency":   "USD",
			"productSKU": "PRD-PREMIUM-SKU",
		},
	}

	values := catalogValuesFromDetail(admincatalog.KindProducts, detail)

	if got := values["price"]; got != "6200" {
		t.Fatalf("price not rehydrated, got %q", got)
	}
	if got := values["leadTime"]; got != "3" {
		t.Fatalf("leadTime not rehydrated, got %q", got)
	}
	if got := values["photoURLs"]; got != detail.Properties["photoURLs"] {
		t.Fatalf("photoURLs not rehydrated, got %q", got)
	}
	if got := values["currency"]; got != "USD" {
		t.Fatalf("currency not rehydrated, got %q", got)
	}
	if got := values["productSKU"]; got != "PRD-PREMIUM-SKU" {
		t.Fatalf("productSKU not rehydrated, got %q", got)
	}
	if got := values["previewAssetID"]; got != "asset-preview-001" {
		t.Fatalf("previewAssetID not rehydrated, got %q", got)
	}
	if got := values["svgAssetID"]; got != "asset-svg-001" {
		t.Fatalf("svgAssetID not rehydrated, got %q", got)
	}
}

func TestCatalogValuesFromDetailFallsBackToMetrics(t *testing.T) {
	detail := admincatalog.ItemDetail{
		Item: admincatalog.Item{
			Name:       "Material Sample",
			Identifier: "MAT-SAMPLE",
			Status:     admincatalog.StatusPublished,
			Category:   "premium",
			Metrics: []admincatalog.ItemMetric{
				{Label: "在庫", Value: "4,200枚"},
			},
		},
		Metadata: []admincatalog.MetadataEntry{
			{Key: "カラー", Value: "アイボリー"},
		},
		Owner: admincatalog.OwnerInfo{Name: "Hiro", Email: "hiro@example.com"},
	}

	values := catalogValuesFromDetail(admincatalog.KindMaterials, detail)

	if got := values["inventory"]; got != "4200" {
		t.Fatalf("expected inventory digits fallback, got %q", got)
	}
	if got := values["color"]; got != "アイボリー" {
		t.Fatalf("expected color fallback, got %q", got)
	}
	if got := values["materialSKU"]; got != "MAT-SAMPLE" {
		t.Fatalf("expected identifier fallback for materialSKU, got %q", got)
	}
}
