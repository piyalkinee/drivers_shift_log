package diary

import (
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"time"
)

func write(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}
func failure(w http.ResponseWriter, status int, message string) {
	write(w, status, map[string]string{"error": message})
}

type Repository interface {
	Add(Trip) (bool, error)
	Day(string) Day
}

func Handler(s Repository) http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", func(w http.ResponseWriter, r *http.Request) { write(w, 200, map[string]string{"status": "ok"}) })
	mux.HandleFunc("GET /api/day", func(w http.ResponseWriter, r *http.Request) {
		date := r.URL.Query().Get("date")
		if _, err := time.Parse("2006-01-02", date); err != nil {
			failure(w, 400, "date должен быть в формате YYYY-MM-DD")
			return
		}
		write(w, 200, s.Day(date))
	})
	mux.HandleFunc("POST /api/trips", func(w http.ResponseWriter, r *http.Request) {
		r.Body = http.MaxBytesReader(w, r.Body, 16*1024)
		dec := json.NewDecoder(r.Body)
		dec.DisallowUnknownFields()
		var t Trip
		if err := dec.Decode(&t); err != nil {
			failure(w, 400, "некорректный JSON поездки")
			return
		}
		if err := dec.Decode(new(any)); err != io.EOF {
			failure(w, 400, "ожидается один JSON объект")
			return
		}
		if err := t.Validate(); err != nil {
			failure(w, 422, err.Error())
			return
		}
		created, err := s.Add(t)
		if errors.Is(err, ErrConflict) {
			failure(w, 409, err.Error())
			return
		}
		if err != nil {
			failure(w, 500, "не удалось сохранить поездку")
			return
		}
		status := 200
		if created {
			status = 201
		}
		write(w, status, map[string]any{"trip": t, "created": created})
	})
	return mux
}
