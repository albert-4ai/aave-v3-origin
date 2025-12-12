# Aave v3 质押借贷流程说明

## 概述

Aave v3 实现了用户质押虚拟币作为抵押品，合约自动计算资产价格，并基于抵押品价值放款给用户的完整流程。

## 核心流程

### 1. 用户质押虚拟币给合约

**主要函数：**
- `IPool.supply()` - 标准质押函数
- `IPool.supplyWithPermit()` - 带 Permit 签名的质押函数（无需先 approve）

**接口定义：**
```solidity
// 文件：src/contracts/interfaces/IPool.sol
function supply(
    address asset,        // 要质押的资产地址（如 USDC、ETH 等）
    uint256 amount,      // 质押数量
    address onBehalfOf,  // 接收 aToken 的地址（通常是用户自己）
    uint16 referralCode  // 推荐码，0 表示直接操作
) external;
```

**实现位置：**
- **接口**：`src/contracts/interfaces/IPool.sol:211`
- **实现**：`src/contracts/protocol/pool/Pool.sol:119-138`
- **核心逻辑**：`src/contracts/protocol/libraries/logic/SupplyLogic.sol:45-95`

**执行流程：**
1. 用户调用 `Pool.supply()` 
2. 调用 `SupplyLogic.executeSupply()`
3. 验证质押参数（资产是否激活、是否冻结等）
4. 更新储备状态和利率
5. 从用户转账资产到 aToken 合约
6. 铸造 aToken 给用户（代表质押凭证）
7. 如果首次质押，自动设置为抵押品

**关键代码：**
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

---

### 2. 合约自动计算虚拟币资产价格

**主要函数：**
- `AaveOracle.getAssetPrice()` - 获取单个资产价格
- `AaveOracle.getAssetsPrices()` - 批量获取多个资产价格

**接口定义：**
```solidity
// 文件：src/contracts/misc/AaveOracle.sol
function getAssetPrice(address asset) public view override returns (uint256);
function getAssetsPrices(address[] calldata assets) external view override returns (uint256[] memory);
```

**实现位置：**
- **合约**：`src/contracts/misc/AaveOracle.sol`
- **接口**：`src/contracts/interfaces/IAaveOracle.sol`

**价格来源：**
1. **主要来源**：Chainlink 价格聚合器（AggregatorInterface）
2. **备用来源**：Fallback Oracle（如果主源不可用）
3. **基础货币**：如果是基础货币（如 USD），直接返回单位值

**价格计算逻辑：**
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

**价格在借贷中的使用：**
- 在 `GenericLogic.calculateUserAccountData()` 中计算用户账户数据
- 用于计算：
  - 抵押品总价值（以基础货币计价）
  - 债务总价值（以基础货币计价）
  - 健康因子（Health Factor）
  - 平均 LTV（Loan To Value）

**关键代码位置：**
- `src/contracts/protocol/libraries/logic/GenericLogic.sol:227-257`
- `src/contracts/protocol/libraries/logic/ValidationLogic.sol:367-395`

---

### 3. 通过合约放款给用户

**主要函数：**
- `IPool.borrow()` - 借贷函数

**接口定义：**
```solidity
// 文件：src/contracts/interfaces/IPool.sol:266-272
function borrow(
    address asset,              // 要借出的资产地址
    uint256 amount,             // 借出数量
    uint256 interestRateMode,   // 利率模式：2 = 浮动利率（Variable）
    uint16 referralCode,        // 推荐码
    address onBehalfOf          // 债务接收者（通常是用户自己）
) external;
```

**实现位置：**
- **接口**：`src/contracts/interfaces/IPool.sol:266`
- **实现**：`src/contracts/protocol/pool/Pool.sol:202-225`
- **核心逻辑**：`src/contracts/protocol/libraries/logic/BorrowLogic.sol:43-129`

**执行流程：**
1. 用户调用 `Pool.borrow()`
2. 调用 `BorrowLogic.executeBorrow()`
3. **验证借贷资格**：
   - 资产是否激活、可借
   - 是否有足够的流动性
   - **使用价格计算健康因子和 LTV**：
     ```solidity
     ValidationLogic.validateBorrow(...)  // 验证借贷参数
     ValidationLogic.validateHFAndLtv(...) // 验证健康因子和 LTV
     ```
4. 铸造债务代币（VariableDebtToken）给用户
5. 更新利率和虚拟余额
6. **转账资产给用户**：
   ```solidity
   IAToken(reserveCache.aTokenAddress).transferUnderlyingTo(params.user, params.amount);
   ```

**关键验证逻辑：**
```solidity
// BorrowLogic.sol:59-74
ValidationLogic.validateBorrow(
    reservesData,
    reservesList,
    eModeCategories,
    DataTypes.ValidateBorrowParams({
        reserveCache: reserveCache,
        userConfig: userConfig,
        asset: params.asset,
        userAddress: params.onBehalfOf,
        amountScaled: amountScaled,
        interestRateMode: params.interestRateMode,
        oracle: params.oracle,  // 价格预言机
        userEModeCategory: params.userEModeCategory,
        priceOracleSentinel: params.priceOracleSentinel
    })
);

// BorrowLogic.sol:110-118
ValidationLogic.validateHFAndLtv(
    reservesData,
    reservesList,
    eModeCategories,
    userConfig,
    params.onBehalfOf,
    params.userEModeCategory,
    params.oracle  // 使用价格预言机计算健康因子
);
```

**健康因子计算：**
```solidity
// GenericLogic.sol:160-162
healthFactor = (totalDebtInBaseCurrency == 0)
    ? type(uint256).max
    : avgLiquidationThreshold.wadDiv(totalDebtInBaseCurrency) / 100_00;
```

---

## 完整流程示例

### 步骤 1：用户质押 USDC
```solidity
// 用户质押 1000 USDC
pool.supply(
    address(usdc),    // 资产地址
    1000e6,           // 1000 USDC (6 decimals)
    msg.sender,       // 自己接收 aToken
    0                 // 无推荐码
);
// 结果：用户收到 1000 aUSDC，USDC 被锁定在合约中
```

### 步骤 2：合约计算价格（自动）
```solidity
// 合约内部自动调用
uint256 usdcPrice = aaveOracle.getAssetPrice(address(usdc));
// 假设 USDC 价格 = 1 USD (1e8，因为价格精度是 8 位小数)
// 用户抵押品价值 = 1000 * 1 = 1000 USD
```

### 步骤 3：用户借出 ETH
```solidity
// 假设 ETH 价格 = 2000 USD，LTV = 80%
// 最大可借 = 1000 USD * 80% / 2000 USD = 0.4 ETH

pool.borrow(
    address(eth),     // 借出 ETH
    0.4e18,          // 0.4 ETH (18 decimals)
    2,                // 浮动利率模式
    0,                // 无推荐码
    msg.sender        // 债务记在自己名下
);
// 结果：用户收到 0.4 ETH，产生 0.4 ETH 的债务
```

---

## 关键模块总结

| 功能 | 模块/合约 | 主要函数 | 文件位置 |
|------|----------|---------|---------|
| **质押资产** | Pool | `supply()` | `src/contracts/protocol/pool/Pool.sol` |
| | SupplyLogic | `executeSupply()` | `src/contracts/protocol/libraries/logic/SupplyLogic.sol` |
| **价格计算** | AaveOracle | `getAssetPrice()` | `src/contracts/misc/AaveOracle.sol` |
| **借贷放款** | Pool | `borrow()` | `src/contracts/protocol/pool/Pool.sol` |
| | BorrowLogic | `executeBorrow()` | `src/contracts/protocol/libraries/logic/BorrowLogic.sol` |
| **价格验证** | ValidationLogic | `validateBorrow()`, `validateHFAndLtv()` | `src/contracts/protocol/libraries/logic/ValidationLogic.sol` |
| **账户计算** | GenericLogic | `calculateUserAccountData()` | `src/contracts/protocol/libraries/logic/GenericLogic.sol` |

---

## 相关测试文件

查看以下测试文件了解完整使用示例：

1. **质押测试**：`tests/protocol/pool/Pool.Supply.t.sol`
2. **借贷测试**：`tests/protocol/pool/Pool.Borrow.t.sol`
3. **价格预言机测试**：`tests/misc/AaveOracle.t.sol`
4. **健康因子测试**：`tests/invariants/invariants/BaseInvariants.t.sol`

---

## 注意事项

1. **价格精度**：价格通常使用 8 位小数（如 Chainlink）
2. **健康因子**：必须 >= 1.0 才能借贷
3. **LTV（贷款价值比）**：不同资产有不同的 LTV，影响可借金额
4. **利率模式**：v3.2.0 后只支持浮动利率（mode = 2）
5. **首次质押**：首次质押会自动设置为抵押品（如果满足条件）

