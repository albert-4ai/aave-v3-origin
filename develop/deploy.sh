#!/bin/bash

# Aave V3.5 部署脚本
# 使用方法: ./deploy.sh <network> [private_key]
# 示例: ./deploy.sh sepolia 0x1234...

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查参数
if [ -z "$1" ]; then
    echo -e "${RED}错误: 请指定网络名称${NC}"
    echo "使用方法: ./deploy.sh <network> [private_key]"
    echo "支持的网络: sepolia, mumbai, mainnet, polygon, arbitrum, optimism, etc."
    exit 1
fi

NETWORK=$1
PRIVATE_KEY=${2:-$PRIVATE_KEY}

# 检查私钥
if [ -z "$PRIVATE_KEY" ]; then
    echo -e "${YELLOW}警告: 未提供私钥，将尝试使用环境变量 PRIVATE_KEY${NC}"
    if [ -z "$PRIVATE_KEY" ]; then
        echo -e "${RED}错误: 请提供私钥作为参数或设置环境变量 PRIVATE_KEY${NC}"
        exit 1
    fi
fi

# 检查 .env 文件
if [ ! -f .env ]; then
    echo -e "${YELLOW}警告: 未找到 .env 文件${NC}"
    echo "建议创建 .env 文件并配置 RPC URL 和 API Keys"
fi

# 加载 .env 文件（如果存在）
if [ -f .env ]; then
    source .env
fi

echo -e "${GREEN}开始部署 Aave V3.5 到 ${NETWORK}...${NC}"
echo ""

# 检查 RPC URL
RPC_VAR="RPC_$(echo $NETWORK | tr '[:lower:]' '[:upper:]')"
RPC_URL=${!RPC_VAR}

if [ -z "$RPC_URL" ]; then
    echo -e "${YELLOW}警告: 未找到 ${RPC_VAR} 环境变量${NC}"
    echo "将使用网络名称作为 RPC URL: ${NETWORK}"
    RPC_URL=$NETWORK
fi

# 构建命令
CMD="forge script scripts/DeployAaveV3MarketBatched.sol:Default \
  --rpc-url ${RPC_URL} \
  --private-key ${PRIVATE_KEY} \
  --broadcast \
  -vvvv"

# 如果是主网，添加验证选项
if [[ "$NETWORK" == "mainnet" ]] || [[ "$NETWORK" == "polygon" ]] || [[ "$NETWORK" == "arbitrum" ]] || [[ "$NETWORK" == "optimism" ]]; then
    ETHERSCAN_VAR="ETHERSCAN_API_KEY_$(echo $NETWORK | tr '[:lower:]' '[:upper:]')"
    ETHERSCAN_KEY=${!ETHERSCAN_VAR}
    
    if [ ! -z "$ETHERSCAN_KEY" ]; then
        echo -e "${GREEN}找到 Etherscan API Key，将启用合约验证${NC}"
        CMD="${CMD} --verify"
    else
        echo -e "${YELLOW}警告: 未找到 ${ETHERSCAN_VAR}，将跳过合约验证${NC}"
    fi
    
    echo -e "${YELLOW}警告: 这是主网部署，请确认所有配置正确！${NC}"
    read -p "按 Enter 继续，或 Ctrl+C 取消..."
fi

echo ""
echo -e "${GREEN}执行命令:${NC}"
echo "$CMD"
echo ""

# 执行部署
eval $CMD

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ 部署成功！${NC}"
    echo "部署报告已保存到 reports/ 目录"
    echo ""
    echo "查看部署报告:"
    echo "  cat reports/market-report-*.json"
else
    echo ""
    echo -e "${RED}❌ 部署失败${NC}"
    exit 1
fi

