package diary

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"sync"
)

type Store struct {
	mu    sync.RWMutex
	path  string
	trips []Trip
}

func Open(path string) (*Store, error) {
	s := &Store{path: path, trips: []Trip{}}
	data, err := os.ReadFile(path)
	if os.IsNotExist(err) {
		return s, nil
	}
	if err != nil {
		return nil, err
	}
	if err = json.Unmarshal(data, &s.trips); err != nil {
		return nil, err
	}
	if s.trips == nil {
		return nil, fmt.Errorf("expected JSON array of trips")
	}
	ids := map[string]bool{}
	for _, t := range s.trips {
		if err = t.Validate(); err != nil {
			return nil, fmt.Errorf("trip %s: %w", t.ID, err)
		}
		if ids[t.ID] {
			return nil, fmt.Errorf("duplicate id %s", t.ID)
		}
		ids[t.ID] = true
	}
	return s, nil
}
func (s *Store) Add(t Trip) (bool, error) {
	if err := t.Validate(); err != nil {
		return false, err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	for _, old := range s.trips {
		if old.ID == t.ID {
			if same(old, t) {
				return false, nil
			}
			return false, ErrConflict
		}
	}
	next := append(append([]Trip{}, s.trips...), t)
	data, err := json.MarshalIndent(next, "", "  ")
	if err != nil {
		return false, err
	}
	if err = os.MkdirAll(filepath.Dir(s.path), 0755); err != nil {
		return false, err
	}
	f, err := os.CreateTemp(filepath.Dir(s.path), ".trips-*.json")
	if err != nil {
		return false, err
	}
	defer os.Remove(f.Name())
	if _, err = f.Write(data); err != nil {
		f.Close()
		return false, err
	}
	if err = f.Sync(); err != nil {
		f.Close()
		return false, err
	}
	if err = f.Close(); err != nil {
		return false, err
	}
	if err = os.Rename(f.Name(), s.path); err != nil {
		return false, err
	}
	s.trips = next
	return true, nil
}
func (s *Store) Day(date string) Day {
	s.mu.RLock()
	defer s.mu.RUnlock()
	trips := []Trip{}
	for _, t := range s.trips {
		if t.Start.In(Almaty).Format("2006-01-02") == date {
			trips = append(trips, t)
		}
	}
	sort.Slice(trips, func(i, j int) bool {
		if trips[i].Start.Equal(trips[j].Start) {
			return trips[i].ID < trips[j].ID
		}
		return trips[i].Start.After(trips[j].Start)
	})
	return Day{date, "Asia/Almaty", Summarize(trips), trips}
}
