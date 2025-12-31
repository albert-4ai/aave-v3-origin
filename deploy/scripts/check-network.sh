#!/bin/bash

# Script to check Sepolia network status and RPC node health
# Usage: ./deploy/scripts/check-network.sh [network]
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

echo -e "${GREEN}=== Sepolia Network Status Check ===${NC}"
echo ""

# Load .env file if exists
if [ -f .env ]; then
    source .env
    echo -e "${BLUE}Loaded environment variables from .env${NC}"
fi

# Test basic RPC connection
echo -e "${BLUE}🔗 Testing RPC connection...${NC}"
BLOCK=$(cast block-number --rpc-url "$NETWORK" 2>&1)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Latest block: $BLOCK${NC}"
else
    echo -e "${RED}❌ RPC connection failed: $BLOCK${NC}"
    exit 1
fi

# Check network ID
echo -e "${BLUE}🌐 Checking network ID...${NC}"
NETWORK_ID=$(cast chain-id --rpc-url "$NETWORK" 2>&1)
if [ $? -eq 0 ]; then
    case $NETWORK_ID in
        1) NETWORK_NAME="Ethereum Mainnet" ;;
        11155111) NETWORK_NAME="Sepolia Testnet" ;;
        5) NETWORK_NAME="Goerli Testnet" ;;
        137) NETWORK_NAME="Polygon Mainnet" ;;
        80001) NETWORK_NAME="Polygon Mumbai" ;;
        *) NETWORK_NAME="Unknown Network" ;;
    esac
    echo -e "${GREEN}✅ Network ID: $NETWORK_ID ($NETWORK_NAME)${NC}"
else
    echo -e "${RED}❌ Failed to get network ID: $NETWORK_ID${NC}"
fi

# Check gas price
echo -e "${BLUE}⛽ Checking gas price...${NC}"
GAS_PRICE=$(cast gas-price --rpc-url "$NETWORK" 2>&1)
if [ $? -eq 0 ]; then
    GAS_PRICE_GWEI=$(echo "scale=2; $GAS_PRICE / 1000000000" | bc 2>/dev/null || echo "N/A")
    echo -e "${GREEN}✅ Gas price: $GAS_PRICE_GWEI gwei ($GAS_PRICE wei)${NC}"
else
    echo -e "${RED}❌ Failed to get gas price: $GAS_PRICE${NC}"
fi

# Test response time
echo -e "${BLUE}⏱️  Testing response time...${NC}"
START_TIME=$(date +%s%3N)
cast block-number --rpc-url "$NETWORK" >/dev/null 2>&1
END_TIME=$(date +%s%3N)
RESPONSE_TIME=$((END_TIME - START_TIME))
if [ $RESPONSE_TIME -lt 500 ]; then
    STATUS="${GREEN}✅"
elif [ $RESPONSE_TIME -lt 1000 ]; then
    STATUS="${YELLOW}⚠️ "
else
    STATUS="${RED}❌"
fi
echo -e "$STATUS RPC response time: ${RESPONSE_TIME}ms${NC}"

echo ""
echo -e "${BLUE}🏦 Testing Aave Pool contract...${NC}"

# Get latest deployment report
LATEST_REPORT=$(ls -t reports/*-market-deployment.json 2>/dev/null | head -1)

if [ -n "$LATEST_REPORT" ]; then
    POOL_ADDRESS=$(jq -r '.poolProxy' "$LATEST_REPORT" 2>/dev/null)

    if [ -n "$POOL_ADDRESS" ] && [ "$POOL_ADDRESS" != "null" ]; then
        # Check if pool contract exists
        CONTRACT_CODE=$(cast code "$POOL_ADDRESS" --rpc-url "$NETWORK" 2>&1)
        if [ ${#CONTRACT_CODE} -gt 2 ]; then
            echo -e "${GREEN}✅ Pool contract deployed at: $POOL_ADDRESS${NC}"

            # Test pool functionality
            RESERVES=$(cast call "$POOL_ADDRESS" "getReservesList()(address[])" --rpc-url "$NETWORK" 2>&1)
            if [ $? -eq 0 ]; then
                RESERVE_COUNT=$(echo "$RESERVES" | grep -o "0x[0-9a-fA-F]\{40\}" | wc -l)
                echo -e "${GREEN}✅ Pool reserves query: OK ($RESERVE_COUNT assets)${NC}"
            else
                echo -e "${RED}❌ Pool reserves query failed${NC}"
            fi
        else
            echo -e "${RED}❌ Pool contract not found${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  Pool address not found in deployment report${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  No deployment report found${NC}"
fi

echo ""
echo -e "${BLUE}📋 Network Status Summary:${NC}"

# Overall status assessment
OVERALL_STATUS="${GREEN}🟢 OPERATIONAL"

if [ $RESPONSE_TIME -gt 2000 ]; then
    OVERALL_STATUS="${RED}🔴 DEGRADED"
elif [ $RESPONSE_TIME -gt 1000 ]; then
    OVERALL_STATUS="${YELLOW}🟡 SLOW"
fi

echo -e "$OVERALL_STATUS"
echo ""
echo -e "${BLUE}Key Metrics:${NC}"
echo "• Block Height: $BLOCK"
echo "• Network: $NETWORK_NAME (ID: $NETWORK_ID)"
echo "• Gas Price: $GAS_PRICE_GWEI gwei"
echo "• Response Time: ${RESPONSE_TIME}ms"
echo ""
echo -e "${GREEN}=== Check Complete ===${NC}"
