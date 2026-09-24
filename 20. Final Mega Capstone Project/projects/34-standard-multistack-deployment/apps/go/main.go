package main

import (
    "context"
    "encoding/json"
    "log"
    "net/http"
    "os"
    "os/signal"
    "syscall"
    "time"
)

func env(key, fallback string) string {
    if value := os.Getenv(key); value != "" { return value }
    return fallback
}

func main() {
    handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        status := http.StatusOK
        body := map[string]string{"status": "ok"}
        if r.Method != "GET" {
            status, body = 405, map[string]string{"error": "method not allowed"}
            w.Header().Set("Allow", "GET")
        } else if r.URL.Path == "/api/info" {
            body = map[string]string{"service": "deployment-demo", "stack": "go",
                "version": env("APP_VERSION", "dev"), "environment": env("APP_ENV", "local")}
        } else if r.URL.Path != "/healthz" && r.URL.Path != "/readyz" {
            status, body = 404, map[string]string{"error": "not found"}
        }
        w.Header().Set("Content-Type", "application/json")
        w.WriteHeader(status)
        _ = json.NewEncoder(w).Encode(body)
        _ = json.NewEncoder(os.Stdout).Encode(map[string]any{"event": "request", "status": status, "stack": "go"})
    })
    server := &http.Server{Addr: ":" + env("PORT", "8080"), Handler: handler,
        ReadHeaderTimeout: 5*time.Second, ReadTimeout: 15*time.Second,
        WriteTimeout: 15*time.Second, IdleTimeout: 60*time.Second}
    stopped := make(chan os.Signal, 1)
    signal.Notify(stopped, syscall.SIGTERM, syscall.SIGINT)
    go func() {
        if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed { log.Fatal(err) }
    }()
    <-stopped
    ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
    defer cancel()
    if err := server.Shutdown(ctx); err != nil { log.Print(err) }
}
