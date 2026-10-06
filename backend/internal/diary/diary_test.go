package diary

import (
	"path/filepath"
	"sync"
	"testing"
	"time"
)

func trip(id string) Trip {
	start, _ := time.Parse(time.RFC3339, "2026-10-01T08:10:00+05:00")
	return Trip{id, start, start.Add(22 * time.Minute), 2400, "card", 360}
}
func store(t *testing.T) *Store {
	t.Helper()
	s, e := Open(filepath.Join(t.TempDir(), "trips.json"))
	if e != nil {
		t.Fatal(e)
	}
	return s
}
func TestSummary(t *testing.T) {
	a := trip("t1")
	b := trip("t2")
	b.Amount = 1500
	b.Commission = 225
	b.Payment = "cash"
	got := Summarize([]Trip{a, b})
	want := Summary{2, 3900, 585, 3315, 1500, 2400}
	if got != want {
		t.Fatalf("got %+v want %+v", got, want)
	}
	if Summarize(nil) != (Summary{}) {
		t.Fatal("empty summary")
	}
}
func TestConcurrentDuplicateAndRestart(t *testing.T) {
	s := store(t)
	var wg sync.WaitGroup
	for i := 0; i < 20; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			if _, e := s.Add(trip("t1")); e != nil {
				t.Error(e)
			}
		}()
	}
	wg.Wait()
	reloaded, e := Open(s.path)
	if e != nil {
		t.Fatal(e)
	}
	if reloaded.Day("2026-10-01").Summary.Count != 1 {
		t.Fatal("duplicate persisted")
	}
	v := trip("t1")
	v.Amount++
	if _, e = reloaded.Add(v); e != ErrConflict {
		t.Fatalf("want conflict: %v", e)
	}
}
func TestDayTimezone(t *testing.T) {
	s := store(t)
	v := trip("night")
	v.Start, _ = time.Parse(time.RFC3339, "2026-10-01T20:00:00Z")
	v.End = v.Start.Add(time.Hour)
	if _, e := s.Add(v); e != nil {
		t.Fatal(e)
	}
	if s.Day("2026-10-02").Summary.Count != 1 || s.Day("2026-10-01").Summary.Count != 0 {
		t.Fatal("wrong local day")
	}
}
func TestValidation(t *testing.T) {
	for _, change := range []func(*Trip){func(v *Trip) { v.Amount = 0 }, func(v *Trip) { v.Amount = -1 }, func(v *Trip) { v.End = v.Start }, func(v *Trip) { v.Commission = -1 }, func(v *Trip) { v.Commission = v.Amount + 1 }, func(v *Trip) { v.Payment = "crypto" }, func(v *Trip) { v.ID = " " }} {
		v := trip("t")
		change(&v)
		if v.Validate() == nil {
			t.Errorf("accepted %+v", v)
		}
	}
}
func TestEquivalentTimezoneRetry(t *testing.T) {
	s := store(t)
	a := trip("same")
	if _, err := s.Add(a); err != nil {
		t.Fatal(err)
	}
	a.Start = a.Start.UTC()
	a.End = a.End.UTC()
	created, err := s.Add(a)
	if err != nil || created {
		t.Fatalf("equivalent instants should be a retry: %v", err)
	}
}
func TestWriteFailureDoesNotChangeMemory(t *testing.T) {
	s := store(t)
	// A directory cannot be replaced with a regular file by rename.
	s.path = t.TempDir()
	if _, err := s.Add(trip("fail")); err == nil {
		t.Fatal("expected write error")
	}
	if s.Day("2026-10-01").Summary.Count != 0 {
		t.Fatal("failed write changed memory")
	}
}
