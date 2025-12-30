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

-- ============================================
-- Seed Data (for demo/testing)
-- ============================================

-- Insert demo compliance officer
INSERT INTO compliance_officers (address, added_by) VALUES
    ('0x0000000000000000000000000000000000000001', 'system'),
    ('0x0000000000000000000000000000000000000002', 'system')
ON CONFLICT (address) DO NOTHING;

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
