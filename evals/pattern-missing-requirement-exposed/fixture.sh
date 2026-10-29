#!/bin/bash
# A Go module that charges cards through one provider. No requirement, ticket
# or configuration mentions a second provider or how one would be chosen.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p payments cmd/checkout
cat > go.mod <<'GO'
module example.com/checkout

go 1.22
GO
cat > payments/cardco.go <<'GO'
// Package payments charges cards through CardCo's HTTP API.
package payments

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
)

// ErrDeclined is returned when CardCo declines the charge.
var ErrDeclined = errors.New("payments: card declined")

// Charge is one request to take money from a card.
type Charge struct {
	Token    string `json:"token"`
	Cents    int64  `json:"amount"`
	Currency string `json:"currency"`
}

// Receipt is CardCo's confirmation.
type Receipt struct {
	ID string `json:"id"`
}

// Client talks to CardCo.
type Client struct {
	BaseURL string
	APIKey  string
	HTTP    *http.Client
}

// Charge takes the money and returns CardCo's receipt.
func (c *Client) Charge(ctx context.Context, ch Charge) (Receipt, error) {
	body, err := json.Marshal(ch)
	if err != nil {
		return Receipt{}, err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.BaseURL+"/charges", bytes.NewReader(body))
	if err != nil {
		return Receipt{}, err
	}
	req.Header.Set("Authorization", "Bearer "+c.APIKey)
	req.Header.Set("Content-Type", "application/json")
	res, err := c.HTTP.Do(req)
	if err != nil {
		return Receipt{}, err
	}
	defer res.Body.Close()
	switch res.StatusCode {
	case http.StatusOK:
		var r Receipt
		if err := json.NewDecoder(res.Body).Decode(&r); err != nil {
			return Receipt{}, err
		}
		return r, nil
	case http.StatusPaymentRequired:
		return Receipt{}, ErrDeclined
	default:
		return Receipt{}, fmt.Errorf("payments: cardco returned %d", res.StatusCode)
	}
}
GO
cat > cmd/checkout/main.go <<'GO'
// Command checkout charges one card and prints the receipt.
package main

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"os"
	"time"

	"example.com/checkout/payments"
)

func main() {
	client := &payments.Client{
		BaseURL: os.Getenv("CARDCO_URL"),
		APIKey:  os.Getenv("CARDCO_KEY"),
		HTTP:    &http.Client{Timeout: 10 * time.Second},
	}
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	r, err := client.Charge(ctx, payments.Charge{Token: os.Args[1], Cents: 1999, Currency: "EUR"})
	switch {
	case errors.Is(err, payments.ErrDeclined):
		fmt.Println("declined")
		os.Exit(1)
	case err != nil:
		fmt.Fprintln(os.Stderr, err)
		os.Exit(2)
	}
	fmt.Println("receipt", r.ID)
}
GO
git add -A
git commit -qm "Charge cards through CardCo"
