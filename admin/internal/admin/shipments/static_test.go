package shipments

import (
	"context"
	"testing"
)

func TestStaticListBatchesCarrierLabelFilter(t *testing.T) {
	t.Parallel()

	svc := NewStaticService()

	result, err := svc.ListBatches(context.Background(), "", ListQuery{Carrier: "ヤマト運輸"})
	if err != nil {
		t.Fatalf("ListBatches error: %v", err)
	}
	if len(result.Batches) == 0 {
		t.Fatalf("expected batches for carrier label")
	}
	for _, batch := range result.Batches {
		if batch.Carrier != "yamato" {
			t.Fatalf("unexpected carrier %q", batch.Carrier)
		}
	}
}
