package diary

import (
	"strings"
	"testing"
	"time"
)

func TestValidationBoundaries(t *testing.T) {
	for _, tc := range []struct {
		name   string
		change func(*Trip)
		valid  bool
	}{
		{"minimum amount", func(v *Trip) { v.Amount = 1; v.Commission = 0 }, true},
		{"maximum amount", func(v *Trip) { v.Amount = MaxAmount }, true},
		{"amount over maximum", func(v *Trip) { v.Amount = MaxAmount + 1 }, false},
		{"full commission", func(v *Trip) { v.Commission = v.Amount }, true},
		{"end before start", func(v *Trip) { v.End = v.Start.Add(-time.Second) }, false},
		{"start missing", func(v *Trip) { v.Start = time.Time{} }, false},
		{"end missing", func(v *Trip) { v.End = time.Time{} }, false},
		{"long ID", func(v *Trip) { v.ID = strings.Repeat("x", 129) }, false},
		{"maximum ID", func(v *Trip) { v.ID = strings.Repeat("x", 128) }, true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			v := trip("t")
			tc.change(&v)
			if got := v.Validate() == nil; got != tc.valid {
				t.Fatalf("valid=%v want %v", got, tc.valid)
			}
		})
	}
}
func TestSummaryLargeAmounts(t *testing.T) {
	a := trip("a")
	a.Amount = MaxAmount
	a.Commission = 0
	b := a
	b.ID = "b"
	b.Payment = "cash"
	b.Commission = MaxAmount
	got := Summarize([]Trip{a, b, a})
	want := Summary{3, 3 * MaxAmount, MaxAmount, 2 * MaxAmount, MaxAmount, 2 * MaxAmount}
	if got != want {
		t.Fatalf("got %+v want %+v", got, want)
	}
}
