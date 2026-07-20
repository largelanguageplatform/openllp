package main

import (
	_ "embed"
	"fmt"
	"html/template"
	"io"
)

//go:embed templates/nec1099.html
var nec1099HTML string

var nec1099Tmpl = template.Must(template.New("nec1099").Parse(nec1099HTML))

type nec1099View struct {
	NEC1099
	YearPrefix string
	YearSuffix string
}

func GenerateNEC1099PDFToWriter(n NEC1099, w io.Writer) error {
	year := fmt.Sprintf("%d", n.TaxYear)
	view := nec1099View{
		NEC1099:    n,
		YearPrefix: year[:2],
		YearSuffix: year[2:],
	}
	b, err := RenderHTMLToPDF(nec1099Tmpl, view)
	if err != nil {
		return err
	}
	_, err = w.Write(b)
	return err
}
