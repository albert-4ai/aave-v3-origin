#!/bin/bash

# Script to verify USDC token registration in Aave Pool on Sepolia testnet
# Usage: ./deploy/scripts/verify-usdc-registration.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Verifying USDC Registration in Aave Pool ===${NC}"
echo ""

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

# Extract addresses from deployment report
POOL_ADDRESS=$(jq -r '.poolProxy' "$LATEST_REPORT")
USDC_ADDRESS="${USDC_ADDRESS:-0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238}"

echo "Pool Address: $POOL_ADDRESS"
echo "USDC Address: $USDC_ADDRESS"
echo ""

# Test RPC connection (use sepolia endpoint from foundry.toml)
echo -e "${BLUE}Testing RPC connection...${NC}"
BLOCK=$(cast block-number --rpc-url sepolia 2>&1)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}[OK] RPC connected, block: $BLOCK${NC}"
else
    echo -e "${RED}[FAIL] RPC connection failed${NC}"
    exit 1
fi
echo ""

# 1. Check reserves list
echo -e "${BLUE}1. Checking reserves list...${NC}"
RESERVES=$(cast call "$POOL_ADDRESS" "getReservesList()(address[])" --rpc-url sepolia 2>&1)

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Successfully retrieved reserves list${NC}"
    RESERVE_COUNT=$(echo "$RESERVES" | wc -w)
    echo "  Current reserves: $RESERVE_COUNT assets"

    # Check if USDC is in the list (case-insensitive comparison)
    if echo "$RESERVES" | grep -iq "$USDC_ADDRESS"; then
        echo -e "${GREEN}✅ USDC is in the reserves list${NC}"
    else
        echo -e "${RED}❌ USDC is NOT in the reserves list${NC}"
        echo ""
        echo -e "${YELLOW}USDC has not been registered yet.${NC}"
        echo -e "${YELLOW}Run the registration script:${NC}"
        echo "  ./deploy/scripts/list-usdc-sepolia.sh"
        exit 1
    fi
else
    echo -e "${RED}❌ Failed to get reserves list: $RESERVES${NC}"
    exit 1
fi
echo ""

# 2. Get USDC reserve data
echo -e "${BLUE}2. Getting USDC reserve data...${NC}"
# Use simplified call signature
RESERVE_DATA=$(cast call "$POOL_ADDRESS" "getReserveData(address)" "$USDC_ADDRESS" --rpc-url sepolia 2>&1)

if [ $? -eq 0 ] && [ ${#RESERVE_DATA} -gt 100 ]; then
    echo -e "${GREEN}✓ Successfully retrieved USDC reserve data${NC}"
    
    # Check if data is non-zero (indicates valid reserve)
    # Zero data would be all zeros which means reserve not configured
    if [[ "$RESERVE_DATA" == "0x0000000000000000000000000000000000000000000000000000000000000000"* ]] && [[ ${#RESERVE_DATA} -lt 100 ]]; then
        echo -e "${RED}❌ USDC reserve data is empty (not properly configured)${NC}"
        exit 1
    fi
    
    echo ""
    echo -e "${GREEN}🎉 USDC has been successfully registered in the Aave Pool!${NC}"
    echo ""
    echo -e "${BLUE}Registration Details:${NC}"
    echo "  • Asset: USDC ($USDC_ADDRESS)"
    echo "  • Pool: $POOL_ADDRESS"
    echo "  • Reserve Data Length: ${#RESERVE_DATA} bytes"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "  1. Update frontend configuration"
    echo "  2. Test deposit/withdraw operations"
    echo "  3. Test borrow/repay operations"
else
    echo -e "${RED}❌ Failed to get USDC reserve data${NC}"
    echo "  Response: $RESERVE_DATA"
    exit 1
fi
