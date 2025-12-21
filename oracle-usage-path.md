# Oracle 使用路径分析

## 1. Oracle 核心合约

### 1.1 AaveOracle 合约
**位置**: `src/contracts/misc/AaveOracle.sol`

**主要功能**:
- 从 Chainlink Aggregator 获取资产价格
- 如果 Chainlink 价格不可用（<= 0），使用 Fallback Oracle
- 管理每个资产的价格源

**核心方法**:
```solidity
function getAssetPrice(address asset) public view override returns (uint256)
function getAssetsPrices(address[] calldata assets) external view override returns (uint256[] memory)
```

**价格获取逻辑** (第 101-116 行):
1. 如果是基础货币（BASE_CURRENCY），直接返回 BASE_CURRENCY_UNIT
2. 如果资产没有配置价格源，使用 Fallback Oracle
3. 从 Chainlink Aggregator 获取价格，如果价格 <= 0，使用 Fallback Oracle

### 1.2 接口定义
- **IPriceOracleGetter**: `src/contracts/interfaces/IPriceOracleGetter.sol`
- **IAaveOracle**: `src/contracts/interfaces/IAaveOracle.sol`
- **IPriceOracle**: `src/contracts/interfaces/IPriceOracle.sol` (测试用)

## 2. Oracle 地址获取路径

### 2.1 通过 PoolAddressesProvider 获取
**位置**: `src/contracts/protocol/configuration/PoolAddressesProvider.sol`

```solidity
// 第 99-100 行
function getPriceOracle() external view override returns (address) {
    return getAddress(PRICE_ORACLE);
}
```

**存储键**: `PRICE_ORACLE = 'PRICE_ORACLE'` (第 25 行)

### 2.2 Pool 合约中的使用
**位置**: `src/contracts/protocol/pool/Pool.sol`

Pool 合约通过 `ADDRESSES_PROVIDER.getPriceOracle()` 获取 oracle 地址，并在多个操作中传递：

- **Supply 操作** (第 195 行)
- **Withdraw 操作** (第 223 行)
- **Borrow 操作** (第 251, 289 行)
- **Repay 操作** (第 323 行)
- **getUserAccountData** (第 342 行)
- **Liquidation 操作** (第 367 行)
- **Flash Loan 操作** (第 495 行)
- **其他查询操作** (第 597, 739, 855, 872 行)

## 3. Oracle 在核心逻辑中的使用

### 3.1 GenericLogic - 计算用户账户数据
**位置**: `src/contracts/protocol/libraries/logic/GenericLogic.sol`

**函数**: `calculateUserAccountData()` (第 67-181 行)

**使用场景**:
- 计算用户总抵押品价值（以基础货币计价）
- 计算用户总债务价值（以基础货币计价）
- 计算平均 LTV 和清算阈值
- 计算健康因子（Health Factor）

**关键代码** (第 107-109 行):
```solidity
vars.assetPrice = IPriceOracleGetter(params.oracle).getAssetPrice(
    vars.currentReserveAddress
);
```

**价格使用**:
- 抵押品价值计算 (第 112-117 行): `_getUserBalanceInBaseCurrency()`
- 债务价值计算 (第 139-144 行): `_getUserDebtInBaseCurrency()`

### 3.2 ValidationLogic - 验证操作
**位置**: `src/contracts/protocol/libraries/logic/ValidationLogic.sol`

**使用场景**:

#### 3.2.1 validateHealthFactor() (第 367-399 行)
- 验证用户健康因子是否满足要求
- 调用 `GenericLogic.calculateUserAccountData()` 获取健康因子

#### 3.2.2 validateHFAndLtv() (第 409-448 行)
- 验证健康因子和 LTV
- 用于转账、提取等操作前的验证

#### 3.2.3 validateHFAndLtvzero() (第 461-490 行)
- 验证零 LTV 抵押品的健康因子

**Oracle 参数传递**:
所有验证函数都接收 `address oracle` 参数，并传递给 `GenericLogic.calculateUserAccountData()`

### 3.3 LiquidationLogic - 清算计算
**位置**: `src/contracts/protocol/libraries/logic/LiquidationLogic.sol`

**函数**: `executeLiquidationCall()` (第 238-241 行)

**使用场景**:
- 获取抵押品资产价格
- 获取债务资产价格
- 计算清算金额

**关键代码**:
```solidity
vars.collateralAssetPrice = IPriceOracleGetter(params.priceOracle).getAssetPrice(
    params.collateralAsset
);
vars.debtAssetPrice = IPriceOracleGetter(params.priceOracle).getAssetPrice(params.debtAsset);
```

**价格使用** (第 245-254 行):
- 计算债务在基础货币中的价值
- 计算抵押品在基础货币中的价值
- 用于计算可清算的债务数量

### 3.4 FlashLoanLogic - 闪电贷
**位置**: `src/contracts/protocol/libraries/logic/FlashLoanLogic.sol`

**使用场景** (第 139 行):
- 在闪电贷回调验证中使用 oracle
- 验证价格 oracle sentinel

## 4. Oracle 使用流程图

```
用户操作 (supply/borrow/withdraw/repay/liquidate)
    ↓
Pool.sol (主入口)
    ↓
ADDRESSES_PROVIDER.getPriceOracle()  ← 获取 Oracle 地址
    ↓
传递给各个 Logic 库
    ↓
┌─────────────────────────────────────┐
│  GenericLogic.calculateUserAccountData() │
│  - 遍历用户所有资产                    │
│  - 调用 oracle.getAssetPrice()      │
│  - 计算抵押品和债务价值                │
│  - 计算健康因子                       │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│  ValidationLogic                     │
│  - validateHealthFactor()           │
│  - validateHFAndLtv()               │
│  - 使用 GenericLogic 的结果验证      │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│  LiquidationLogic                    │
│  - 获取抵押品和债务价格               │
│  - 计算清算金额                      │
└─────────────────────────────────────┘
    ↓
AaveOracle.getAssetPrice()
    ↓
Chainlink Aggregator.latestAnswer()
    ↓
(如果失败) Fallback Oracle.getAssetPrice()
```

## 5. 关键调用链

### 5.1 借贷操作中的 Oracle 使用
```
Pool.borrow()
  → BorrowLogic.executeBorrow()
    → ValidationLogic.validateBorrow()
      → ValidationLogic.validateHealthFactor()
        → GenericLogic.calculateUserAccountData()
          → IPriceOracleGetter.getAssetPrice() (多次调用，每个资产一次)
            → AaveOracle.getAssetPrice()
              → Chainlink Aggregator 或 Fallback Oracle
```

### 5.2 清算操作中的 Oracle 使用
```
Pool.liquidationCall()
  → LiquidationLogic.executeLiquidationCall()
    → IPriceOracleGetter.getAssetPrice(collateralAsset)  // 获取抵押品价格
    → IPriceOracleGetter.getAssetPrice(debtAsset)        // 获取债务价格
      → AaveOracle.getAssetPrice()
        → Chainlink Aggregator 或 Fallback Oracle
```

### 5.3 查询操作中的 Oracle 使用
```
Pool.getUserAccountData()
  → GenericLogic.calculateUserAccountData()
    → IPriceOracleGetter.getAssetPrice() (遍历所有用户资产)
      → AaveOracle.getAssetPrice()
        → Chainlink Aggregator 或 Fallback Oracle
```

## 6. 相关组件

### 6.1 PriceOracleSentinel
**位置**: `src/contracts/misc/PriceOracleSentinel.sol`

**功能**:
- 监控价格 oracle 的健康状态
- 在价格异常时暂停借贷和清算操作

**使用位置**:
- `ValidationLogic.validateBorrow()` (第 161-164 行)
- `ValidationLogic.validateLiquidationCall()` (第 331-335 行)

### 6.2 价格源配置
**位置**: `src/contracts/misc/AaveOracle.sol`

**配置方法**:
- `setAssetSources()`: 设置资产的价格源（Chainlink Aggregator）
- `setFallbackOracle()`: 设置备用 Oracle

**权限**: 仅 Asset Listing Admin 或 Pool Admin 可调用

## 7. 总结

Oracle 在 Aave V3 中的使用路径：

1. **入口**: 所有需要价格的操作都通过 `PoolAddressesProvider.getPriceOracle()` 获取 Oracle 地址

2. **核心计算**: `GenericLogic.calculateUserAccountData()` 是使用 Oracle 的核心函数，遍历用户所有资产并获取价格

3. **验证**: `ValidationLogic` 使用 Oracle 计算的结果验证操作是否允许

4. **清算**: `LiquidationLogic` 直接调用 Oracle 获取抵押品和债务价格

5. **实现**: `AaveOracle` 从 Chainlink Aggregator 获取价格，失败时使用 Fallback Oracle

6. **监控**: `PriceOracleSentinel` 监控 Oracle 健康状态，异常时暂停操作

