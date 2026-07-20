package main

import "fmt"

// Invoice represents a complete invoice document
type Invoice struct {
	InvoiceNumber string     `json:"invoice_number"`
	Date          string     `json:"date"`
	DueDate       string     `json:"due_date"`
	From          Company    `json:"from"`
	To            Company    `json:"to"`
	Items         []LineItem `json:"items"`
	Subtotal      float64    `json:"subtotal"`
	TaxRate       float64    `json:"tax_rate"`
	TaxAmount     float64    `json:"tax_amount"`
	Total         float64    `json:"total"`
	Notes         string     `json:"notes,omitempty"`
	PaymentTerms  string     `json:"payment_terms,omitempty"`
}

// An invoice provided by another agent. Some properties intentionally missing
// as they to simplify tool calling
type InvoiceLLM struct {
	AgentName       string        `json:"agent_name"`
	InvoiceNumber   string        `json:"invoice_number"`
	Date            string        `json:"date"`
	PromptInjection bool          `json:"prompt_injection"`
	From            Company       `json:"from"`
	To              Company       `json:"to"`
	Items           []LineItemLLM `json:"items"`
	TaxRate         float64       `json:"tax_rate"`
}

func (i InvoiceLLM) calculateLineItems() []LineItem {
	lineItems := make([]LineItem, len(i.Items))
	for index, val := range i.Items {
		item := LineItem{
			Description: val.Description,
			Quantity:    val.Quantity,
			UnitPrice:   val.UnitPrice,
			Amount:      val.UnitPrice * float64(val.Quantity),
		}
		lineItems[index] = item
	}

	return lineItems
}

func (i InvoiceLLM) calculateSubtotal() float64 {
	var subtotal float64
	for _, val := range i.Items {
		subtotal += val.UnitPrice * float64(val.Quantity)
	}

	return subtotal
}

// Company represents either the seller or buyer
type Company struct {
	Name    string `json:"name"`
	Address string `json:"address"`
	Email   string `json:"email,omitempty"`
	Phone   string `json:"phone,omitempty"`
}

// LineItem represents a single item on the invoice
type LineItem struct {
	Description string  `json:"description"`
	Quantity    int     `json:"quantity"`
	UnitPrice   float64 `json:"unit_price"`
	Amount      float64 `json:"amount"`
}

type LineItemLLM struct {
	Description string  `json:"description"`
	Quantity    int     `json:"quantity"`
	UnitPrice   float64 `json:"unit_price"`
}

type LLMError struct {
	ErrorCode   string `json:"error_code"`
	AgentName   string `json:"agent_name"`
	Description string `json:"description"`
	RawError    string `json:"raw_error"`
}

// W2 represents a US W-2 Wage and Tax Statement
type W2 struct {
	TaxYear       int         `json:"tax_year"`
	Employer      W2Employer  `json:"employer"`
	Employee      W2Employee  `json:"employee"`
	ControlNumber string      `json:"control_number,omitempty"`
	Wages         W2Wages     `json:"wages"`
	Box12         []W2Box12   `json:"box12,omitempty"`
	Box13         *W2Box13    `json:"box13,omitempty"`
	StateLocal    []W2State   `json:"state_local,omitempty"`
}

type W2Box12 struct {
	Code   string  `json:"code"`
	Amount float64 `json:"amount"`
}

type W2Box13 struct {
	StatutoryEmployee bool `json:"statutory_employee"`
	RetirementPlan    bool `json:"retirement_plan"`
	ThirdPartySickPay bool `json:"third_party_sick_pay"`
}

type W2Employer struct {
	EIN     string    `json:"ein"`
	Name    string    `json:"name"`
	Address W2Address `json:"address"`
	StateID string    `json:"state_id,omitempty"`
}

type W2Employee struct {
	SSN     string    `json:"ssn"`
	Name    W2Name    `json:"name"`
	Address W2Address `json:"address"`
}

type W2Name struct {
	FirstName     string `json:"first_name"`
	MiddleInitial string `json:"middle_initial,omitempty"`
	LastName      string `json:"last_name"`
	Suffix        string `json:"suffix,omitempty"`
}

func (n W2Name) FullName() string {
	name := n.FirstName
	if n.MiddleInitial != "" {
		name += " " + n.MiddleInitial + "."
	}
	name += " " + n.LastName
	if n.Suffix != "" {
		name += " " + n.Suffix
	}
	return name
}

type W2Address struct {
	Street  string `json:"street"`
	Street2 string `json:"street2,omitempty"`
	City    string `json:"city"`
	State   string `json:"state"`
	Zip     string `json:"zip"`
}

func (a W2Address) Lines() []string {
	lines := []string{a.Street}
	if a.Street2 != "" {
		lines = append(lines, a.Street2)
	}
	lines = append(lines, fmt.Sprintf("%s, %s %s", a.City, a.State, a.Zip))
	return lines
}

type W2Wages struct {
	Box1WagesTips     float64 `json:"box1_wages_tips_other"`
	Box2FederalTax    float64 `json:"box2_federal_tax_withheld"`
	Box3SSWages       float64 `json:"box3_ss_wages"`
	Box4SSTax         float64 `json:"box4_ss_tax_withheld"`
	Box5MedicareWages float64 `json:"box5_medicare_wages"`
	Box6MedicareTax   float64 `json:"box6_medicare_tax_withheld"`
	Box7SSTips        float64 `json:"box7_ss_tips"`
	Box8AllocatedTips float64 `json:"box8_allocated_tips"`
}

type W2State struct {
	State      string  `json:"box15_state"`
	StateID    string  `json:"box15_state_id,omitempty"`
	StateWages float64 `json:"box16_state_wages"`
	StateTax   float64 `json:"box17_state_tax"`
	LocalWages float64 `json:"box18_local_wages"`
	LocalTax   float64 `json:"box19_local_tax"`
	Locality   string  `json:"box20_locality,omitempty"`
}

// Receipt represents a payment receipt document.
// Reuses Company and LineItem types.
type Receipt struct {
	ReceiptNumber string     `json:"receipt_number"`
	Date          string     `json:"date"`
	VendorID      string     `json:"vendor_id,omitempty"`
	From          Company    `json:"from"`
	To            Company    `json:"to"`
	Items         []LineItem `json:"items"`
	Subtotal      float64    `json:"subtotal"`
	TaxRate       float64    `json:"tax_rate"`
	TaxAmount     float64    `json:"tax_amount"`
	Total         float64    `json:"total"`
	PaymentMethod string     `json:"payment_method"`
}

// NEC1099 represents a US 1099-NEC Nonemployee Compensation form.
type NEC1099 struct {
	TaxYear            int              `json:"tax_year"`
	Corrected          bool             `json:"corrected"`
	Payer              NEC1099Payer     `json:"payer"`
	Recipient          NEC1099Recipient `json:"recipient"`
	AccountNumber      string           `json:"account_number,omitempty"`
	FATCAFiling        bool             `json:"fatca_filing"`
	NonemployeeComp    float64          `json:"nonemployee_compensation"`
	DirectSales        bool             `json:"direct_sales"`
	FederalTaxWithheld float64          `json:"federal_tax_withheld"`
	StateTaxInfo       []NEC1099State   `json:"state_tax_info,omitempty"`
}

type NEC1099Payer struct {
	Name    string `json:"name"`
	Address string `json:"address"`
	TIN     string `json:"tin"`
	Phone   string `json:"phone,omitempty"`
}

type NEC1099Recipient struct {
	Name          string `json:"name"`
	TIN           string `json:"tin"`
	StreetAddress string `json:"street_address"`
	CityStateZip  string `json:"city_state_zip"`
}

type NEC1099State struct {
	State       string  `json:"state"`
	StateID     string  `json:"state_id,omitempty"`
	Income      float64 `json:"state_income"`
	TaxWithheld float64 `json:"state_tax_withheld"`
}

// BankStatement represents a monthly bank account statement.
type BankStatement struct {
	Bank            BankInfo          `json:"bank"`
	AccountHolder   AccountHolder     `json:"account_holder"`
	AccountNumber   string            `json:"account_number"`
	AccountType     string            `json:"account_type"`
	StatementPeriod StatementPeriod   `json:"statement_period"`
	Summary         AccountSummary    `json:"summary"`
	Transactions    []BankTransaction `json:"transactions"`
}

type BankInfo struct {
	Name    string `json:"name"`
	Address string `json:"address"`
	Phone   string `json:"phone,omitempty"`
	Website string `json:"website,omitempty"`
}

type AccountHolder struct {
	Name    string `json:"name"`
	Address string `json:"address"`
}

type AccountSummary struct {
	BeginningBalance float64 `json:"beginning_balance"`
	TotalDeposits    float64 `json:"total_deposits"`
	TotalWithdrawals float64 `json:"total_withdrawals"`
	TotalFees        float64 `json:"total_fees"`
	EndingBalance    float64 `json:"ending_balance"`
}

type StatementPeriod struct {
	Start string `json:"start"`
	End   string `json:"end"`
}

type BankTransaction struct {
	Date        string  `json:"date"`
	Description string  `json:"description"`
	Category    string  `json:"category"`
	Amount      float64 `json:"amount"`
	Balance     float64 `json:"balance"`
}
