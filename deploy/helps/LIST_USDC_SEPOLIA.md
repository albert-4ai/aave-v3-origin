# 在 Sepolia 测试网注册 USDC 代币（增强版）

本指南说明如何使用增强的自动化脚本在 Sepolia 测试网的 Aave Pool 中注册 USDC 代币。脚本包含全面的诊断、权限检查和错误处理功能。

## 前置条件

1. **已部署 Aave 协议合约**到 Sepolia 测试网
2. **部署账户具有 POOL_ADMIN_ROLE** 权限
3. **环境变量已配置**：
   - `RPC_SEPOLIA`: Sepolia RPC URL
   - `PRIVATE_KEY`: 部署账户私钥

## 方法 1：使用 Shell 脚本（推荐）

最简单的方法是使用提供的 shell 脚本：

```bash
./deploy/scripts/list-usdc-sepolia.sh
```

脚本会自动执行全面的预检查和注册流程：

### 预检查阶段
1. **环境变量验证** - 检查 RPC URL 和私钥配置
2. **部署报告读取** - 从最新的部署报告提取合约地址
3. **网络连接测试** - 验证 RPC 连接和区块同步
4. **合约代码验证** - 检查 Pool、ConfigEngine 等合约代码存在性
5. **储备列表检查** - 查询当前池中的储备资产
6. **USDC 代币验证** - 确认 USDC 合约存在并获取代币信息
7. **权限检查** - 验证部署账户具有 POOL_ADMIN_ROLE

### 注册执行阶段
8. **USDC 状态检查** - 确认 USDC 是否已注册到池中
9. **价格预言机部署** - 部署 Mock 价格预言机（价格 $1.00）
10. **Payload 创建** - 创建并配置 USDC 注册 Payload
11. **权限管理** - 临时授予 Payload POOL_ADMIN_ROLE
12. **注册执行** - 执行 USDC 注册到 Aave Pool
13. **权限清理** - 移除 Payload 的临时权限

### 环境变量

脚本会从以下位置读取配置：
- `.env` 文件（如果存在）
- 环境变量
- 部署报告（自动提取最新报告）

### 自动诊断功能

脚本包含全面的诊断功能，会在执行前检查：

| 检查项目 | 说明 | 失败处理 |
|---------|------|----------|
| **RPC 连接** | 测试网络连接和区块同步 | 退出执行 |
| **合约代码** | 验证 Pool/ConfigEngine 合约存在 | 显示警告 |
| **储备列表** | 查询当前池中资产 | 继续执行 |
| **USDC 合约** | 验证代币合约和获取信息 | 退出执行 |
| **权限检查** | 验证 POOL_ADMIN_ROLE | 可选择继续 |

### 权限管理

脚本会自动处理权限：
- 检查当前账户是否具有 POOL_ADMIN_ROLE
- 如果没有权限，提供明确的错误信息
- 无权限时可选择继续执行（由用户决定）

### 自定义 USDC 地址

如果需要使用不同的 USDC 地址，可以设置环境变量：

```bash
export USDC_ADDRESS=0xYourCustomUSDCAddress
./deploy/scripts/list-usdc-sepolia.sh
```

## 方法 2：手动执行 Forge 脚本

如果需要更多控制，可以手动执行：

```bash
# 1. 从部署报告提取地址
LATEST_REPORT=$(ls -t reports/*-market-deployment.json | head -1)
POOL_ADDRESSES_PROVIDER=$(jq -r '.poolAddressesProvider' $LATEST_REPORT)
CONFIG_ENGINE=$(jq -r '.configEngine' $LATEST_REPORT)
POOL_ADDRESS=$(jq -r '.poolProxy' $LATEST_REPORT)

# 2. 设置 USDC 地址（可选，默认使用 Sepolia USDC）
USDC_ADDRESS=0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238

# 3. 执行脚本
forge script scripts/ListUSDCOnSepolia.sol:ListUSDCOnSepolia \
  --rpc-url $RPC_SEPOLIA \
  --private-key $PRIVATE_KEY \
  --broadcast \
  -vvv \
  --env-var POOL_ADDRESSES_PROVIDER=$POOL_ADDRESSES_PROVIDER \
  --env-var CONFIG_ENGINE=$CONFIG_ENGINE \
  --env-var POOL_ADDRESS=$POOL_ADDRESS \
  --env-var USDC_ADDRESS=$USDC_ADDRESS
```

## USDC 配置参数

脚本会使用以下配置注册 USDC：

| 参数 | 值 | 说明 |
|------|-----|------|
| **利率策略** | | |
| Optimal Usage Ratio | 80% | 最优使用率 |
| Base Variable Borrow Rate | 0% | 基础可变借出利率 |
| Variable Rate Slope 1 | 4% | 可变利率斜率 1 |
| Variable Rate Slope 2 | 60% | 可变利率斜率 2 |
| **借贷配置** | | |
| Enabled to Borrow | ✅ | 允许借出 |
| Borrowable in Isolation | ❌ | 不能单独借出 |
| Flashloanable | ✅ | 允许闪电贷 |
| **抵押配置** | | |
| LTV (Loan-to-Value) | 82.5% | 贷款价值比 |
| Liquidation Threshold | 86% | 清算阈值 |
| Liquidation Bonus | 5% | 清算奖励 |
| **其他配置** | | |
| Reserve Factor | 10% | 储备因子 |
| Supply Cap | 无限制 | 供应上限 |
| Borrow Cap | 无限制 | 借出上限 |
| Liquidation Protocol Fee | 10% | 清算协议费用 |

## 验证注册

注册完成后，可以通过多种方式验证 USDC 已成功注册：

### 1. 使用专用验证脚本（推荐）

最简单的方法是使用专门的验证脚本：

```bash
./deploy/scripts/verify-usdc-registration.sh
```

该脚本会：
- 检查储备列表中是否包含 USDC
- 验证 USDC 的储备数据和 aToken 地址
- 确认 aToken 合约代码存在
- 提供详细的状态报告和下一步建议

### 1.5 使用脚本自带的诊断功能

或者重新运行注册脚本，它会显示 USDC 状态：

```bash
./deploy/scripts/list-usdc-sepolia.sh
# 输出会显示: "✓ USDC not yet listed, proceeding..." 变为已注册状态
```

### 2. 检查储备列表

```bash
# 从部署报告获取地址
LATEST_REPORT=$(ls -t reports/*-market-deployment.json | head -1)
POOL_ADDRESS=$(jq -r '.poolProxy' $LATEST_REPORT)

# 检查储备列表
cast call $POOL_ADDRESS "getReservesList()(address[])" --rpc-url $RPC_SEPOLIA
# 预期输出包含 USDC 地址: 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238
```

### 3. 查询 USDC 储备数据

```bash
# 获取 ProtocolDataProvider 地址
DATA_PROVIDER=$(jq -r '.protocolDataProvider' $LATEST_REPORT)
USDC_ADDRESS=0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238

# 查询 USDC 储备数据
cast call $DATA_PROVIDER \
  "getReserveData(address)(uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,address,address,address,uint256,uint256,uint256)" \
  $USDC_ADDRESS \
  --rpc-url $RPC_SEPOLIA
```

### 4. 验证价格预言机

```bash
# 检查部署的 Mock 价格预言机
PRICE_FEED=$(cast call $POOL_ADDRESS "getReserveData(address)(address,address,address,address,address,address,uint256,uint256,uint256,uint256,uint40,uint8,uint128,uint128,uint128,uint128,uint128,uint16,address)" $USDC_ADDRESS --rpc-url $RPC_SEPOLIA | cut -d' ' -f6)

# 查询价格（应该返回 1e8，表示 $1.00）
cast call $PRICE_FEED "latestAnswer()(int256)" --rpc-url $RPC_SEPOLIA
```

### 5. 在前端验证

更新前端配置后：
1. USDC 会出现在资产列表中
2. 可以进行供应和借贷操作
3. 价格显示为 $1.00

## 常见问题

### Q: 脚本运行时显示诊断错误

**A:** 脚本包含多层诊断，请根据具体错误处理：

- **RPC 连接失败**: 检查 `$RPC_SEPOLIA` 环境变量和网络连接
- **合约代码不存在**: 确认部署报告中的地址正确
- **USDC 合约验证失败**: 确认 USDC 地址在当前网络存在
- **权限检查失败**: 按下面的方法获取 POOL_ADMIN_ROLE

### Q: 提示 "Deployer does not have POOL_ADMIN_ROLE"

**A:** 需要先授予部署账户 POOL_ADMIN 权限：

```bash
# 获取 ACL Manager 地址
LATEST_REPORT=$(ls -t reports/*-market-deployment.json | head -1)
ACL_MANAGER=$(jq -r '.aclManager' $LATEST_REPORT)

# 授予权限（需要当前 POOL_ADMIN 执行）
cast send $ACL_MANAGER \
  "addPoolAdmin(address)" \
  $YOUR_ADDRESS \
  --rpc-url $RPC_SEPOLIA \
  --private-key $POOL_ADMIN_PRIVATE_KEY
```

### Q: 出现 "Usage of `address(this)` detected" 错误

**A:** 这是 Solidity 脚本中的 Foundry 安全检查。脚本已修复此问题。如果仍然出现，请确保使用最新版本的脚本。

### Q: 储备列表检查显示 USDC 已存在

**A:** 如果 USDC 已经注册，脚本会显示确认信息并询问是否继续。选择 "y" 可以重新注册（会更新配置）。

### Q: USDC 地址在哪里找到？

**A:** Sepolia 测试网上的 USDC 地址：
- Circle USDC: `0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238`
- 可以在 [Sepolia Etherscan](https://sepolia.etherscan.io) 上验证

### Q: 价格预言机是什么？

**A:** 脚本会自动部署一个 Mock 价格预言机，价格为 $1.00。在生产环境中，应该使用 Chainlink 或其他可信的价格预言机。

### Q: 如何修改配置参数？

**A:** 编辑 `scripts/ListUSDCOnSepolia.sol` 文件中的 `USDCListingPayload` 合约，修改 `newListings()` 函数中的参数。

## 下一步

注册完成后：

1. **更新前端配置**：确保 `frontend/src/config/contracts.ts` 中的 USDC 地址正确
2. **测试功能**：在前端测试存入、借出等操作
3. **添加流动性**：作为流动性管理员，可以向池中添加初始流动性

## 脚本功能特性

| 特性 | 描述 |
|------|------|
| **自动诊断** | 全面的预检查，包括网络、合约、权限验证 |
| **权限管理** | 自动检查和处理 POOL_ADMIN_ROLE |
| **错误处理** | 详细的错误信息和恢复建议 |
| **状态验证** | 检查 USDC 是否已注册，避免重复操作 |
| **权限清理** | 执行完成后自动清理临时权限 |
| **兼容性** | 支持多种环境变量配置方式 |

## 相关文件

- `scripts/ListUSDCOnSepolia.sol`: 增强的主脚本，包含连接验证和权限管理
- `deploy/scripts/list-usdc-sepolia.sh`: 完整的 Shell 包装脚本，提供用户友好的界面
- `deploy/scripts/verify-usdc-registration.sh`: 专用验证脚本，检查USDC注册状态
- `scripts/TestSepoliaConnection.sol`: 已删除（功能已合并到主脚本）
- `deploy/scripts/check-sepolia-connection.sh`: 已删除（功能已合并到主脚本）

## 故障排除

### 调试模式

启用详细输出进行调试：

```bash
# 启用 verbose 模式
export VERBOSE=1
./deploy/scripts/list-usdc-sepolia.sh

# 或手动执行 forge 脚本
forge script scripts/ListUSDCOnSepolia.sol --rpc-url $RPC_SEPOLIA --private-key $PRIVATE_KEY -vvv
```

### 常见错误码

| 错误信息 | 可能原因 | 解决方案 |
|---------|----------|----------|
| "RPC connection failed" | 网络问题或 API 密钥无效 | 检查 RPC URL 和网络连接 |
| "Contract code not found" | 合约未部署或地址错误 | 验证部署报告和网络 |
| "POOL_ADMIN_ROLE required" | 权限不足 | 获取管理员权限 |
| "USDC already listed" | 重复注册 | 检查是否需要更新配置 |

## 注意事项

⚠️ **重要安全提醒**：
- 这是测试网操作，不会影响主网
- 确保使用测试账户，不要使用主网账户私钥
- 价格预言机是 Mock，仅用于测试
- 生产环境需要使用真实的价格预言机
- 建议在测试环境充分验证后再在生产环境使用

🔄 **版本更新**：
- 脚本已优化，支持最新的 Foundry 版本
- 包含全面的错误处理和用户提示
- 支持多种配置方式和环境

