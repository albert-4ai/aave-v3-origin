# 部署指南

本文档介绍如何将 Aave V3.5 协议部署到本地和远程网络。

## 📋 第一步：准备工作

在开始部署之前，必须完成以下准备工作。

### 1.1 安装必需工具

**Foundry** - Solidity 开发框架（必需）

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

验证安装：
```bash
forge --version
cast --version
anvil --version
```

**Node.js** - 可选，用于某些工具

```bash
npm install
```

### 1.2 配置环境变量

在项目根目录创建 `.env` 文件：

```bash
# RPC 端点（远程部署必需）
RPC_MAINNET=https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY
RPC_SEPOLIA=https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY
RPC_POLYGON=https://polygon-mainnet.g.alchemy.com/v2/YOUR_API_KEY

# Etherscan API Keys（用于合约验证，可选）
ETHERSCAN_API_KEY_MAINNET=your_etherscan_api_key
ETHERSCAN_API_KEY_SEPOLIA=your_etherscan_api_key

# 部署账户配置（远程部署必需）
PRIVATE_KEY=your_private_key  # 测试网推荐
# 或使用 Ledger 硬件钱包（主网推荐）
# LEDGER=true
# MNEMONIC_INDEX=0
# LEDGER_SENDER=0xYourLedgerAddress
```

**重要提示**：
- 本地部署（Anvil）**不需要**配置 RPC 和私钥
- 远程部署**必须**配置对应的 RPC URL
- 主网部署**强烈建议**使用 Ledger 硬件钱包

## 📝 第二步：了解部署脚本

### 2.1 脚本基本语法

```bash
./deploy/scripts/deploy.sh <network> [private_key]
```

**参数说明**：
- `<network>`: 网络名称（必需）
  - `local` / `anvil` / `localhost` - 本地 Anvil 节点
  - `sepolia` - Sepolia 测试网
  - `mainnet` - Ethereum 主网
  - `polygon` - Polygon 主网
  - `arbitrum` - Arbitrum One
  - `optimism` - Optimism
- `[private_key]`: 私钥（可选）
  - 如果未提供，会从环境变量 `PRIVATE_KEY` 或 `.env` 文件读取
  - 本地部署时，如果未提供，会自动使用 Anvil 默认账户

### 2.2 私钥配置方式（按优先级）

1. **命令行参数**（最高优先级）
   ```bash
   ./deploy/scripts/deploy.sh sepolia 0x1234...
   ```

2. **环境变量**
   ```bash
   export PRIVATE_KEY=0x1234...
   ./deploy/scripts/deploy.sh sepolia
   ```

3. **`.env` 文件**（最低优先级）
   ```bash
   # .env 文件中
   PRIVATE_KEY=0x1234...
   ```

### 2.3 RPC URL 配置

脚本会自动从环境变量读取 RPC URL：

```bash
# .env 文件或环境变量
RPC_SEPOLIA=https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY
RPC_MAINNET=https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY
```

如果未找到对应的环境变量，脚本会使用网络名称作为 RPC URL（适用于 Foundry 内置网络别名）。

## 🚀 第三步：执行部署

根据目标网络选择对应的部署方式。

### 场景 A：本地部署（Anvil）

**适用场景**：开发、测试、学习

#### 步骤 1：启动 Anvil 节点

打开**终端 1**，运行：

```bash
# 方式 1：直接启动
anvil

# 方式 2：使用脚本（推荐）
./deploy/scripts/start-anvil.sh
```

**预期输出**：
- Anvil 节点运行在 `http://127.0.0.1:8545`
- 显示 10 个预充值账户及其私钥

#### 步骤 2：运行部署脚本

打开**终端 2**（保持终端 1 的 Anvil 运行），运行：

```bash
# 使用 Anvil 默认账户（推荐，最简单）
./deploy/scripts/deploy.sh local

# 或指定私钥
./deploy/scripts/deploy.sh local $PRIVATE_KEY
```

**脚本执行流程**：
1. ✅ 检查 Anvil 节点状态（自动重试 5 次，每次间隔 1 秒）
2. ✅ 自动设置 CREATE2 工厂（如果不存在）
3. ✅ 自动使用 Anvil 默认账户（如果未提供私钥）
4. ✅ 部署 Aave V3 协议
5. ✅ 生成部署报告到 `reports/` 目录
6. ✅ 显示部署后的下一步操作提示

**预期输出**：
```
🚀 开始本地部署 Aave V3.5 到 Anvil...
✅ Anvil 节点运行正常 (区块: 0)
✅ CREATE2 工厂设置成功
开始部署...
✅ 本地部署成功！
部署报告已保存到 reports/ 目录
```

#### 步骤 3：验证部署（见第四步）

---

### 场景 B：远程网络部署（测试网/主网）

**适用场景**：测试网测试、主网部署

#### 步骤 1：确认环境配置

**测试网部署**：
- ✅ 已配置 `RPC_SEPOLIA` 环境变量
- ✅ 已配置 `PRIVATE_KEY`（测试网可以使用私钥）

**主网部署**：
- ✅ 已配置 `RPC_MAINNET` 环境变量
- ✅ 已配置 `ETHERSCAN_API_KEY_MAINNET`（用于合约验证）
- ✅ 已准备 Ledger 硬件钱包（强烈推荐）
- ✅ 已确认账户有足够的 ETH 支付 Gas 费用

#### 步骤 2：运行部署脚本

**测试网部署**：
```bash
./deploy/scripts/deploy.sh sepolia $PRIVATE_KEY
```

**主网部署**：
```bash
# 脚本会要求确认（防止误操作）
./deploy/scripts/deploy.sh mainnet $PRIVATE_KEY
```

**脚本执行流程**：
1. ✅ 检查私钥是否提供
2. ✅ 从环境变量读取 RPC URL
3. ✅ 自动检测并启用合约验证（如果配置了 Etherscan API Key）
4. ✅ 主网部署前要求确认（防止误操作）
5. ✅ 执行部署
6. ✅ 自动生成部署报告到 `reports/` 目录

**预期输出**：
```
开始部署 Aave V3.5 到 sepolia...
找到 Etherscan API Key，将启用合约验证
执行命令: forge script ...
✅ 部署成功！
部署报告已保存到 reports/ 目录
```

#### 步骤 3：验证部署（见第四步）

---

### 场景 C：手动部署（高级用法）

如果脚本不可用或需要更多控制，可以手动部署。

#### 本地手动部署

**步骤 1：设置 CREATE2 工厂**（必需）

```bash
cast rpc anvil_setCode \
  0x914d7Fec6aaC8cd542e72Bca78B30650d45643d7 \
  "0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378035828234f58015156039578182fd5b8082525050506014600cf3" \
  --rpc-url http://127.0.0.1:8545
```

**步骤 2：部署协议**

```bash
forge script scripts/DeployAaveV3MarketBatched.sol:Default \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --broadcast \
  -vvv
```

#### 远程手动部署

**测试网部署**：
```bash
forge script scripts/DeployAaveV3MarketBatched.sol:Default \
  --rpc-url $RPC_SEPOLIA \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  -vvvv
```

**主网部署**（使用 Ledger 硬件钱包）：
```bash
forge script scripts/DeployAaveV3MarketBatched.sol:Default \
  --rpc-url $RPC_MAINNET \
  --ledger \
  --mnemonic-indexes $MNEMONIC_INDEX \
  --sender $LEDGER_SENDER \
  --broadcast \
  --verify \
  --slow \
  -vvvv
```

---

## 📊 第四步：部署后验证

部署完成后，需要验证部署是否成功。

### 4.1 快速验证（推荐）

使用验证脚本自动检查所有项目：

```bash
# 本地部署验证
./deploy/scripts/verify-deployment.sh local

# 远程部署验证（如 Sepolia）
./deploy/scripts/verify-deployment.sh sepolia

# 指定 Pool 地址验证
./deploy/scripts/verify-deployment.sh sepolia 0xYourPoolAddress
```

验证脚本会检查：
1. ✅ 部署报告文件是否存在
2. ✅ 合约代码是否已部署到链上
3. ✅ 合约功能是否正常（调用关键方法）
4. ✅ Etherscan 链接（远程部署）

### 4.2 查看部署报告

```bash
# 查看最新的部署报告（格式化输出）
ls -la reports/*-market-deployment.json | tail -1 | xargs cat | jq

# 查看所有报告文件
ls -la reports/*.json

# 提取关键地址
cat reports/*-market-deployment.json | jq -r '.poolProxy'
cat reports/*-market-deployment.json | jq -r '.poolConfiguratorProxy'
cat reports/*-market-deployment.json | jq -r '.aaveOracle'
cat reports/*-market-deployment.json | jq -r '.treasury'
```

**报告包含的关键信息**：
- `poolProxy`: Pool 代理地址
- `poolConfiguratorProxy`: PoolConfigurator 代理地址
- `aaveOracle`: Oracle 地址
- `treasury`: Treasury 地址
- 所有代币地址（aToken, variableDebtToken）

### 4.3 手动验证合约功能

如果验证脚本不可用，可以手动验证：

```bash
# 设置 RPC URL（本地）
RPC_URL="http://127.0.0.1:8545"

# 或远程网络（从环境变量读取）
RPC_URL=$RPC_SEPOLIA  # 或其他网络

# 获取 Pool 地址
POOL=$(cat reports/*-market-deployment.json | jq -r '.poolProxy')

# 检查合约代码是否存在
cast code $POOL --rpc-url $RPC_URL

# 调用合约方法验证
cast call $POOL "getReservesCount()" --rpc-url $RPC_URL
cast call $POOL "ADDRESSES_PROVIDER()" --rpc-url $RPC_URL
cast call $POOL "getReservesList()" --rpc-url $RPC_URL
```

**验证要点**：
- ✅ `getReservesCount()` 应返回储备数量（初始为 0）
- ✅ `ADDRESSES_PROVIDER()` 应返回非零地址
- ✅ `getReservesList()` 应返回储备列表（可能为空）

### 4.4 检查 Etherscan（远程部署）

如果启用了合约验证，可以在 Etherscan 上查看：
- 合约源代码
- 合约交互界面
- 交易历史

**各网络 Etherscan 链接**：
- **Sepolia**: https://sepolia.etherscan.io/address/{POOL_ADDRESS}
- **Mainnet**: https://etherscan.io/address/{POOL_ADDRESS}
- **Polygon**: https://polygonscan.com/address/{POOL_ADDRESS}
- **Arbitrum**: https://arbiscan.io/address/{POOL_ADDRESS}
- **Optimism**: https://optimistic.etherscan.io/address/{POOL_ADDRESS}

### 4.5 常见问题排查

#### 问题 1: 找不到部署报告
```bash
# 检查 reports 目录
ls -la reports/

# 如果目录不存在，创建它
mkdir -p reports
```

#### 问题 2: 合约代码不存在
- 检查 RPC URL 是否正确
- 确认部署交易是否成功
- 检查网络连接

#### 问题 3: 合约方法调用失败
- 确认合约地址正确
- 检查 RPC 节点是否同步
- 验证合约 ABI 是否匹配

---

## 📚 参考信息

### 支持的网络

#### 脚本直接支持的网络

部署脚本 (`deploy.sh`) 内置支持以下网络：

- **本地**: `local` / `anvil` / `localhost` - 本地 Anvil 节点
- **测试网**: `sepolia` - Sepolia 测试网
- **主网**: `mainnet`, `polygon`, `arbitrum`, `optimism`

#### 其他网络

对于其他网络（Avalanche, Base, BNB Chain, Gnosis, Metis, Linea, Scroll, zkSync 等），可以：

1. **使用脚本**：设置环境变量后直接使用
   ```bash
   export RPC_AVALANCHE=https://avalanche-mainnet.infura.io/v3/YOUR_KEY
   ./deploy/scripts/deploy.sh avalanche $PRIVATE_KEY
   ```

2. **手动部署**：使用 `forge script` 命令直接部署
   ```bash
   forge script scripts/DeployAaveV3MarketBatched.sol:Default \
     --rpc-url $RPC_URL \
     --private-key $PRIVATE_KEY \
     --broadcast \
     -vvvv
   ```

### 配置参数说明

#### MarketConfig 结构体

| 参数 | 类型 | 说明 | 必需 |
|------|------|------|------|
| `marketId` | string | 市场标识符 | ✅ |
| `providerId` | uint256 | Provider ID | ✅ |
| `oracleDecimals` | uint8 | 预言机精度（通常为 8） | ✅ |
| `flashLoanPremium` | uint128 | Flash Loan 手续费（基点） | ✅ |
| `networkBaseTokenPriceInUsdProxyAggregator` | address | 基础代币价格源 | ⚠️ |
| `marketReferenceCurrencyPriceInUsdProxyAggregator` | address | 参考货币价格源 | ⚠️ |
| `wrappedNativeToken` | address | Wrapped Native Token 地址 | ❌ |
| `l2SequencerUptimeFeed` | address | L2 序列器状态源（L2 必需） | ⚠️ |
| `l2PriceOracleSentinelGracePeriod` | uint256 | L2 价格预言机宽限期 | ⚠️ |
| `treasury` | address | 金库地址（空则部署新的） | ❌ |

#### Roles 结构体

| 参数 | 类型 | 说明 |
|------|------|------|
| `marketOwner` | address | 市场所有者地址 |
| `emergencyAdmin` | address | 紧急管理员地址 |
| `poolAdmin` | address | 池管理员地址 |

### 本地部署配置说明

本地部署使用 `DefaultMarketInput` 配置，特点：
- ✅ 无需真实预言机（可部署后设置 mock）
- ✅ 无需真实代币
- ✅ 所有角色为部署者
- ✅ 无需 L2 配置

### 自定义配置部署

如果需要自定义配置，可以创建自定义 MarketInput 合约：

1. **创建自定义 MarketInput 合约**

   创建 `scripts/CustomMarketInput.sol`:

   ```solidity
   // SPDX-License-Identifier: BUSL-1.1
   pragma solidity ^0.8.0;
   
   import './misc/DeployAaveV3MarketBatchedBase.sol';
   import '../src/deployments/inputs/MarketInput.sol';
   
   contract CustomMarketInput is MarketInput {
     function _getMarketInput(address deployer)
       internal pure override returns (
         Roles memory roles,
         MarketConfig memory config,
         DeployFlags memory flags,
         MarketReport memory deployedContracts
       ) {
       // 配置角色
       roles.marketOwner = deployer;
       roles.emergencyAdmin = deployer;
       roles.poolAdmin = deployer;
       
       // 配置市场参数
       config.marketId = 'Your Custom Market Name';
       config.providerId = 8080;
       config.oracleDecimals = 8;
       config.flashLoanPremium = 0.0005e4; // 0.05%
       
       // 配置预言机（必需）
       config.networkBaseTokenPriceInUsdProxyAggregator = address(0x...);
       config.marketReferenceCurrencyPriceInUsdProxyAggregator = address(0x...);
       
       // L2 配置（如果是 L2 网络）
       flags.l2 = true;
       config.l2SequencerUptimeFeed = address(0x...);
       config.l2PriceOracleSentinelGracePeriod = 2 hours;
       
       return (roles, config, flags, deployedContracts);
     }
   }
   ```

2. **创建部署脚本**

   创建 `scripts/DeployCustom.sol`:

   ```solidity
   // SPDX-License-Identifier: BUSL-1.1
   pragma solidity ^0.8.0;
   
   import {DeployAaveV3MarketBatchedBase} from './misc/DeployAaveV3MarketBatchedBase.sol';
   import {CustomMarketInput} from './CustomMarketInput.sol';
   
   contract CustomDeploy is DeployAaveV3MarketBatchedBase, CustomMarketInput {}
   ```

3. **运行部署**

   ```bash
   forge script scripts/DeployCustom.sol:CustomDeploy \
     --rpc-url sepolia \
     --private-key $PRIVATE_KEY \
     --broadcast \
     --verify \
     -vvvv
   ```

---

## ⚠️ 注意事项

### 安全建议

- 🔒 **主网部署**：强烈建议使用 Ledger 硬件钱包
- 🔒 **私钥管理**：永远不要将私钥提交到 Git 仓库
- 🔒 **环境变量**：使用 `.env` 文件存储敏感信息（已在 `.gitignore` 中）

### 测试建议

- ✅ 始终先在本地测试
- ✅ 在测试网完整测试所有功能
- ✅ 验证所有配置参数
- ✅ 检查 Gas 费用估算

### Gas 费用

完整部署 Aave V3 市场需要大量 gas，建议：
- 使用 `--slow` 标志避免 nonce 冲突
- 确保账户有足够的余额
- 主网部署前估算总费用

### L2 网络特殊配置

如果部署到 L2，需要：
- 设置 `flags.l2 = true`
- 配置 `l2SequencerUptimeFeed`
- 配置 `l2PriceOracleSentinelGracePeriod`

---

## 🔧 故障排除

### 常见问题

1. **RPC 连接失败**
   - 检查 `.env` 文件中的 RPC URL 是否正确
   - 确认网络连接正常
   - 验证 RPC 端点是否可用

2. **Gas 不足**
   - 确保账户有足够的 ETH
   - 检查 gas price 设置
   - 估算部署所需的总 Gas 费用

3. **CREATE2 工厂错误**（本地部署）
   - ✅ 部署脚本会自动检测并设置 CREATE2 工厂
   - ⚠️ 手动部署需要先设置工厂代码（见"手动部署"部分）
   - 🔍 检查：`cast code 0x914d7Fec6aaC8cd542e72Bca78B30650d45643d7 --rpc-url http://127.0.0.1:8545`

4. **合约验证失败**
   - 检查 Etherscan API Key 是否正确
   - 确认网络配置正确
   - 检查合约是否已成功部署

5. **Nonce 冲突**
   - 使用 `--slow` 标志
   - 检查是否有待处理的交易
   - 等待之前的交易确认

6. **Anvil 节点无法连接**（本地部署）
   - 确认 Anvil 节点正在运行
   - 检查端口是否为 8545
   - 尝试重启 Anvil 节点

---

## 🔗 相关文档

- [配置指南](./CONFIGURATION.md) - RPC 和 Oracle 配置
- [架构文档](./ARCHITECTURE.md) - 权限架构详解
- [功能文档](./FEATURE.md) - 质押借贷流程说明
- [返回首页](./README.md)
