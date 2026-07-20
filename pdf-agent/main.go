package main

import (
	"context"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"

	"github.com/joho/godotenv"
	"github.com/llpsdk/llp-go"
)

// Industries for LLM selection (kept for future use)
var Industries = []string{
	"Technology",
	"Healthcare",
	"Finance",
	"Manufacturing",
	"Retail",
	"Energy",
	"Transportation",
	"Real Estate",
	"Education",
	"Hospitality",
}

func main() {
	if err := godotenv.Load(); err != nil {
		slog.Warn("No .env file found, using environment variables")
	}

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Handle graceful shutdown
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-sigCh
		slog.Info("Shutting down...")
		cancel()
	}()

	usePlatform := os.Getenv("USE_PLATFORM") == "1"

	apiKey := os.Getenv("LLP_API_KEY")
	if apiKey == "" {
		slog.Error("LLP_API_KEY environment variable is required")
		os.Exit(1)
	}

	platformURL := os.Getenv("LLP_URL")
	if platformURL == "" {
		platformURL = "ws://localhost:4000/agent/websocket"
	}

	apiURL := os.Getenv("LLP_API_URL")
	if apiURL == "" {
		apiURL = "http://localhost:4000/api/v1"
	}
	upload := NewUpload("pdf-agent", apiKey, apiURL)

	if usePlatform {
		client, err := setupLLP(ctx, upload, apiKey, platformURL)

		if err != nil {
			slog.Error("Failed to connect", "error", err)
			os.Exit(1)
		}
		defer client.Close()

		slog.Info("PDF Agent connected and ready", "url", platformURL)
	}

	port := 8000
	srv := &http.Server{
		Addr:    fmt.Sprintf(":%v", port),
		Handler: upload,
	}
	closed := make(chan struct{})

	go waitForShutdown(ctx, srv, closed)
	slog.Info("HTTP server listening", "port", port)
	srv.ListenAndServe()
	<-closed
}

func waitForShutdown(ctx context.Context, srv *http.Server, closed chan struct{}) {
	<-ctx.Done()
	slog.Info("Shutting down HTTP server")
	srv.Shutdown(context.Background())

	close(closed)
}

func setupLLP(ctx context.Context, upload *Upload, apiKey, platformURL string) (*llp.Client, error) {

	cfg := llp.Config{
		PlatformURL: platformURL,
	}

	return llp.NewClient("pdf-agent", apiKey).
		WithConfig(cfg).
		WithLogger(slog.Default()).
		OnMessage(upload.handleMessage).
		Connect(ctx)
}
