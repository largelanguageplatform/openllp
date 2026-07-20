package main

import (
	"bytes"
	"encoding/base64"
	"html/template"
	"math"
	"sync"

	"github.com/go-rod/rod"
	"github.com/go-rod/rod/lib/launcher"
	"github.com/go-rod/rod/lib/proto"
	"github.com/ysmood/gson"
)

var (
	browser     *rod.Browser
	browserOnce sync.Once
)

func getBrowser() *rod.Browser {
	browserOnce.Do(func() {
		path, _ := launcher.LookPath()
		u := launcher.New().Bin(path).NoSandbox(true).MustLaunch()
		browser = rod.New().ControlURL(u).MustConnect()
	})
	return browser
}

// PDFOptions controls the PDF page dimensions and margins.
type PDFOptions struct {
	PaperWidth   float64 // inches
	PaperHeight  float64 // inches
	MarginTop    float64 // inches
	MarginBottom float64
	MarginLeft   float64
	MarginRight  float64
}

// LetterPDF is the standard US Letter page size (8.5" x 11").
var LetterPDF = PDFOptions{
	PaperWidth:   8.5,
	PaperHeight:  11,
	MarginTop:    0.4,
	MarginBottom: 0.4,
	MarginLeft:   0.4,
	MarginRight:  0.4,
}

// ThermalPDFOptions returns PDF options sized for a thermal receipt.
// Height is calculated dynamically from the item count so the receipt
// is only as tall as its content with no blank tail.
func ThermalPDFOptions(itemCount int) PDFOptions {
	height := math.Max(5.0, 3.5+float64(itemCount)*0.35)
	return PDFOptions{
		PaperWidth:   3.15,
		PaperHeight:  height,
		MarginTop:    0.15,
		MarginBottom: 0.15,
		MarginLeft:   0.1,
		MarginRight:  0.1,
	}
}

// RenderHTMLToPDFWithOptions executes the template and returns PDF bytes
// using the supplied page dimensions.
func RenderHTMLToPDFWithOptions(tmpl *template.Template, data any, opts PDFOptions) ([]byte, error) {
	var buf bytes.Buffer
	if err := tmpl.Execute(&buf, data); err != nil {
		return nil, err
	}

	page := getBrowser().MustPage("")
	defer page.MustClose()

	dataURL := "data:text/html;base64," + base64.StdEncoding.EncodeToString(buf.Bytes())
	page.MustNavigate(dataURL).MustWaitStable()

	pdf, err := page.PDF(&proto.PagePrintToPDF{
		PaperWidth:      gson.Num(opts.PaperWidth),
		PaperHeight:     gson.Num(opts.PaperHeight),
		PrintBackground: true,
		MarginTop:       gson.Num(opts.MarginTop),
		MarginBottom:    gson.Num(opts.MarginBottom),
		MarginLeft:      gson.Num(opts.MarginLeft),
		MarginRight:     gson.Num(opts.MarginRight),
	})
	if err != nil {
		return nil, err
	}

	reader := pdf
	var out bytes.Buffer
	if _, err := out.ReadFrom(reader); err != nil {
		return nil, err
	}
	return out.Bytes(), nil
}

// RenderHTMLToPDF renders with US Letter defaults for backward compatibility.
func RenderHTMLToPDF(tmpl *template.Template, data any) ([]byte, error) {
	return RenderHTMLToPDFWithOptions(tmpl, data, LetterPDF)
}
