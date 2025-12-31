#!/bin/bash

# Script to drop/remove a reserve from Aave Pool on Sepolia testnet with pre-deployment checks
# This script performs comprehensive validation before dropping a reserve
# Usage: ./deploy/scripts/drop-reserve-sepolia.sh [1]
#   - Without arguments: Interactive mode (prompts for confirmation)
#   - With '1' argument: Non-interactive mode (automatic execution)

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Drop Reserve from Aave Pool on Sepolia ===${NC}"
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

# Check if ASSET_ADDRESS is provided
if [ -z "$ASSET_ADDRESS" ]; then
    echo -e "${RED}ERROR: ASSET_ADDRESS environment variable not set${NC}"
    echo ""
    echo "Please set it in .env file or export it:"
    echo "  export ASSET_ADDRESS=0x..."
    echo ""
    echo "Available assets in the pool:"
    ./deploy/scripts/check-reserves.sh 2>/dev/null | grep "0x[0-9a-fA-F]\{40\}" | sed 's/.*: //' || echo "Run ./deploy/scripts/check-reserves.sh to see current assets"
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

# Extract addresses from deployment report
POOL_ADDRESS=$(jq -r '.poolProxy' "$LATEST_REPORT")
POOL_ADDRESSES_PROVIDER=$(jq -r '.poolAddressesProvider' "$LATEST_REPORT")
CONFIG_ENGINE=$(jq -r '.configEngine' "$LATEST_REPORT")

# Verify addresses are not zero
if [ "$POOL_ADDRESS" == "null" ] || [ -z "$POOL_ADDRESS" ]; then
    echo -e "${RED}ERROR: Could not extract POOL_ADDRESS from deployment report${NC}"
    exit 1
fi

if [ "$POOL_ADDRESSES_PROVIDER" == "null" ] || [ -z "$POOL_ADDRESSES_PROVIDER" ]; then
    echo -e "${RED}ERROR: Could not extract POOL_ADDRESSES_PROVIDER from deployment report${NC}"
    exit 1
fi

if [ "$CONFIG_ENGINE" == "null" ] || [ -z "$CONFIG_ENGINE" ]; then
    echo -e "${RED}ERROR: Could not extract CONFIG_ENGINE from deployment report${NC}"
    exit 1
fi

echo -e "${GREEN}Configuration:${NC}"
echo "  POOL_ADDRESSES_PROVIDER: $POOL_ADDRESSES_PROVIDER"
echo "  CONFIG_ENGINE: $CONFIG_ENGINE"
echo "  POOL_ADDRESS: $POOL_ADDRESS"
echo "  ASSET_ADDRESS: $ASSET_ADDRESS"
echo ""

# Pre-drop validation
echo -e "${BLUE}=== Pre-Drop Validation ===${NC}"

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
echo -e "${BLUE}Checking pool contract...${NC}"
POOL_CODE=$(cast code "$POOL_ADDRESS" --rpc-url "$RPC_SEPOLIA" 2>&1)
if [ ${#POOL_CODE} -gt 2 ]; then
    echo -e "${GREEN}✓ Pool contract exists${NC}"
else
    echo -e "${RED}✗ Pool contract not found${NC}"
    echo "$POOL_CODE"
    exit 1
fi

# Check if asset is currently listed
echo -e "${BLUE}Checking if asset is listed...${NC}"
RESERVES=$(cast call "$POOL_ADDRESS" "getReservesList()(address[])" --rpc-url "$RPC_SEPOLIA" 2>&1)
if [ $? -eq 0 ]; then
    if echo "$RESERVES" | grep -iq "$ASSET_ADDRESS"; then
        echo -e "${GREEN}✓ Asset is currently listed in the pool${NC}"
    else
        echo -e "${RED}✗ Asset is NOT listed in the pool${NC}"
        echo ""
        echo -e "${YELLOW}Available assets:${NC}"
        echo "$RESERVES" | grep -o "0x[0-9a-fA-F]\{40\}" | nl -v1
        exit 1
    fi
else
    echo -e "${YELLOW}⚠ Could not check reserves list${NC}"
fi

# Check reserve data and outstanding positions using Solidity script
echo -e "${BLUE}Checking reserve data and outstanding positions...${NC}"
CHECK_OUTPUT=$(forge script scripts/CheckReserveCanDrop.sol:CheckReserveCanDrop --rpc-url sepolia 2>&1)
CHECK_EXIT_CODE=$?

if [ $CHECK_EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✓ No outstanding positions found - safe to drop${NC}"
    # Extract and display key information
    echo "$CHECK_OUTPUT" | grep -E "(aToken|Variable Debt|Treasury)" | sed 's/^/  /'
else
    echo -e "${RED}❌ CRITICAL: Cannot drop reserve with outstanding positions!${NC}"
    echo ""
    echo -e "${YELLOW}Details:${NC}"
    echo "$CHECK_OUTPUT" | grep -E "(aToken|Variable Debt|ERROR|WARNING)" | sed 's/^/  /'
    echo ""
    echo -e "${RED}Safety conditions not met. Aborting.${NC}"
    exit 1
fi

echo -e "${GREEN}=== Validation Complete ===${NC}"
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
    echo -e "${YELLOW}⚠️  WARNING: This will permanently remove the asset from the Aave pool!${NC}"
    echo -e "${YELLOW}   Make sure:${NC}"
    echo -e "${YELLOW}   - No users have outstanding aTokens${NC}"
    echo -e "${YELLOW}   - No users have outstanding variable debt${NC}"
    echo -e "${YELLOW}   - You have confirmed this is the correct asset${NC}"
    echo ""
    read -p "Are you sure you want to drop this reserve? (yes/No): " -r
    echo
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo "Operation cancelled."
        exit 0
    fi
else
    echo -e "${BLUE}Running in non-interactive mode - proceeding automatically${NC}"
fi

echo ""
echo -e "${GREEN}Executing drop reserve script...${NC}"
echo ""

# Export environment variables for the script
export POOL_ADDRESSES_PROVIDER="$POOL_ADDRESSES_PROVIDER"
export CONFIG_ENGINE="$CONFIG_ENGINE"
export POOL_ADDRESS="$POOL_ADDRESS"
export ASSET_ADDRESS="$ASSET_ADDRESS"

# Execute the script with timeout
echo -e "${BLUE}Executing drop reserve script...${NC}"
echo -e "${YELLOW}Using RPC endpoint: sepolia (from foundry.toml)${NC}"
echo ""

# Use --skip-simulation for faster execution (simulation can be very slow with Alchemy)
forge script scripts/DropReserveOnSepolia.sol:DropReserveOnSepolia \
  --rpc-url sepolia \
  --private-key "$PRIVATE_KEY" \
  --broadcast \
  --skip-simulation \
  --with-gas-price 200gwei \
  -vvv

SCRIPT_EXIT_CODE=$?

if [ $SCRIPT_EXIT_CODE -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ Reserve drop completed successfully!${NC}"
    echo ""

    # Verify the reserve was dropped
    echo -e "${BLUE}Verifying reserve removal...${NC}"
    RESERVES=$(cast call "$POOL_ADDRESS" "getReservesList()(address[])" --rpc-url sepolia 2>&1)
    if echo "$RESERVES" | grep -iq "$ASSET_ADDRESS"; then
        echo -e "${RED}❌ ERROR: Asset is still listed in the pool!${NC}"
        echo "  Current reserves: $RESERVES"
        exit 1
    else
        echo -e "${GREEN}✅ SUCCESS: Asset successfully removed from pool${NC}"
        echo "  Remaining reserves: $RESERVES"
    fi

    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "  1. Verify no users were affected"
    echo "  2. Update frontend configuration if needed"
    echo "  3. Update documentation"
else
    echo ""
    echo -e "${RED}❌ Reserve drop failed (exit code: $SCRIPT_EXIT_CODE)${NC}"
    echo ""
    echo "Please check:"
    echo "  - Deployer has DEFAULT_ADMIN_ROLE (not just POOL_ADMIN_ROLE)"
    echo "  - All safety conditions are met"
    echo "  - RPC connection is working"
    echo "  - No pending transactions blocking nonce"
    echo ""
    echo "Debug steps:"
    echo "  1. Check nonce: cast nonce \$DEPLOYER --rpc-url sepolia"
    echo "  2. Clear pending txs: cast send \$DEPLOYER --value 0 --gas-price 200gwei --rpc-url sepolia --private-key \$PRIVATE_KEY"
    exit 1
fi
