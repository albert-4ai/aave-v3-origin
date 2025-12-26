# 配置指南

本文档介绍如何配置 RPC 节点和 Chainlink 价格预言机。

## 📡 RPC 节点配置

### 为什么需要 Archive 模式的 RPC？

运行 Aave V3 fork 测试需要支持 **archive 模式**的以太坊主网 RPC 节点。免费公共 RPC 节点通常有以下限制：
- 历史状态被修剪（pruned）
- 需要 API Key
- 请求频率限制

### 推荐方案：Alchemy（免费）

1. **注册 Alchemy 账号**
   - 访问：https://dashboard.alchemy.com/
   - 创建新的 App，选择 Ethereum Mainnet

2. **获取 API URL**
   ```
   https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY
   ```

3. **配置方式**

   **方法 A：环境变量**
   ```bash
   export RPC_MAINNET="https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY"
   ```

   **方法 B：.env 文件**（推荐）
   ```bash
   # .env
   RPC_MAINNET=https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY
   RPC_SEPOLIA=https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY
   ```

### 其他 RPC 提供商

- **Infura**: https://infura.io/ - `https://mainnet.infura.io/v3/YOUR_API_KEY`
- **QuickNode**: https://www.quicknode.com/ - 有免费层
- **Ankr**: https://www.ankr.com/rpc/ - 需要注册

### 验证 RPC 连接

```bash
cast block latest --rpc-url $RPC_MAINNET
```

## 🔗 Chainlink 价格预言机配置

### 接口定义

**文件位置**: `src/contracts/dependencies/chainlink/AggregatorInterface.sol`

```solidity
interface AggregatorInterface {
  function decimals() external view returns (uint8);
  function latestAnswer() external view returns (int256);
  function latestRoundData() external view returns (
    uint80 roundId,
    int256 answer,
    uint256 startedAt,
    uint256 updatedAt,
    uint80 answeredInRound
  );
}
```

**关键方法**：
- `latestAnswer()` - 返回最新价格（`int256`），Aave 主要使用此方法
- `decimals()` - 返回价格精度（通常为 8）

### AaveOracle 价格获取逻辑

**文件位置**: `src/contracts/misc/AaveOracle.sol`

```solidity
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

**价格获取优先级**：
1. 基础货币 → 直接返回单位值
2. Chainlink Aggregator → 如果价格 > 0
3. Fallback Oracle → 如果 Chainlink 不可用或价格 <= 0

### 配置价格源

#### 方法 1: 直接调用 AaveOracle（需要 PoolAdmin 权限）

```solidity
address[] memory assets = new address[](2);
address[] memory sources = new address[](2);

// 资产地址（以太坊主网示例）
assets[0] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC
assets[1] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH

// Chainlink Aggregator 地址
sources[0] = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6; // USDC/USD
sources[1] = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419; // ETH/USD

aaveOracle.setAssetSources(assets, sources);
```

#### 方法 2: 使用 Config Engine（推荐）

**文件位置**: `src/contracts/extensions/v3-config-engine/libraries/PriceFeedEngine.sol`

Config Engine 提供了更安全的价格源更新方式，包含验证逻辑：

```solidity
library PriceFeedEngine {
    function executeUpdatePriceFeed(
        mapping(address => DataTypes.ReserveData) storage reservesData,
        mapping(uint256 => address) storage reservesList,
        DataTypes.UpdatePriceFeedParams memory params
    ) external {
        // 验证价格源
        require(params.priceSource != address(0), Errors.ZERO_ADDRESS_NOT_VALID);
        
        // 更新价格源
        IPriceOracleGetter(params.oracle).setAssetSources(
            params.assets,
            params.priceSources
        );
    }
}
```

### 获取 Chainlink 价格源地址

- **Chainlink 官方文档**: https://docs.chain.link/
- **价格源地址列表**: https://data.chain.link/
- **各网络价格源**:
  - 以太坊主网: https://docs.chain.link/data-feeds/price-feeds/addresses?network=ethereum
  - Polygon: https://docs.chain.link/data-feeds/price-feeds/addresses?network=polygon
  - Arbitrum: https://docs.chain.link/data-feeds/price-feeds/addresses?network=arbitrum

### 配置示例

#### 以太坊主网常用资产

| 资产 | 地址 | Chainlink Aggregator |
|------|------|---------------------|
| USDC | 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48 | 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6 |
| WETH | 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2 | 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419 |
| WBTC | 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599 | 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c |
| DAI | 0x6B175474E89094C44Da98b954EedeAC495271d0F | 0xAed0c38402a5d19df6E4c8FBeE2e5E0e6567c825 |

## 🔄 Oracle 在协议中的使用路径

### 获取 Oracle 地址

**通过 PoolAddressesProvider**:
```solidity
address oracle = poolAddressesProvider.getPriceOracle();
```

**存储键**: `PRICE_ORACLE = 'PRICE_ORACLE'`

### Oracle 在核心操作中的使用

#### 1. Supply（质押）
- **位置**: `Pool.supply()` → `SupplyLogic.executeSupply()`
- **用途**: 验证资产状态，更新储备数据

#### 2. Borrow（借贷）
- **位置**: `Pool.borrow()` → `BorrowLogic.executeBorrow()`
- **用途**: 计算用户账户数据，验证健康因子

#### 3. 账户数据计算
- **位置**: `GenericLogic.calculateUserAccountData()`
- **用途**: 
  - 计算用户总抵押品价值（以基础货币计价）
  - 计算用户总债务价值（以基础货币计价）
  - 计算健康因子（Health Factor）

```solidity
vars.assetPrice = IPriceOracleGetter(params.oracle).getAssetPrice(
    vars.currentReserveAddress
);
```

#### 4. 清算计算
- **位置**: `LiquidationLogic.executeLiquidationCall()`
- **用途**: 获取抵押品和债务价格，计算清算奖励

#### 5. 健康因子验证
- **位置**: `ValidationLogic.validateHealthFactor()`
- **用途**: 验证用户健康因子是否满足要求

### 价格监控

**PriceOracleSentinel**（如果配置）：
- 监控 Oracle 健康状态
- 异常时暂停相关操作
- 防止使用过时价格

## ⚠️ 注意事项

### 价格精度

- Chainlink 价格通常使用 **8 位小数**
- 价格以 `1e8` 为单位（例如：$2000 = 200000000000）
- 在计算时需要正确处理精度转换

### 价格验证

- 确保 Chainlink Aggregator 地址正确
- 验证价格源是否活跃（`latestAnswer() > 0`）
- 配置 Fallback Oracle 作为备用

### 权限要求

配置价格源需要以下权限之一：
- `POOL_ADMIN_ROLE`
- `ASSET_LISTING_ADMIN_ROLE`

### 安全建议

- 🔒 使用 Config Engine 而不是直接调用 Oracle
- 🔒 验证价格源地址的有效性
- 🔒 配置 Fallback Oracle 作为备用
- 🔒 定期检查价格源的活跃状态

## 🔗 相关文档

- [部署指南](./DEPLOYMENT.md) - 部署协议
- [架构文档](./ARCHITECTURE.md) - 权限架构
- [返回首页](./README.md)

## 📚 参考资料

- [Chainlink 官方文档](https://docs.chain.link/)
- [Chainlink 价格源地址](https://data.chain.link/)
- [AaveOracle 合约](../src/contracts/misc/AaveOracle.sol)
- [AggregatorInterface](../src/contracts/dependencies/chainlink/AggregatorInterface.sol)

