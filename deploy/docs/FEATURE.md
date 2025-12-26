# 功能文档

本文档说明 Aave V3.5 的核心功能：质押和借贷流程。

## 📋 概述

Aave V3 实现了用户质押虚拟币作为抵押品，合约自动计算资产价格，并基于抵押品价值放款给用户的完整流程。

## 🔄 核心流程

### 1. 用户质押虚拟币给合约

**主要函数**：
- `IPool.supply()` - 标准质押函数
- `IPool.supplyWithPermit()` - 带 Permit 签名的质押函数（无需先 approve）

**接口定义**：
```solidity
function supply(
    address asset,        // 要质押的资产地址（如 USDC、ETH 等）
    uint256 amount,      // 质押数量
    address onBehalfOf,  // 接收 aToken 的地址（通常是用户自己）
    uint16 referralCode  // 推荐码，0 表示直接操作
) external;
```

**实现位置**：
- **接口**: `src/contracts/interfaces/IPool.sol:211`
- **实现**: `src/contracts/protocol/pool/Pool.sol:119-138`
- **核心逻辑**: `src/contracts/protocol/libraries/logic/SupplyLogic.sol:45-95`

**执行流程**：
1. 用户调用 `Pool.supply()`
2. 调用 `SupplyLogic.executeSupply()`
3. 验证质押参数（资产是否激活、是否冻结等）
4. 更新储备状态和利率
5. 从用户转账资产到 aToken 合约
6. 铸造 aToken 给用户（代表质押凭证）
7. 如果首次质押，自动设置为抵押品

**关键代码**：
```solidity
// SupplyLogic.sol
IERC20(params.asset).safeTransferFrom(params.user, reserveCache.aTokenAddress, params.amount);
IAToken(reserveCache.aTokenAddress).mint(
    params.user,
    params.onBehalfOf,
    scaledAmount,
    reserveCache.nextLiquidityIndex
);
```

### 2. 合约自动计算虚拟币资产价格

**主要函数**：
- `AaveOracle.getAssetPrice()` - 获取单个资产价格
- `AaveOracle.getAssetsPrices()` - 批量获取多个资产价格

**价格来源**：
1. **主要来源**: Chainlink 价格聚合器（AggregatorInterface）
2. **备用来源**: Fallback Oracle（如果主源不可用）
3. **基础货币**: 如果是基础货币（如 USD），直接返回单位值

**价格计算逻辑**：
```solidity
// AaveOracle.sol:101-116
function getAssetPrice(address asset) public view override returns (uint256) {
    AggregatorInterface source = assetsSources[asset];
    
    if (asset == BASE_CURRENCY) {
        return BASE_CURRENCY_UNIT;
    } else if (address(source) == address(0)) {
        return _fallbackOracle.getAssetPrice(asset);
    } else {
        int256 price = source.latestAnswer();
        if (price > 0) {
            return uint256(price);
        } else {
            return _fallbackOracle.getAssetPrice(asset);
        }
    }
}
```

**价格在借贷中的使用**：
- 在 `GenericLogic.calculateUserAccountData()` 中计算用户账户数据
- 用于计算：
  - 抵押品总价值（以基础货币计价）
  - 债务总价值（以基础货币计价）
  - 健康因子（Health Factor）

### 3. 基于抵押品价值计算可借额度

**核心函数**: `GenericLogic.calculateUserAccountData()`

**位置**: `src/contracts/protocol/libraries/logic/GenericLogic.sol:67-181`

**计算步骤**：

1. **遍历用户所有资产**
   ```solidity
   for (uint256 i = 0; i < reservesCount; i++) {
       address currentReserveAddress = reservesList[i];
       // 获取资产价格
       vars.assetPrice = IPriceOracleGetter(params.oracle).getAssetPrice(
           currentReserveAddress
       );
   }
   ```

2. **计算抵押品总价值**
   ```solidity
   // 抵押品价值 = 余额 × 价格 × LTV
   vars.totalCollateralInBaseCurrency += 
       (userBalance * vars.assetPrice * reserveCache.ltv) / 
       (10 ** (vars.reserveDecimals + BASE_CURRENCY_UNIT));
   ```

3. **计算债务总价值**
   ```solidity
   // 债务价值 = 债务余额 × 价格
   vars.totalDebtInBaseCurrency += 
       (userStableDebt + userVariableDebt) * vars.assetPrice / 
       (10 ** (vars.reserveDecimals + BASE_CURRENCY_UNIT));
   ```

4. **计算健康因子**
   ```solidity
   // 健康因子 = (抵押品总价值 × 清算阈值) / 债务总价值
   vars.healthFactor = vars.totalDebtInBaseCurrency == 0
       ? type(uint256).max
       : (vars.totalCollateralInBaseCurrency * vars.avgLiquidationThreshold) / 
         vars.totalDebtInBaseCurrency;
   ```

### 4. 用户借贷虚拟币

**主要函数**：
- `IPool.borrow()` - 标准借贷函数
- `IPool.borrowWithPermit()` - 带 Permit 签名的借贷函数

**接口定义**：
```solidity
function borrow(
    address asset,           // 要借贷的资产地址
    uint256 amount,         // 借贷数量
    uint256 interestRateMode, // 利率模式（2 = 浮动利率）
    uint16 referralCode,    // 推荐码
    address onBehalfOf      // 债务接收地址（通常是用户自己）
) external;
```

**实现位置**：
- **接口**: `src/contracts/interfaces/IPool.sol:223`
- **实现**: `src/contracts/protocol/pool/Pool.sol:140-158`
- **核心逻辑**: `src/contracts/protocol/libraries/logic/BorrowLogic.sol:52-145`

**执行流程**：
1. 用户调用 `Pool.borrow()`
2. 调用 `BorrowLogic.executeBorrow()`
3. 验证借贷参数（资产是否激活、是否冻结等）
4. 计算用户账户数据（使用 Oracle 获取价格）
5. 验证健康因子 >= 1.0
6. 更新储备状态和利率
7. 铸造债务代币（variableDebtToken 或 stableDebtToken）
8. 从池子转账资产给用户

**关键验证**：
```solidity
// ValidationLogic.sol
function validateBorrow(
    DataTypes.UserConfigurationMap memory userConfig,
    DataTypes.ReserveData memory reserve,
    address asset,
    uint256 amount,
    uint256 amountInBaseCurrency,
    uint256 healthFactor,
    address oracle
) internal view {
    // 验证资产是否激活
    require(reserve.configuration.getActive(), Errors.RESERVE_INACTIVE);
    
    // 验证健康因子
    require(
        healthFactor >= HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
        Errors.HEALTH_FACTOR_LOWER_THAN_LIQUIDATION_THRESHOLD
    );
    
    // 验证借贷额度
    require(
        amountInBaseCurrency <= maxLoanAmount,
        Errors.BORROWING_NOT_ENABLED
    );
}
```

## 📊 关键概念

### 健康因子（Health Factor）

**公式**：
```
健康因子 = (抵押品总价值 × 平均清算阈值) / 债务总价值
```

**含义**：
- `健康因子 >= 1.0`: 可以借贷
- `健康因子 < 1.0`: 可以被清算
- `健康因子 = 0`: 无债务

### LTV（Loan-to-Value，贷款价值比）

**定义**: 资产作为抵押品时，可以借贷的最大比例

**示例**：
- USDC LTV = 80% → 质押 $1000 USDC，最多可借 $800
- WETH LTV = 82.5% → 质押 $1000 WETH，最多可借 $825

### 清算阈值（Liquidation Threshold）

**定义**: 当健康因子低于此值时，可以被清算

**示例**：
- USDC 清算阈值 = 85% → 健康因子 < 0.85 时可以被清算

### 利率模式

**Aave V3.2.0+ 只支持浮动利率**：
- `interestRateMode = 2`: 浮动利率（Variable Rate）
- 利率根据市场供需动态调整

## ⚠️ 注意事项

1. **价格精度**: 价格通常使用 8 位小数（如 Chainlink）
2. **健康因子**: 必须 >= 1.0 才能借贷
3. **LTV（贷款价值比）**: 不同资产有不同的 LTV，影响可借金额
4. **利率模式**: v3.2.0 后只支持浮动利率（mode = 2）
5. **首次质押**: 首次质押会自动设置为抵押品（如果满足条件）

## 🔗 相关文档

- [部署指南](./DEPLOYMENT.md) - 部署协议
- [配置指南](./CONFIGURATION.md) - 配置 Oracle
- [架构文档](./ARCHITECTURE.md) - 权限架构
- [返回首页](./README.md)

## 📚 测试文件

- **质押测试**: `tests/protocol/pool/Pool.Supply.t.sol`
- **借贷测试**: `tests/protocol/pool/Pool.Borrow.t.sol`
- **价格预言机测试**: `tests/misc/AaveOracle.t.sol`
- **健康因子测试**: `tests/invariants/invariants/BaseInvariants.t.sol`

