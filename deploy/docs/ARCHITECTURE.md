# 架构文档

本文档详细说明 Aave V3.5 的三层权限架构设计。

## 🎯 核心概念：地址的"二象性"

在 EVM 中，`address` 参数具有"二象性"：

### 1. EOA (External Owned Account)
- **定义**: 由私钥控制的账户
- **特点**: 单签控制，一个人拥有私钥即可完全控制
- **示例**: `0xUser...` (普通用户钱包地址)

### 2. Contract Account (合约账户)
- **定义**: 由智能合约代码控制的账户
- **特点**: 控制逻辑由合约代码决定，可以是多签、DAO、自动化等
- **示例**: `0xSafe...` (Gnosis Safe 多签钱包地址)

### 关键洞察

**Aave 合约根本不在乎这个地址背后是"一个人"还是"一群人"。它只认：谁持有这个地址的控制权，谁就有权调用函数。**

## 🏗️ 三层架构的嵌套关系

### 架构图

```
┌─────────────────────────────────────────────────────────────┐
│  第一层: Aave ACLManager (代码层面)                         │
│  ┌───────────────────────────────────────────────────────┐ │
│  │ POOL_ADMIN_ROLE = 0x8888...8888                       │ │
│  │ (看起来只是一个普通的地址)                             │ │
│  └───────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                          ↓ 赋给
┌─────────────────────────────────────────────────────────────┐
│  第二层: Gnosis Safe 合约 (0x8888...8888)                  │
│  ┌───────────────────────────────────────────────────────┐ │
│  │ 内部逻辑: 需要 3-of-5 签名才能执行交易                 │ │
│  │                                                       │ │
│  │  Owners:                                              │ │
│  │  ├─ Owner 1: Alice (银行资产负债部)                   │ │
│  │  ├─ Owner 2: Bob (银行资产负债部)                     │ │
│  │  ├─ Owner 3: Charlie (风险管理部)                    │ │
│  │  ├─ Owner 4: Dave (风险管理部)                        │ │
│  │  └─ Owner 5: Eve (运营部)                             │ │
│  │                                                       │ │
│  │  阈值: 3 票                                           │ │
│  └───────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                          ↓ 由
┌─────────────────────────────────────────────────────────────┐
│  第三层: 实际控制者 (5 个真实的人)                          │
│  ┌───────────────────────────────────────────────────────┐ │
│  │ 需要至少 3 个人签名才能执行操作                        │ │
│  └───────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### 关键点

1. **Aave 层面**: 只看到一个地址 `0x8888...8888`
2. **Safe 层面**: 该地址是智能合约，内部要求多人签名
3. **实际控制**: 需要 5 个人中的至少 3 个人签名

## 🔄 执行流程详解

### 场景：3-of-5 多签执行 `setReserveFactor`

#### 步骤 1: 线下签名阶段

```
Alice 签名: setReserveFactor(USDC, 0.1)
Bob 签名:   setReserveFactor(USDC, 0.1)
Charlie 签名: setReserveFactor(USDC, 0.1)
```

**结果**: 收集到 3 个签名（满足 3-of-5 阈值）

#### 步骤 2: 提交到 Gnosis Safe

```
交易提交到: 0x8888...8888 (Gnosis Safe 合约地址)

Safe 合约内部验证:
├─ 检查签名数量: 3 >= 阈值 3 ✓
├─ 验证签名有效性: 所有签名来自有效的 owners ✓
└─ 验证交易数据: 交易数据一致 ✓
```

#### 步骤 3: Safe 执行交易

```
Safe 合约调用:
PoolConfigurator.setReserveFactor(USDC, 0.1)
    ↓
ACLManager 检查:
├─ msg.sender = 0x8888...8888 (Safe 地址)
├─ 检查: hasRole(POOL_ADMIN_ROLE, 0x8888...8888)
└─ 结果: true ✓ (因为之前已经赋给 Safe)
    ↓
执行 setReserveFactor() 逻辑
```

#### 步骤 4: 完成

交易成功执行，USDC 的储备因子被更新为 0.1。

## 🔐 权限角色

### 核心角色

| 角色 | 说明 | 权限范围 |
|------|------|---------|
| `POOL_ADMIN_ROLE` | 池管理员 | 配置储备参数、利率策略等 |
| `EMERGENCY_ADMIN_ROLE` | 紧急管理员 | 紧急暂停、恢复操作 |
| `ASSET_LISTING_ADMIN_ROLE` | 资产上架管理员 | 添加新资产、配置价格源 |
| `RISK_ADMIN_ROLE` | 风险管理员 | 配置风险参数 |

### 角色管理

**ACLManager 合约** (`src/contracts/protocol/configuration/ACLManager.sol`):

```solidity
// 授予角色
function grantRole(bytes32 role, address account) external;

// 撤销角色
function revokeRole(bytes32 role, address account) external;

// 检查角色
function hasRole(bytes32 role, address account) external view returns (bool);
```

## 🛡️ 安全机制

### 1. 多签保护

- 关键操作需要多签批准
- 防止单点故障
- 增加攻击成本

### 2. 时间锁（Timelock）

- 重要操作有延迟执行
- 给社区时间审查
- 防止恶意操作

### 3. 角色分离

- 不同角色管理不同功能
- 最小权限原则
- 降低风险集中

## 📋 实际应用场景

### 场景 1: 银行部署

```
第一层: ACLManager → POOL_ADMIN_ROLE = 0xSafe...
第二层: Gnosis Safe (3-of-5)
  - Owner 1: 资产负债部负责人
  - Owner 2: 资产负债部副负责人
  - Owner 3: 风险管理部负责人
  - Owner 4: 风险管理部副负责人
  - Owner 5: CTO
第三层: 需要至少 3 个部门负责人签名
```

### 场景 2: DAO 治理

```
第一层: ACLManager → POOL_ADMIN_ROLE = 0xTimelock...
第二层: TimelockController (48小时延迟)
  - 由 DAO 提案控制
第三层: DAO 成员投票决定
```

## ⚠️ 注意事项

1. **地址验证**: 确保赋给角色的地址是有效的合约
2. **权限审查**: 定期审查角色分配
3. **多签配置**: 合理设置多签阈值（不要太高也不要太低）
4. **时间锁**: 重要操作建议使用时间锁

## 🔗 相关文档

- [部署指南](./DEPLOYMENT.md) - 部署协议
- [配置指南](./CONFIGURATION.md) - 配置 Oracle
- [功能文档](./FEATURE.md) - 质押借贷流程
- [返回首页](./README.md)

## 📚 参考资料

- [Gnosis Safe 文档](https://docs.safe.global/)
- [OpenZeppelin AccessControl](https://docs.openzeppelin.com/contracts/4.x/access-control)
- [OpenZeppelin TimelockController](https://docs.openzeppelin.com/contracts/4.x/api/governance#TimelockController)

