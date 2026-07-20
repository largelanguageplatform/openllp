package main

import (
	_ "embed"
	"html/template"
	"io"
)

//go:embed templates/bank_statement.html
var bankStatementHTML string

var bankStatementTmpl = template.Must(template.New("bank_statement").Parse(bankStatementHTML))

type transactionGroup struct {
	Category     string
	Transactions []BankTransaction
	Total        float64
}

type bankStatementView struct {
	BankStatement
	Groups []transactionGroup
}

func groupTransactions(txns []BankTransaction) []transactionGroup {
	order := []string{}
	groups := map[string]*transactionGroup{}
	for _, t := range txns {
		cat := t.Category
		if cat == "" {
			cat = "Other"
		}
		g, ok := groups[cat]
		if !ok {
			g = &transactionGroup{Category: cat}
			groups[cat] = g
			order = append(order, cat)
		}
		g.Transactions = append(g.Transactions, t)
		g.Total += t.Amount
	}
	result := make([]transactionGroup, len(order))
	for i, cat := range order {
		result[i] = *groups[cat]
	}
	return result
}

func GenerateBankStatementPDFToWriter(bs BankStatement, w io.Writer) error {
	view := bankStatementView{
		BankStatement: bs,
		Groups:        groupTransactions(bs.Transactions),
	}
	b, err := RenderHTMLToPDF(bankStatementTmpl, view)
	if err != nil {
		return err
	}
	_, err = w.Write(b)
	return err
}
