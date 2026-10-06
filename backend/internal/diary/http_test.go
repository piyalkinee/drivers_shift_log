package diary

import (
	"bytes"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
)

func request(t *testing.T, h http.Handler, method, path string, body []byte, status int) *httptest.ResponseRecorder {
	t.Helper()
	w := httptest.NewRecorder()
	h.ServeHTTP(w, httptest.NewRequest(method, path, bytes.NewReader(body)))
	if w.Code != status {
		t.Fatalf("%s %s: got %d want %d: %s", method, path, w.Code, status, w.Body.String())
	}
	if !strings.HasPrefix(w.Header().Get("Content-Type"), "application/json") {
		t.Fatal("response is not JSON")
	}
	return w
}
func encoded(t *testing.T, v any) []byte {
	t.Helper()
	data, err := json.Marshal(v)
	if err != nil {
		t.Fatal(err)
	}
	return data
}

func TestHTTPCreateRetryConflictAndRead(t *testing.T) {
	s := store(t)
	h := Handler(s)
	a := trip("first")
	b := trip("second")
	b.Amount = 1500
	b.Commission = 225
	b.Payment = "cash"
	for _, tc := range []struct {
		trip    Trip
		status  int
		created bool
	}{{a, 201, true}, {a, 200, false}, {b, 201, true}} {
		w := request(t, h, "POST", "/api/trips", encoded(t, tc.trip), tc.status)
		var result struct {
			Trip    Trip `json:"trip"`
			Created bool `json:"created"`
		}
		if err := json.Unmarshal(w.Body.Bytes(), &result); err != nil {
			t.Fatal(err)
		}
		if !same(result.Trip, tc.trip) || result.Created != tc.created {
			t.Fatalf("unexpected response: %+v", result)
		}
	}
	a.Amount++
	w := request(t, h, "POST", "/api/trips", encoded(t, a), 409)
	var conflict map[string]string
	if err := json.Unmarshal(w.Body.Bytes(), &conflict); err != nil || conflict["error"] == "" {
		t.Fatal("missing conflict error")
	}
	w = request(t, h, "GET", "/api/day?date=2026-10-01", nil, 200)
	var day Day
	if err := json.Unmarshal(w.Body.Bytes(), &day); err != nil {
		t.Fatal(err)
	}
	if day.Date != "2026-10-01" || day.Timezone != "Asia/Almaty" || day.Summary != (Summary{2, 3900, 585, 3315, 1500, 2400}) || len(day.Trips) != 2 {
		t.Fatalf("wrong day: %+v", day)
	}
	if day.Trips[0].Amount != 2400 {
		t.Fatal("conflict changed original data")
	}
	w = request(t, h, "GET", "/api/day?date=2026-10-03", nil, 200)
	if err := json.Unmarshal(w.Body.Bytes(), &day); err != nil {
		t.Fatal(err)
	}
	if day.Summary != (Summary{}) || day.Trips == nil || len(day.Trips) != 0 {
		t.Fatalf("empty day must contain zero summary and []: %+v", day)
	}
}
func TestHTTPRejectsInvalidRequests(t *testing.T) {
	valid := trip("t")
	negative := valid
	negative.Amount = -1
	backwards := valid
	backwards.End = backwards.Start.Add(-1)
	for _, tc := range []struct {
		name, body string
		status     int
	}{
		{"broken JSON", "{", 400}, {"unknown field", `{"unknown":1}`, 400},
		{"fractional money", `{"amount":1.5}`, 400}, {"missing values", `{}`, 422},
		{"two objects", string(encoded(t, valid)) + ` {}`, 400},
		{"negative amount", string(encoded(t, negative)), 422}, {"end before start", string(encoded(t, backwards)), 422},
		{"oversize", `{"id":"` + strings.Repeat("x", 17*1024) + `"}`, 400},
		{"timezone missing", `{"start":"2026-10-01T08:00:00"}`, 400},
	} {
		t.Run(tc.name, func(t *testing.T) {
			s := store(t)
			w := request(t, Handler(s), "POST", "/api/trips", []byte(tc.body), tc.status)
			var body map[string]string
			if err := json.Unmarshal(w.Body.Bytes(), &body); err != nil || body["error"] == "" {
				t.Fatal("missing error body")
			}
			if s.Day("2026-10-01").Summary.Count != 0 {
				t.Fatal("invalid request mutated store")
			}
		})
	}
	for _, date := range []string{"", "2026-02-30", "2026-1-01", "yesterday"} {
		request(t, Handler(store(t)), "GET", "/api/day?date="+date, nil, 400)
	}
}
func TestHTTPConcurrentRetry(t *testing.T) {
	s := store(t)
	h := Handler(s)
	body := encoded(t, trip("concurrent"))
	var created atomic.Int32
	var wg sync.WaitGroup
	for i := 0; i < 30; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			w := httptest.NewRecorder()
			h.ServeHTTP(w, httptest.NewRequest("POST", "/api/trips", bytes.NewReader(body)))
			switch w.Code {
			case 201:
				created.Add(1)
			case 200:
			default:
				t.Errorf("unexpected response: %d", w.Code)
			}
		}()
	}
	wg.Wait()
	if created.Load() != 1 || s.Day("2026-10-01").Summary.Count != 1 {
		t.Fatal("concurrent requests created duplicates")
	}
}

type failingRepository struct{}

func (failingRepository) Add(Trip) (bool, error) {
	return false, errors.New("private filesystem details")
}
func (failingRepository) Day(string) Day { return Day{} }
func TestHTTPStorageFailureAndHealth(t *testing.T) {
	h := Handler(failingRepository{})
	w := request(t, h, "POST", "/api/trips", encoded(t, trip("t")), 500)
	if strings.Contains(w.Body.String(), "private") {
		t.Fatal("internal error leaked")
	}
	w = request(t, h, "GET", "/health", nil, 200)
	if strings.TrimSpace(w.Body.String()) != `{"status":"ok"}` {
		t.Fatal(w.Body.String())
	}
	for _, tc := range []struct {
		method, path string
		code         int
	}{{"DELETE", "/api/trips", 405}, {"GET", "/missing", 404}} {
		w = httptest.NewRecorder()
		h.ServeHTTP(w, httptest.NewRequest(tc.method, tc.path, nil))
		if w.Code != tc.code {
			t.Fatal(w.Code)
		}
	}
}
