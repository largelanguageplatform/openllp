package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"net/url"
	"os"
	"strings"

	"github.com/ollama/ollama/api"
)

// authTransport wraps http.RoundTripper to add Authorization header
type authTransport struct {
	base   http.RoundTripper
	apiKey string
}

func (t *authTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	req.Header.Set("Authorization", "Bearer "+t.apiKey)
	return t.base.RoundTrip(req)
}

// NewOllamaClient creates an Ollama API client with authentication
func NewOllamaClient() (*api.Client, error) {
	ollamaHost := os.Getenv("OLLAMA_HOST")
	if ollamaHost == "" {
		ollamaHost = "http://localhost:11434"
	}

	ollamaURL, err := url.Parse(ollamaHost)
	if err != nil {
		return nil, fmt.Errorf("invalid OLLAMA_HOST URL: %w", err)
	}

	apiKey := os.Getenv("OLLAMA_API_KEY")
	httpClient := &http.Client{
		Transport: &authTransport{
			base:   http.DefaultTransport,
			apiKey: apiKey,
		},
	}

	return api.NewClient(ollamaURL, httpClient), nil
}

const invoiceSystemPrompt = `You are a financial data generator. Generate realistic invoice data for freelancers.
You must pick the freelancer profession from the following list:
- Game tech artist
- Hair stylist
- Make-up artist
- Animator
- Game music composer
- Game level designer
- Video editor
- Photographer
- Graphic designer
- Web developer

IMPORTANT: Respond ONLY with a valid JSON array. No markdown, no explanation, no code blocks.

Generate 3 invoices from ONE fictional company (the seller) to 3 DIFFERENT customers (buyers).

Each invoice should have different items and amounts to make them realistic.

The JSON must match this exact schema:
[
  {
    "invoice_number": "INV-2026-001",
    "date": "January 1, 2026",
    "due_date": "January 31, 2026",
    "from": {
      "name": "Company Name",
      "address": "Full address with city, state, zip",
      "email": "contact@company.com",
      "phone": "(555) 123-4567"
    },
    "to": {
      "name": "Customer Name",
      "address": "Full address with city, state, zip",
      "email": "customer@email.com",
      "phone": "(555) 987-6543"
    },
    "items": [
      {
        "description": "Service or product description",
        "quantity": 1,
        "unit_price": 100.00,
        "amount": 100.00
      }
    ],
    "subtotal": 100.00,
    "tax_rate": 0.08,
    "tax_amount": 8.00,
    "total": 108.00,
    "notes": "Thank you for your business!",
    "payment_terms": "Net 30"
  }
]

Requirements:
- Use the SAME "from" company for all 3 invoices
- Use DIFFERENT "to" customers for each invoice
- Make company names, addresses, and items realistic (consulting, software, design, etc.)
- Ensure math is correct: amount = quantity * unit_price, subtotal = sum of amounts, tax_amount = subtotal * tax_rate, total = subtotal + tax_amount
- Each invoice should have 2-5 line items
- Invoice numbers should be sequential (INV-2026-001, INV-2026-002, INV-2026-003)

Return ONLY the JSON array, nothing else.`

// GenerateInvoices calls Ollama to generate 3 sample invoices
func GenerateInvoices(ctx context.Context, client *api.Client) ([]Invoice, error) {
	model := os.Getenv("OLLAMA_MODEL")
	if model == "" {
		model = "hf.co/Qwen/Qwen3-4B-GGUF:latest"
	}

	slog.Info("Generating invoices", "model", model)

	messages := []api.Message{
		{
			Role:    "system",
			Content: invoiceSystemPrompt,
		},
		{
			Role:    "user",
			Content: "Generate 3 realistic invoices now.",
		},
	}

	var resp api.ChatResponse
	stream := false
	err := client.Chat(ctx, &api.ChatRequest{
		Model:    model,
		Messages: messages,
		Stream:   &stream,
	}, func(r api.ChatResponse) error {
		if r.Done {
			resp = r
		}
		return nil
	})
	if err != nil {
		return nil, fmt.Errorf("ollama chat failed: %w", err)
	}

	slog.Info("Ollama response", "response", resp.Message.Content)

	content := strings.TrimSpace(resp.Message.Content)

	// Strip markdown code blocks if present
	content = strings.TrimPrefix(content, "```json")
	content = strings.TrimPrefix(content, "```")
	content = strings.TrimSuffix(content, "```")
	content = strings.TrimSpace(content)

	var invoices []Invoice
	if err := json.Unmarshal([]byte(content), &invoices); err != nil {
		return nil, fmt.Errorf("failed to parse invoice JSON: %w\nRaw response:\n%s", err, content)
	}

	if len(invoices) == 0 {
		return nil, fmt.Errorf("no invoices generated")
	}

	return invoices, nil
}
