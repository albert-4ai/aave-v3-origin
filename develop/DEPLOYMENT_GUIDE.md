# Aave V3.5 部署指南

本文档介绍如何部署 Aave V3.5 协议到各种网络。

## 📋 前置要求

1. **安装 Foundry**
   ```bash
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```

2. **安装 Node.js 依赖**
   ```bash
   npm install
   ```

3. **配置环境变量**
   创建 `.env` 文件（项目根目录），配置以下变量：

   ```bash
   # RPC 端点（根据要部署的网络配置）
   RPC_MAINNET=https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY
   RPC_SEPOLIA=https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY
   RPC_POLYGON=https://polygon-mainnet.g.alchemy.com/v2/YOUR_API_KEY
   # ... 其他网络的 RPC URL
   
   # Etherscan API Keys（用于合约验证）
   ETHERSCAN_API_KEY_MAINNET=your_etherscan_api_key
   ETHERSCAN_API_KEY_POLYGON=your_polygon_scan_api_key
   # ... 其他网络的 API keys
   
   # 部署账户配置（选择一种方式）
   # 方式1: 使用私钥（测试网推荐）
   PRIVATE_KEY=your_private_key
   
   # 方式2: 使用 Ledger 硬件钱包（主网推荐）
   LEDGER=true
   MNEMONIC_INDEX=0
   LEDGER_SENDER=0xYourLedgerAddress
   ```

## 🚀 部署方式

### 方式 1: 使用默认配置部署（测试网）

最简单的部署方式，使用默认配置：

```bash
# 部署到 Sepolia 测试网
forge script scripts/DeployAaveV3MarketBatched.sol:Default \
  --rpc-url sepolia \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  -vvvv
```

### 方式 2: 自定义部署配置

如果需要自定义配置，需要创建自己的部署脚本：

1. **创建自定义 MarketInput 合约**

   创建文件 `scripts/CustomMarketInput.sol`:

   ```solidity
   // SPDX-License-Identifier: BUSL-1.1
   pragma solidity ^0.8.0;
   
   import './misc/DeployAaveV3MarketBatchedBase.sol';
   import '../src/deployments/inputs/MarketInput.sol';
   
   contract CustomMarketInput is MarketInput {
     function _getMarketInput(
       address deployer
     )
       internal
       pure
       override
       returns (
         Roles memory roles,
         MarketConfig memory config,
         DeployFlags memory flags,
         MarketReport memory deployedContracts
       )
     {
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
       config.networkBaseTokenPriceInUsdProxyAggregator = address(0x...); // ETH/USD 价格源
       config.marketReferenceCurrencyPriceInUsdProxyAggregator = address(0x...); // 参考货币价格源
       
       // 配置 Wrapped Native Token（可选）
       config.wrappedNativeToken = address(0x...); // WETH 地址
       
       // L2 配置（如果是 L2 网络）
       flags.l2 = true; // 或 false
       config.l2SequencerUptimeFeed = address(0x...); // L2 序列器状态源
       config.l2PriceOracleSentinelGracePeriod = 2 hours;
       
       // Paraswap 配置（可选）
       config.paraswapAugustusRegistry = address(0x...);
       
       // 金库配置（可选）
       config.treasury = address(0x...); // 如果为空，将部署新的 Collector
       config.treasuryPartner = address(0x...); // 收入分成伙伴（可选）
       config.treasurySplitPercent = 5000; // 50% 分成（如果设置了 partner）
       
       return (roles, config, flags, deployedContracts);
     }
   }
   ```

2. **创建部署脚本**

   创建文件 `scripts/DeployCustom.sol`:

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

### 方式 3: 使用 Ledger 硬件钱包部署（主网推荐）

```bash
forge script scripts/DeployAaveV3MarketBatched.sol:Default \
  --rpc-url mainnet \
  --ledger \
  --mnemonic-indexes $MNEMONIC_INDEX \
  --sender $LEDGER_SENDER \
  --broadcast \
  --verify \
  --slow \
  -vvvv
```

## 📝 部署配置说明

### MarketConfig 结构体参数

| 参数 | 类型 | 说明 | 必需 |
|------|------|------|------|
| `marketId` | string | 市场标识符 | ✅ |
| `providerId` | uint256 | Provider ID | ✅ |
| `oracleDecimals` | uint8 | 预言机精度（通常为 8） | ✅ |
| `flashLoanPremium` | uint128 | Flash Loan 手续费（基点） | ✅ |
| `networkBaseTokenPriceInUsdProxyAggregator` | address | 基础代币价格源（如 ETH/USD） | ⚠️ |
| `marketReferenceCurrencyPriceInUsdProxyAggregator` | address | 参考货币价格源 | ⚠️ |
| `wrappedNativeToken` | address | Wrapped Native Token 地址 | ❌ |
| `paraswapAugustusRegistry` | address | Paraswap 注册表地址 | ❌ |
| `l2SequencerUptimeFeed` | address | L2 序列器状态源（L2 必需） | ⚠️ |
| `l2PriceOracleSentinelGracePeriod` | uint256 | L2 价格预言机宽限期 | ⚠️ |
| `treasury` | address | 金库地址（空则部署新的） | ❌ |
| `treasuryPartner` | address | 收入分成伙伴地址 | ❌ |
| `treasurySplitPercent` | uint16 | 收入分成百分比（基点） | ❌ |

### Roles 结构体参数

| 参数 | 类型 | 说明 |
|------|------|------|
| `marketOwner` | address | 市场所有者地址 |
| `emergencyAdmin` | address | 紧急管理员地址 |
| `poolAdmin` | address | 池管理员地址 |

### DeployFlags 结构体参数

| 参数 | 类型 | 说明 |
|------|------|------|
| `l2` | bool | 是否为 L2 网络 |

## 🌐 支持的网络

项目支持以下网络部署：

- **主网**: Ethereum, Polygon, Arbitrum, Optimism, Avalanche, Base, BNB Chain, Gnosis, Metis, Linea, Scroll, zkSync
- **测试网**: Sepolia, Mumbai, Amoy, BNB Testnet, Fantom Testnet

在 `foundry.toml` 中配置了各网络的 RPC 端点。

## 📊 部署后

部署完成后，会在 `reports/` 目录下生成部署报告 JSON 文件，包含所有已部署合约的地址。

### 查看部署报告

```bash
cat reports/market-report-*.json
```

报告包含以下信息：
- Pool 代理地址
- PoolConfigurator 代理地址
- Oracle 地址
- Treasury 地址
- 所有代币地址（aToken, variableDebtToken）
- 其他辅助合约地址

## ⚠️ 注意事项

1. **测试网部署**: 使用默认配置即可，适合测试和学习
2. **主网部署**: 
   - 强烈建议使用 Ledger 硬件钱包
   - 仔细检查所有配置参数
   - 确保有足够的 ETH 支付 gas 费用
   - 建议先在测试网完整测试

3. **Gas 费用**: 完整部署 Aave V3 市场需要大量 gas，建议：
   - 使用 `--slow` 标志避免 nonce 冲突
   - 确保账户有足够的余额

4. **合约验证**: 使用 `--verify` 标志自动验证合约，需要配置相应的 Etherscan API Key

5. **L2 网络**: 如果部署到 L2，需要：
   - 设置 `flags.l2 = true`
   - 配置 `l2SequencerUptimeFeed`
   - 配置 `l2PriceOracleSentinelGracePeriod`

## 🔧 故障排除

### 常见问题

1. **RPC 连接失败**
   - 检查 `.env` 文件中的 RPC URL 是否正确
   - 确认网络连接正常

2. **Gas 不足**
   - 确保账户有足够的 ETH
   - 检查 gas price 设置

3. **合约验证失败**
   - 检查 Etherscan API Key 是否正确
   - 确认网络配置正确

4. **Nonce 冲突**
   - 使用 `--slow` 标志
   - 检查是否有待处理的交易

## 📚 更多资源

- [Foundry 文档](https://book.getfoundry.sh/)
- [Aave V3 技术文档](./docs/Aave_V3_Technical_Paper.pdf)
- [Aave V3.5 特性文档](./docs/3.5/Aave-v3.5-features.md)

## 🆘 获取帮助

如有问题，请参考：
- 项目 GitHub Issues
- Aave 社区论坛
- Foundry Discord

