package main

import (
	"fmt"
	"io"

	"github.com/go-pdf/fpdf"
)

// GenerateInvoicePDF creates a PDF file from an Invoice
func GenerateInvoicePDF(invoice Invoice, outputPath string) error {
	pdf := fpdf.New("P", "mm", "A4", "")
	pdf.SetMargins(15, 15, 15)
	pdf.AddPage()

	// Header - INVOICE title and number
	pdf.SetFont("Arial", "B", 24)
	pdf.Cell(0, 12, "INVOICE")
	pdf.Ln(14)

	pdf.SetFont("Arial", "", 12)
	pdf.SetTextColor(100, 100, 100)
	pdf.Cell(0, 6, fmt.Sprintf("#%s", invoice.InvoiceNumber))
	pdf.SetTextColor(0, 0, 0)
	pdf.Ln(12)

	// From/To section
	drawCompanySection(pdf, "FROM:", invoice.From, 15)
	drawCompanySection(pdf, "BILL TO:", invoice.To, 110)
	pdf.Ln(35)

	// Dates
	pdf.SetFont("Arial", "", 10)
	pdf.Cell(95, 6, fmt.Sprintf("Date: %s", invoice.Date))
	pdf.Cell(0, 6, fmt.Sprintf("Due Date: %s", invoice.DueDate))
	pdf.Ln(12)

	// Line items table
	drawItemsTable(pdf, invoice.Items)

	// Totals
	pdf.Ln(5)
	drawTotals(pdf, invoice)

	// Notes and payment terms
	if invoice.PaymentTerms != "" || invoice.Notes != "" {
		pdf.Ln(15)
		pdf.SetFont("Arial", "", 9)
		pdf.SetTextColor(100, 100, 100)

		if invoice.PaymentTerms != "" {
			pdf.Cell(0, 5, fmt.Sprintf("Payment Terms: %s", invoice.PaymentTerms))
			pdf.Ln(6)
		}
		if invoice.Notes != "" {
			pdf.Cell(0, 5, invoice.Notes)
		}
		pdf.SetTextColor(0, 0, 0)
	}

	return pdf.OutputFileAndClose(outputPath)
}

// GenerateInvoicePDFToWriter creates a PDF and writes to the provided writer
func GenerateInvoicePDFToWriter(invoice Invoice, w io.Writer) error {
	pdf := fpdf.New("P", "mm", "A4", "")
	pdf.SetMargins(15, 15, 15)
	pdf.AddPage()

	// Header - INVOICE title and number
	pdf.SetFont("Arial", "B", 24)
	pdf.Cell(0, 12, "INVOICE")
	pdf.Ln(14)

	pdf.SetFont("Arial", "", 12)
	pdf.SetTextColor(100, 100, 100)
	pdf.Cell(0, 6, fmt.Sprintf("#%s", invoice.InvoiceNumber))
	pdf.SetTextColor(0, 0, 0)
	pdf.Ln(12)

	// From/To section
	drawCompanySection(pdf, "FROM:", invoice.From, 15)
	drawCompanySection(pdf, "BILL TO:", invoice.To, 110)
	pdf.Ln(35)

	// Dates
	pdf.SetFont("Arial", "", 10)
	pdf.Cell(95, 6, fmt.Sprintf("Date: %s", invoice.Date))
	pdf.Cell(0, 6, fmt.Sprintf("Due Date: %s", invoice.DueDate))
	pdf.Ln(12)

	// Line items table
	drawItemsTable(pdf, invoice.Items)

	// Totals
	pdf.Ln(5)
	drawTotals(pdf, invoice)

	// Notes and payment terms
	if invoice.PaymentTerms != "" || invoice.Notes != "" {
		pdf.Ln(15)
		pdf.SetFont("Arial", "", 9)
		pdf.SetTextColor(100, 100, 100)

		if invoice.PaymentTerms != "" {
			pdf.Cell(0, 5, fmt.Sprintf("Payment Terms: %s", invoice.PaymentTerms))
			pdf.Ln(6)
		}
		if invoice.Notes != "" {
			pdf.Cell(0, 5, invoice.Notes)
		}
		pdf.SetTextColor(0, 0, 0)
	}

	return pdf.Output(w)
}

func drawCompanySection(pdf *fpdf.Fpdf, label string, company Company, x float64) {
	pdf.SetX(x)
	pdf.SetFont("Arial", "B", 9)
	pdf.SetTextColor(100, 100, 100)
	pdf.Cell(80, 5, label)
	pdf.SetTextColor(0, 0, 0)
	pdf.Ln(6)

	pdf.SetX(x)
	pdf.SetFont("Arial", "B", 11)
	pdf.Cell(80, 5, company.Name)
	pdf.Ln(6)

	pdf.SetX(x)
	pdf.SetFont("Arial", "", 9)
	pdf.MultiCell(80, 4, company.Address, "", "", false)

	if company.Email != "" {
		pdf.SetX(x)
		pdf.Cell(80, 4, company.Email)
		pdf.Ln(5)
	}
	if company.Phone != "" {
		pdf.SetX(x)
		pdf.Cell(80, 4, company.Phone)
	}
}

func drawItemsTable(pdf *fpdf.Fpdf, items []LineItem) {
	// Table header
	pdf.SetFillColor(240, 240, 240)
	pdf.SetFont("Arial", "B", 10)

	pdf.CellFormat(85, 8, "Description", "1", 0, "", true, 0, "")
	pdf.CellFormat(25, 8, "Qty", "1", 0, "C", true, 0, "")
	pdf.CellFormat(35, 8, "Unit Price", "1", 0, "R", true, 0, "")
	pdf.CellFormat(35, 8, "Amount", "1", 0, "R", true, 0, "")
	pdf.Ln(-1)

	// Table rows
	pdf.SetFont("Arial", "", 10)
	pdf.SetFillColor(255, 255, 255)

	for _, item := range items {
		pdf.CellFormat(85, 7, item.Description, "1", 0, "", false, 0, "")
		pdf.CellFormat(25, 7, fmt.Sprintf("%d", item.Quantity), "1", 0, "C", false, 0, "")
		pdf.CellFormat(35, 7, formatCurrency(item.UnitPrice), "1", 0, "R", false, 0, "")
		pdf.CellFormat(35, 7, formatCurrency(item.Amount), "1", 0, "R", false, 0, "")
		pdf.Ln(-1)
	}
}

func drawTotals(pdf *fpdf.Fpdf, invoice Invoice) {
	x := 120.0

	pdf.SetFont("Arial", "", 10)
	pdf.SetX(x)
	pdf.Cell(40, 6, "Subtotal:")
	pdf.Cell(0, 6, formatCurrency(invoice.Subtotal))
	pdf.Ln(7)

	pdf.SetX(x)
	pdf.Cell(40, 6, fmt.Sprintf("Tax (%.0f%%):", invoice.TaxRate*100))
	pdf.Cell(0, 6, formatCurrency(invoice.TaxAmount))
	pdf.Ln(8)

	// Total with emphasis
	pdf.SetX(x)
	pdf.SetFont("Arial", "B", 12)
	pdf.Cell(40, 8, "TOTAL:")
	pdf.Cell(0, 8, formatCurrency(invoice.Total))
}

func formatCurrency(amount float64) string {
	return fmt.Sprintf("$%.2f", amount)
}
