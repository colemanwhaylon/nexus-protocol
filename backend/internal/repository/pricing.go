// Package repository defines the interfaces for data access
package repository

import (
	"context"
	"time"
)

// PricingRepository defines the contract for pricing data operations
type PricingRepository interface {
	// Pricing CRUD
	GetPricing(ctx context.Context, serviceCode string) (*Pricing, error)
	ListPricing(ctx context.Context, activeOnly bool) ([]*Pricing, error)
	UpdatePricing(ctx context.Context, serviceCode string, update *PricingUpdate) error

	// Payment Methods
	GetPaymentMethod(ctx context.Context, methodCode string) (*PaymentMethod, error)
	ListPaymentMethods(ctx context.Context, activeOnly bool) ([]*PaymentMethod, error)
	UpdatePaymentMethod(ctx context.Context, methodCode string, update *PaymentMethodUpdate) error

	// Pricing History (for audit)
	GetPricingHistory(ctx context.Context, serviceCode string, limit int) ([]*PricingHistoryEntry, error)
}

// Pricing represents a service pricing record
type Pricing struct {
	ID            string   `json:"id" db:"id"`
	ServiceCode   string   `json:"service_code" db:"service_code"`
	ServiceName   string   `json:"service_name" db:"service_name"`
	Description   string   `json:"description" db:"description"`
	CostUSD       float64  `json:"cost_usd" db:"cost_usd"`        // Our cost
	CostProvider  string   `json:"cost_provider" db:"cost_provider"` // Who we pay
	PriceUSD      float64  `json:"price_usd" db:"price_usd"`      // What we charge
	PriceETH      *float64 `json:"price_eth" db:"price_eth"`
	PriceNEXUS    *float64 `json:"price_nexus" db:"price_nexus"`
	MarkupPercent float64  `json:"markup_percent" db:"markup_percent"`
	IsActive      bool     `json:"is_active" db:"is_active"`
	CreatedAt     time.Time `json:"created_at" db:"created_at"`
	UpdatedAt     time.Time `json:"updated_at" db:"updated_at"`
	UpdatedBy     string   `json:"updated_by,omitempty" db:"updated_by"`
}

// PricingUpdate represents fields that can be updated
type PricingUpdate struct {
	PriceUSD      *float64 `json:"price_usd,omitempty"`
	PriceETH      *float64 `json:"price_eth,omitempty"`
	PriceNEXUS    *float64 `json:"price_nexus,omitempty"`
	MarkupPercent *float64 `json:"markup_percent,omitempty"`
	IsActive      *bool    `json:"is_active,omitempty"`
	UpdatedBy     string   `json:"updated_by"`
}

// PaymentMethod represents a payment method configuration
type PaymentMethod struct {
	ID              string    `json:"id" db:"id"`
	MethodCode      string    `json:"method_code" db:"method_code"`
	MethodName      string    `json:"method_name" db:"method_name"`
	IsActive        bool      `json:"is_active" db:"is_active"`
	ProcessorConfig any       `json:"processor_config" db:"processor_config"` // JSONB
	MinAmountUSD    float64   `json:"min_amount_usd" db:"min_amount_usd"`
	MaxAmountUSD    *float64  `json:"max_amount_usd" db:"max_amount_usd"`
	FeePercent      float64   `json:"fee_percent" db:"fee_percent"`
	DisplayOrder    int       `json:"display_order" db:"display_order"`
	CreatedAt       time.Time `json:"created_at" db:"created_at"`
	UpdatedAt       time.Time `json:"updated_at" db:"updated_at"`
}

// PaymentMethodUpdate represents fields that can be updated
type PaymentMethodUpdate struct {
	IsActive     *bool    `json:"is_active,omitempty"`
	MinAmountUSD *float64 `json:"min_amount_usd,omitempty"`
	MaxAmountUSD *float64 `json:"max_amount_usd,omitempty"`
	FeePercent   *float64 `json:"fee_percent,omitempty"`
	DisplayOrder *int     `json:"display_order,omitempty"`
}

// PricingHistoryEntry represents a pricing change record
type PricingHistoryEntry struct {
	ID               string    `json:"id" db:"id"`
	PricingID        string    `json:"pricing_id" db:"pricing_id"`
	OldPriceUSD      *float64  `json:"old_price_usd" db:"old_price_usd"`
	OldPriceETH      *float64  `json:"old_price_eth" db:"old_price_eth"`
	OldPriceNEXUS    *float64  `json:"old_price_nexus" db:"old_price_nexus"`
	OldMarkupPercent *float64  `json:"old_markup_percent" db:"old_markup_percent"`
	NewPriceUSD      *float64  `json:"new_price_usd" db:"new_price_usd"`
	NewPriceETH      *float64  `json:"new_price_eth" db:"new_price_eth"`
	NewPriceNEXUS    *float64  `json:"new_price_nexus" db:"new_price_nexus"`
	NewMarkupPercent *float64  `json:"new_markup_percent" db:"new_markup_percent"`
	ChangedBy        string    `json:"changed_by" db:"changed_by"`
	ChangedAt        time.Time `json:"changed_at" db:"changed_at"`
	ChangeReason     string    `json:"change_reason" db:"change_reason"`
}
