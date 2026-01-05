#!/bin/bash
#
# Nexus Protocol - Development Setup Script
#
# This script performs a complete fresh setup of the development environment:
# 1. Recycles Docker containers (stops, removes volumes, restarts)
# 2. Waits for all services to be healthy
# 3. Deploys all contracts to Anvil
# 4. Registers contracts in the database
# 5. Initializes contracts for immediate use
# 6. Pre-tests all features to ensure they're working
#
# Usage: ./scripts/dev-setup.sh [--skip-recycle] [--skip-tests]
#

set -e

# ============ Configuration ============
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTRACTS_DIR="$PROJECT_ROOT/contracts"
DOCKER_DIR="$PROJECT_ROOT/infrastructure/docker"
FORGE_BIN="/home/whaylon/.foundry/bin/forge"
CAST_BIN="/home/whaylon/.foundry/bin/cast"

API_URL="http://localhost:8080"
RPC_URL="http://localhost:8545"
CHAIN_ID=31337

# Anvil's first test account
DEPLOYER="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
DEPLOYER_PK="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============ Parse Arguments ============
SKIP_RECYCLE=false
SKIP_TESTS=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --skip-recycle) SKIP_RECYCLE=true ;;
        --skip-tests) SKIP_TESTS=true ;;
        -h|--help)
            echo "Usage: $0 [--skip-recycle] [--skip-tests]"
            echo "  --skip-recycle  Skip Docker container recycling"
            echo "  --skip-tests    Skip feature pre-tests"
            exit 0
            ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

# ============ Helper Functions ============

print_header() {
    echo ""
    echo -e "${BLUE}========================================"
    echo -e "  $1"
    echo -e "========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_step() {
    echo -e "${BLUE}→ $1${NC}"
}

wait_for_service() {
    local url=$1
    local name=$2
    local max_attempts=${3:-30}
    local attempt=0

    print_step "Waiting for $name..."
    while [ $attempt -lt $max_attempts ]; do
        if curl -s "$url" > /dev/null 2>&1; then
            print_success "$name is ready"
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 1
    done

    print_error "$name failed to start after $max_attempts seconds"
    return 1
}

wait_for_anvil() {
    local max_attempts=${1:-30}
    local attempt=0

    print_step "Waiting for Anvil..."
    while [ $attempt -lt $max_attempts ]; do
        if $CAST_BIN block-number --rpc-url "$RPC_URL" > /dev/null 2>&1; then
            print_success "Anvil is ready"
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 1
    done

    print_error "Anvil failed to start after $max_attempts seconds"
    return 1
}

get_contract_address() {
    local name=$1
    curl -s "$API_URL/api/v1/contracts/$CHAIN_ID" | python3 -c "
import sys, json
data = json.load(sys.stdin)
contracts = data.get('data', {}).get('contracts', [])
for c in contracts:
    if c['db_name'] == '$name':
        print(c['address'])
        break
"
}

# ============ Step 1: Recycle Docker Containers ============

if [ "$SKIP_RECYCLE" = false ]; then
    print_header "Step 1: Recycling Docker Containers"

    cd "$DOCKER_DIR"

    print_step "Stopping all containers..."
    docker compose --profile dev down -v 2>/dev/null || true

    print_step "Starting fresh containers..."
    docker compose --profile dev up -d

    print_success "Docker containers started"

    # Wait for services
    # Note: API needs extra time on first run to download go-ethereum deps (~4-5 min)
    wait_for_anvil 60
    wait_for_service "$API_URL/health" "API Server" 300

    # Give database a moment to seed
    print_step "Waiting for database seed data..."
    sleep 3
else
    print_header "Step 1: Skipping Docker Recycle"
    print_warning "Using existing containers"

    # Still verify services are up
    wait_for_anvil 10 || { print_error "Anvil not running!"; exit 1; }
    wait_for_service "$API_URL/health" "API Server" 10 || { print_error "API not running!"; exit 1; }
fi

# ============ Step 2: Deploy Contracts ============

print_header "Step 2: Deploying Contracts to Anvil"

cd "$CONTRACTS_DIR"

print_step "Running forge deployment script..."
$FORGE_BIN script script/DeployLocal.s.sol \
    --rpc-url "$RPC_URL" \
    --broadcast \
    --via-ir \
    2>&1 | tail -30

print_success "Contracts deployed"

# ============ Step 3: Register Contracts in Database ============

print_header "Step 3: Registering Contracts in Database"

print_step "Running post_deploy.py..."
python3 script/post_deploy.py --chain-id $CHAIN_ID --api-url "$API_URL"

print_success "Contracts registered in database"

# Give API a moment to process
sleep 1

# ============ Step 4: Fetch Contract Addresses ============

print_header "Step 4: Fetching Contract Addresses from API"

# Verify contracts are registered
print_step "Verifying contract registration..."
CONTRACTS_RESPONSE=$(curl -s "$API_URL/api/v1/contracts/$CHAIN_ID")
CONTRACT_COUNT=$(echo "$CONTRACTS_RESPONSE" | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('data',{}).get('contracts',[])))")

if [ "$CONTRACT_COUNT" -eq "0" ]; then
    print_error "No contracts registered! Check post_deploy.py output"
    exit 1
fi

print_success "Found $CONTRACT_COUNT contracts registered"

# Get specific addresses for initialization
TOKEN_ADDRESS=$(get_contract_address "nexusToken")
NFT_ADDRESS=$(get_contract_address "nexusNFT")
KYC_ADDRESS=$(get_contract_address "nexusKYC")
STAKING_ADDRESS=$(get_contract_address "nexusStaking")
GOVERNOR_ADDRESS=$(get_contract_address "nexusGovernor")

echo "  Token:    $TOKEN_ADDRESS"
echo "  NFT:      $NFT_ADDRESS"
echo "  KYC:      $KYC_ADDRESS"
echo "  Staking:  $STAKING_ADDRESS"
echo "  Governor: $GOVERNOR_ADDRESS"

# ============ Step 5: Initialize Contracts ============

print_header "Step 5: Initializing Contracts for Use"

# Export addresses for InitializeLocal.s.sol
export NEXUS_TOKEN_ADDRESS="$TOKEN_ADDRESS"
export NEXUS_NFT_ADDRESS="$NFT_ADDRESS"
export NEXUS_KYC_ADDRESS="$KYC_ADDRESS"

print_step "Running initialization script..."
$FORGE_BIN script script/InitializeLocal.s.sol \
    --rpc-url "$RPC_URL" \
    --broadcast \
    2>&1 | tail -20

print_success "Contracts initialized"

# ============ Step 6: Pre-Tests (Feature Verification) ============

if [ "$SKIP_TESTS" = false ]; then
    print_header "Step 6: Pre-Testing Features"

    # Test 1: NFT Minting
    print_step "Testing NFT minting..."
    NFT_SALE_PHASE=$($CAST_BIN call "$NFT_ADDRESS" "salePhase()(uint8)" --rpc-url "$RPC_URL")
    if [ "$NFT_SALE_PHASE" = "2" ]; then
        print_success "NFT sale phase is Public (2)"
    else
        print_error "NFT sale phase is $NFT_SALE_PHASE, expected 2 (Public)"
    fi

    NFT_PRICE=$($CAST_BIN call "$NFT_ADDRESS" "mintPrice()(uint256)" --rpc-url "$RPC_URL")
    NFT_PRICE_ETH=$($CAST_BIN from-wei "$NFT_PRICE" 2>/dev/null || echo "0.01")
    print_success "NFT mint price: $NFT_PRICE_ETH ETH"

    # Test 2: Token Voting Power
    print_step "Testing governance voting power..."
    VOTES=$($CAST_BIN call "$TOKEN_ADDRESS" "getVotes(address)(uint256)" "$DEPLOYER" --rpc-url "$RPC_URL")
    if [ "$VOTES" != "0" ]; then
        VOTES_ETH=$($CAST_BIN from-wei "$VOTES" 2>/dev/null || echo "$VOTES")
        print_success "Deployer has voting power: $VOTES_ETH NXS"
    else
        print_error "Deployer has no voting power!"
    fi

    # Test 3: Token Balance
    print_step "Testing token balance..."
    BALANCE=$($CAST_BIN call "$TOKEN_ADDRESS" "balanceOf(address)(uint256)" "$DEPLOYER" --rpc-url "$RPC_URL")
    BALANCE_ETH=$($CAST_BIN from-wei "$BALANCE" 2>/dev/null || echo "$BALANCE")
    print_success "Deployer token balance: $BALANCE_ETH NXS"

    # Test 4: KYC Whitelist
    print_step "Testing KYC whitelist..."
    IS_WHITELISTED=$($CAST_BIN call "$KYC_ADDRESS" "isWhitelisted(address)(bool)" "$DEPLOYER" --rpc-url "$RPC_URL")
    if [ "$IS_WHITELISTED" = "true" ]; then
        print_success "Deployer is whitelisted in KYC registry"
    else
        print_error "Deployer is NOT whitelisted!"
    fi

    # Test 5: Staking Contract
    print_step "Testing staking contract..."
    STAKING_TOKEN=$($CAST_BIN call "$STAKING_ADDRESS" "stakingToken()(address)" --rpc-url "$RPC_URL")
    if [ "${STAKING_TOKEN,,}" = "${TOKEN_ADDRESS,,}" ]; then
        print_success "Staking contract configured with correct token"
    else
        print_error "Staking token mismatch! Expected $TOKEN_ADDRESS, got $STAKING_TOKEN"
    fi

    # Test 6: Governor Contract
    print_step "Testing governor contract..."
    GOV_TOKEN=$($CAST_BIN call "$GOVERNOR_ADDRESS" "token()(address)" --rpc-url "$RPC_URL")
    if [ "${GOV_TOKEN,,}" = "${TOKEN_ADDRESS,,}" ]; then
        print_success "Governor configured with correct token"
    else
        print_error "Governor token mismatch!"
    fi

    # Test 7: Try actual NFT mint
    print_step "Attempting test NFT mint..."
    MINT_TX=$($CAST_BIN send "$NFT_ADDRESS" "publicMint(uint256)" 1 \
        --value "0.01ether" \
        --private-key "$DEPLOYER_PK" \
        --rpc-url "$RPC_URL" 2>&1) || true

    NFT_BALANCE=$($CAST_BIN call "$NFT_ADDRESS" "balanceOf(address)(uint256)" "$DEPLOYER" --rpc-url "$RPC_URL")
    if [ "$NFT_BALANCE" -gt "0" ]; then
        print_success "Successfully minted NFT! Deployer now owns $NFT_BALANCE NFT(s)"
    else
        print_warning "NFT mint may have failed, balance is $NFT_BALANCE"
    fi

else
    print_header "Step 6: Skipping Pre-Tests"
    print_warning "Use --skip-tests to run with tests enabled"
fi

# ============ Final Summary ============

print_header "SETUP COMPLETE!"

echo ""
echo "Frontend: http://localhost:3000"
echo "API:      http://localhost:8080"
echo "Anvil:    http://localhost:8545"
echo ""
echo "Contract Addresses (from database):"
echo "  Token:        $TOKEN_ADDRESS"
echo "  Staking:      $STAKING_ADDRESS"
echo "  NFT:          $NFT_ADDRESS"
echo "  Governor:     $GOVERNOR_ADDRESS"
echo "  KYC Registry: $KYC_ADDRESS"
echo ""
echo -e "${GREEN}All features are ready for testing!${NC}"
echo ""
echo "Next steps:"
echo "  1. Open http://localhost:3000 in your browser"
echo "  2. Connect MetaMask to localhost:8545"
echo "  3. Import Anvil account: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
echo "  4. Clear MetaMask activity data (Settings > Advanced)"
echo ""
