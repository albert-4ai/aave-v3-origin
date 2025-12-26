#!/bin/bash

# Aave V3.5 部署脚本
# 使用方法: ./deploy.sh <network> [private_key]
# 示例: 
#   ./deploy.sh local                    # 本地 Anvil 部署
#   ./deploy.sh sepolia 0x1234...        # Sepolia 测试网部署

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 清除代理设置（确保本地连接不被代理）
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY all_proxy ALL_PROXY
export no_proxy="127.0.0.1,localhost,127.*,::1"
export NO_PROXY="127.0.0.1,localhost,127.*,::1"

# CREATE2 工厂配置
CREATE2_FACTORY_ADDRESS="0x914d7Fec6aaC8cd542e72Bca78B30650d45643d7"
CREATE2_FACTORY_BYTECODE="0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378035828234f58015156039578182fd5b8082525050506014600cf3"

# Anvil 默认私钥
ANVIL_DEFAULT_PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

# 检查参数
if [ -z "$1" ]; then
    echo -e "${RED}错误: 请指定网络名称${NC}"
    echo ""
    echo "使用方法: ./deploy.sh <network> [private_key]"
    echo ""
    echo "支持的网络:"
    echo "  ${GREEN}local${NC}     - 本地 Anvil 节点 (http://127.0.0.1:8545)"
    echo "  ${GREEN}sepolia${NC}   - Sepolia 测试网"
    echo "  ${GREEN}mainnet${NC}   - Ethereum 主网"
    echo "  ${GREEN}polygon${NC}   - Polygon 主网"
    echo "  ${GREEN}arbitrum${NC}  - Arbitrum One"
    echo "  ${GREEN}optimism${NC}  - Optimism"
    echo ""
    echo "示例:"
    echo "  ./deploy.sh local                         # 本地部署（使用 Anvil 默认账户）"
    echo "  ./deploy.sh sepolia \$PRIVATE_KEY         # Sepolia 部署"
    exit 1
fi

NETWORK=$1
PRIVATE_KEY=${2:-$PRIVATE_KEY}

# 加载 .env 文件（如果存在）
if [ -f .env ]; then
    source .env
fi

# ============================================
# 本地 Anvil 部署
# ============================================
if [ "$NETWORK" == "local" ] || [ "$NETWORK" == "anvil" ] || [ "$NETWORK" == "localhost" ]; then
    echo -e "${GREEN}🚀 开始本地部署 Aave V3.5 到 Anvil...${NC}"
    echo ""
    
    RPC_URL="http://127.0.0.1:8545"
    
    # 使用 Anvil 默认私钥（如果未提供）
    if [ -z "$PRIVATE_KEY" ]; then
        PRIVATE_KEY=$ANVIL_DEFAULT_PRIVATE_KEY
        echo -e "${BLUE}使用 Anvil 默认账户私钥${NC}"
    fi
    
    # 检查 Anvil 节点状态
    echo -e "${YELLOW}检查 Anvil 节点状态...${NC}"
    
    RPC_READY=false
    for i in {1..5}; do
        if cast block-number --rpc-url $RPC_URL >/dev/null 2>&1; then
            BLOCK_NUM=$(cast block-number --rpc-url $RPC_URL 2>/dev/null || echo "0")
            echo -e "${GREEN}✅ Anvil 节点运行正常 (区块: $BLOCK_NUM)${NC}"
            RPC_READY=true
            break
        fi
        
        if [ $i -lt 5 ]; then
            echo -e "${YELLOW}   等待 Anvil 准备就绪... ($i/5)${NC}"
            sleep 1
        fi
    done
    
    if [ "$RPC_READY" = false ]; then
        echo -e "${RED}❌ Anvil 节点无法连接${NC}"
        echo ""
        echo "请先启动 Anvil 节点："
        echo "  anvil"
        echo "  或"
        echo "  ./deploy/start-anvil.sh"
        exit 1
    fi
    
    # 检查并设置 CREATE2 工厂
    echo ""
    echo -e "${YELLOW}检查 CREATE2 工厂...${NC}"
    
    FACTORY_CODE=$(cast code $CREATE2_FACTORY_ADDRESS --rpc-url $RPC_URL 2>/dev/null || echo "0x")
    
    if [ "$FACTORY_CODE" == "0x" ] || [ -z "$FACTORY_CODE" ]; then
        echo -e "${YELLOW}CREATE2 工厂未部署，正在设置...${NC}"
        
        cast rpc anvil_setCode $CREATE2_FACTORY_ADDRESS $CREATE2_FACTORY_BYTECODE --rpc-url $RPC_URL >/dev/null 2>&1
        
        # 验证设置成功
        FACTORY_CODE=$(cast code $CREATE2_FACTORY_ADDRESS --rpc-url $RPC_URL 2>/dev/null || echo "0x")
        if [ "$FACTORY_CODE" != "0x" ] && [ -n "$FACTORY_CODE" ]; then
            echo -e "${GREEN}✅ CREATE2 工厂设置成功${NC}"
        else
            echo -e "${RED}❌ CREATE2 工厂设置失败${NC}"
            exit 1
        fi
    else
        echo -e "${GREEN}✅ CREATE2 工厂已存在${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}开始部署...${NC}"
    echo ""
    echo -e "${YELLOW}提示: 部署可能需要 2-5 分钟，请耐心等待...${NC}"
    echo -e "${YELLOW}      （需要部署约 20 个合约）${NC}"
    echo ""
    
    # 执行部署
    # --slow: 逐个发送交易并等待确认，避免交易拥堵
    # 这比并发发送稍慢，但更稳定可靠
    forge script scripts/DeployAaveV3MarketBatched.sol:Default \
        --rpc-url $RPC_URL \
        --private-key $PRIVATE_KEY \
        --broadcast \
        --slow \
        -vvv
    
    DEPLOY_EXIT_CODE=$?
    
    if [ $DEPLOY_EXIT_CODE -eq 0 ]; then
        echo ""
        echo -e "${GREEN}✅ 本地部署成功！${NC}"
        echo ""
        echo "部署报告已保存到 reports/ 目录"
        echo ""
        echo -e "${BLUE}查看部署报告:${NC}"
        echo "  ls -la reports/*.json | tail -1"
        echo ""
        echo -e "${BLUE}下一步:${NC}"
        echo "  1. 部署测试代币"
        echo "  2. 配置预言机价格"
        echo "  3. 添加资产到池中"
    else
        echo ""
        echo -e "${RED}❌ 部署失败 (退出码: $DEPLOY_EXIT_CODE)${NC}"
        exit 1
    fi
    
    exit 0
fi

# ============================================
# 远程网络部署
# ============================================

# 检查私钥
if [ -z "$PRIVATE_KEY" ]; then
    echo -e "${YELLOW}警告: 未提供私钥${NC}"
    echo "请提供私钥作为参数或设置环境变量 PRIVATE_KEY"
    exit 1
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

# 如果是主网，添加验证选项和确认
if [[ "$NETWORK" == "mainnet" ]] || [[ "$NETWORK" == "polygon" ]] || [[ "$NETWORK" == "arbitrum" ]] || [[ "$NETWORK" == "optimism" ]]; then
    ETHERSCAN_VAR="ETHERSCAN_API_KEY_$(echo $NETWORK | tr '[:lower:]' '[:upper:]')"
    ETHERSCAN_KEY=${!ETHERSCAN_VAR}
    
    if [ ! -z "$ETHERSCAN_KEY" ]; then
        echo -e "${GREEN}找到 Etherscan API Key，将启用合约验证${NC}"
        CMD="${CMD} --verify"
    else
        echo -e "${YELLOW}警告: 未找到 ${ETHERSCAN_VAR}，将跳过合约验证${NC}"
    fi
    
    echo ""
    echo -e "${RED}⚠️  警告: 这是主网部署，请确认所有配置正确！${NC}"
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
    echo "  ls -la reports/*.json | tail -1"
else
    echo ""
    echo -e "${RED}❌ 部署失败${NC}"
    exit 1
fi
