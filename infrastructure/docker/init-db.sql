-- Nexus Protocol Database Initialization Script
-- This script runs when PostgreSQL container starts for the first time

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================
-- Users and Permissions
-- ============================================

-- Create read-only user for analytics
CREATE USER nexus_readonly WITH PASSWORD 'readonly_password_change_me';

-- Grant read permissions on all tables in public schema
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO nexus_readonly;

-- ============================================
-- Core Tables
-- ============================================

-- Staking positions
CREATE TABLE IF NOT EXISTS staking_positions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    address VARCHAR(42) NOT NULL UNIQUE,
    staked_amount NUMERIC(78, 0) NOT NULL DEFAULT 0,
    staked_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    unbonding_at TIMESTAMPTZ,
    unbonding_amount NUMERIC(78, 0) DEFAULT 0,
    delegatee VARCHAR(42),
    pending_reward NUMERIC(78, 0) NOT NULL DEFAULT 0,
    last_claim_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_staking_address ON staking_positions(address);
CREATE INDEX idx_staking_delegatee ON staking_positions(delegatee);

-- Token balances (for demo purposes - production uses blockchain)
CREATE TABLE IF NOT EXISTS token_balances (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    address VARCHAR(42) NOT NULL UNIQUE,
    balance NUMERIC(78, 0) NOT NULL DEFAULT 0,
    nonce BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_balance_address ON token_balances(address);

-- Token transfers (audit log)
CREATE TABLE IF NOT EXISTS token_transfers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tx_hash VARCHAR(66) NOT NULL UNIQUE,
    from_address VARCHAR(42) NOT NULL,
    to_address VARCHAR(42) NOT NULL,
    amount NUMERIC(78, 0) NOT NULL,
    block_number BIGINT,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_transfer_from ON token_transfers(from_address);
CREATE INDEX idx_transfer_to ON token_transfers(to_address);
CREATE INDEX idx_transfer_timestamp ON token_transfers(timestamp);

-- ============================================
-- Governance Tables
-- ============================================

-- Proposals
CREATE TABLE IF NOT EXISTS proposals (
    id VARCHAR(66) PRIMARY KEY,
    proposer VARCHAR(42) NOT NULL,
    title VARCHAR(256) NOT NULL,
    description TEXT NOT NULL,
    targets TEXT[] NOT NULL,
    values TEXT[] NOT NULL,
    calldatas TEXT[] NOT NULL,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ NOT NULL,
    state VARCHAR(20) NOT NULL DEFAULT 'pending',
    for_votes NUMERIC(78, 0) NOT NULL DEFAULT 0,
    against_votes NUMERIC(78, 0) NOT NULL DEFAULT 0,
    abstain_votes NUMERIC(78, 0) NOT NULL DEFAULT 0,
    queued_at TIMESTAMPTZ,
    executed_at TIMESTAMPTZ,
    canceled_at TIMESTAMPTZ,
    eta TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_proposal_proposer ON proposals(proposer);
CREATE INDEX idx_proposal_state ON proposals(state);
CREATE INDEX idx_proposal_end_time ON proposals(end_time);

-- Votes
CREATE TABLE IF NOT EXISTS votes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    proposal_id VARCHAR(66) NOT NULL REFERENCES proposals(id),
    voter VARCHAR(42) NOT NULL,
    support SMALLINT NOT NULL CHECK (support BETWEEN 0 AND 2),
    weight NUMERIC(78, 0) NOT NULL,
    reason TEXT,
    voted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(proposal_id, voter)
);

CREATE INDEX idx_vote_proposal ON votes(proposal_id);
CREATE INDEX idx_vote_voter ON votes(voter);

-- ============================================
-- NFT Tables
-- ============================================

-- NFT tokens
CREATE TABLE IF NOT EXISTS nft_tokens (
    token_id VARCHAR(78) PRIMARY KEY,
    owner VARCHAR(42) NOT NULL,
    name VARCHAR(256) NOT NULL,
    description TEXT,
    image VARCHAR(512),
    attributes JSONB,
    soulbound BOOLEAN NOT NULL DEFAULT FALSE,
    minted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    transferred_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_nft_owner ON nft_tokens(owner);
CREATE INDEX idx_nft_soulbound ON nft_tokens(soulbound);

-- NFT approvals
CREATE TABLE IF NOT EXISTS nft_approvals (
    token_id VARCHAR(78) PRIMARY KEY REFERENCES nft_tokens(token_id),
    approved VARCHAR(42) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- NFT operator approvals
CREATE TABLE IF NOT EXISTS nft_operator_approvals (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    owner VARCHAR(42) NOT NULL,
    operator VARCHAR(42) NOT NULL,
    approved BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(owner, operator)
);

CREATE INDEX idx_operator_owner ON nft_operator_approvals(owner);

-- ============================================
-- KYC/Compliance Tables
-- ============================================

-- KYC registrations
CREATE TABLE IF NOT EXISTS kyc_registrations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    address VARCHAR(42) NOT NULL UNIQUE,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    level SMALLINT NOT NULL DEFAULT 0,
    jurisdiction VARCHAR(2) NOT NULL,
    verified_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ,
    rejection_reason TEXT,
    suspension_reason TEXT,
    document_hash VARCHAR(66),
    risk_score SMALLINT DEFAULT 0 CHECK (risk_score BETWEEN 0 AND 100),
    accredited_investor BOOLEAN NOT NULL DEFAULT FALSE,
    reviewed_by VARCHAR(42),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_kyc_address ON kyc_registrations(address);
CREATE INDEX idx_kyc_status ON kyc_registrations(status);
CREATE INDEX idx_kyc_jurisdiction ON kyc_registrations(jurisdiction);

-- Whitelist
CREATE TABLE IF NOT EXISTS whitelist (
    address VARCHAR(42) PRIMARY KEY,
    added_by VARCHAR(42) NOT NULL,
    reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Blacklist
CREATE TABLE IF NOT EXISTS blacklist (
    address VARCHAR(42) PRIMARY KEY,
    added_by VARCHAR(42) NOT NULL,
    reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Compliance officers
CREATE TABLE IF NOT EXISTS compliance_officers (
    address VARCHAR(42) PRIMARY KEY,
    added_by VARCHAR(42) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Audit log
CREATE TABLE IF NOT EXISTS audit_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    action VARCHAR(50) NOT NULL,
    actor VARCHAR(42) NOT NULL,
    subject VARCHAR(42),
    details TEXT,
    ip_address INET,
    previous_state TEXT,
    new_state TEXT,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audit_actor ON audit_log(actor);
CREATE INDEX idx_audit_subject ON audit_log(subject);
CREATE INDEX idx_audit_action ON audit_log(action);
CREATE INDEX idx_audit_timestamp ON audit_log(timestamp);

-- ============================================
-- Jurisdictions (reference data)
-- ============================================

CREATE TABLE IF NOT EXISTS jurisdictions (
    code VARCHAR(2) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    allowed BOOLEAN NOT NULL DEFAULT TRUE,
    required_level SMALLINT NOT NULL DEFAULT 1,
    max_transaction_usd BIGINT DEFAULT 0,
    requires_accredited BOOLEAN NOT NULL DEFAULT FALSE,
    restricted BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Insert initial jurisdictions
INSERT INTO jurisdictions (code, name, allowed, required_level, requires_accredited, restricted) VALUES
    ('US', 'United States', TRUE, 3, TRUE, FALSE),
    ('GB', 'United Kingdom', TRUE, 2, FALSE, FALSE),
    ('DE', 'Germany', TRUE, 2, FALSE, FALSE),
    ('SG', 'Singapore', TRUE, 2, FALSE, FALSE),
    ('JP', 'Japan', TRUE, 3, FALSE, FALSE),
    ('CH', 'Switzerland', TRUE, 1, FALSE, FALSE),
    ('AE', 'United Arab Emirates', TRUE, 2, FALSE, FALSE),
    ('KP', 'North Korea', FALSE, 0, FALSE, TRUE),
    ('IR', 'Iran', FALSE, 0, FALSE, TRUE),
    ('CU', 'Cuba', FALSE, 0, FALSE, TRUE),
    ('SY', 'Syria', FALSE, 0, FALSE, TRUE)
ON CONFLICT (code) DO NOTHING;

-- ============================================
-- Pricing & Fee Configuration Tables
-- ============================================

-- Fee types and their current pricing (DATABASE-DRIVEN PRICING)
-- This allows changing fees via DB updates instead of code changes
CREATE TABLE IF NOT EXISTS pricing (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    service_code VARCHAR(50) NOT NULL UNIQUE,  -- 'kyc_verification', 'nft_mint', etc.
    service_name VARCHAR(100) NOT NULL,
    description TEXT,

    -- Base cost (what we pay)
    cost_usd DECIMAL(18,8) NOT NULL DEFAULT 0,
    cost_provider VARCHAR(50),  -- 'sumsub', 'gas', 'internal'

    -- Pricing in different currencies
    price_usd DECIMAL(18,8) NOT NULL,
    price_eth DECIMAL(18,8),           -- NULL = not accepted
    price_nexus DECIMAL(18,8),         -- NULL = not accepted

    -- Markup calculation
    markup_percent DECIMAL(5,2) NOT NULL DEFAULT 0,  -- e.g., 200.00 = 200%

    -- Status
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(42)  -- Admin address who made change
);

CREATE INDEX idx_pricing_service_code ON pricing(service_code);
CREATE INDEX idx_pricing_is_active ON pricing(is_active);

-- Price history for audit trail
CREATE TABLE IF NOT EXISTS pricing_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pricing_id UUID NOT NULL REFERENCES pricing(id) ON DELETE CASCADE,

    -- Previous values
    old_price_usd DECIMAL(18,8),
    old_price_eth DECIMAL(18,8),
    old_price_nexus DECIMAL(18,8),
    old_markup_percent DECIMAL(5,2),

    -- New values
    new_price_usd DECIMAL(18,8),
    new_price_eth DECIMAL(18,8),
    new_price_nexus DECIMAL(18,8),
    new_markup_percent DECIMAL(5,2),

    -- Who and when
    changed_by VARCHAR(42) NOT NULL,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    change_reason TEXT,

    -- Audit timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_pricing_history_pricing_id ON pricing_history(pricing_id);
CREATE INDEX idx_pricing_history_changed_at ON pricing_history(changed_at);

-- Payment methods accepted
CREATE TABLE IF NOT EXISTS payment_methods (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    method_code VARCHAR(20) NOT NULL UNIQUE,  -- 'nexus', 'eth', 'stripe'
    method_name VARCHAR(50) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    processor_config JSONB,  -- Stripe keys, etc (encrypted in app layer)
    min_amount_usd DECIMAL(18,8) DEFAULT 0,
    max_amount_usd DECIMAL(18,8),
    fee_percent DECIMAL(5,2) DEFAULT 0,  -- Payment processor fee
    display_order SMALLINT DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_payment_methods_code ON payment_methods(method_code);
CREATE INDEX idx_payment_methods_active ON payment_methods(is_active);

-- Payment transactions
CREATE TABLE IF NOT EXISTS payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- What was paid for
    service_code VARCHAR(50) NOT NULL,
    pricing_id UUID REFERENCES pricing(id),

    -- Who paid
    payer_address VARCHAR(42) NOT NULL,

    -- Payment details
    payment_method VARCHAR(20) NOT NULL,
    amount_charged DECIMAL(18,8) NOT NULL,
    currency VARCHAR(10) NOT NULL,  -- 'USD', 'ETH', 'NEXUS'
    amount_usd DECIMAL(18,8),  -- USD equivalent at time of payment

    -- Transaction references
    tx_hash VARCHAR(66),           -- Blockchain tx (ETH/NEXUS)
    stripe_payment_id VARCHAR(100), -- Stripe payment intent
    stripe_session_id VARCHAR(100), -- Stripe checkout session

    -- Status
    status VARCHAR(20) NOT NULL DEFAULT 'pending',

    -- Error tracking
    error_message TEXT,

    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,

    -- Constraints
    CONSTRAINT valid_payment_status CHECK (status IN ('pending', 'processing', 'completed', 'failed', 'refunded', 'cancelled'))
);

CREATE INDEX idx_payments_payer ON payments(payer_address);
CREATE INDEX idx_payments_status ON payments(status);
CREATE INDEX idx_payments_service ON payments(service_code);
CREATE INDEX idx_payments_created ON payments(created_at);
CREATE INDEX idx_payments_stripe_session ON payments(stripe_session_id);

-- KYC verification requests (links payment to Sumsub verification)
CREATE TABLE IF NOT EXISTS kyc_verifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Link to payment
    payment_id UUID REFERENCES payments(id),

    -- User info
    user_address VARCHAR(42) NOT NULL,

    -- Sumsub data
    sumsub_applicant_id VARCHAR(100),
    sumsub_inspection_id VARCHAR(100),
    sumsub_review_status VARCHAR(50),  -- 'init', 'pending', 'completed', etc.
    sumsub_review_result JSONB,  -- Full Sumsub response

    -- Verification status
    status VARCHAR(20) NOT NULL DEFAULT 'pending',

    -- On-chain status
    whitelist_tx_hash VARCHAR(66),  -- Tx that added to whitelist

    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    submitted_at TIMESTAMPTZ,  -- When user completed Sumsub flow
    verified_at TIMESTAMPTZ,   -- When approved
    rejected_at TIMESTAMPTZ,   -- When rejected

    -- Constraints
    CONSTRAINT valid_kyc_status CHECK (status IN ('pending', 'payment_required', 'submitted', 'in_review', 'approved', 'rejected', 'expired'))
);

CREATE INDEX idx_kyc_verifications_user ON kyc_verifications(user_address);
CREATE INDEX idx_kyc_verifications_status ON kyc_verifications(status);
CREATE INDEX idx_kyc_verifications_sumsub ON kyc_verifications(sumsub_applicant_id);

-- ============================================
-- Functions and Triggers
-- ============================================

-- Update timestamp trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to all tables with updated_at
CREATE TRIGGER update_staking_positions_updated_at
    BEFORE UPDATE ON staking_positions
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_token_balances_updated_at
    BEFORE UPDATE ON token_balances
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_proposals_updated_at
    BEFORE UPDATE ON proposals
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_nft_tokens_updated_at
    BEFORE UPDATE ON nft_tokens
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_kyc_registrations_updated_at
    BEFORE UPDATE ON kyc_registrations
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Triggers for new pricing/payment tables
CREATE TRIGGER update_pricing_updated_at
    BEFORE UPDATE ON pricing
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_payment_methods_updated_at
    BEFORE UPDATE ON payment_methods
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_payments_updated_at
    BEFORE UPDATE ON payments
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_kyc_verifications_updated_at
    BEFORE UPDATE ON kyc_verifications
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- Pricing History Auto-Logging
-- ============================================

-- Function to automatically log pricing changes
CREATE OR REPLACE FUNCTION log_pricing_change()
RETURNS TRIGGER AS $$
BEGIN
    -- Only log if price-related fields changed
    IF OLD.price_usd IS DISTINCT FROM NEW.price_usd
       OR OLD.price_eth IS DISTINCT FROM NEW.price_eth
       OR OLD.price_nexus IS DISTINCT FROM NEW.price_nexus
       OR OLD.markup_percent IS DISTINCT FROM NEW.markup_percent THEN

        INSERT INTO pricing_history (
            pricing_id,
            old_price_usd, old_price_eth, old_price_nexus, old_markup_percent,
            new_price_usd, new_price_eth, new_price_nexus, new_markup_percent,
            changed_by, change_reason
        ) VALUES (
            NEW.id,
            OLD.price_usd, OLD.price_eth, OLD.price_nexus, OLD.markup_percent,
            NEW.price_usd, NEW.price_eth, NEW.price_nexus, NEW.markup_percent,
            COALESCE(NEW.updated_by, 'system'),
            'Price update'
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply pricing history trigger
CREATE TRIGGER log_pricing_changes
    AFTER UPDATE ON pricing
    FOR EACH ROW
    EXECUTE FUNCTION log_pricing_change();

-- Trigger for pricing_history updated_at (if records are ever modified)
CREATE TRIGGER update_pricing_history_updated_at
    BEFORE UPDATE ON pricing_history
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- Seed Data (for demo/testing)
-- ============================================

-- Insert demo compliance officer
INSERT INTO compliance_officers (address, added_by) VALUES
    ('0x0000000000000000000000000000000000000001', 'system'),
    ('0x0000000000000000000000000000000000000002', 'system')
ON CONFLICT (address) DO NOTHING;

-- Insert payment methods
INSERT INTO payment_methods (method_code, method_name, is_active, fee_percent, display_order, processor_config) VALUES
    ('nexus', 'NEXUS Token', true, 0, 1, '{"contract": "NexusToken", "discount_percent": 10}'::jsonb),
    ('eth', 'Ethereum (ETH)', true, 0, 2, '{"min_confirmations": 2}'::jsonb),
    ('stripe', 'Credit Card (Stripe)', true, 2.9, 3, '{"currency": "usd", "payment_method_types": ["card"]}'::jsonb)
ON CONFLICT (method_code) DO NOTHING;

-- Insert initial pricing (200% markup as per user decision: $5 Sumsub cost -> $15 charge)
-- ETH prices assume ~$3000/ETH, NEXUS assumes $0.10/token
INSERT INTO pricing (service_code, service_name, description, cost_usd, cost_provider, price_usd, price_eth, price_nexus, markup_percent, is_active) VALUES
    -- KYC verification: $15 USD (cost $5, markup 200%)
    ('kyc_verification', 'KYC Identity Verification', 'Full identity verification with document check and AML screening via Sumsub', 5.00, 'sumsub', 15.00, 0.005, 150, 200.00, true),
    ('kyc_aml_recheck', 'AML Re-screening', 'Periodic AML/sanctions re-check for existing users', 1.00, 'sumsub', 3.00, 0.001, 30, 200.00, true),
    ('kyc_enhanced', 'Enhanced Due Diligence', 'Enhanced verification for high-value accounts', 15.00, 'sumsub', 45.00, 0.015, 450, 200.00, true),
    -- Meta-transaction relay: $0.50 per tx
    ('meta_tx_relay', 'Meta-Transaction Relay', 'Gasless transaction relay fee per meta-transaction', 0.10, 'gas', 0.50, 0.000167, 5, 400.00, true),
    -- NFT minting: $25 USD
    ('nft_mint', 'NFT Minting Fee', 'Platform fee for minting new NFTs (includes gas subsidy)', 5.00, 'platform', 25.00, 0.00833, 250, 400.00, true),
    -- Premium features: $10/month
    ('premium_monthly', 'Premium Features (Monthly)', 'Monthly subscription for premium platform features', 2.00, 'platform', 10.00, 0.00333, 100, 400.00, true),
    -- Governance proposal fee (existing)
    ('governance_proposal', 'Governance Proposal Fee', 'Fee for submitting governance proposals (refundable if passed)', 0, 'platform', 10.00, 0.00333, 100, 0, true)
ON CONFLICT (service_code) DO NOTHING;

-- ============================================
-- Meta-Transactions (ERC-2771 Relayer)
-- ============================================

-- Meta-transaction requests and their status
CREATE TABLE IF NOT EXISTS meta_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Request details
    from_address VARCHAR(42) NOT NULL,       -- Original signer
    to_address VARCHAR(42) NOT NULL,         -- Target contract
    function_name VARCHAR(100) NOT NULL,     -- Human-readable function name
    calldata TEXT NOT NULL,                  -- Encoded function call
    value NUMERIC(78, 0) NOT NULL DEFAULT 0, -- ETH value (usually 0)
    gas_limit BIGINT NOT NULL,               -- Requested gas limit
    nonce BIGINT NOT NULL,                   -- ERC-2771 nonce
    deadline TIMESTAMPTZ NOT NULL,           -- Request expiry

    -- Signature
    signature TEXT NOT NULL,                 -- EIP-712 signature

    -- Execution status
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    tx_hash VARCHAR(66),                     -- Relayed transaction hash
    gas_used BIGINT,                         -- Actual gas used
    gas_price NUMERIC(78, 0),                -- Gas price paid
    relay_cost_eth NUMERIC(18, 18),          -- Cost to relayer in ETH

    -- Error tracking
    error_message TEXT,
    retry_count INT NOT NULL DEFAULT 0,

    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    submitted_at TIMESTAMPTZ,                -- When sent to chain
    confirmed_at TIMESTAMPTZ,                -- When tx confirmed

    -- Constraints
    CONSTRAINT valid_meta_tx_status CHECK (status IN ('pending', 'submitted', 'confirmed', 'failed', 'expired', 'cancelled'))
);

CREATE INDEX idx_meta_tx_from ON meta_transactions(from_address);
CREATE INDEX idx_meta_tx_status ON meta_transactions(status);
CREATE INDEX idx_meta_tx_tx_hash ON meta_transactions(tx_hash);
CREATE INDEX idx_meta_tx_created ON meta_transactions(created_at);

-- Add trigger for updated_at
CREATE TRIGGER update_meta_transactions_updated_at
    BEFORE UPDATE ON meta_transactions
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Grant read access to analytics user
GRANT SELECT ON ALL TABLES IN SCHEMA public TO nexus_readonly;

-- ============================================
-- Final Setup
-- ============================================

-- Analyze tables for query optimization
ANALYZE;

-- Print success message
DO $$
BEGIN
    RAISE NOTICE 'Nexus Protocol database initialized successfully!';
END $$;
