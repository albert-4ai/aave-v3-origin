#!/bin/bash

# Script to check Aave Pool reserves and count tokens
# Usage: ./deploy/scripts/check-reserves.sh [network]
# Network defaults to 'sepolia' if not specified

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default network
NETWORK="${1:-sepolia}"

echo -e "${GREEN}=== Aave Pool Reserves Checker ===${NC}"
echo ""

# Load .env file if exists
if [ -f .env ]; then
    source .env
    echo -e "${BLUE}Loaded environment variables from .env${NC}"
fi

# Get latest deployment report
LATEST_REPORT=$(ls -t reports/*-market-deployment.json 2>/dev/null | head -1)

if [ -z "$LATEST_REPORT" ]; then
    echo -e "${RED}ERROR: No deployment report found${NC}"
    echo ""
    echo "Please deploy contracts first:"
    echo "  ./deploy/scripts/deploy.sh $NETWORK"
    exit 1
fi

echo -e "${BLUE}Using deployment report: $LATEST_REPORT${NC}"

# Extract pool address from deployment report
POOL_ADDRESS=$(jq -r '.poolProxy' "$LATEST_REPORT" 2>/dev/null)

if [ -z "$POOL_ADDRESS" ] || [ "$POOL_ADDRESS" == "null" ]; then
    echo -e "${RED}ERROR: Could not extract pool address from deployment report${NC}"
    exit 1
fi

echo -e "${GREEN}Pool Address: $POOL_ADDRESS${NC}"
echo -e "${GREEN}Network: $NETWORK${NC}"
echo ""

# Test RPC connection
echo -e "${BLUE}Testing RPC connection...${NC}"
BLOCK=$(cast block-number --rpc-url "$NETWORK" 2>&1)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Latest block: $BLOCK${NC}"
else
    echo -e "${RED}❌ RPC connection failed: $BLOCK${NC}"
    exit 1
fi

# Check pool contract
echo -e "${BLUE}Checking pool contract...${NC}"
POOL_CODE=$(cast code "$POOL_ADDRESS" --rpc-url "$NETWORK" 2>&1)
if [ ${#POOL_CODE} -gt 2 ]; then
    echo -e "${GREEN}✓ Pool contract exists${NC}"
else
    echo -e "${RED}✗ Pool contract not found${NC}"
    echo "$POOL_CODE"
    exit 1
fi
echo ""

# Get reserves list
echo -e "${BLUE}Fetching reserves list...${NC}"
RESERVES=$(cast call "$POOL_ADDRESS" "getReservesList()(address[])" --rpc-url "$NETWORK" 2>&1)

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Successfully retrieved reserves${NC}"
    echo ""

    # Count reserves
    RESERVE_ADDRESSES=$(echo "$RESERVES" | grep -o "0x[0-9a-fA-F]\{40\}" | sort | uniq)
    RESERVE_COUNT=$(echo "$RESERVE_ADDRESSES" | wc -l)

    echo -e "${GREEN}📊 Total Reserves: $RESERVE_COUNT assets${NC}"
    echo ""

    if [ "$RESERVE_COUNT" -gt 0 ]; then
        echo -e "${BLUE}=== Reserve Assets ===${NC}"
        echo "$RESERVE_ADDRESSES" | nl -v1 -w2 -s'. '

        echo ""
        echo -e "${BLUE}=== Reserve Details ===${NC}"

        # Get details for each reserve
        i=1
        echo "$RESERVE_ADDRESSES" | while read -r asset; do
            echo -e "${YELLOW}Asset $i: $asset${NC}"

            # Try to get token symbol and decimals
            SYMBOL=$(cast call "$asset" "symbol()(string)" --rpc-url "$NETWORK" 2>&1)
            if [ $? -eq 0 ]; then
                echo "  Symbol: $SYMBOL"
            else
                echo "  Symbol: Unknown"
            fi

            DECIMALS=$(cast call "$asset" "decimals()(uint8)" --rpc-url "$NETWORK" 2>&1)
            if [ $? -eq 0 ]; then
                echo "  Decimals: $DECIMALS"
            else
                echo "  Decimals: Unknown"
            fi

            # Get reserve data from pool
            RESERVE_DATA=$(cast call "$POOL_ADDRESS" "getReserveData(address)" "$asset" --rpc-url "$NETWORK" 2>/dev/null || echo "Failed")
            if [ "$RESERVE_DATA" != "Failed" ] && [ ${#RESERVE_DATA} -gt 100 ]; then
                echo -e "${GREEN}  ✓ Reserve is active${NC}"
            else
                echo -e "${YELLOW}  ⚠ Reserve data not found or empty${NC}"
            fi

            echo ""
            i=$((i + 1))
        done
    else
        echo -e "${YELLOW}No reserves found in the pool${NC}"
        echo "This is normal for a fresh deployment."
        echo "Use ./deploy/scripts/list-usdc-sepolia.sh to add USDC to the pool."
    fi

else
    echo -e "${RED}❌ Failed to fetch reserves list${NC}"
    echo "$RESERVES"
    exit 1
fi

echo -e "${GREEN}=== Check Complete ===${NC}"
