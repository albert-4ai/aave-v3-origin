# USDC 初始化与预充值脚本使用指南

本指南介绍如何在 Anvil 测试网络中初始化 USDC（如果需要）并给账户预充值 10000 USDC。

## 📋 前置条件

1. **已部署 Aave V3 协议**
   - 确保 Aave V3 协议已经部署到 Anvil 网络
   - 脚本会自动从部署报告中读取必要地址

2. **Anvil 节点运行中**
   ```bash
   anvil
   ```

3. **Owner 权限**
   - 脚本会自动初始化 USDC（如果池中没有）
   - 需要拥有部署权限（通常是 Anvil 默认第一个账户）
   - 初始化后的 USDC owner 是部署者账户

## 🚀 使用方法

### ⚠️ 重要提示

**请使用 shell 脚本运行，不要直接使用 `forge script` 命令！**

Shell 脚本会自动：
- 从部署报告读取必要地址
- 设置环境变量
- 处理所有错误情况

### 方法 1: 使用脚本（推荐）

脚本会自动处理以下步骤：
1. 从部署报告读取 Pool 地址
2. 在池中查找 USDC
3. 如果未找到，自动初始化 USDC 到池中
4. 给 10 个账户各充值 10000 USDC

```bash
# 自动查找/初始化并充值（推荐）
./deploy/scripts/mint-usdc.sh

# 或手动指定 USDC 地址（如果已知）
./deploy/scripts/mint-usdc.sh 0x1234567890123456789012345678901234567890
```

### ⚠️ 不要直接使用 forge script

如果直接使用 `forge script` 命令，需要手动设置所有环境变量：

```bash
# ❌ 不推荐：需要手动设置所有环境变量
export POOL_ADDRESS=0x...
export POOL_ADDRESSES_PROVIDER=0x...
export CONFIG_ENGINE=0x...
forge script scripts/MintUSDC.sol:MintUSDC --rpc-url http://127.0.0.1:8545 --broadcast

# ✅ 推荐：使用 shell 脚本自动处理
./deploy/scripts/mint-usdc.sh
```

### 方法 2: 使用环境变量

```bash
# 方法 2a: 只设置 USDC 地址（其他地址从部署报告读取）
export USDC_ADDRESS=0x1234567890123456789012345678901234567890
./deploy/scripts/mint-usdc.sh

# 方法 2b: 手动设置所有环境变量（如果部署报告不存在）
export USDC_ADDRESS=0x1234567890123456789012345678901234567890
export POOL_ADDRESS=0x...
export POOL_ADDRESSES_PROVIDER=0x...
export CONFIG_ENGINE=0x...
./deploy/scripts/mint-usdc.sh
```

### 方法 3: 使用 cast 命令（快速方法）

如果你知道 USDC 地址和 owner 私钥，可以直接使用 cast：

```bash
# 设置变量（替换 USDC_ADDRESS 为实际地址）
USDC_ADDRESS="0x1234567890123456789012345678901234567890"
OWNER_PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
RPC_URL="http://localhost:8545"

# Anvil 默认账户列表
ACCOUNTS=(
  "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
  "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
  "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"
  "0x90F79bf6EB2c4f870365E785982E1f101E93b906"
  "0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65"
  "0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc"
  "0x976EA74026E726554dB657fA54763abd0C3a0aa9"
  "0x14dC79964da2C08b23698B3D3cc7Ca32193d9955"
  "0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f"
  "0xa0Ee7A142d267C1f36714E4a8F75612F20a797E8"
)

# 给每个账户铸造 10000 USDC (10000 * 10^6)
for account in "${ACCOUNTS[@]}"; do
  echo "Minting 10000 USDC to $account"
  cast send "$USDC_ADDRESS" \
    "mint(address,uint256)" \
    "$account" \
    10000000000 \
    --rpc-url "$RPC_URL" \
    --private-key "$OWNER_PRIVATE_KEY"
done
```

## 📊 账户列表

脚本会给以下 10 个 Anvil 默认账户各充值 10000 USDC：

| 索引 | 地址 | 私钥 |
|------|------|------|
| 0 | `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266` | `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80` |
| 1 | `0x70997970C51812dc3A010C7d01b50e0d17dc79C8` | `0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d` |
| 2 | `0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC` | `0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a` |
| 3 | `0x90F79bf6EB2c4f870365E785982E1f101E93b906` | `0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6` |
| 4 | `0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65` | `0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733569c69ba420e0ae4` |
| 5 | `0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc` | `0x8b3a350cf5c34c9194ca85829a2df0ec3153be0318b5e2d3348e872092edffba` |
| 6 | `0x976EA74026E726554dB657fA54763abd0C3a0aa9` | `0x92db14e403b83dfe3df233f83dfa3a0d7096f21ca9b0d6d6b8d88b2b4ec1564e` |
| 7 | `0x14dC79964da2C08b23698B3D3cc7Ca32193d9955` | `0x4bbbf85ce3377467afe5d46f804f221813b2bb87f24d81f60f1fcdbf7cbf4356` |
| 8 | `0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f` | `0xdbda1821b80551c9d65939329250298aa3472ba22feea921c0cf5d620ea67b97` |
| 9 | `0xa0Ee7A142d267C1f36714E4a8F75612F20a797E8` | `0x2a871d0798f97d79848a013d4936a73bf4cc922c825d33c1cf7073dff6d409c6` |

## 🔍 验证余额

### 步骤 1: 获取 USDC 地址

在验证余额之前，需要先获取实际的 USDC 地址：

```bash
# 方法 1: 从部署报告中获取（如果脚本已执行）
# 查看脚本输出中的 "USDC Token deployed at:" 或 "Using USDC Address:"

# 方法 2: 从池中查询
POOL_ADDRESS="0x..."  # 从部署报告中获取
cast call "$POOL_ADDRESS" "getReservesList()" --rpc-url http://localhost:8545

# 然后查询每个储备的 symbol
# cast call <RESERVE_ADDRESS> "symbol()" --rpc-url http://localhost:8545
```

### 步骤 2: 验证合约是否存在

```bash
# 验证 USDC 合约是否存在（替换为实际地址）
USDC_ADDRESS="0x..."  # 替换为实际的 USDC 地址
cast code "$USDC_ADDRESS" --rpc-url http://localhost:8545

# 如果返回 "0x" 或 "Contract code is empty"，说明合约不存在
# 需要先运行初始化脚本：./deploy/scripts/mint-usdc.sh
```

### 步骤 3: 查询账户余额

```bash
# 查询单个账户余额（替换为实际地址）
USDC_ADDRESS="0x..."  # 替换为实际的 USDC 地址
ACCOUNT="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"

cast call "$USDC_ADDRESS" \
  "balanceOf(address)" \
  "$ACCOUNT" \
  --rpc-url http://localhost:8545

# 结果是以 wei 为单位，USDC 有 6 位小数
# 例如：10000000000 = 10000 USDC
```

### 批量验证所有账户

```bash
# 首先获取实际的 USDC 地址（从脚本输出或池中查询）
USDC_ADDRESS="0x..."  # ⚠️ 替换为实际的 USDC 地址，不要使用示例地址

# 验证合约是否存在
if [ "$(cast code "$USDC_ADDRESS" --rpc-url http://localhost:8545)" == "0x" ]; then
  echo "错误: USDC 合约不存在于地址 $USDC_ADDRESS"
  echo "请先运行: ./deploy/scripts/mint-usdc.sh"
  exit 1
fi

ACCOUNTS=(
  "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
  "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
  "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"
  "0x90F79bf6EB2c4f870365E785982E1f101E93b906"
  "0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65"
  "0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc"
  "0x976EA74026E726554dB657fA54763abd0C3a0aa9"
  "0x14dC79964da2C08b23698B3D3cc7Ca32193d9955"
  "0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f"
  "0xa0eE7a142d267c1F36714E4A8f75612f20A797e8"
)

for account in "${ACCOUNTS[@]}"; do
  balance=$(cast call "$USDC_ADDRESS" "balanceOf(address)" "$account" --rpc-url http://localhost:8545 2>/dev/null || echo "0x0")
  # 将 wei 转换为 USDC (除以 10^6)
  balance_usdc=$(echo "scale=2; $(cast --to-dec "$balance" 2>/dev/null || echo 0) / 1000000" | bc 2>/dev/null || echo "N/A")
  echo "$account: $balance ($balance_usdc USDC)"
done
```

## 📝 脚本执行流程

1. ✅ **检查 Anvil 节点状态** - 确保节点运行正常
2. ✅ **从部署报告读取地址** - 获取 Pool、PoolAddressesProvider、ConfigEngine 地址
3. ✅ **查找 USDC** - 在池中查找 USDC 代币
4. ✅ **自动初始化** - 如果未找到，自动部署并初始化 USDC 到池中
5. ✅ **验证 Owner 权限** - 确保部署者是 owner
6. ✅ **批量铸造** - 给 10 个账户各铸造 10000 USDC
7. ✅ **验证余额** - 确认铸造成功

## ⚠️ 注意事项

1. **自动初始化**: 如果池中没有 USDC，脚本会自动初始化（需要部署报告中有 ConfigEngine 地址）
2. **Owner 权限**: 只有 USDC 代币的 owner 可以调用 `mint()` 函数
3. **USDC 精度**: USDC 使用 6 位小数，10000 USDC = 10000000000 (10^10)
4. **Anvil 账户**: 脚本使用 Anvil 默认的 10 个账户
5. **网络要求**: 仅适用于 Anvil 本地网络
6. **部署报告**: 脚本需要部署报告来获取必要地址，确保已运行过部署脚本

## 🐛 故障排除

### 问题 1: Owner 权限错误

**错误**: `Ownable: caller is not the owner`

**解决**:
- 确保使用正确的 owner 账户私钥
- 检查 USDC 代币的 owner 地址（替换为实际 USDC 地址）：
  ```bash
  cast call <USDC_ADDRESS> "owner()" --rpc-url http://localhost:8545
  ```

### 问题 2: 环境变量未设置错误

**错误**: `POOL_ADDRESS must be provided if USDC_ADDRESS is not set`

**原因**: 直接使用 `forge script` 命令时，没有设置必要的环境变量

**解决**:
```bash
# ✅ 方法 1: 使用 shell 脚本（推荐）
./deploy/scripts/mint-usdc.sh

# ✅ 方法 2: 手动设置环境变量后使用 forge script
export POOL_ADDRESS=0x...  # 从部署报告中获取
export POOL_ADDRESSES_PROVIDER=0x...  # 从部署报告中获取
export CONFIG_ENGINE=0x...  # 从部署报告中获取
forge script scripts/MintUSDC.sol:MintUSDC \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --broadcast

# ✅ 方法 3: 直接提供 USDC 地址
export USDC_ADDRESS=0x...  # 如果已知 USDC 地址
forge script scripts/MintUSDC.sol:MintUSDC \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --broadcast
```

### 问题 3: USDC 初始化失败

**错误**: `USDC token not found in pool reserves` 或初始化相关错误

**解决**:
```bash
# 确保部署报告存在
ls -t reports/*-market-deployment.json

# 检查部署报告中是否有必要地址
cat reports/*-market-deployment.json | grep -E "poolAddressesProvider|configEngine|poolProxy"

# 如果缺少地址，重新部署协议
./deploy/scripts/deploy.sh local

# 然后重新运行脚本
./deploy/scripts/mint-usdc.sh
```

### 问题 4: 合约不存在或代码为空

**错误**: `Contract code is empty` 或 `0x` 或 `Warning: Contract code is empty`

**原因**:
- 使用了示例地址（如 `0x1234567890123456789012345678901234567890`）
- USDC 还没有部署
- 地址不正确

**解决**:
```bash
# 1. 首先运行初始化脚本（会自动部署和初始化 USDC）
./deploy/scripts/mint-usdc.sh

# 2. 从脚本输出中获取实际的 USDC 地址
# 查找 "USDC Token deployed at:" 或 "Using USDC Address:"

# 3. 或者从池中查询
POOL_ADDRESS="0x..."  # 从部署报告中获取
cast call "$POOL_ADDRESS" "getReservesList()" --rpc-url http://localhost:8545

# 4. 验证合约是否存在
USDC_ADDRESS="0x..."  # 替换为实际地址
cast code "$USDC_ADDRESS" --rpc-url http://localhost:8545
# 应该返回非空的合约代码，而不是 "0x"
```

## 🔗 相关脚本

- `./scripts/mint-usdc.sh` - USDC 预充值脚本
- `./deploy/scripts/deploy.sh` - 部署 Aave V3 协议

## 📚 相关文档

- [部署指南](../deploy/docs/DEPLOYMENT.md)
- [ETH 初始化文档](../docs/ETH_INITIALIZATION.md)

