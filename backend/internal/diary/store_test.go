package diary

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestOpenRejectsInvalidFiles(t *testing.T) {
	a := trip("same")
	for _, tc := range []struct {
		name string
		data []byte
	}{
		{"malformed", []byte("[")}, {"null", []byte("null")}, {"invalid trip", []byte(`[{"id":"bad"}]`)},
		{"duplicate IDs", encoded(t, []Trip{a, a})},
	} {
		t.Run(tc.name, func(t *testing.T) {
			path := filepath.Join(t.TempDir(), "trips.json")
			if err := os.WriteFile(path, tc.data, 0600); err != nil {
				t.Fatal(err)
			}
			if _, err := Open(path); err == nil {
				t.Fatal("accepted invalid file")
			}
		})
	}
	if _, err := Open(t.TempDir()); err == nil {
		t.Fatal("accepted directory")
	}
}
func TestDaySortBoundaryAndIsolation(t *testing.T) {
	s := store(t)
	for _, tc := range []struct{ id, start string }{{"before", "2026-09-30T18:59:59Z"}, {"a", "2026-09-30T19:00:00Z"}, {"b", "2026-09-30T19:00:00Z"}, {"last", "2026-10-01T18:59:59Z"}, {"after", "2026-10-01T19:00:00Z"}} {
		v := trip(tc.id)
		v.Start, _ = time.Parse(time.RFC3339, tc.start)
		v.End = v.Start.Add(time.Hour)
		if _, err := s.Add(v); err != nil {
			t.Fatal(err)
		}
	}
	day := s.Day("2026-10-01")
	if len(day.Trips) != 3 {
		t.Fatalf("wrong count %d", len(day.Trips))
	}
	for i, id := range []string{"last", "a", "b"} {
		if day.Trips[i].ID != id {
			t.Fatal("wrong order")
		}
	}
	day.Trips[0].Amount = 1
	if s.Day("2026-10-01").Trips[0].Amount != 2400 {
		t.Fatal("caller mutated stored trip")
	}
}
func TestDistinctIDsAndInvalidAdd(t *testing.T) {
	s := store(t)
	for _, id := range []string{"first", "second"} {
		if created, err := s.Add(trip(id)); err != nil || !created {
			t.Fatal("distinct IDs must be independent trips")
		}
	}
	invalid := trip("bad")
	invalid.Amount = 0
	if _, err := s.Add(invalid); err == nil {
		t.Fatal("invalid add accepted")
	}
	if s.Day("2026-10-01").Summary.Count != 2 {
		t.Fatal("wrong count")
	}
}

func TestDeliveredExamples(t *testing.T) {
	s, err := Open("../../testdata/trips.json")
	if err != nil {
		t.Fatal(err)
	}
	if got := s.Day("2026-10-01").Summary; got != (Summary{2, 3900, 585, 3315, 1500, 2400}) {
		t.Fatalf("unexpected assignment example: %+v", got)
	}
	if got := s.Day("2026-10-02").Summary; got != (Summary{3, 9100, 1365, 7735, 1800, 7300}) {
		t.Fatalf("unexpected second example day: %+v", got)
	}
}
