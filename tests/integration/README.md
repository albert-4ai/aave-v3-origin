# 银行自营借贷系统集成测试

## 概述

`BankLendingSystem.t.sol` 是银行自营借贷系统的完整集成测试，覆盖了从银行注入资金到用户借贷的整个业务流程。

## 测试场景

### 1. 完整借贷流程测试 (`test_complete_lending_workflow`)

测试完整的业务流程：
- ✅ 银行供应出借资产（USDX）
- ✅ 用户1供应抵押品（WBTC）并借款
- ✅ 用户2供应抵押品并借款
- ✅ 验证流动性平衡

**关键验证点**：
- 银行成功注入 5M USDC
- 用户1用 10 WBTC 抵押借出 150k USDC
- 用户2用 5 WBTC 抵押借出 80k USDC
- 总流动性 = 可用流动性 + 已借出金额

### 2. 权限控制测试 (`test_user_cannot_supply_lending_asset`)

测试普通用户无法供应出借资产：
- ✅ 普通用户尝试供应 USDX（borrowingEnabled=true）
- ✅ 交易被拒绝，抛出 `CallerNotLiquidityAdmin` 错误

### 3. 借款和还款测试 (`test_borrow_and_repay_with_interest`)

测试完整的借还款周期：
- ✅ 银行供应资金
- ✅ 用户借款
- ✅ 时间推移（365天），利息累积
- ✅ 用户还款（本金 + 利息）
- ✅ 银行获得利息收益

**关键验证点**：
- 债务随时间增长（利息累积）
- 还款后债务清零
- 银行 aToken 余额增加（赚取利息）

### 4. 银行提现测试 (`test_bank_withdraws_with_interest`)

测试银行提现本金和利息：
- ✅ 银行供应资金
- ✅ 用户借款并还款
- ✅ 银行提现所有资金
- ✅ 提现金额 > 初始供应金额（包含利息）

### 5. 多用户借款测试 (`test_multiple_users_borrow_from_bank`)

测试多个用户从同一资金池借款：
- ✅ 银行供应 5M USDC
- ✅ 用户1和用户2分别借款 150k USDC
- ✅ 验证两个用户都有债务
- ✅ 验证可用流动性 = 供应 - 借出

### 6. 抵押品提现测试 (`test_user_withdraws_collateral_after_repay`)

测试用户还款后提现抵押品：
- ✅ 用户供应抵押品并借款
- ✅ 用户还清债务
- ✅ 用户提现全部抵押品

### 7. 角色移除测试 (`test_removed_liquidity_admin_cannot_supply`)

测试移除流动性提供者角色后的行为：
- ✅ 银行供应资金（成功）
- ✅ 移除银行的 LIQUIDITY_ADMIN_ROLE
- ✅ 银行再次尝试供应（失败）

### 8. 角色移除后提现测试 (`test_bank_can_withdraw_after_role_removal`)

测试角色移除不影响提现：
- ✅ 银行供应资金
- ✅ 移除 LIQUIDITY_ADMIN_ROLE
- ✅ 银行仍可提现已供应的资金

### 9. 资产配置变更测试 (`test_asset_configuration_change`)

测试资产类型配置变更的影响：
- ✅ WBTC 初始为抵押资产（borrowingEnabled=false），任何人可供应
- ✅ 将 WBTC 改为出借资产（borrowingEnabled=true）
- ✅ 普通用户无法再供应 WBTC
- ✅ 银行可以供应 WBTC

### 10. 代理供应测试 (`test_bank_supply_on_behalf`)

测试银行代表其他地址供应：
- ✅ 银行为受益人地址供应资金
- ✅ 受益人获得 aToken
- ✅ 银行的底层资产减少

### 11. 流动性不足测试 (`test_insufficient_liquidity_for_borrow`)

测试借款金额超过可用流动性：
- ✅ 银行供应有限资金（100k USDC）
- ✅ 用户有足够抵押品但尝试借款 200k USDC
- ✅ 交易被拒绝，抛出 `InvalidAmount` 错误

### 12. 完整业务周期测试 (`test_complete_business_cycle`)

测试完整的业务生命周期：
- ✅ **供应阶段**：银行注入 2M USDC
- ✅ **借款阶段**：用户用 20 WBTC 抵押借出 300k USDC
- ✅ **利息累积**：时间推移 6 个月
- ✅ **还款阶段**：用户还清债务并提现抵押品
- ✅ **收益阶段**：银行提现本金和利息

**关键验证点**：
- 用户收回全部抵押品
- 银行获得利息收益
- 银行收益 > 0 且 ≤ 用户支付的利息（考虑储备金因子）

## 测试覆盖率

### 功能覆盖
- ✅ 银行供应出借资产
- ✅ 用户供应抵押资产
- ✅ 用户借款
- ✅ 用户还款
- ✅ 银行提现
- ✅ 用户提现抵押品
- ✅ 权限检查
- ✅ 角色管理
- ✅ 资产配置变更
- ✅ 利息累积和分配

### 边界条件
- ✅ 流动性不足
- ✅ 角色移除
- ✅ 多用户并发操作
- ✅ 代理操作

### 业务场景
- ✅ 单用户借贷
- ✅ 多用户借贷
- ✅ 完整业务周期
- ✅ 资产类型切换

## 运行测试

```bash
# 运行所有集成测试
forge test --match-path tests/protocol/integration/BankLendingSystem.t.sol -vv

# 运行特定测试
forge test --match-test test_complete_lending_workflow -vvv

# 查看 gas 报告
forge test --match-path tests/protocol/integration/BankLendingSystem.t.sol --gas-report
```

## 测试数据

### 资产价格（测试环境）
- USDC: $1
- WBTC: $27,000

### 风险参数
- WBTC LTV: 70%
- WBTC 清算阈值: 75%
- 储备金因子: 10%

### 测试账户初始余额
- 银行: 10M USDC
- 用户1: 100 WBTC
- 用户2: 100 WBTC

## 注意事项

1. **借款金额计算**：考虑抵押品价值和 LTV，确保不超过借款能力
2. **利息计算**：银行实际收益 < 用户支付利息，因为储备金因子会扣除部分利息
3. **Gas 优化**：集成测试 gas 消耗较高，适合用于端到端验证而非性能测试
4. **时间模拟**：使用 `vm.warp` 模拟时间推移以测试利息累积

## 相关文件

- 实现代码：
  - `src/contracts/protocol/configuration/ACLManager.sol`
  - `src/contracts/protocol/libraries/logic/ValidationLogic.sol`
  - `src/contracts/protocol/libraries/logic/SupplyLogic.sol`
  - `src/contracts/protocol/pool/Pool.sol`

- 单元测试：
  - `tests/protocol/configuration/ACLManager.t.sol`
  - `tests/protocol/pool/Pool.Supply.LiquidityProvider.t.sol`

- 文档：
  - `.cursor/plans/单一流动性提供者简化方案_8a91e27f.plan.md`

