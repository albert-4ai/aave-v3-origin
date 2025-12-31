#!/bin/bash

# USDC 初始化与预充值脚本（合并版）
# 使用方法: ./deploy/scripts/mint-usdc.sh [usdc_address]
# 功能：
#   1. 自动查找 USDC 地址（如果未提供）
#   2. 如果池中没有 USDC，自动初始化 USDC 到池中
#   3. 给 10 个 Anvil 默认账户各充值 10000 USDC
# 示例: 
#   ./deploy/scripts/mint-usdc.sh              # 自动查找/初始化并充值
#   ./deploy/scripts/mint-usdc.sh 0x...        # 指定 USDC 地址

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 清除代理设置
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY all_proxy ALL_PROXY
export no_proxy="127.0.0.1,localhost,127.*,::1"
export NO_PROXY="127.0.0.1,localhost,127.*,::1"

# Anvil 默认私钥（第一个账户）
ANVIL_DEFAULT_PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

RPC_URL="http://127.0.0.1:8545"

# 检查参数
USDC_ADDRESS=${1:-""}

# 加载 .env 文件（如果存在）
if [ -f .env ]; then
    source .env
fi

# 从环境变量或参数获取 USDC 地址
if [ -z "$USDC_ADDRESS" ]; then
    USDC_ADDRESS=${USDC_ADDRESS_ENV:-""}
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
    exit 1
fi

# 获取脚本所在目录的父目录（项目根目录）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# 如果没有提供 USDC 地址，尝试从部署报告中获取必要地址
# 脚本会自动从池中查找 USDC，如果找不到会自动初始化
POOL_ADDRESS=""
POOL_ADDRESSES_PROVIDER=""
CONFIG_ENGINE=""

if [ -z "$USDC_ADDRESS" ]; then
    echo -e "${YELLOW}USDC 地址未提供，将自动从池中查找或初始化...${NC}"
    
    # 查找最新的部署报告
    LATEST_REPORT=$(ls -t "$PROJECT_ROOT/reports"/*-market-deployment.json 2>/dev/null | head -1)
    
    if [ -n "$LATEST_REPORT" ] && [ -f "$LATEST_REPORT" ]; then
        echo -e "${GREEN}找到部署报告: $LATEST_REPORT${NC}"
        
        # 从报告中提取必要地址
        POOL_ADDRESS=$(grep -o '"poolProxy"[[:space:]]*:[[:space:]]*"[^"]*"' "$LATEST_REPORT" | sed 's/.*"\(0x[a-fA-F0-9]*\)".*/\1/' | head -1)
        POOL_ADDRESSES_PROVIDER=$(grep -o '"poolAddressesProvider"[[:space:]]*:[[:space:]]*"[^"]*"' "$LATEST_REPORT" | sed 's/.*"\(0x[a-fA-F0-9]*\)".*/\1/' | head -1)
        CONFIG_ENGINE=$(grep -o '"configEngine"[[:space:]]*:[[:space:]]*"[^"]*"' "$LATEST_REPORT" | sed 's/.*"\(0x[a-fA-F0-9]*\)".*/\1/' | head -1)
        
        if [ -n "$POOL_ADDRESS" ]; then
            echo -e "${GREEN}找到 Pool 地址: $POOL_ADDRESS${NC}"
        fi
        if [ -n "$POOL_ADDRESSES_PROVIDER" ]; then
            echo -e "${GREEN}找到 PoolAddressesProvider: $POOL_ADDRESSES_PROVIDER${NC}"
        fi
        if [ -n "$CONFIG_ENGINE" ]; then
            echo -e "${GREEN}找到 Config Engine: $CONFIG_ENGINE${NC}"
        fi
        
        if [ -n "$POOL_ADDRESS" ] && [ -n "$POOL_ADDRESSES_PROVIDER" ] && [ -n "$CONFIG_ENGINE" ]; then
            echo -e "${YELLOW}脚本将自动从池中查找 USDC，如果未找到将自动初始化${NC}"
        else
            echo -e "${YELLOW}警告: 无法从部署报告中提取所有必要地址${NC}"
        fi
    else
        echo -e "${YELLOW}警告: 未找到部署报告${NC}"
        echo -e "${BLUE}提示: 可以手动提供环境变量${NC}"
    fi
fi

# 如果提供了 USDC 地址，验证合约是否存在
if [ -n "$USDC_ADDRESS" ]; then
    USDC_CODE=$(cast code "$USDC_ADDRESS" --rpc-url $RPC_URL 2>/dev/null || echo "0x")
    if [ "$USDC_CODE" == "0x" ] || [ -z "$USDC_CODE" ]; then
        echo -e "${RED}❌ 错误: USDC 合约不存在于地址 $USDC_ADDRESS${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ 验证 USDC 合约存在${NC}"
fi

# 使用 Anvil 默认私钥（第一个账户，通常是 owner）
PRIVATE_KEY=${PRIVATE_KEY:-$ANVIL_DEFAULT_PRIVATE_KEY}

echo ""
echo -e "${GREEN}🚀 开始给账户预充值 USDC...${NC}"
echo ""
echo -e "${BLUE}配置信息:${NC}"
if [ -n "$USDC_ADDRESS" ]; then
    echo "  USDC Address: $USDC_ADDRESS (已提供)"
else
    echo "  USDC Address: 将从池中自动查找或初始化"
fi
if [ -n "$POOL_ADDRESS" ]; then
    echo "  Pool Address: $POOL_ADDRESS"
fi
if [ -n "$POOL_ADDRESSES_PROVIDER" ]; then
    echo "  PoolAddressesProvider: $POOL_ADDRESSES_PROVIDER"
fi
if [ -n "$CONFIG_ENGINE" ]; then
    echo "  Config Engine: $CONFIG_ENGINE"
fi
echo "  RPC URL: $RPC_URL"
echo "  Amount per Account: 10,000 USDC"
echo "  Number of Accounts: 10"
echo ""

# 设置环境变量
if [ -n "$USDC_ADDRESS" ]; then
    export USDC_ADDRESS=$USDC_ADDRESS
fi

if [ -n "$POOL_ADDRESS" ]; then
    export POOL_ADDRESS=$POOL_ADDRESS
fi

if [ -n "$POOL_ADDRESSES_PROVIDER" ]; then
    export POOL_ADDRESSES_PROVIDER=$POOL_ADDRESSES_PROVIDER
fi

if [ -n "$CONFIG_ENGINE" ]; then
    export CONFIG_ENGINE=$CONFIG_ENGINE
fi

# 切换到项目根目录执行脚本
cd "$PROJECT_ROOT"

# 执行脚本（合并后的脚本会自动查找 USDC 如果未提供）
echo -e "${YELLOW}执行 MintUSDC 脚本...${NC}"
echo ""

forge script scripts/MintUSDC.sol:MintUSDC \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --slow \
    -vvv

cd - > /dev/null

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ USDC 预充值成功！${NC}"
    echo ""
    
    # 如果 USDC 地址未提供，尝试从脚本输出或池中获取
    if [ -z "$USDC_ADDRESS" ]; then
        # 方法 1: 从 forge script 的输出日志中提取
        # 查找 "USDC Token deployed at:" 或 "Using USDC Address:" 或 "USDC initialized at:"
        FORGE_OUTPUT=$(forge script scripts/MintUSDC.sol:MintUSDC --rpc-url $RPC_URL -vvv 2>&1 || true)
        EXTRACTED_USDC=$(echo "$FORGE_OUTPUT" | grep -oE "(USDC Token deployed at:|Using USDC Address:|USDC initialized at:)[[:space:]]*0x[a-fA-F0-9]{40}" | grep -oE "0x[a-fA-F0-9]{40}" | head -1)
        
        # 方法 2: 如果方法1失败，从池中查询
        if [ -z "$EXTRACTED_USDC" ] && [ -n "$POOL_ADDRESS" ]; then
            echo -e "${YELLOW}从池中查询 USDC 地址...${NC}"
            RESERVES=$(cast call "$POOL_ADDRESS" "getReservesList()" --rpc-url $RPC_URL 2>/dev/null || echo "")
            if [ -n "$RESERVES" ] && [ "$RESERVES" != "0x" ]; then
                # 解析数组并查找 USDC
                # 简化版：尝试查询每个可能的储备地址
                for reserve in $(echo "$RESERVES" | grep -oE "0x[a-fA-F0-9]{40}"); do
                    SYMBOL=$(cast call "$reserve" "symbol()" --rpc-url $RPC_URL 2>/dev/null || echo "")
                    if [ "$SYMBOL" == "USDC" ] || [ "$SYMBOL" == "USDX" ]; then
                        EXTRACTED_USDC="$reserve"
                        break
                    fi
                done
            fi
        fi
        
        if [ -n "$EXTRACTED_USDC" ]; then
            USDC_ADDRESS="$EXTRACTED_USDC"
            echo -e "${GREEN}找到 USDC 地址: $USDC_ADDRESS${NC}"
        else
            echo -e "${YELLOW}无法自动获取 USDC 地址${NC}"
            echo "  可以从脚本输出日志中查找以下信息："
            echo "    - 'USDC Token deployed at: 0x...'"
            echo "    - 'Using USDC Address: 0x...'"
            echo "    - 'USDC initialized at: 0x...'"
        fi
    fi
    
    if [ -n "$USDC_ADDRESS" ]; then
        echo ""
        echo -e "${BLUE}USDC 地址:${NC}"
        echo "  $USDC_ADDRESS"
        echo ""
        echo -e "${BLUE}验证余额:${NC}"
        echo "  使用以下命令验证账户余额："
        echo "  cast call $USDC_ADDRESS \"balanceOf(address)\" <ACCOUNT_ADDRESS> --rpc-url $RPC_URL"
        echo ""
        echo "  示例（第一个账户）："
        echo "  cast call $USDC_ADDRESS \"balanceOf(address)\" 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --rpc-url $RPC_URL"
    fi
else
    echo ""
    echo -e "${RED}❌ USDC 预充值失败 (退出码: $EXIT_CODE)${NC}"
    echo ""
    echo -e "${YELLOW}故障排除:${NC}"
    echo ""
    echo -e "${BLUE}如果错误信息显示 'USDC token not found in pool reserves':${NC}"
    echo "  说明池中还没有 USDC 储备，但脚本应该已经尝试自动初始化"
    echo "  请检查是否提供了 POOL_ADDRESSES_PROVIDER 和 CONFIG_ENGINE 环境变量"
    echo ""
    echo -e "${BLUE}其他可能的问题:${NC}"
    echo "  1. 确保 Anvil 节点正在运行"
    echo "  2. 确保使用正确的 owner 账户（通常是 Anvil 第一个账户）"
    echo "  3. 如果自动查找失败，可以手动提供 USDC 地址："
    echo "     ./deploy/scripts/mint-usdc.sh 0x<USDC_ADDRESS>"
    exit 1
fi
