package main

import (
	_ "embed"
	"html/template"
	"io"
)

//go:embed templates/receipt.html
var receiptHTML string

//go:embed templates/receipt_thermal.html
var receiptThermalHTML string

var receiptTmpl = template.Must(template.New("receipt").Parse(receiptHTML))
var receiptThermalTmpl = template.Must(template.New("receipt_thermal").Parse(receiptThermalHTML))

type vendorBrand struct {
	LogoSVG    template.HTML
	Color      string
	LightColor string
	Format     string // "a4" or "thermal"
}

type receiptView struct {
	Receipt
	Brand vendorBrand
}

var defaultBrand = vendorBrand{
	LogoSVG:    `<svg width="140" height="36"><text x="70" y="26" text-anchor="middle" font-family="Arial,sans-serif" font-size="24" font-weight="700" fill="#333">RECEIPT</text></svg>`,
	Color:      "#333333",
	LightColor: "#f5f5f5",
	Format:     "a4",
}

var vendorBrands = map[string]vendorBrand{
	"amazon": {
		LogoSVG:    `<svg width="160" height="44" viewBox="0 0 160 44"><text x="80" y="28" text-anchor="middle" font-family="Arial,sans-serif" font-size="28" font-weight="700" fill="#232F3E" letter-spacing="-0.5">amazon</text><path d="M38 34 Q80 44 122 34" stroke="#FF9900" stroke-width="3" fill="none" stroke-linecap="round"/><polygon points="120,30 128,34 120,38" fill="#FF9900"/></svg>`,
		Color:      "#FF9900",
		LightColor: "#FFF5E6",
		Format:     "a4",
	},
	"uber": {
		LogoSVG:    `<svg width="100" height="40" viewBox="0 0 100 40"><text x="50" y="30" text-anchor="middle" font-family="Arial,sans-serif" font-size="30" font-weight="700" fill="#000000">Uber</text></svg>`,
		Color:      "#000000",
		LightColor: "#F5F5F5",
		Format:     "a4",
	},
	"fedex": {
		LogoSVG:    `<svg width="120" height="40" viewBox="0 0 120 40"><text x="0" y="30" font-family="Arial,sans-serif" font-size="30" font-weight="700" fill="#4D148C">Fed</text><text x="60" y="30" font-family="Arial,sans-serif" font-size="30" font-weight="700" fill="#FF6600">Ex</text></svg>`,
		Color:      "#4D148C",
		LightColor: "#F3EBF9",
		Format:     "a4",
	},
	"delta": {
		LogoSVG:    `<svg width="140" height="44" viewBox="0 0 140 44"><polygon points="30,4 12,36 48,36" fill="#003366"/><text x="85" y="28" text-anchor="middle" font-family="Arial,sans-serif" font-size="20" font-weight="700" fill="#003366" letter-spacing="2">DELTA</text></svg>`,
		Color:      "#003366",
		LightColor: "#EBF0F5",
		Format:     "a4",
	},

	// Thermal vendors — logo/color fields unused by the thermal template.
	"costco": {
		Format: "thermal",
	},
	"homedepot": {
		Format: "thermal",
	},
	"shell": {
		Format: "thermal",
	},
	"staples": {
		Format: "thermal",
	},
	"starbucks": {
		Format: "thermal",
	},
	"mcdonalds": {
		Format: "thermal",
	},
	"chipotle": {
		Format: "thermal",
	},
	"walmart": {
		Format: "thermal",
	},
}

func GenerateReceiptPDFToWriter(r Receipt, w io.Writer) error {
	brand := defaultBrand
	if b, ok := vendorBrands[r.VendorID]; ok {
		brand = b
	}
	view := receiptView{
		Receipt: r,
		Brand:   brand,
	}

	var (
		tmpl *template.Template
		opts PDFOptions
	)
	if brand.Format == "thermal" {
		tmpl = receiptThermalTmpl
		opts = ThermalPDFOptions(len(r.Items))
	} else {
		tmpl = receiptTmpl
		opts = LetterPDF
	}

	b, err := RenderHTMLToPDFWithOptions(tmpl, view, opts)
	if err != nil {
		return err
	}
	_, err = w.Write(b)
	return err
}
