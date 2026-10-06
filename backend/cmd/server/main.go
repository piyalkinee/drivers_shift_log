package main

import (
	"context"
	"drivers_shift_log/internal/diary"
	"errors"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"
)

func main() {
	path := os.Getenv("DATA_FILE")
	if path == "" {
		path = "data/trips.json"
	}
	addr := os.Getenv("ADDR")
	if addr == "" {
		addr = ":8080"
	}
	store, err := diary.Open(path)
	if err != nil {
		log.Fatal(err)
	}
	server := &http.Server{Addr: addr, Handler: diary.Handler(store), ReadHeaderTimeout: 5 * time.Second, ReadTimeout: 10 * time.Second, WriteTimeout: 10 * time.Second, IdleTimeout: 60 * time.Second}
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	errorsCh := make(chan error, 1)
	go func() { errorsCh <- server.ListenAndServe() }()
	log.Printf("Shift Log API listening on %s", addr)
	select {
	case err = <-errorsCh:
		if !errors.Is(err, http.ErrServerClosed) {
			log.Fatal(err)
		}
	case <-ctx.Done():
		shutdown, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		// Wait for active requests before exiting the process.
		if err = server.Shutdown(shutdown); err != nil {
			_ = server.Close()
			log.Printf("shutdown: %v", err)
		}
	}
}
