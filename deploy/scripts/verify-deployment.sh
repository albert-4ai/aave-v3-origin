#!/bin/bash

# Aave V3.5 部署验证脚本
# 使用方法: ./verify-deployment.sh [network] [pool_address]
# 示例:
#   ./verify-deployment.sh local
#   ./verify-deployment.sh sepolia 0x1234...

# 不使用 set -e，以便更好地处理错误

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

NETWORK=${1:-local}
POOL_ADDRESS=$2

# 设置 RPC URL
if [ "$NETWORK" == "local" ] || [ "$NETWORK" == "anvil" ] || [ "$NETWORK" == "localhost" ]; then
    RPC_URL="http://127.0.0.1:8545"
else
    RPC_VAR="RPC_$(echo $NETWORK | tr '[:lower:]' '[:upper:]')"
    RPC_URL=${!RPC_VAR}
    if [ -z "$RPC_URL" ]; then
        RPC_URL=$NETWORK
    fi
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Aave V3.5 部署验证${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 检查 RPC 连接
echo -e "${YELLOW}[0/4] 检查 RPC 连接...${NC}"

# 先检查端口是否在监听（仅本地）
if [ "$NETWORK" == "local" ] || [ "$NETWORK" == "anvil" ] || [ "$NETWORK" == "localhost" ]; then
    PORT_CHECK=$(nc -z 127.0.0.1 8545 2>/dev/null && echo "OPEN" || echo "CLOSED")
    if [ "$PORT_CHECK" == "CLOSED" ]; then
        # 尝试其他方式检查
        PORT_CHECK=$(timeout 1 bash -c "echo > /dev/tcp/127.0.0.1/8545" 2>/dev/null && echo "OPEN" || echo "CLOSED")
    fi
    
    if [ "$PORT_CHECK" == "CLOSED" ]; then
        echo -e "${RED}❌ 端口 8545 未在监听${NC}"
        echo ""
        echo -e "${YELLOW}诊断信息:${NC}"
        echo "   - 检查 Anvil 进程: ${BLUE}ps aux | grep anvil${NC}"
        echo "   - 检查端口占用: ${BLUE}lsof -i :8545${NC} 或 ${BLUE}netstat -tlnp | grep 8545${NC}"
        echo ""
        echo -e "${YELLOW}请确保 Anvil 正在运行:${NC}"
        echo "   ${BLUE}anvil${NC}"
        echo ""
        echo -e "${RED}验证失败，退出...${NC}"
        exit 1
    fi
fi

# 检查 RPC 连接（使用更可靠的方法）
# 先尝试简单的 JSON-RPC 调用（绕过可能的代理问题）
RPC_RESPONSE=$(curl -s --noproxy "*" -X POST -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
    "$RPC_URL" 2>/dev/null)

if echo "$RPC_RESPONSE" | grep -q "result"; then
    # JSON-RPC 调用成功，提取区块号
    BLOCK_HEX=$(echo "$RPC_RESPONSE" | sed -n 's/.*"result":"\([^"]*\)".*/\1/p' | head -1)
    if [ -n "$BLOCK_HEX" ]; then
        BLOCK_NUMBER=$(python3 -c "print(int('$BLOCK_HEX', 16))" 2>/dev/null || echo "N/A")
        echo -e "${GREEN}✅ RPC 连接正常（区块: ${BLOCK_NUMBER}）${NC}"
        RPC_CONNECTED=true
    else
        # 尝试使用 cast 获取详细信息
        RPC_CHECK=$(cast block latest --rpc-url "$RPC_URL" 2>&1)
        RPC_ERROR=$?
        if [ $RPC_ERROR -eq 0 ] && [ -n "$RPC_CHECK" ] && ! echo "$RPC_CHECK" | grep -q "Error\|error\|ERROR"; then
            BLOCK_NUMBER=$(echo "$RPC_CHECK" | head -1 | sed -n 's/.*number:[[:space:]]*\([0-9]*\).*/\1/p' || echo "N/A")
            echo -e "${GREEN}✅ RPC 连接正常（区块: ${BLOCK_NUMBER}）${NC}"
            RPC_CONNECTED=true
        else
            RPC_ERROR=1
        fi
    fi
else
    # JSON-RPC 调用失败，尝试 cast
    RPC_CHECK=$(cast block latest --rpc-url "$RPC_URL" 2>&1)
    RPC_ERROR=$?
    if [ $RPC_ERROR -eq 0 ] && [ -n "$RPC_CHECK" ] && ! echo "$RPC_CHECK" | grep -q "Error\|error\|ERROR"; then
        BLOCK_NUMBER=$(echo "$RPC_CHECK" | head -1 | sed -n 's/.*number:[[:space:]]*\([0-9]*\).*/\1/p' || echo "N/A")
        echo -e "${GREEN}✅ RPC 连接正常（区块: ${BLOCK_NUMBER}）${NC}"
        RPC_CONNECTED=true
    fi
fi

if [ "$RPC_CONNECTED" != "true" ]; then
    echo -e "${RED}❌ 无法连接到 RPC 节点: $RPC_URL${NC}"
    if [ -n "$RPC_CHECK" ] && [ "$RPC_CHECK" != "ERROR" ]; then
        echo -e "${YELLOW}错误详情:${NC} $(echo "$RPC_CHECK" | head -1)"
    fi
    if [ -n "$RPC_RESPONSE" ]; then
        echo -e "${YELLOW}JSON-RPC 响应:${NC} $(echo "$RPC_RESPONSE" | head -1)"
    fi
    echo ""
    if [ "$NETWORK" == "local" ] || [ "$NETWORK" == "anvil" ] || [ "$NETWORK" == "localhost" ]; then
        echo -e "${RED}错误: 无法连接到 Anvil 节点${NC}"
        echo ""
        echo -e "${YELLOW}可能的原因:${NC}"
        echo "   1. Anvil 进程已启动但未正常响应"
        echo "   2. Anvil 运行在不同的端口"
        echo "   3. 网络配置问题（代理、防火墙等）"
        echo ""
        echo -e "${YELLOW}诊断步骤:${NC}"
        echo "   1. 检查 Anvil 进程: ${BLUE}ps aux | grep anvil${NC}"
        echo "   2. 检查端口监听: ${BLUE}lsof -i :8545${NC}"
        echo "   3. 测试连接: ${BLUE}curl --noproxy '*' -X POST -H 'Content-Type: application/json' --data '{\"jsonrpc\":\"2.0\",\"method\":\"eth_blockNumber\",\"params\":[],\"id\":1}' http://127.0.0.1:8545${NC}"
        echo "   4. 重启 Anvil: ${BLUE}./deploy/scripts/start-anvil.sh${NC}"
    else
        echo -e "${RED}错误: 无法连接到远程 RPC 节点${NC}"
        echo ""
        echo -e "${YELLOW}请检查:${NC}"
        echo "   - RPC URL 是否正确: $RPC_URL"
        echo "   - 网络连接是否正常"
        echo "   - 环境变量 ${RPC_VAR} 是否已设置"
    fi
    echo ""
    echo -e "${RED}验证失败，退出...${NC}"
    exit 1
fi

echo ""

# 方法 1: 检查部署报告
echo -e "${YELLOW}[1/4] 检查部署报告...${NC}"
REPORT_FILE=$(ls -t reports/*-market-deployment.json 2>/dev/null | head -1)

if [ -z "$REPORT_FILE" ]; then
    echo -e "${RED}❌ 未找到部署报告文件${NC}"
    echo "   请确认已完成部署，报告应位于 reports/ 目录"
else
    echo -e "${GREEN}✅ 找到部署报告: ${REPORT_FILE}${NC}"
    echo ""
    echo -e "${BLUE}关键合约地址:${NC}"
    
    # 使用 Python3 解析 JSON（不依赖 jq）
    POOL=$(python3 -c "import json, sys; data = json.load(open('$REPORT_FILE')); print(data.get('poolProxy', '') or '')" 2>/dev/null || echo "")
    CONFIGURATOR=$(python3 -c "import json, sys; data = json.load(open('$REPORT_FILE')); print(data.get('poolConfiguratorProxy', '') or '')" 2>/dev/null || echo "")
    ORACLE=$(python3 -c "import json, sys; data = json.load(open('$REPORT_FILE')); print(data.get('aaveOracle', '') or '')" 2>/dev/null || echo "")
    TREASURY=$(python3 -c "import json, sys; data = json.load(open('$REPORT_FILE')); print(data.get('treasury', '') or '')" 2>/dev/null || echo "")
    
    if [ -n "$POOL" ] && [ "$POOL" != "null" ] && [ "$POOL" != "None" ]; then
        echo "  Pool:              $POOL"
        POOL_ADDRESS=$POOL
    fi
    if [ -n "$CONFIGURATOR" ] && [ "$CONFIGURATOR" != "null" ] && [ "$CONFIGURATOR" != "None" ]; then
        echo "  PoolConfigurator:   $CONFIGURATOR"
    fi
    if [ -n "$ORACLE" ] && [ "$ORACLE" != "null" ] && [ "$ORACLE" != "None" ]; then
        echo "  Oracle:            $ORACLE"
    fi
    if [ -n "$TREASURY" ] && [ "$TREASURY" != "null" ] && [ "$TREASURY" != "None" ]; then
        echo "  Treasury:          $TREASURY"
    fi
fi

echo ""

# 方法 2: 检查合约代码是否存在
if [ -z "$POOL_ADDRESS" ]; then
    echo -e "${YELLOW}[2/4] 跳过合约验证（未找到 Pool 地址）${NC}"
else
    echo -e "${YELLOW}[2/4] 验证合约代码...${NC}"
    
    # 使用 JSON-RPC 直接检查合约代码（绕过代理问题）
    if [ "$NETWORK" == "local" ] || [ "$NETWORK" == "anvil" ] || [ "$NETWORK" == "localhost" ]; then
        # 本地部署：使用 curl 直接调用，绕过代理
        CODE_HEX=$(curl --noproxy '*' -s -X POST -H "Content-Type: application/json" \
            --data "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getCode\",\"params\":[\"$POOL_ADDRESS\",\"latest\"],\"id\":1}" \
            "$RPC_URL" 2>/dev/null | python3 -c "import json, sys; data = json.load(sys.stdin); print(data.get('result', '0x'))" 2>/dev/null || echo "0x")
        
        if [ "$CODE_HEX" != "0x" ] && [ -n "$CODE_HEX" ] && [ "$CODE_HEX" != "None" ]; then
            CODE_LENGTH=$(((${#CODE_HEX} - 2) / 2))
            echo -e "${GREEN}✅ 合约代码存在（${CODE_LENGTH} 字节）${NC}"
            CODE_EXISTS=true
        else
            CODE="0x"
            CODE_EXISTS=false
        fi
    else
        # 远程部署：使用 cast
        CODE=$(cast code "$POOL_ADDRESS" --rpc-url "$RPC_URL" 2>/dev/null || echo "0x")
        if [ "$CODE" != "0x" ] && [ -n "$CODE" ]; then
            CODE_LENGTH=${#CODE}
            echo -e "${GREEN}✅ 合约代码存在（${CODE_LENGTH} 字符）${NC}"
            CODE_EXISTS=true
        else
            CODE_EXISTS=false
        fi
    fi
    
    if [ "$CODE_EXISTS" != "true" ]; then
        echo -e "${RED}❌ 合约代码不存在（地址: $POOL_ADDRESS）${NC}"
        echo ""
        if [ "$NETWORK" == "local" ] || [ "$NETWORK" == "anvil" ] || [ "$NETWORK" == "localhost" ]; then
            echo -e "${YELLOW}可能原因:${NC}"
            echo "   1. Anvil 节点已重启，之前的部署状态丢失"
            echo "   2. 合约未成功部署"
            echo ""
            echo -e "${BLUE}解决方案:${NC}"
            echo "   重新部署合约:"
            echo "   ${GREEN}./deploy/scripts/deploy.sh local${NC}"
        else
            echo -e "${YELLOW}可能原因:${NC}"
            echo "   - 合约未成功部署"
            echo "   - 部署交易失败"
            echo "   - 网络不同步"
            echo ""
            echo -e "${BLUE}建议:${NC}"
            echo "   检查部署交易是否成功，或重新部署"
        fi
    fi
fi

echo ""

# 方法 3: 调用合约方法验证
if [ -z "$POOL_ADDRESS" ]; then
    echo -e "${YELLOW}[3/4] 跳过功能验证（未找到 Pool 地址）${NC}"
else
    echo -e "${YELLOW}[3/4] 验证合约功能...${NC}"
    
    # 检查 getReservesCount
    echo -n "  检查 getReservesCount()... "
    if [ "$NETWORK" == "local" ] || [ "$NETWORK" == "anvil" ] || [ "$NETWORK" == "localhost" ]; then
        # 本地部署：使用 JSON-RPC 直接调用（getReservesCount() 函数选择器: 0x72218d04）
        RESERVES_COUNT_HEX=$(curl --noproxy '*' -s -X POST -H "Content-Type: application/json" \
            --data "{\"jsonrpc\":\"2.0\",\"method\":\"eth_call\",\"params\":[{\"to\":\"$POOL_ADDRESS\",\"data\":\"0x72218d04\"},\"latest\"],\"id\":1}" \
            "$RPC_URL" 2>/dev/null | python3 -c "import json, sys; data = json.load(sys.stdin); result = data.get('result', '0x'); print(result if result and result != '0x' and 'error' not in data else '0x')" 2>/dev/null || echo "0x")
        if [ "$RESERVES_COUNT_HEX" != "0x" ] && [ -n "$RESERVES_COUNT_HEX" ] && [ "$RESERVES_COUNT_HEX" != "None" ]; then
            RESERVES_COUNT_DEC=$(python3 -c "print(int('$RESERVES_COUNT_HEX', 16))" 2>/dev/null || echo "N/A")
            echo -e "${GREEN}✅ ${RESERVES_COUNT_DEC}${NC}"
        else
            echo -e "${RED}❌ 调用失败${NC}"
        fi
        RESERVES_COUNT="$RESERVES_COUNT_HEX"
    else
        RESERVES_COUNT=$(cast call "$POOL_ADDRESS" "getReservesCount()" --rpc-url "$RPC_URL" 2>/dev/null || echo "")
        if [ -n "$RESERVES_COUNT" ]; then
            COUNT=$(cast --to-dec "$RESERVES_COUNT" 2>/dev/null || echo "N/A")
            echo -e "${GREEN}✅ ${COUNT}${NC}"
        else
            echo -e "${RED}❌ 调用失败${NC}"
        fi
    fi
    
    # 检查 ADDRESSES_PROVIDER
    echo -n "  检查 ADDRESSES_PROVIDER()... "
    if [ "$NETWORK" == "local" ] || [ "$NETWORK" == "anvil" ] || [ "$NETWORK" == "localhost" ]; then
        # 本地部署：使用 JSON-RPC 直接调用（ADDRESSES_PROVIDER() 函数选择器: 0x0542975c）
        PROVIDER_HEX=$(curl --noproxy '*' -s -X POST -H "Content-Type: application/json" \
            --data "{\"jsonrpc\":\"2.0\",\"method\":\"eth_call\",\"params\":[{\"to\":\"$POOL_ADDRESS\",\"data\":\"0x0542975c\"},\"latest\"],\"id\":1}" \
            "$RPC_URL" 2>/dev/null | python3 -c "import json, sys; data = json.load(sys.stdin); result = data.get('result', '0x'); print(result if result and result != '0x' and 'error' not in data else '0x')" 2>/dev/null || echo "0x")
        if [ "$PROVIDER_HEX" != "0x" ] && [ -n "$PROVIDER_HEX" ] && [ "$PROVIDER_HEX" != "None" ] && [ "$PROVIDER_HEX" != "0x0000000000000000000000000000000000000000000000000000000000000000" ]; then
            # 提取地址（最后40个字符，去掉0x前缀）
            PROVIDER_ADDR="0x${PROVIDER_HEX: -40}"
            echo -e "${GREEN}✅ $PROVIDER_ADDR${NC}"
        else
            echo -e "${RED}❌ 调用失败或返回零地址${NC}"
        fi
        PROVIDER="$PROVIDER_HEX"
    else
        PROVIDER=$(cast call "$POOL_ADDRESS" "ADDRESSES_PROVIDER()" --rpc-url "$RPC_URL" 2>/dev/null || echo "")
        if [ -n "$PROVIDER" ] && [ "$PROVIDER" != "0x0000000000000000000000000000000000000000" ]; then
            echo -e "${GREEN}✅ $PROVIDER${NC}"
        else
            echo -e "${RED}❌ 调用失败或返回零地址${NC}"
        fi
    fi
    
    # 检查 getReservesList（如果有储备）
    if [ -n "$RESERVES_COUNT" ] && [ "$RESERVES_COUNT" != "0x0000000000000000000000000000000000000000000000000000000000000000" ]; then
        echo -n "  检查 getReservesList()... "
        RESERVES_LIST=$(cast call "$POOL_ADDRESS" "getReservesList()" --rpc-url "$RPC_URL" 2>/dev/null || echo "")
        if [ -n "$RESERVES_LIST" ]; then
            echo -e "${GREEN}✅ 成功${NC}"
        else
            echo -e "${YELLOW}⚠️  调用失败（可能没有储备）${NC}"
        fi
    fi
fi

echo ""

# 方法 4: 检查 Etherscan（仅远程网络）
if [ "$NETWORK" == "local" ] || [ "$NETWORK" == "anvil" ] || [ "$NETWORK" == "localhost" ]; then
    echo -e "${YELLOW}[4/4] 跳过 Etherscan 检查（本地部署）${NC}"
else
    echo -e "${YELLOW}[4/4] Etherscan 验证提示...${NC}"
    if [ -n "$POOL_ADDRESS" ]; then
        case "$NETWORK" in
            sepolia)
                ETHERSCAN_URL="https://sepolia.etherscan.io/address/$POOL_ADDRESS"
                ;;
            mainnet)
                ETHERSCAN_URL="https://etherscan.io/address/$POOL_ADDRESS"
                ;;
            polygon)
                ETHERSCAN_URL="https://polygonscan.com/address/$POOL_ADDRESS"
                ;;
            arbitrum)
                ETHERSCAN_URL="https://arbiscan.io/address/$POOL_ADDRESS"
                ;;
            optimism)
                ETHERSCAN_URL="https://optimistic.etherscan.io/address/$POOL_ADDRESS"
                ;;
            *)
                ETHERSCAN_URL=""
                ;;
        esac
        
        if [ -n "$ETHERSCAN_URL" ]; then
            echo -e "${BLUE}   在浏览器中查看:${NC}"
            echo "   $ETHERSCAN_URL"
            echo ""
            echo "   如果合约已验证，您应该能看到:"
            echo "   - ✅ 合约源代码"
            echo "   - ✅ 合约交互界面"
            echo "   - ✅ 交易历史"
        fi
    fi
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}验证完成！${NC}"
echo -e "${BLUE}========================================${NC}"

