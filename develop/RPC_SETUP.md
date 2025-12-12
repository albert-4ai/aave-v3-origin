# RPC 配置说明

## 问题说明

运行 Aave V3 fork 测试需要一个支持 **archive 模式**的以太坊主网 RPC 节点。免费的公共 RPC 节点通常有以下限制：
- 历史状态被修剪（pruned）
- 需要 API Key
- 请求频率限制

## ✅ 推荐方案：使用 Alchemy（免费）

### 1. 注册 Alchemy 账号

1. 访问：https://dashboard.alchemy.com/
2. 点击 "Sign Up" 注册（免费）
3. 创建新的 App：
   - **Chain**: Ethereum
   - **Network**: Mainnet
   - **Name**: 任意名称（如 "Aave V3 Testing"）

### 2. 获取 API URL

在 Dashboard 中找到你的 App，点击 "View Key"，复制 **HTTPS** URL。

格式类似：
```
https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY
```

### 3. 配置和运行测试

#### 方法 A：临时使用（推荐用于测试）

```bash
# 直接在命令中指定 RPC URL
forge test --match-path tests/lending/Lend.t.sol -vv \
```

#### 方法 B：设置环境变量

```bash
# 设置环境变量
export RPC_MAINNET="https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY"

# 运行测试（会自动读取 foundry.toml 中的配置）
forge test --match-path tests/lending/Lend.t.sol -vv --fork-url $RPC_MAINNET
```

#### 方法 C：使用 .env 文件（长期使用）

1. 创建 `.env` 文件（已在 .gitignore 中）：

```bash
cat > .env << 'EOF'
# Ethereum Mainnet RPC
RPC_MAINNET=https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY

# 其他链（可选）
# RPC_OPTIMISM=
# RPC_ARBITRUM=
# RPC_POLYGON=
EOF
```

2. 加载环境变量并运行：

```bash
source .env
forge test --match-path tests/lending/Lend.t.sol -vv --fork-url $RPC_MAINNET
```

## 🔄 其他 RPC 提供商

### Infura（免费）

1. 注册：https://infura.io/
2. 创建项目，获取 Mainnet Endpoint
3. URL 格式：`https://mainnet.infura.io/v3/YOUR_API_KEY`

### QuickNode（有免费层）

1. 注册：https://www.quicknode.com/
2. 创建 Endpoint，选择 Ethereum Mainnet
3. 复制 HTTP Provider URL

### Ankr（需要注册）

1. 注册：https://www.ankr.com/rpc/
2. 获取免费 API Key
3. URL 格式：`https://rpc.ankr.com/eth/YOUR_API_KEY`

## 🚀 快速开始（完整流程）

```bash
# 1. 注册 Alchemy 并获取 API Key
# 访问：https://dashboard.alchemy.com/

# 2. 设置环境变量（替换为你的 API Key）
export RPC_MAINNET="https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY"

# 3. 运行测试
cd ~/web3/aave-v3-origin
forge test --match-path tests/lending/Lend.t.sol -vv --fork-url $RPC_MAINNET

# 4. 看到成功的输出！✅
```

## 📌 常见问题

### Q: 为什么不能使用免费公共 RPC？

A: 免费公共 RPC 节点通常：
- 不支持历史状态查询（pruned state）
- 有严格的请求频率限制
- 不稳定，经常出现错误

### Q: Alchemy 免费层够用吗？

A: 足够！免费层包括：
- 每月 3 亿 Compute Units
- Archive 数据访问
- 对于开发和测试完全够用

### Q: 如何验证 RPC 是否工作？

A: 运行简单的测试：

```bash
cast block latest --rpc-url https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY
```

如果返回最新区块信息，说明 RPC 工作正常。

### Q: 错误 "state is pruned" 是什么意思？

A: 表示 RPC 节点没有保存历史状态数据。需要使用支持 archive 模式的节点（如 Alchemy、Infura）。

## 🎯 测试命令总结

```bash
# 完整命令（推荐）
forge test --match-path tests/lending/Lend.t.sol -vv \
  --fork-url https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY

# 简短命令（配置环境变量后）
forge test --match-path tests/lending/Lend.t.sol -vv --fork-url $RPC_MAINNET

# 指定区块号（可选）
forge test --match-path tests/lending/Lend.t.sol -vv \
  --fork-url $RPC_MAINNET \
  --fork-block-number 21000000
```

## 🔐 安全提示

⚠️ **重要**：
- 不要将 API Key 提交到 Git 仓库
- 使用 `.env` 文件存储密钥（已在 .gitignore 中）
- 如果不小心泄露，立即在提供商 Dashboard 中重新生成



