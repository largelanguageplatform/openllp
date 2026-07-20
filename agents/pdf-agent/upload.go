package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/llpsdk/llp-go"
)

type Upload struct {
	apiURL    string
	apiKey    string
	agentName string
	server    *http.ServeMux
}

func NewUpload(agentName, apiKey, apiURL string) *Upload {
	mux := http.NewServeMux()
	u := &Upload{
		apiURL:    apiURL,
		apiKey:    apiKey,
		agentName: agentName,
		server:    mux,
	}
	u.server.HandleFunc("GET /", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	})
	u.server.HandleFunc("POST /invoice", u.handleInvoice)
	u.server.HandleFunc("POST /w2", u.handleW2)
	u.server.HandleFunc("POST /receipt", u.handleReceipt)
	u.server.HandleFunc("POST /1099-nec", u.handleNEC1099)
	u.server.HandleFunc("POST /bank-statement", u.handleBankStatement)
	return u
}

type AttachmentJSON struct {
	Filename string `json:"filename"`
}

type AttachmentResponseJSON struct {
	SignedURL string `json:"signed_url"`
}

func (u *Upload) getSignedURL(ctx context.Context, filename string) (string, error) {
	url, err := url.Parse(u.apiURL)
	if err != nil {
		return "", err
	}
	apiUrl := url.JoinPath("attachment")

	attachment, _ := json.Marshal(AttachmentJSON{Filename: filename})
	req, err := http.NewRequestWithContext(ctx, "POST", apiUrl.String(), bytes.NewReader(attachment))
	if err != nil {
		return "", err
	}

	req.Header.Add("content-type", "application/json")
	req.Header.Add("authorization", "Bearer "+u.apiKey)
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return "", err
	}

	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		if resp.StatusCode >= 400 && resp.StatusCode <= 499 {
			slog.Error("Attachment endpoint client error", "request", req)
		}
		return "", fmt.Errorf("attachment endpoint: %v", resp)
	}

	var jsonResponse AttachmentResponseJSON
	err = json.NewDecoder(resp.Body).Decode(&jsonResponse)
	if err != nil {
		return "", err
	}

	return jsonResponse.SignedURL, nil
}

func (u *Upload) doUpload(ctx context.Context, signedURL string, content io.Reader) error {
	req, err := http.NewRequestWithContext(ctx, "PUT", signedURL, content)
	if err != nil {
		return err
	}
	req.Header.Add("content-type", "application/pdf")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return err
	}

	if resp.StatusCode >= 300 && resp.StatusCode < 200 {
		return fmt.Errorf("upload: %v", resp)
	}

	return nil
}

func (u *Upload) handleMessage(ctx context.Context, msg llp.TextMessage) (llp.TextMessage, error) {
	slog.Info("Received message", "id", msg.ID, "from", msg.Sender, "prompt", msg.Prompt)

	// Create Ollama client
	ollamaClient, err := NewOllamaClient()
	if err != nil {
		slog.Error("Failed to create Ollama client", "error", err)
		return msg.Reply(fmt.Sprintf("Error: Failed to initialize LLM: %v", err)), nil
	}

	// Generate invoices via LLM
	invoices, err := GenerateInvoices(ctx, ollamaClient)
	if err != nil {
		slog.Error("Failed to generate invoices", "error", err)
		return msg.Reply(fmt.Sprintf("Error generating invoices: %v", err)), nil
	}

	if len(invoices) == 0 {
		return msg.Reply("No invoices generated"), nil
	}

	// Generate PDF in memory
	invoice := invoices[0]
	filename, err := u.uploadInvoice(ctx, invoice)
	if err != nil {
		return msg.Reply(fmt.Sprintf("Error uploading invoice: %v", err)), nil
	}

	url, _ := url.Parse(u.apiURL)
	location := url.JoinPath("attachment", filename).String()
	return msg.Reply(fmt.Sprintf("Invoice file uploaded to: %v", location)), nil
}

func (u *Upload) handleInvoice(w http.ResponseWriter, r *http.Request) {
	defer r.Body.Close()
	var invoiceLLM InvoiceLLM
	if err := json.NewDecoder(r.Body).Decode(&invoiceLLM); err != nil {
		w.WriteHeader(http.StatusBadRequest)
		errorResponse := LLMError{
			ErrorCode:   "INVOICE-001",
			AgentName:   u.agentName,
			Description: "Failed to decode request body",
			RawError:    err.Error(),
		}
		json.NewEncoder(w).Encode(errorResponse)
		return
	}

	date := time.Now()
	dueDate := date.AddDate(0, 0, 30)
	subtotal := invoiceLLM.calculateSubtotal()
	tax := subtotal * float64(0.08)
	invoice := Invoice{
		InvoiceNumber: invoiceLLM.InvoiceNumber,
		Date:          date.Format(time.DateOnly),
		DueDate:       dueDate.Format(time.DateOnly),
		From: Company{
			Name:    invoiceLLM.From.Name,
			Email:   invoiceLLM.From.Email,
			Address: invoiceLLM.From.Address,
		},
		To: Company{
			Name:    invoiceLLM.To.Name,
			Email:   invoiceLLM.To.Email,
			Address: invoiceLLM.To.Address,
		},
		Items:     invoiceLLM.calculateLineItems(),
		Subtotal:  subtotal,
		TaxRate:   float64(0.08),
		TaxAmount: tax,
		Total:     tax + subtotal,
		Notes:     "Thank you for your business!",
	}
	filename, err := u.uploadInvoice(r.Context(), invoice)
	if err != nil {
		slog.Error("upload failure", "error", err)
		w.WriteHeader(http.StatusInternalServerError)
		errorResponse := LLMError{
			ErrorCode:   "INVOICE-002",
			AgentName:   u.agentName,
			Description: "Failed to upload invoice due to server error, please try again.",
			RawError:    err.Error(),
		}
		json.NewEncoder(w).Encode(errorResponse)
		return
	}
	url, _ := url.Parse(u.apiURL)
	location := url.JoinPath("attachment", filename).String()
	w.Header().Set("Location", location)
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(map[string]string{"location": location, "filename": filename})
}

func (u *Upload) uploadInvoice(ctx context.Context, invoice Invoice) (string, error) {
	var buf bytes.Buffer
	if err := GenerateInvoicePDFToWriter(invoice, &buf); err != nil {
		slog.Error("Failed to generate PDF", "error", err)
		return "", fmt.Errorf("pdf generation: %w", err)
	}

	now := time.Now()
	filename := fmt.Sprintf("invoice_%s_%s_%d.pdf", invoice.InvoiceNumber, now.Format("2006-01-02"), now.Unix())
	slog.Info("Generated invoice", "number", invoice.InvoiceNumber, "filename", filename, "size", buf.Len())

	signedURL, err := u.getSignedURL(ctx, filename)
	if err != nil {
		slog.Error("Failed to get signed url", "error", err)
		return "", fmt.Errorf("pdf signed url: %w", err)
	}

	slog.Info("Received signed url, uploading to storage bucket")
	err = u.doUpload(ctx, signedURL, &buf)
	if err != nil {
		return "", fmt.Errorf("pdf upload: %w", err)
	}
	slog.Info("Upload completed")
	return filename, nil
}

func (u *Upload) handleW2(w http.ResponseWriter, r *http.Request) {
	defer r.Body.Close()
	var w2 W2
	if err := json.NewDecoder(r.Body).Decode(&w2); err != nil {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(LLMError{
			ErrorCode:   "W2-001",
			AgentName:   u.agentName,
			Description: "Failed to decode request body",
			RawError:    err.Error(),
		})
		return
	}

	filename, err := u.uploadW2(r.Context(), w2)
	if err != nil {
		slog.Error("w2 upload failure", "error", err)
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(LLMError{
			ErrorCode:   "W2-002",
			AgentName:   u.agentName,
			Description: "Failed to upload W-2 PDF",
			RawError:    err.Error(),
		})
		return
	}

	loc, _ := url.Parse(u.apiURL)
	location := loc.JoinPath("attachment", filename).String()
	w.Header().Set("Location", location)
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(map[string]string{"location": location, "filename": filename})
}

func (u *Upload) uploadW2(ctx context.Context, w2 W2) (string, error) {
	var buf bytes.Buffer
	if err := GenerateW2PDFToWriter(w2, &buf); err != nil {
		slog.Error("Failed to generate W-2 PDF", "error", err)
		return "", fmt.Errorf("w2 pdf generation: %w", err)
	}

	now := time.Now()
	filename := fmt.Sprintf("w2_%d_%d.pdf", w2.TaxYear, now.Unix())
	slog.Info("Generated W-2", "tax_year", w2.TaxYear, "filename", filename, "size", buf.Len())

	signedURL, err := u.getSignedURL(ctx, filename)
	if err != nil {
		return "", fmt.Errorf("w2 signed url: %w", err)
	}

	slog.Info("Received signed url, uploading W-2 to storage bucket")
	if err := u.doUpload(ctx, signedURL, &buf); err != nil {
		return "", fmt.Errorf("w2 upload: %w", err)
	}
	slog.Info("W-2 upload completed")
	return filename, nil
}

func (u *Upload) handleReceipt(w http.ResponseWriter, r *http.Request) {
	defer r.Body.Close()
	var receipt Receipt
	if err := json.NewDecoder(r.Body).Decode(&receipt); err != nil {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(LLMError{
			ErrorCode:   "RECEIPT-001",
			AgentName:   u.agentName,
			Description: "Failed to decode request body",
			RawError:    err.Error(),
		})
		return
	}

	filename, err := u.uploadReceipt(r.Context(), receipt)
	if err != nil {
		slog.Error("receipt upload failure", "error", err)
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(LLMError{
			ErrorCode:   "RECEIPT-002",
			AgentName:   u.agentName,
			Description: "Failed to upload receipt PDF",
			RawError:    err.Error(),
		})
		return
	}

	loc, _ := url.Parse(u.apiURL)
	location := loc.JoinPath("attachment", filename).String()
	w.Header().Set("Location", location)
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(map[string]string{"location": location, "filename": filename})
}

func (u *Upload) uploadReceipt(ctx context.Context, receipt Receipt) (string, error) {
	var buf bytes.Buffer
	if err := GenerateReceiptPDFToWriter(receipt, &buf); err != nil {
		return "", fmt.Errorf("receipt pdf generation: %w", err)
	}

	now := time.Now()
	filename := fmt.Sprintf("receipt_%s_%d.pdf", receipt.ReceiptNumber, now.Unix())

	signedURL, err := u.getSignedURL(ctx, filename)
	if err != nil {
		return "", fmt.Errorf("receipt signed url: %w", err)
	}

	if err := u.doUpload(ctx, signedURL, &buf); err != nil {
		return "", fmt.Errorf("receipt upload: %w", err)
	}
	return filename, nil
}

func (u *Upload) handleNEC1099(w http.ResponseWriter, r *http.Request) {
	defer r.Body.Close()
	var nec NEC1099
	if err := json.NewDecoder(r.Body).Decode(&nec); err != nil {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(LLMError{
			ErrorCode:   "1099NEC-001",
			AgentName:   u.agentName,
			Description: "Failed to decode request body",
			RawError:    err.Error(),
		})
		return
	}

	filename, err := u.uploadNEC1099(r.Context(), nec)
	if err != nil {
		slog.Error("1099-NEC upload failure", "error", err)
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(LLMError{
			ErrorCode:   "1099NEC-002",
			AgentName:   u.agentName,
			Description: "Failed to upload 1099-NEC PDF",
			RawError:    err.Error(),
		})
		return
	}

	loc, _ := url.Parse(u.apiURL)
	location := loc.JoinPath("attachment", filename).String()
	w.Header().Set("Location", location)
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(map[string]string{"location": location, "filename": filename})
}

func (u *Upload) uploadNEC1099(ctx context.Context, nec NEC1099) (string, error) {
	var buf bytes.Buffer
	if err := GenerateNEC1099PDFToWriter(nec, &buf); err != nil {
		return "", fmt.Errorf("1099-nec pdf generation: %w", err)
	}

	now := time.Now()
	filename := fmt.Sprintf("1099-nec_%d_%d.pdf", nec.TaxYear, now.Unix())

	signedURL, err := u.getSignedURL(ctx, filename)
	if err != nil {
		return "", fmt.Errorf("1099-nec signed url: %w", err)
	}

	if err := u.doUpload(ctx, signedURL, &buf); err != nil {
		return "", fmt.Errorf("1099-nec upload: %w", err)
	}
	return filename, nil
}

func (u *Upload) handleBankStatement(w http.ResponseWriter, r *http.Request) {
	defer r.Body.Close()
	var stmt BankStatement
	if err := json.NewDecoder(r.Body).Decode(&stmt); err != nil {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(LLMError{
			ErrorCode:   "STATEMENT-001",
			AgentName:   u.agentName,
			Description: "Failed to decode request body",
			RawError:    err.Error(),
		})
		return
	}

	filename, err := u.uploadBankStatement(r.Context(), stmt)
	if err != nil {
		slog.Error("bank statement upload failure", "error", err)
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(LLMError{
			ErrorCode:   "STATEMENT-002",
			AgentName:   u.agentName,
			Description: "Failed to upload bank statement PDF",
			RawError:    err.Error(),
		})
		return
	}

	loc, _ := url.Parse(u.apiURL)
	location := loc.JoinPath("attachment", filename).String()
	w.Header().Set("Location", location)
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(map[string]string{"location": location, "filename": filename})
}

func (u *Upload) uploadBankStatement(ctx context.Context, stmt BankStatement) (string, error) {
	var buf bytes.Buffer
	if err := GenerateBankStatementPDFToWriter(stmt, &buf); err != nil {
		return "", fmt.Errorf("bank statement pdf generation: %w", err)
	}

	now := time.Now()
	acct := strings.NewReplacer("*", "", "x", "", "X", "").Replace(stmt.AccountNumber)
	filename := fmt.Sprintf("statement_%s_%d.pdf", acct, now.Unix())

	signedURL, err := u.getSignedURL(ctx, filename)
	if err != nil {
		return "", fmt.Errorf("bank statement signed url: %w", err)
	}

	if err := u.doUpload(ctx, signedURL, &buf); err != nil {
		return "", fmt.Errorf("bank statement upload: %w", err)
	}
	return filename, nil
}

func (u *Upload) ServeHTTP(r http.ResponseWriter, req *http.Request) {
	u.server.ServeHTTP(r, req)
}

// curl -H "content-type: application/json" http://localhost:8000/invoice \
// -d '{"agent_name":"chaos-agent", "invoice_number":"INV-0001",
// "from":{"name":"acme inc", "email": "acme@example.com", "address":"123 Main St., San Jose, CA 12345"},
// "to":{"name":"construction inc", "email": "construction@example.com", "address": "456 Broadway Ave., Palo Alto, CA 12345"},
// "items": [{"description": "acme brick", "quantity": 1, "unit_price": 5.0}],
// "tax_rate": 0.08}'
