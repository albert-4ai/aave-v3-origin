#!/bin/bash

# Script to list USDC token in Aave Pool on Sepolia testnet with pre-deployment checks
# This script performs comprehensive diagnostic checks before listing USDC
# Usage: ./deploy/scripts/list-usdc-sepolia.sh [1]
#   - Without arguments: Interactive mode (prompts for confirmation)
#   - With '1' argument: Non-interactive mode (automatic execution)

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== List USDC on Sepolia Testnet ===${NC}"
echo ""

# Parse command line arguments
NON_INTERACTIVE=""
if [ $# -eq 1 ] && [ "$1" = "1" ]; then
    NON_INTERACTIVE=1
    echo -e "${BLUE}Running in non-interactive mode${NC}"
fi

# Load .env file if exists
if [ -f .env ]; then
    source .env
    echo -e "${BLUE}Loaded environment variables from .env${NC}"
fi

# Check required environment variables
if [ -z "$RPC_SEPOLIA" ]; then
    echo -e "${RED}ERROR: RPC_SEPOLIA environment variable not set${NC}"
    echo ""
    echo "Please set it in .env file or export it:"
    echo "  export RPC_SEPOLIA=https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY"
    exit 1
fi

if [ -z "$PRIVATE_KEY" ]; then
    echo -e "${RED}ERROR: PRIVATE_KEY environment variable not set${NC}"
    echo ""
    echo "Please set it in .env file or export it:"
    echo "  export PRIVATE_KEY=0xYOUR_PRIVATE_KEY"
    exit 1
fi

# Get latest deployment report
LATEST_REPORT=$(ls -t reports/*-market-deployment.json 2>/dev/null | head -1)

if [ -z "$LATEST_REPORT" ]; then
    echo -e "${RED}ERROR: No deployment report found${NC}"
    echo ""
    echo "Please deploy contracts first:"
    echo "  ./deploy/scripts/deploy.sh sepolia"
    exit 1
fi

echo -e "${BLUE}Using deployment report: $LATEST_REPORT${NC}"
echo ""

# Extract addresses from deployment report (using Python if jq is not available)
if command -v jq &> /dev/null; then
    POOL_ADDRESSES_PROVIDER=$(jq -r '.poolAddressesProvider' "$LATEST_REPORT")
    CONFIG_ENGINE=$(jq -r '.configEngine' "$LATEST_REPORT")
    POOL_ADDRESS=$(jq -r '.poolProxy' "$LATEST_REPORT")
else
    POOL_ADDRESSES_PROVIDER=$(python3 -c "import json, sys; print(json.load(open('$LATEST_REPORT'))['poolAddressesProvider'])")
    CONFIG_ENGINE=$(python3 -c "import json, sys; print(json.load(open('$LATEST_REPORT'))['configEngine'])")
    POOL_ADDRESS=$(python3 -c "import json, sys; print(json.load(open('$LATEST_REPORT'))['poolProxy'])")
fi

# Sepolia USDC address (default)
USDC_ADDRESS="${USDC_ADDRESS:-0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238}"

echo -e "${GREEN}Configuration:${NC}"
echo "  POOL_ADDRESSES_PROVIDER: $POOL_ADDRESSES_PROVIDER"
echo "  CONFIG_ENGINE: $CONFIG_ENGINE"
echo "  POOL_ADDRESS: $POOL_ADDRESS"
echo "  USDC_ADDRESS: $USDC_ADDRESS"
echo ""

# Verify addresses are not zero
if [ "$POOL_ADDRESSES_PROVIDER" == "null" ] || [ -z "$POOL_ADDRESSES_PROVIDER" ]; then
    echo -e "${RED}ERROR: Could not extract POOL_ADDRESSES_PROVIDER from deployment report${NC}"
    exit 1
fi

if [ "$CONFIG_ENGINE" == "null" ] || [ -z "$CONFIG_ENGINE" ]; then
    echo -e "${RED}ERROR: Could not extract CONFIG_ENGINE from deployment report${NC}"
    exit 1
fi

# Get ACL Manager address
echo -e "${BLUE}Getting ACL Manager address...${NC}"
ACL_MANAGER=$(cast call "$POOL_ADDRESSES_PROVIDER" "getACLManager()(address)" --rpc-url "$RPC_SEPOLIA" 2>&1)
if [ $? -eq 0 ] && [ "$ACL_MANAGER" != "0x0000000000000000000000000000000000000000" ]; then
    echo -e "${GREEN}[OK] ACL Manager: $ACL_MANAGER${NC}"
else
    echo -e "${YELLOW}[WARNING] Could not get ACL Manager address: $ACL_MANAGER${NC}"
    echo -e "${YELLOW}Proceeding anyway, but POOL_ADMIN_ROLE check may fail${NC}"
    ACL_MANAGER=""
fi
echo ""

# Pre-deployment checks and diagnostic
echo -e "${BLUE}=== Pre-deployment Diagnostic ===${NC}"

# Test RPC connection
echo -e "${BLUE}Testing RPC connection...${NC}"
BLOCK=$(cast block-number --rpc-url "$RPC_SEPOLIA" 2>&1)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}[OK] RPC connected, block: $BLOCK${NC}"
else
    echo -e "${RED}[FAIL] RPC connection failed: $BLOCK${NC}"
    exit 1
fi

# Check contract code on Sepolia
echo -e "${BLUE}Checking contract code on Sepolia...${NC}"
POOL_CODE=$(cast code "$POOL_ADDRESS" --rpc-url "$RPC_SEPOLIA" 2>&1)
if [ ${#POOL_CODE} -gt 2 ]; then
    echo -e "${GREEN}✓ Pool contract code exists${NC}"
else
    echo -e "${RED}✗ Pool contract code not found${NC}"
    echo "$POOL_CODE"
    echo -e "${YELLOW}⚠ Warning: Pool contract may not be deployed yet${NC}"
fi

CONFIG_CODE=$(cast code "$CONFIG_ENGINE" --rpc-url "$RPC_SEPOLIA" 2>&1)
if [ ${#CONFIG_CODE} -gt 2 ]; then
    echo -e "${GREEN}✓ ConfigEngine contract code exists${NC}"
else
    echo -e "${RED}✗ ConfigEngine contract code not found${NC}"
    echo "$CONFIG_CODE"
    exit 1
fi

# Check current reserves
echo -e "${BLUE}Checking current pool reserves...${NC}"
RESERVES=$(cast call "$POOL_ADDRESS" "getReservesList()(address[])" --rpc-url "$RPC_SEPOLIA" 2>&1)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Successfully queried reserves${NC}"
    echo "  Current reserves: $RESERVES"
    # Check if USDC is already listed (case-insensitive comparison)
    if echo "$RESERVES" | grep -iq "$USDC_ADDRESS"; then
        echo -e "${YELLOW}⚠ USDC is already listed in the pool${NC}"
        if [ -z "$NON_INTERACTIVE" ]; then
            read -p "Continue anyway? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 0
            fi
        else
            echo -e "${BLUE}Running in non-interactive mode - continuing automatically${NC}"
        fi
    else
        echo -e "${GREEN}✓ USDC not yet listed, proceeding...${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Could not query reserves (may be empty pool)${NC}"
    echo "$RESERVES"
fi

# Check USDC token
echo -e "${BLUE}Checking USDC token...${NC}"
USDC_CODE=$(cast code "$USDC_ADDRESS" --rpc-url "$RPC_SEPOLIA" 2>&1)
if [ ${#USDC_CODE} -gt 2 ]; then
    echo -e "${GREEN}✓ USDC contract code exists${NC}"
    USDC_SYMBOL=$(cast call "$USDC_ADDRESS" "symbol()(string)" --rpc-url "$RPC_SEPOLIA" 2>&1)
    if [ $? -eq 0 ]; then
        echo "  Symbol: $USDC_SYMBOL"
    fi
    USDC_DECIMALS=$(cast call "$USDC_ADDRESS" "decimals()(uint8)" --rpc-url "$RPC_SEPOLIA" 2>&1)
    if [ $? -eq 0 ]; then
        echo "  Decimals: $USDC_DECIMALS"
    fi
else
    echo -e "${RED}✗ USDC contract code not found${NC}"
    echo "$USDC_CODE"
    exit 1
fi

echo -e "${GREEN}=== Diagnostic Complete ===${NC}"
echo ""

# Check POOL_ADMIN_ROLE before proceeding
if [ -n "$ACL_MANAGER" ]; then
    echo -e "${BLUE}Checking POOL_ADMIN_ROLE...${NC}"

    # Get deployer address from private key
    DEPLOYER_ADDRESS=$(cast wallet address --private-key "$PRIVATE_KEY" 2>&1)
    if [ $? -ne 0 ]; then
        echo -e "${RED}ERROR: Could not derive address from private key${NC}"
        echo "$DEPLOYER_ADDRESS"
        exit 1
    fi

    echo "  Deployer address: $DEPLOYER_ADDRESS"

    # Check if deployer has POOL_ADMIN_ROLE
    HAS_ROLE=$(cast call "$ACL_MANAGER" "isPoolAdmin(address)(bool)" "$DEPLOYER_ADDRESS" --rpc-url "$RPC_SEPOLIA" 2>&1)
    if [ $? -eq 0 ]; then
        if [[ "$HAS_ROLE" == "true" ]]; then
            echo -e "${GREEN}[OK] Deployer has POOL_ADMIN_ROLE${NC}"
        else
            echo -e "${RED}[FAIL] Deployer does NOT have POOL_ADMIN_ROLE${NC}"
            echo ""
            echo -e "${YELLOW}Please ensure your account has POOL_ADMIN_ROLE before proceeding.${NC}"
            echo -e "${YELLOW}You may need to request the role from the pool admin or use a different account.${NC}"
            echo ""
            read -p "Continue anyway? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 0
            fi
        fi
    else
        echo -e "${YELLOW}[WARNING] Could not check POOL_ADMIN_ROLE: $HAS_ROLE${NC}"
        echo -e "${YELLOW}Proceeding with caution...${NC}"
    fi
else
    echo -e "${YELLOW}[WARNING] Skipping POOL_ADMIN_ROLE check (ACL Manager not available)${NC}"
fi
echo ""

# Confirm before proceeding (skip in non-interactive mode)
if [ -z "$NON_INTERACTIVE" ]; then
    echo -e "${YELLOW}This will list USDC token in the Aave pool on Sepolia testnet.${NC}"
    echo ""
    read -p "Press Enter to continue, or Ctrl+C to cancel..."
else
    echo -e "${BLUE}Running in non-interactive mode - proceeding automatically${NC}"
fi

echo ""
echo -e "${GREEN}Executing listing script...${NC}"
echo ""

# Export environment variables for the script
export POOL_ADDRESSES_PROVIDER="$POOL_ADDRESSES_PROVIDER"
export CONFIG_ENGINE="$CONFIG_ENGINE"
export POOL_ADDRESS="$POOL_ADDRESS"
export USDC_ADDRESS="$USDC_ADDRESS"

# Execute the script with timeout
echo -e "${BLUE}Executing USDC listing script...${NC}"
echo -e "${YELLOW}Using RPC endpoint: sepolia (from foundry.toml)${NC}"
echo ""

# Use --skip-simulation for faster execution (simulation can be very slow with Alchemy)
# Use --with-gas-price to ensure transactions are confirmed quickly
# Use sepolia endpoint name (configured in foundry.toml) instead of direct URL
forge script scripts/ListUSDCOnSepolia.sol:ListUSDCOnSepolia \
  --rpc-url sepolia \
  --private-key "$PRIVATE_KEY" \
  --broadcast \
  --skip-simulation \
  --with-gas-price 200gwei \
  -vvv

SCRIPT_EXIT_CODE=$?

if [ $SCRIPT_EXIT_CODE -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ USDC listing completed successfully!${NC}"
    echo ""
    
    # Verify the listing
    echo -e "${BLUE}Verifying USDC registration...${NC}"
    RESERVES=$(cast call "$POOL_ADDRESS" "getReservesList()(address[])" --rpc-url sepolia 2>&1)
    if echo "$RESERVES" | grep -iq "$USDC_ADDRESS"; then
        echo -e "${GREEN}✓ USDC is now listed in the pool${NC}"
        echo "  Reserves: $RESERVES"
    else
        echo -e "${YELLOW}⚠ USDC not found in reserves yet (may need time to propagate)${NC}"
        echo "  Current reserves: $RESERVES"
    fi
    
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "  1. Verify USDC is listed: ./deploy/scripts/verify-usdc-registration.sh"
    echo "  2. Update frontend config if needed"
    echo "  3. Test supply/borrow operations"
else
    echo ""
    echo -e "${RED}❌ USDC listing failed (exit code: $SCRIPT_EXIT_CODE)${NC}"
    echo ""
    echo "Please check:"
    echo "  - Deployer has DEFAULT_ADMIN_ROLE (not just POOL_ADMIN_ROLE)"
    echo "  - All addresses are correct"
    echo "  - RPC connection is working"
    echo "  - No pending transactions blocking nonce"
    echo ""
    echo "Debug steps:"
    echo "  1. Check nonce: cast nonce \$DEPLOYER --rpc-url sepolia"
    echo "  2. Clear pending txs: cast send \$DEPLOYER --value 0 --gas-price 200gwei --rpc-url sepolia --private-key \$PRIVATE_KEY"
    exit 1
fi

