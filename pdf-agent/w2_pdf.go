package main

import (
	"fmt"
	"io"
	"strings"

	"github.com/go-pdf/fpdf"
)

func GenerateW2PDFToWriter(w2 W2, w io.Writer) error {
	pdf := fpdf.New("P", "mm", "A4", "")
	pdf.SetMargins(15, 15, 15)
	pdf.AddPage()

	const (
		x   = 15.0  // left margin
		lw  = 90.0  // left column width
		r1  = 45.0  // right column left half
		r2  = 45.0  // right column right half
		h   = 12.0  // standard box height
		rx  = x + lw // right column start
	)

	// Title
	pdf.SetFont("Arial", "B", 16)
	pdf.Cell(90, 7, "Form W-2")
	pdf.SetFont("Arial", "B", 11)
	pdf.Cell(90, 7, "Wage and Tax Statement")
	pdf.Ln(8)
	pdf.SetFont("Arial", "", 7)
	pdf.SetTextColor(80, 80, 80)
	pdf.Cell(90, 4, "Department of the Treasury \u2014 Internal Revenue Service")
	pdf.SetFont("Arial", "B", 9)
	pdf.Cell(90, 4, fmt.Sprintf("Tax Year %d", w2.TaxYear))
	pdf.SetTextColor(0, 0, 0)
	pdf.Ln(8)

	y := pdf.GetY()

	// Row 1: Box a + OMB
	w2box(pdf, x, y, lw, h, "a  Employee's social security number", w2.Employee.SSN)
	w2box(pdf, rx, y, 90, h, "OMB No. 1545-0008", "")

	// Row 2: Box b + Boxes 1, 2
	y += h
	w2box(pdf, x, y, lw, h, "b  Employer identification number (EIN)", w2.Employer.EIN)
	w2box(pdf, rx, y, r1, h, "1  Wages, tips, other compensation", money(w2.Wages.Box1WagesTips))
	w2box(pdf, rx+r1, y, r2, h, "2  Federal income tax withheld", money(w2.Wages.Box2FederalTax))

	// Rows 3-4: Box c (tall) + Boxes 3-6
	y += h
	w2boxAddr(pdf, x, y, lw, h*2, "c  Employer's name, address, and ZIP code", w2.Employer.Name, w2.Employer.Address)
	w2box(pdf, rx, y, r1, h, "3  Social security wages", money(w2.Wages.Box3SSWages))
	w2box(pdf, rx+r1, y, r2, h, "4  Social security tax withheld", money(w2.Wages.Box4SSTax))
	y += h
	w2box(pdf, rx, y, r1, h, "5  Medicare wages and tips", money(w2.Wages.Box5MedicareWages))
	w2box(pdf, rx+r1, y, r2, h, "6  Medicare tax withheld", money(w2.Wages.Box6MedicareTax))

	// Row 5: Box d + Boxes 7, 8
	y += h
	w2box(pdf, x, y, lw, h, "d  Control number", w2.ControlNumber)
	w2box(pdf, rx, y, r1, h, "7  Social security tips", moneyOpt(w2.Wages.Box7SSTips))
	w2box(pdf, rx+r1, y, r2, h, "8  Allocated tips", moneyOpt(w2.Wages.Box8AllocatedTips))

	// Row 6: Box e + Boxes 9, 10
	y += h
	w2box(pdf, x, y, lw, h, "e  Employee's first name and initial  Last name  Suff.", w2.Employee.Name.FullName())
	w2box(pdf, rx, y, r1, h, "9", "")
	w2box(pdf, rx+r1, y, r2, h, "10  Dependent care benefits", "")

	// Rows 7-8: Box f (tall) + Boxes 11, 12a, 13, 12b
	y += h
	w2boxAddr(pdf, x, y, lw, h*2, "f  Employee's address and ZIP code", "", w2.Employee.Address)
	w2box(pdf, rx, y, r1, h, "11  Nonqualified plans", "")
	w2box(pdf, rx+r1, y, r2, h, "12a", box12val(w2.Box12, 0))
	y += h
	w2box(pdf, rx, y, r1, h, "13  Statutory / Retirement / Third-party", box13val(w2.Box13))
	w2box(pdf, rx+r1, y, r2, h, "12b", box12val(w2.Box12, 1))

	// Row 9: Box 14 + Boxes 12c, 12d
	y += h
	w2box(pdf, x, y, lw, h, "14  Other", "")
	w2box(pdf, rx, y, r1, h, "12c", box12val(w2.Box12, 2))
	w2box(pdf, rx+r1, y, r2, h, "12d", box12val(w2.Box12, 3))

	// State/Local rows (up to 2)
	y += h + 1
	stWidths := []float64{20, 30, 30, 25, 25, 25, 25}
	stLabels := []string{"15 State", "Employer's state ID", "16 State wages", "17 State tax", "18 Local wages", "19 Local tax", "20 Locality"}
	for i := 0; i < 2; i++ {
		var s W2State
		if i < len(w2.StateLocal) {
			s = w2.StateLocal[i]
		}
		vals := []string{s.State, s.StateID, moneyOpt(s.StateWages), moneyOpt(s.StateTax), moneyOpt(s.LocalWages), moneyOpt(s.LocalTax), s.Locality}
		sx := x
		for j := range stWidths {
			w2box(pdf, sx, y, stWidths[j], h, stLabels[j], vals[j])
			sx += stWidths[j]
		}
		y += h
	}

	return pdf.Output(w)
}

// w2box draws a bordered form box with a small label and a value.
func w2box(pdf *fpdf.Fpdf, x, y, w, h float64, label, value string) {
	pdf.Rect(x, y, w, h, "D")
	pdf.SetFont("Arial", "", 5.5)
	pdf.SetTextColor(80, 80, 80)
	pdf.SetXY(x+1, y+0.5)
	pdf.CellFormat(w-2, 3.5, label, "", 0, "L", false, 0, "")
	pdf.SetFont("Courier", "B", 10)
	pdf.SetTextColor(0, 0, 0)
	pdf.SetXY(x+2, y+4.5)
	pdf.CellFormat(w-4, h-5.5, value, "", 0, "L", false, 0, "")
}

// w2boxAddr draws a tall box with name and address lines.
func w2boxAddr(pdf *fpdf.Fpdf, x, y, w, h float64, label, name string, addr W2Address) {
	pdf.Rect(x, y, w, h, "D")
	pdf.SetFont("Arial", "", 5.5)
	pdf.SetTextColor(80, 80, 80)
	pdf.SetXY(x+1, y+0.5)
	pdf.CellFormat(w-2, 3.5, label, "", 0, "L", false, 0, "")
	yy := y + 4.5
	if name != "" {
		pdf.SetFont("Courier", "B", 10)
		pdf.SetTextColor(0, 0, 0)
		pdf.SetXY(x+2, yy)
		pdf.CellFormat(w-4, 5, name, "", 0, "L", false, 0, "")
		yy += 5
	}
	pdf.SetFont("Courier", "", 9)
	pdf.SetTextColor(0, 0, 0)
	for _, line := range addr.Lines() {
		pdf.SetXY(x+2, yy)
		pdf.CellFormat(w-4, 4.5, line, "", 0, "L", false, 0, "")
		yy += 4.5
	}
}

func money(v float64) string     { return formatCurrency(v) }
func moneyOpt(v float64) string  { if v == 0 { return "" }; return formatCurrency(v) }

func box12val(entries []W2Box12, i int) string {
	if i >= len(entries) {
		return ""
	}
	return fmt.Sprintf("%s  %s", entries[i].Code, formatCurrency(entries[i].Amount))
}

func box13val(b *W2Box13) string {
	if b == nil {
		return ""
	}
	var parts []string
	if b.StatutoryEmployee {
		parts = append(parts, "Stat")
	}
	if b.RetirementPlan {
		parts = append(parts, "Ret")
	}
	if b.ThirdPartySickPay {
		parts = append(parts, "3rd")
	}
	return strings.Join(parts, " | ")
}
