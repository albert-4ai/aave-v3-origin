#!/bin/bash

# 启动 Anvil 本地以太坊节点
# 用法: ./deploy/start-anvil.sh [port] [accounts]

PORT=${1:-8545}
ACCOUNTS=${2:-20}  # 默认生成 20 个账户（需要 18 个，留有余地）

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}启动 Anvil 节点...${NC}"
echo "端口: $PORT"
echo "账户数: $ACCOUNTS"
echo ""

# 检查端口是否被占用
if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  端口 $PORT 已被占用${NC}"
    
    # 查找占用端口的进程
    PID=$(lsof -ti :$PORT 2>/dev/null | head -1)
    if [ -n "$PID" ]; then
        PROCESS_NAME=$(ps -p $PID -o comm= 2>/dev/null || echo "unknown")
        echo -e "${YELLOW}发现进程: PID=$PID ($PROCESS_NAME)${NC}"
        
        # 如果是 anvil 进程，直接停止
        if echo "$PROCESS_NAME" | grep -q "anvil"; then
            echo -e "${YELLOW}停止现有的 Anvil 进程...${NC}"
            kill $PID 2>/dev/null || true
            sleep 1
            
            # 如果还在运行，强制停止
            if kill -0 $PID 2>/dev/null; then
                echo -e "${YELLOW}强制停止进程...${NC}"
                kill -9 $PID 2>/dev/null || true
                sleep 1
            fi
        else
            echo -e "${RED}端口被其他进程占用，请手动停止或使用其他端口${NC}"
            echo "停止进程: kill $PID"
            echo "或使用其他端口: ./deploy/start-anvil.sh 8546"
            exit 1
        fi
    else
        # 尝试停止所有 anvil 进程
        echo -e "${YELLOW}尝试停止 Anvil 进程...${NC}"
        pkill -f "anvil.*$PORT" 2>/dev/null || true
        sleep 2
    fi
    
    # 再次检查端口
    if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo -e "${RED}❌ 无法释放端口 $PORT${NC}"
        echo "请手动停止占用端口的进程"
        exit 1
    else
        echo -e "${GREEN}✅ 端口已释放${NC}"
        echo ""
    fi
fi

echo -e "${GREEN}启动 Anvil...${NC}"
echo "按 Ctrl+C 停止"
echo ""
echo -e "${YELLOW}优化配置（加快部署速度）:${NC}"
echo "  --no-mining: 手动挖矿模式，批量处理交易"
echo "  --order fifo: 按顺序处理交易"
echo ""

# 优化参数说明：
# --no-mining: 禁用自动挖矿，使用手动挖矿（配合 --mine-interval 效果更好）
# 但这会导致需要手动触发挖矿，所以我们使用默认的即时挖矿
# --order fifo: 按先进先出顺序处理交易
# --steps-tracing: 禁用步骤跟踪（加快速度）
# --silent: 减少输出（可选）

anvil \
  --port $PORT \
  --accounts $ACCOUNTS \
  --order fifo

