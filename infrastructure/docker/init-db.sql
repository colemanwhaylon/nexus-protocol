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
-- Governance Configuration Tables (Database-Driven)
-- ============================================

-- Governance configuration parameters
-- Stores all configurable governance settings (threshold, voting period, etc.)
-- This allows changing governance params via DB updates instead of redeploying contracts
CREATE TABLE IF NOT EXISTS governance_config (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    config_key VARCHAR(50) NOT NULL,              -- 'proposal_threshold', 'voting_delay', etc.
    config_name VARCHAR(100) NOT NULL,            -- Display name
    description TEXT,

    -- Value storage (flexible for different types)
    value_wei NUMERIC(78, 0),                     -- Wei value for token amounts (e.g., 100 NXS = 100 * 10^18)
    value_number BIGINT,                          -- Numeric value (blocks, seconds, etc.)
    value_percent DECIMAL(10, 4),                 -- Percentage value (e.g., 4.0000 for 4%)
    value_string VARCHAR(255),                    -- String value for any other config

    -- Value type for frontend display
    value_type VARCHAR(20) NOT NULL,              -- 'wei', 'blocks', 'seconds', 'percent', 'string'
    unit_label VARCHAR(20),                       -- 'NXS', 'blocks', 'seconds', '%', etc.

    -- Chain-specific (governance params may differ per network)
    chain_id BIGINT NOT NULL,  -- Network chain ID (31337=localhost, 11155111=sepolia)

    -- Sync status with smart contract
    contract_synced BOOLEAN NOT NULL DEFAULT FALSE,
    last_sync_tx VARCHAR(66),                     -- Tx hash of last sync to contract
    last_sync_at TIMESTAMPTZ,

    -- Status
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by VARCHAR(42),                       -- Admin address who made change

    -- Unique constraint: one config key per chain
    CONSTRAINT governance_config_key_chain_unique UNIQUE (config_key, chain_id)
);

CREATE INDEX idx_governance_config_key ON governance_config(config_key);
CREATE INDEX idx_governance_config_chain ON governance_config(chain_id);
CREATE INDEX idx_governance_config_active ON governance_config(is_active);
CREATE INDEX idx_governance_config_synced ON governance_config(contract_synced);

-- Governance config history for audit trail
CREATE TABLE IF NOT EXISTS governance_config_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    governance_config_id UUID NOT NULL REFERENCES governance_config(id) ON DELETE CASCADE,

    -- Previous values
    old_value_wei NUMERIC(78, 0),
    old_value_number BIGINT,
    old_value_percent DECIMAL(10, 4),
    old_value_string VARCHAR(255),

    -- New values
    new_value_wei NUMERIC(78, 0),
    new_value_number BIGINT,
    new_value_percent DECIMAL(10, 4),
    new_value_string VARCHAR(255),

    -- Sync status at time of change
    was_synced BOOLEAN,
    sync_tx VARCHAR(66),

    -- Who and when
    changed_by VARCHAR(42) NOT NULL,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    change_reason TEXT,

    -- Audit timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_governance_config_history_config ON governance_config_history(governance_config_id);
CREATE INDEX idx_governance_config_history_changed_at ON governance_config_history(changed_at);

-- ============================================
-- Application Configuration (Unified Static Config)
-- ============================================

-- General application configuration table
-- Stores all configurable values that don't fit in specialized tables
-- Uses namespace + key pattern for flexible configuration
CREATE TABLE IF NOT EXISTS app_config (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    namespace VARCHAR(50) NOT NULL,              -- 'nft', 'token', 'staking', 'kyc', 'relayer', 'api'
    config_key VARCHAR(100) NOT NULL,            -- 'mint_price', 'max_supply', etc.
    value_type VARCHAR(20) NOT NULL,             -- 'string', 'number', 'wei', 'address', 'boolean', 'json'

    -- Value storage (use appropriate column based on value_type)
    value_string TEXT,                           -- For strings, addresses, URLs, JSON
    value_number BIGINT,                         -- For integers
    value_wei NUMERIC(78, 0),                    -- For wei amounts (up to 2^256)
    value_boolean BOOLEAN,                       -- For boolean flags

    -- Metadata
    description TEXT,                            -- Human-readable description
    is_secret BOOLEAN NOT NULL DEFAULT FALSE,    -- If true, mask in UI
    is_active BOOLEAN NOT NULL DEFAULT TRUE,     -- Soft delete

    -- Chain-specific (some configs may differ per network)
    chain_id BIGINT NOT NULL DEFAULT 0,          -- 0 = all chains, otherwise specific chain

    -- Audit
    updated_by VARCHAR(42),                      -- Admin address who changed it
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Unique constraint: one config key per namespace per chain
    CONSTRAINT app_config_namespace_key_chain_unique UNIQUE (namespace, config_key, chain_id)
);

CREATE INDEX idx_app_config_namespace ON app_config(namespace);
CREATE INDEX idx_app_config_key ON app_config(config_key);
CREATE INDEX idx_app_config_chain ON app_config(chain_id);
CREATE INDEX idx_app_config_active ON app_config(is_active);

-- App config history for audit trail
CREATE TABLE IF NOT EXISTS app_config_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    app_config_id UUID NOT NULL REFERENCES app_config(id) ON DELETE CASCADE,

    -- Previous values
    old_value_string TEXT,
    old_value_number BIGINT,
    old_value_wei NUMERIC(78, 0),
    old_value_boolean BOOLEAN,

    -- New values
    new_value_string TEXT,
    new_value_number BIGINT,
    new_value_wei NUMERIC(78, 0),
    new_value_boolean BOOLEAN,

    -- Who and when
    changed_by VARCHAR(42) NOT NULL,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    change_reason TEXT,

    -- Audit timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_app_config_history_config ON app_config_history(app_config_id);
CREATE INDEX idx_app_config_history_changed_at ON app_config_history(changed_at);

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

-- Triggers for governance config tables
CREATE TRIGGER update_governance_config_updated_at
    BEFORE UPDATE ON governance_config
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_governance_config_history_updated_at
    BEFORE UPDATE ON governance_config_history
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Triggers for app_config tables
CREATE TRIGGER update_app_config_updated_at
    BEFORE UPDATE ON app_config
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- App Config History Auto-Logging
-- ============================================

-- Function to automatically log app config changes
CREATE OR REPLACE FUNCTION log_app_config_change()
RETURNS TRIGGER AS $$
BEGIN
    -- Only log if value-related fields changed
    IF OLD.value_string IS DISTINCT FROM NEW.value_string
       OR OLD.value_number IS DISTINCT FROM NEW.value_number
       OR OLD.value_wei IS DISTINCT FROM NEW.value_wei
       OR OLD.value_boolean IS DISTINCT FROM NEW.value_boolean THEN

        INSERT INTO app_config_history (
            app_config_id,
            old_value_string, old_value_number, old_value_wei, old_value_boolean,
            new_value_string, new_value_number, new_value_wei, new_value_boolean,
            changed_by, change_reason
        ) VALUES (
            NEW.id,
            OLD.value_string, OLD.value_number, OLD.value_wei, OLD.value_boolean,
            NEW.value_string, NEW.value_number, NEW.value_wei, NEW.value_boolean,
            COALESCE(NEW.updated_by, 'system'),
            'Config update'
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply app config history trigger
CREATE TRIGGER log_app_config_changes
    AFTER UPDATE ON app_config
    FOR EACH ROW
    EXECUTE FUNCTION log_app_config_change();

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
-- Governance Config History Auto-Logging
-- ============================================

-- Function to automatically log governance config changes
CREATE OR REPLACE FUNCTION log_governance_config_change()
RETURNS TRIGGER AS $$
BEGIN
    -- Only log if value-related fields changed
    IF OLD.value_wei IS DISTINCT FROM NEW.value_wei
       OR OLD.value_number IS DISTINCT FROM NEW.value_number
       OR OLD.value_percent IS DISTINCT FROM NEW.value_percent
       OR OLD.value_string IS DISTINCT FROM NEW.value_string THEN

        INSERT INTO governance_config_history (
            governance_config_id,
            old_value_wei, old_value_number, old_value_percent, old_value_string,
            new_value_wei, new_value_number, new_value_percent, new_value_string,
            was_synced, sync_tx,
            changed_by, change_reason
        ) VALUES (
            NEW.id,
            OLD.value_wei, OLD.value_number, OLD.value_percent, OLD.value_string,
            NEW.value_wei, NEW.value_number, NEW.value_percent, NEW.value_string,
            OLD.contract_synced, OLD.last_sync_tx,
            COALESCE(NEW.updated_by, 'system'),
            'Governance config update'
        );

        -- Reset sync status when value changes
        NEW.contract_synced := FALSE;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply governance config history trigger (BEFORE so we can reset sync status)
CREATE TRIGGER log_governance_config_changes
    BEFORE UPDATE ON governance_config
    FOR EACH ROW
    EXECUTE FUNCTION log_governance_config_change();

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

-- Insert governance config seed data for localhost (31337)
-- Demo-friendly values: 100 NXS threshold instead of 100,000 NXS
INSERT INTO governance_config (config_key, config_name, description, value_wei, value_number, value_percent, value_type, unit_label, chain_id, is_active)
VALUES
    -- Proposal threshold: 100 NXS (100 * 10^18 wei) - demo-friendly
    ('proposal_threshold', 'Proposal Threshold', 'Minimum tokens required to create a governance proposal', 100000000000000000000, NULL, NULL, 'wei', 'NXS', 31337, true),
    -- Voting delay: 1 block - proposals go active almost immediately
    ('voting_delay', 'Voting Delay', 'Number of blocks after proposal creation before voting starts', NULL, 1, NULL, 'blocks', 'blocks', 31337, true),
    -- Voting period: 100 blocks - short for demo (~20 minutes on mainnet, instant on localhost)
    ('voting_period', 'Voting Period', 'Number of blocks that voting remains open', NULL, 100, NULL, 'blocks', 'blocks', 31337, true),
    -- Quorum: 4% of total supply must vote for proposal to pass
    ('quorum_percent', 'Quorum Percentage', 'Minimum percentage of total supply that must vote for a proposal to be valid', NULL, NULL, 4.0000, 'percent', '%', 31337, true),
    -- Timelock delay: 60 seconds - fast for demo
    ('timelock_delay', 'Timelock Delay', 'Seconds to wait after proposal passes before it can be executed', NULL, 60, NULL, 'seconds', 'sec', 31337, true)
ON CONFLICT ON CONSTRAINT governance_config_key_chain_unique DO NOTHING;

-- Insert governance config seed data for Sepolia (11155111)
-- Same demo-friendly values for testnet
INSERT INTO governance_config (config_key, config_name, description, value_wei, value_number, value_percent, value_type, unit_label, chain_id, is_active)
VALUES
    ('proposal_threshold', 'Proposal Threshold', 'Minimum tokens required to create a governance proposal', 100000000000000000000, NULL, NULL, 'wei', 'NXS', 11155111, true),
    ('voting_delay', 'Voting Delay', 'Number of blocks after proposal creation before voting starts', NULL, 1, NULL, 'blocks', 'blocks', 11155111, true),
    ('voting_period', 'Voting Period', 'Number of blocks that voting remains open', NULL, 100, NULL, 'blocks', 'blocks', 11155111, true),
    ('quorum_percent', 'Quorum Percentage', 'Minimum percentage of total supply that must vote for a proposal to be valid', NULL, NULL, 4.0000, 'percent', '%', 11155111, true),
    ('timelock_delay', 'Timelock Delay', 'Seconds to wait after proposal passes before it can be executed', NULL, 60, NULL, 'seconds', 'sec', 11155111, true)
ON CONFLICT ON CONSTRAINT governance_config_key_chain_unique DO NOTHING;

-- ============================================
-- App Config Seed Data (Unified Static Config)
-- ============================================

-- NFT Configuration (chain_id = 0 means applies to all chains)
INSERT INTO app_config (namespace, config_key, value_type, value_wei, description, chain_id) VALUES
    ('nft', 'mint_price', 'wei', 10000000000000000, 'NFT mint price in wei (0.01 ETH for testnet)', 11155111),
    ('nft', 'mint_price', 'wei', 100000000000000000, 'NFT mint price in wei (0.1 ETH for mainnet)', 1)
ON CONFLICT ON CONSTRAINT app_config_namespace_key_chain_unique DO NOTHING;

INSERT INTO app_config (namespace, config_key, value_type, value_number, description, chain_id) VALUES
    ('nft', 'max_supply', 'number', 10000, 'Maximum NFT collection supply', 0),
    ('nft', 'royalty_bps', 'number', 500, 'Royalty in basis points (500 = 5%)', 0),
    ('nft', 'max_per_wallet', 'number', 5, 'Maximum NFTs per wallet during public sale', 0)
ON CONFLICT ON CONSTRAINT app_config_namespace_key_chain_unique DO NOTHING;

INSERT INTO app_config (namespace, config_key, value_type, value_string, description, chain_id) VALUES
    ('nft', 'base_uri', 'string', 'https://nexus.dapp.academy/metadata/', 'NFT metadata base URI', 0),
    ('nft', 'contract_uri', 'string', 'https://nexus.dapp.academy/contract-metadata.json', 'OpenSea collection metadata URI', 0),
    ('nft', 'royalty_receiver', 'address', '0xFc9019b7e35A480445b6Ea50Ab9049dca20695Ab', 'Royalty payment receiver address', 0)
ON CONFLICT ON CONSTRAINT app_config_namespace_key_chain_unique DO NOTHING;

-- Token Configuration
INSERT INTO app_config (namespace, config_key, value_type, value_wei, description, chain_id) VALUES
    ('token', 'total_supply', 'wei', 100000000000000000000000000, 'Total token supply in wei (100M tokens)', 0),
    ('token', 'initial_liquidity', 'wei', 10000000000000000000000000, 'Initial liquidity pool allocation (10M tokens)', 0)
ON CONFLICT ON CONSTRAINT app_config_namespace_key_chain_unique DO NOTHING;

INSERT INTO app_config (namespace, config_key, value_type, value_string, description, chain_id) VALUES
    ('token', 'treasury_address', 'address', '0xFc9019b7e35A480445b6Ea50Ab9049dca20695Ab', 'Treasury wallet address', 0)
ON CONFLICT ON CONSTRAINT app_config_namespace_key_chain_unique DO NOTHING;

-- Staking Configuration
INSERT INTO app_config (namespace, config_key, value_type, value_number, description, chain_id) VALUES
    ('staking', 'unbonding_days', 'number', 7, 'Unbonding period in days', 0),
    ('staking', 'min_stake_amount', 'number', 100, 'Minimum stake amount in tokens', 0),
    ('staking', 'max_validators', 'number', 100, 'Maximum number of validators', 0)
ON CONFLICT ON CONSTRAINT app_config_namespace_key_chain_unique DO NOTHING;

INSERT INTO app_config (namespace, config_key, value_type, value_wei, description, chain_id) VALUES
    ('staking', 'min_stake_wei', 'wei', 100000000000000000000, 'Minimum stake in wei (100 tokens)', 0)
ON CONFLICT ON CONSTRAINT app_config_namespace_key_chain_unique DO NOTHING;

-- Relayer Configuration
INSERT INTO app_config (namespace, config_key, value_type, value_number, description, chain_id) VALUES
    ('relayer', 'gas_price_multiplier', 'number', 120, 'Gas price multiplier in percent (120 = 1.2x)', 0),
    ('relayer', 'max_gas_price_gwei', 'number', 100, 'Maximum gas price in gwei', 0),
    ('relayer', 'min_gas_price_gwei', 'number', 1, 'Minimum gas price in gwei', 0),
    ('relayer', 'max_retries', 'number', 3, 'Maximum retry attempts for failed transactions', 0),
    ('relayer', 'tx_timeout_seconds', 'number', 120, 'Transaction confirmation timeout in seconds', 0)
ON CONFLICT ON CONSTRAINT app_config_namespace_key_chain_unique DO NOTHING;

-- API Configuration
INSERT INTO app_config (namespace, config_key, value_type, value_string, description, chain_id) VALUES
    ('api', 'metadata_base_url', 'string', 'https://nexus.dapp.academy', 'Base URL for metadata and API', 0),
    ('api', 'cors_origins', 'json', '["https://nexus.dapp.academy", "http://localhost:3000"]', 'Allowed CORS origins (JSON array)', 0)
ON CONFLICT ON CONSTRAINT app_config_namespace_key_chain_unique DO NOTHING;

INSERT INTO app_config (namespace, config_key, value_type, value_number, description, chain_id) VALUES
    ('api', 'rate_limit_per_minute', 'number', 60, 'API rate limit per minute per IP', 0),
    ('api', 'max_page_size', 'number', 100, 'Maximum page size for paginated endpoints', 0)
ON CONFLICT ON CONSTRAINT app_config_namespace_key_chain_unique DO NOTHING;

-- KYC Configuration
INSERT INTO app_config (namespace, config_key, value_type, value_number, description, chain_id) VALUES
    ('kyc', 'verification_expiry_days', 'number', 365, 'Days until KYC verification expires', 0),
    ('kyc', 'max_daily_verifications', 'number', 1000, 'Maximum KYC verifications per day', 0)
ON CONFLICT ON CONSTRAINT app_config_namespace_key_chain_unique DO NOTHING;

INSERT INTO app_config (namespace, config_key, value_type, value_boolean, description, chain_id) VALUES
    ('kyc', 'require_kyc_for_staking', 'boolean', false, 'Require KYC to stake tokens', 0),
    ('kyc', 'require_kyc_for_governance', 'boolean', false, 'Require KYC to participate in governance', 0)
ON CONFLICT ON CONSTRAINT app_config_namespace_key_chain_unique DO NOTHING;

INSERT INTO app_config (namespace, config_key, value_type, value_string, description, chain_id) VALUES
    ('kyc', 'sumsub_base_url', 'string', 'https://api.sumsub.com', 'Sumsub API base URL', 0),
    ('kyc', 'sumsub_level_name', 'string', 'basic-kyc-level', 'Sumsub KYC verification level name', 0)
ON CONFLICT ON CONSTRAINT app_config_namespace_key_chain_unique DO NOTHING;

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
-- Contract Address Management (Database-Driven)
-- ============================================

-- Network configurations
-- Stores per-network settings (deployer address, RPC URL, etc.)
CREATE TABLE IF NOT EXISTS network_config (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    chain_id BIGINT NOT NULL UNIQUE,
    network_name VARCHAR(50) NOT NULL UNIQUE,     -- 'localhost', 'sepolia', 'mainnet'
    display_name VARCHAR(100) NOT NULL,           -- 'Local Development', 'Sepolia Testnet'
    rpc_url VARCHAR(255),
    explorer_url VARCHAR(255),
    default_deployer VARCHAR(42),                 -- Default deployer address for this network
    is_testnet BOOLEAN NOT NULL DEFAULT TRUE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_network_config_chain ON network_config(chain_id);
CREATE INDEX idx_network_config_name ON network_config(network_name);
CREATE INDEX idx_network_config_active ON network_config(is_active);

-- Contract name mappings
-- Maps Solidity contract names to database keys
-- Allows adding new contracts without code changes
CREATE TABLE IF NOT EXISTS contract_mappings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    solidity_name VARCHAR(100) NOT NULL UNIQUE,   -- 'NexusToken', 'NexusStaking'
    db_name VARCHAR(50) NOT NULL UNIQUE,          -- 'nexusToken', 'nexusStaking'
    display_name VARCHAR(100) NOT NULL,           -- 'Nexus Token', 'Nexus Staking'
    category VARCHAR(50) NOT NULL,                -- 'core', 'defi', 'governance', 'security', 'metatx'
    description TEXT,
    is_required BOOLEAN NOT NULL DEFAULT TRUE,    -- Must be deployed for app to work
    sort_order INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_contract_mappings_solidity ON contract_mappings(solidity_name);
CREATE INDEX idx_contract_mappings_db ON contract_mappings(db_name);
CREATE INDEX idx_contract_mappings_category ON contract_mappings(category);

-- Contract addresses
-- Stores deployed contract addresses per network
CREATE TABLE IF NOT EXISTS contract_addresses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    chain_id BIGINT NOT NULL REFERENCES network_config(chain_id),
    contract_mapping_id UUID NOT NULL REFERENCES contract_mappings(id),
    address VARCHAR(42) NOT NULL,
    deployment_tx_hash VARCHAR(66),
    deployment_block BIGINT,
    abi_version VARCHAR(20) DEFAULT '1.0.0',
    status VARCHAR(20) NOT NULL DEFAULT 'active',
    is_primary BOOLEAN NOT NULL DEFAULT TRUE,
    deployed_by VARCHAR(42),
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT contract_addresses_status_check CHECK (status IN ('active', 'deprecated', 'paused'))
);

-- Partial unique index: only one primary address per chain+contract
CREATE UNIQUE INDEX IF NOT EXISTS idx_contract_addresses_unique_active
    ON contract_addresses(chain_id, contract_mapping_id)
    WHERE is_primary = TRUE;

CREATE INDEX idx_contract_addresses_chain ON contract_addresses(chain_id);
CREATE INDEX idx_contract_addresses_mapping ON contract_addresses(contract_mapping_id);
CREATE INDEX idx_contract_addresses_status ON contract_addresses(status);
CREATE INDEX idx_contract_addresses_primary ON contract_addresses(is_primary);

-- Contract addresses history
-- Audit trail for address changes
CREATE TABLE IF NOT EXISTS contract_addresses_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    contract_id UUID NOT NULL REFERENCES contract_addresses(id) ON DELETE CASCADE,
    old_address VARCHAR(42),
    new_address VARCHAR(42) NOT NULL,
    change_reason VARCHAR(255),
    changed_by VARCHAR(42) NOT NULL,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_contract_history_contract ON contract_addresses_history(contract_id);
CREATE INDEX idx_contract_history_changed_at ON contract_addresses_history(changed_at);

-- Triggers for contract management tables
CREATE TRIGGER update_network_config_updated_at
    BEFORE UPDATE ON network_config
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_contract_addresses_updated_at
    BEFORE UPDATE ON contract_addresses
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to log contract address changes
CREATE OR REPLACE FUNCTION log_contract_address_change()
RETURNS TRIGGER AS $$
BEGIN
    -- Log when address changes
    IF OLD.address IS DISTINCT FROM NEW.address THEN
        INSERT INTO contract_addresses_history (
            contract_id,
            old_address,
            new_address,
            change_reason,
            changed_by
        ) VALUES (
            NEW.id,
            OLD.address,
            NEW.address,
            'Address update',
            COALESCE(NEW.deployed_by, 'system')
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER log_contract_address_changes
    AFTER UPDATE ON contract_addresses
    FOR EACH ROW
    EXECUTE FUNCTION log_contract_address_change();

-- ============================================
-- Contract Management Seed Data
-- ============================================

-- Seed data: Network configurations
INSERT INTO network_config (chain_id, network_name, display_name, rpc_url, explorer_url, default_deployer, is_testnet, is_active)
VALUES
    (31337, 'localhost', 'Local Development (Anvil)', 'http://localhost:8545', NULL, '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266', TRUE, TRUE),
    (11155111, 'sepolia', 'Sepolia Testnet', NULL, 'https://sepolia.etherscan.io', NULL, TRUE, TRUE),
    (1, 'mainnet', 'Ethereum Mainnet', NULL, 'https://etherscan.io', NULL, FALSE, FALSE),
    (137, 'polygon', 'Polygon Mainnet', 'https://polygon-rpc.com', 'https://polygonscan.com', NULL, FALSE, FALSE),
    (80002, 'amoy', 'Polygon Amoy Testnet', 'https://rpc-amoy.polygon.technology', 'https://amoy.polygonscan.com', NULL, TRUE, FALSE),
    (42161, 'arbitrum', 'Arbitrum One', 'https://arb1.arbitrum.io/rpc', 'https://arbiscan.io', NULL, FALSE, FALSE),
    (421614, 'arbitrum-sepolia', 'Arbitrum Sepolia', 'https://sepolia-rollup.arbitrum.io/rpc', 'https://sepolia.arbiscan.io', NULL, TRUE, FALSE),
    (10, 'optimism', 'Optimism', 'https://mainnet.optimism.io', 'https://optimistic.etherscan.io', NULL, FALSE, FALSE),
    (11155420, 'optimism-sepolia', 'Optimism Sepolia', 'https://sepolia.optimism.io', 'https://sepolia-optimism.etherscan.io', NULL, TRUE, FALSE),
    (8453, 'base', 'Base', 'https://mainnet.base.org', 'https://basescan.org', NULL, FALSE, FALSE)
ON CONFLICT (chain_id) DO NOTHING;

-- Seed data: Contract mappings
INSERT INTO contract_mappings (solidity_name, db_name, display_name, category, description, is_required, sort_order)
VALUES
    ('NexusToken', 'nexusToken', 'Nexus Token', 'core', 'ERC-20 governance token with snapshot, permit, votes', TRUE, 1),
    ('NexusStaking', 'nexusStaking', 'Nexus Staking', 'defi', 'Token staking with rewards and delegation', TRUE, 2),
    ('NexusNFT', 'nexusNFT', 'Nexus NFT', 'core', 'ERC-721A NFT collection with royalties', TRUE, 3),
    ('NexusAccessControl', 'nexusAccessControl', 'Access Control', 'security', 'Role-based access control (ADMIN, OPERATOR, COMPLIANCE, PAUSER)', TRUE, 4),
    ('NexusKYCRegistry', 'nexusKYC', 'KYC Registry', 'security', 'Whitelist/blacklist management for compliance', TRUE, 5),
    ('NexusEmergency', 'nexusEmergency', 'Emergency', 'security', 'Circuit breakers and global pause functionality', TRUE, 6),
    ('NexusTimelock', 'nexusTimelock', 'Timelock', 'governance', 'Governance execution delay (24h minimum)', TRUE, 7),
    ('NexusGovernor', 'nexusGovernor', 'Governor', 'governance', 'DAO governance with proposal/vote system', TRUE, 8),
    ('NexusForwarder', 'nexusForwarder', 'Forwarder', 'metatx', 'ERC-2771 meta-transactions for gasless UX', FALSE, 9),
    ('RewardsDistributor', 'rewardsDistributor', 'Rewards Distributor', 'defi', 'Merkle-based reward distribution', FALSE, 10)
ON CONFLICT (solidity_name) DO NOTHING;

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
