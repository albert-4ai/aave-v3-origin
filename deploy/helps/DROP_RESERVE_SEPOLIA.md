# 下架资产 (Drop Reserve) - Sepolia 测试网

## 概述

下架资产是从 Aave 协议中完全移除一个代币的功能。这是一个高风险操作，需要满足严格的安全条件。

## ⚠️ 重要安全警告

**下架资产前必须确保：**
- ✅ 没有用户持有该资产的 aToken
- ✅ 没有用户持有该资产的变量债务 (variable debt)
- ✅ 没有应计到国库的利息
- ✅ 资产当前确实在池中列出

如果不满足这些条件，操作将失败。

## 前提条件

### 环境变量
```bash
# 必需的环境变量
export RPC_SEPOLIA=https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY
export PRIVATE_KEY=0xYOUR_PRIVATE_KEY
export ASSET_ADDRESS=0xASSET_TO_DROP  # 要下架的资产地址

# 可选的环境变量（如果不设置会自动从部署报告获取）
export POOL_ADDRESSES_PROVIDER=0x...
export CONFIG_ENGINE=0x...
export POOL_ADDRESS=0x...
```

### 权限要求
- 部署者必须拥有 `DEFAULT_ADMIN_ROLE` 或 `POOL_ADMIN_ROLE`

## 使用方法

### 1. 查看当前储备列表

首先查看池中当前有哪些资产：

```bash
./deploy/scripts/check-reserves.sh
```

### 2. 设置要下架的资产地址

```bash
export ASSET_ADDRESS=0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238  # 例如 Circle USDC
```

### 3. 运行下架脚本

#### 交互模式（推荐）
```bash
./deploy/scripts/drop-reserve-sepolia.sh
```

#### 非交互模式
```bash
./deploy/scripts/drop-reserve-sepolia.sh 1
```

## 脚本执行流程

1. **环境验证**: 检查所有必需的环境变量和网络连接
2. **安全验证**: 验证资产是否可以安全下架
3. **权限检查**: 确认部署者有足够权限
4. **部署Payload**: 部署下架资产的负载合约
5. **执行下架**: 调用 `dropReserve()` 函数
6. **权限清理**: 撤销临时权限
7. **验证结果**: 确认资产已成功下架

## 安全验证详情

### 必需条件检查

```solidity
// 检查 aToken 供应量必须为 0
require(IERC20(aTokenAddress).totalSupply() == 0, "VariableDebtSupplyNotZero");

// 检查变量债务供应量必须为 0
require(IERC20(variableDebtTokenAddress).totalSupply() == 0, "UnderlyingClaimableRightsNotZero");
```

### 验证命令

手动验证资产是否可以下架：

```bash
# 1. 获取储备数据
cast call $POOL_ADDRESS "getReserveData(address)" $ASSET_ADDRESS --rpc-url sepolia

# 2. 检查 aToken 供应
cast call $ATOKEN_ADDRESS "totalSupply()(uint256)" --rpc-url sepolia

# 3. 检查变量债务供应
cast call $VARIABLE_DEBT_ADDRESS "totalSupply()(uint256)" --rpc-url sepolia
```

## 故障排除

### 常见错误

#### 1. "VariableDebtSupplyNotZero"
```
❌ CRITICAL: Cannot drop reserve with outstanding variable debt!
```
**原因**: 用户仍有未偿还的变量债务
**解决**: 等待所有用户偿还债务，或联系用户处理

#### 2. "UnderlyingClaimableRightsNotZero"
```
❌ CRITICAL: Cannot drop reserve with outstanding aTokens!
```
**原因**: 用户仍持有 aToken
**解决**: 等待所有用户赎回 aToken，或联系用户处理

#### 3. "AssetNotListed"
```
Asset is not currently listed in the pool
```
**原因**: 资产地址不正确或资产已被移除
**解决**: 检查资产地址是否正确

### 权限问题

#### POOL_ADMIN_ROLE 缺失
```
[FAIL] Deployer does NOT have POOL_ADMIN_ROLE
```
**解决**:
1. 请求池管理员授予权限
2. 或使用有权限的账户

## 技术细节

### 合约调用流程

```solidity
// 1. 获取 PoolConfigurator
IPoolConfigurator poolConfigurator = addressesProvider.getPoolConfigurator();

// 2. 调用 dropReserve
poolConfigurator.dropReserve(assetAddress);

// 内部执行：
PoolLogic.executeDropReserve(reservesData, reservesList, asset);
```

### 状态变更

下架资产会：
- 从 `reservesList` 中移除资产
- 删除 `reservesData[asset]` 中的所有数据
- 触发 `ReserveDropped(asset)` 事件

### 不可逆操作

⚠️ **下架资产是不可逆操作**，一旦执行：
- 资产将从池中永久移除
- 无法重新添加相同的资产地址
- 需要通过治理重新添加

## 示例输出

### 成功执行
```
=== RESERVE DROP COMPLETE ===
Dropped asset: 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238
Payload: 0x1234567890123456789012345678901234567890

✅ Verification: Asset successfully removed from pool
```

### 安全检查失败
```
❌ CRITICAL: Cannot drop reserve with outstanding aTokens!
         aToken supply must be 0 before dropping reserve
```

## 相关链接

- [Aave 文档 - 储备管理](https://docs.aave.com/developers/core-contracts/poolconfigurator#dropreserve)
- [Aave V3 合约接口](https://github.com/aave/aave-v3-core/blob/master/contracts/interfaces/IPoolConfigurator.sol)

## 下一步

下架资产后：
1. ✅ 验证没有用户受到影响
2. 📝 更新前端配置（如果需要）
3. 📖 更新项目文档
4. 🔍 监控池的整体健康状况
