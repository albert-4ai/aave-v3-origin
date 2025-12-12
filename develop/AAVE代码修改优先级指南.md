# AAVE代码修改优先级指南

## 📋 概述

基于开发计划和合规要求，本文档说明应该优先修改AAVE的哪些代码，以及如何修改。

---

## 🎯 修改优先级（按重要性排序）

### 优先级1：权限管理相关（必须最先完成）🔴

#### 1.1 PoolAddressesProvider.sol

**文件位置：** `contracts/protocol/configuration/PoolAddressesProvider.sol`

**为什么优先修改：**
- 这是AAVE的核心配置合约，管理所有合约地址
- 包含`owner`权限，控制整个协议
- **必须移除银行单独控制权**

**需要修改的内容：**

1. **移除owner权限**
   ```solidity
   // 原代码可能有：
   address private _owner;
   
   // 修改为：将owner设置为Timelock地址
   // 部署后立即执行：
   function transferOwnership(address timelockAddress) external onlyOwner {
       _transferOwnership(timelockAddress);
   }
   ```

2. **修改setPoolAdmin等函数**
   ```solidity
   // 确保所有管理员设置函数都通过Timelock
   function setPoolAdmin(address admin) external onlyOwner {
       // 修改为：onlyTimelock
       _setPoolAdmin(admin);
   }
   ```

**修改步骤：**
- [ ] 找到`owner`相关代码
- [ ] 添加Timelock地址验证
- [ ] 修改所有`onlyOwner`为`onlyTimelock`
- [ ] 部署后立即转移owner给Timelock

---

#### 1.2 ACLManager.sol

**文件位置：** `contracts/protocol/configuration/ACLManager.sol`

**为什么优先修改：**
- 管理所有角色权限（POOL_ADMIN、EMERGENCY_ADMIN等）
- 控制谁能执行管理员操作
- **必须确保银行不单独控制**

**需要修改的内容：**

1. **修改角色管理函数**
   ```solidity
   // 原代码：
   function addPoolAdmin(address admin) external onlyRole(DEFAULT_ADMIN_ROLE) {
       // ...
   }
   
   // 修改为：确保只有Timelock可以调用
   function addPoolAdmin(address admin) external onlyTimelock {
       // ...
   }
   ```

2. **验证权限设置**
   ```solidity
   // 确保所有管理员角色都通过Timelock设置
   // 检查所有onlyRole(DEFAULT_ADMIN_ROLE)的地方
   ```

**修改步骤：**
- [ ] 找到所有角色管理函数
- [ ] 修改权限检查为`onlyTimelock`
- [ ] 验证银行无法单独添加/移除管理员

---

### 优先级2：核心借贷合约（Pool.sol）🟠

**文件位置：** `contracts/protocol/pool/Pool.sol`

**为什么优先修改：**
- 用户交互的主要入口
- 需要适配资产托管合约
- 需要添加KYC检查

**需要修改的内容：**

1. **适配资产托管合约**
   ```solidity
   // 原代码：用户直接存入资产
   function supply(
       address asset,
       uint256 amount,
       address onBehalfOf,
       uint16 referralCode
   ) external virtual override {
       // 原逻辑：直接从用户转账
       IERC20(asset).transferFrom(msg.sender, address(this), amount);
   }
   
   // 修改为：从资产托管合约转入
   function supply(
       address asset,
       uint256 amount,
       address onBehalfOf,
       uint16 referralCode
   ) external virtual override {
       // 新逻辑：从资产托管合约转入
       IAssetCustody(assetCustodyAddress).transferToPool(
           onBehalfOf,
           asset,
           amount
       );
   }
   ```

2. **添加KYC检查（链下验证）**
   ```solidity
   // 添加KYC状态检查
   mapping(address => bool) public kycVerified; // 由后端设置
   
   function supply(...) external virtual override {
       require(kycVerified[onBehalfOf], "KYC not verified");
       // ...
   }
   
   function borrow(...) external virtual override {
       require(kycVerified[onBehalfOf], "KYC not verified");
       // ...
   }
   ```

3. **修改资产释放逻辑**
   ```solidity
   // 原代码：直接返还给用户
   function withdraw(...) external virtual override {
       // 原逻辑：直接转账给用户
       IERC20(asset).transfer(user, amount);
   }
   
   // 修改为：返还到资产托管合约
   function withdraw(...) external virtual override {
       // 新逻辑：返还到资产托管合约
       IAssetCustody(assetCustodyAddress).releaseAssets(
           user,
           asset,
           amount
       );
   }
   ```

**修改步骤：**
- [ ] 添加资产托管合约接口
- [ ] 修改supply函数（从托管合约转入）
- [ ] 修改withdraw函数（返还到托管合约）
- [ ] 添加KYC检查（链下验证结果）
- [ ] 修改repay函数（适配托管合约）

---

### 优先级3：配置合约（PoolConfigurator.sol）🟡

**文件位置：** `contracts/protocol/pool/PoolConfigurator.sol`

**为什么优先修改：**
- 管理协议参数（LTV、利率等）
- 需要确保所有操作通过Timelock

**需要修改的内容：**

1. **验证管理员权限**
   ```solidity
   // 确保所有配置函数都通过Timelock
   function setLtv(address asset, uint256 ltv) external onlyPoolAdmin {
       // 验证：onlyPoolAdmin应该指向Timelock地址
       // 确保银行无法单独调用
   }
   ```

2. **添加参数验证**
   ```solidity
   // 添加合理的参数范围检查
   function setLtv(address asset, uint256 ltv) external onlyPoolAdmin {
       require(ltv <= MAX_LTV, "LTV too high");
       require(ltv >= MIN_LTV, "LTV too low");
       // ...
   }
   ```

**修改步骤：**
- [ ] 验证所有配置函数权限
- [ ] 确保通过Timelock调用
- [ ] 添加参数验证

---

### 优先级4：代理合约相关🟢

**文件位置：** `contracts/protocol/libraries/aave-upgradeability/`

**为什么需要修改：**
- 需要实现可升级代理
- 升级需要多重签名 + 时间锁

**需要修改的内容：**

1. **使用OpenZeppelin Proxy**
   ```solidity
   // 建议：不使用AAVE的自定义Proxy
   // 改用OpenZeppelin的TransparentUpgradeableProxy
   // 这样可以更好地集成Timelock
   ```

2. **升级权限控制**
   ```solidity
   // 确保升级需要Timelock批准
   // 通过Timelock调用upgradeTo函数
   ```

**修改步骤：**
- [ ] 评估AAVE现有Proxy实现
- [ ] 决定是否使用OpenZeppelin Proxy
- [ ] 实现升级权限控制

---

## 📝 具体修改清单

### 第一周任务：权限管理改造

#### Day 1-2: PoolAddressesProvider.sol

**修改内容：**
1. [ ] 找到`owner`变量和`onlyOwner`修饰符
2. [ ] 添加Timelock地址变量
3. [ ] 创建`onlyTimelock`修饰符
4. [ ] 修改`setPoolAdmin`、`setEmergencyAdmin`等函数
5. [ ] 添加`transferOwnershipToTimelock`函数
6. [ ] 编写测试

**关键代码位置：**
```solidity
// 查找这些关键词：
- owner
- onlyOwner
- setOwner
- setPoolAdmin
- setEmergencyAdmin
```

---

#### Day 3-4: ACLManager.sol

**修改内容：**
1. [ ] 找到所有角色管理函数
2. [ ] 修改权限检查为`onlyTimelock`
3. [ ] 验证银行无法单独控制
4. [ ] 编写测试

**关键代码位置：**
```solidity
// 查找这些函数：
- addPoolAdmin
- removePoolAdmin
- addEmergencyAdmin
- removeEmergencyAdmin
- isPoolAdmin
- isEmergencyAdmin
```

---

#### Day 5: 集成测试

**测试内容：**
1. [ ] 部署Timelock合约
2. [ ] 部署Gnosis Safe钱包
3. [ ] 将PoolAddressesProvider.owner设置为Timelock
4. [ ] 将Timelock执行者设置为Safe地址
5. [ ] 测试多重签名流程
6. [ ] 验证银行无法单独控制

---

### 第二周任务：Pool.sol适配

#### Day 1-2: 资产托管合约集成

**修改内容：**
1. [ ] 添加IAssetCustody接口
2. [ ] 修改supply函数（从托管合约转入）
3. [ ] 修改withdraw函数（返还到托管合约）
4. [ ] 修改repay函数（适配托管合约）
5. [ ] 编写测试

**关键修改点：**
```solidity
// supply函数中：
// 原：IERC20(asset).transferFrom(msg.sender, ...)
// 改：IAssetCustody(custody).transferToPool(...)

// withdraw函数中：
// 原：IERC20(asset).transfer(user, amount)
// 改：IAssetCustody(custody).releaseAssets(user, asset, amount)
```

---

#### Day 3-4: KYC检查集成

**修改内容：**
1. [ ] 添加KYC状态映射
2. [ ] 添加设置KYC状态的函数（仅后端可调用）
3. [ ] 在supply和borrow函数中添加KYC检查
4. [ ] 编写测试

**关键代码：**
```solidity
// 添加：
mapping(address => bool) public kycVerified;
address public kycManager; // 后端地址

modifier onlyKycManager() {
    require(msg.sender == kycManager, "Not KYC manager");
    _;
}

function setKycVerified(address user, bool verified) external onlyKycManager {
    kycVerified[user] = verified;
}

// 在supply和borrow中添加：
require(kycVerified[onBehalfOf], "KYC not verified");
```

---

#### Day 5: 集成测试

**测试内容：**
1. [ ] 测试资产从托管合约转入
2. [ ] 测试资产返还到托管合约
3. [ ] 测试KYC检查
4. [ ] 端到端测试

---

## 🔍 代码查找指南

### 如何找到需要修改的代码

#### 1. 查找owner相关代码

```bash
# 在AAVE目录下搜索
grep -r "owner" contracts/protocol/configuration/
grep -r "onlyOwner" contracts/protocol/
grep -r "_owner" contracts/protocol/
```

#### 2. 查找管理员权限相关代码

```bash
grep -r "POOL_ADMIN" contracts/protocol/
grep -r "EMERGENCY_ADMIN" contracts/protocol/
grep -r "addPoolAdmin" contracts/protocol/
grep -r "removePoolAdmin" contracts/protocol/
```

#### 3. 查找supply/withdraw函数

```bash
grep -r "function supply" contracts/protocol/pool/
grep -r "function withdraw" contracts/protocol/pool/
grep -r "function borrow" contracts/protocol/pool/
grep -r "function repay" contracts/protocol/pool/
```

---

## ⚠️ 重要注意事项

### 1. 不要修改的部分

以下部分**不要修改**，保持AAVE原有逻辑：
- ✅ 利率计算逻辑
- ✅ LTV计算逻辑
- ✅ 清算逻辑（LiquidationLogic.sol）
- ✅ 数学库（WadRayMath.sol等）
- ✅ 数据结构（DataTypes.sol）

### 2. 必须保持兼容的部分

- ✅ 接口定义（IPool.sol等）
- ✅ 事件定义
- ✅ 返回值格式

### 3. 测试要求

每个修改都必须：
- ✅ 编写单元测试
- ✅ 编写集成测试
- ✅ 通过现有测试套件
- ✅ 安全审计

---

## 📚 参考文件

### 核心合约文件（按优先级）

1. **PoolAddressesProvider.sol** - 最高优先级
   - 路径：`contracts/protocol/configuration/PoolAddressesProvider.sol`
   - 作用：管理所有合约地址和owner权限

2. **ACLManager.sol** - 最高优先级
   - 路径：`contracts/protocol/configuration/ACLManager.sol`
   - 作用：管理角色权限

3. **Pool.sol** - 高优先级
   - 路径：`contracts/protocol/pool/Pool.sol`
   - 作用：主借贷池合约

4. **PoolConfigurator.sol** - 中优先级
   - 路径：`contracts/protocol/pool/PoolConfigurator.sol`
   - 作用：配置合约参数

5. **SupplyLogic.sol** - 中优先级
   - 路径：`contracts/protocol/libraries/logic/SupplyLogic.sol`
   - 作用：存入资产逻辑

6. **BorrowLogic.sol** - 中优先级
   - 路径：`contracts/protocol/libraries/logic/BorrowLogic.sol`
   - 作用：借出资产逻辑

---

## 🎯 修改顺序总结

### 第一周：权限管理（必须完成）

1. **Day 1-2**: PoolAddressesProvider.sol
   - 移除owner权限
   - 集成Timelock

2. **Day 3-4**: ACLManager.sol
   - 修改角色管理权限
   - 集成Timelock

3. **Day 5**: 集成测试
   - 测试多重签名
   - 测试时间锁
   - 验证银行无法单独控制

### 第二周：核心功能适配

1. **Day 1-2**: Pool.sol - 资产托管集成
   - 修改supply函数
   - 修改withdraw函数

2. **Day 3-4**: Pool.sol - KYC检查
   - 添加KYC验证
   - 集成链下验证结果

3. **Day 5**: 集成测试
   - 端到端测试

---

## ✅ 检查清单

### 权限管理检查

- [ ] PoolAddressesProvider.owner已转移给Timelock
- [ ] 所有管理员操作需要Timelock批准
- [ ] 银行无法单独执行管理员操作
- [ ] 多重签名正常工作
- [ ] 时间锁正常工作

### 功能适配检查

- [ ] 资产从托管合约正确转入
- [ ] 资产正确返还到托管合约
- [ ] KYC检查正常工作
- [ ] 用户正常交易不受影响

---

**最后更新**: 2025-11-24
**状态**: 待执行


