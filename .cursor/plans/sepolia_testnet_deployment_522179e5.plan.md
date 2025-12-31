---
name: Sepolia Testnet Deployment
overview: 将 Aave V3.5 银行借贷系统的智能合约和前端应用部署到 Sepolia 测试网，包括环境配置、合约部署、合约验证以及前端网络适配。
todos:
  - id: env-setup
    content: 创建 .env 文件，配置 RPC_SEPOLIA、PRIVATE_KEY、ETHERSCAN_API_KEY_SEPOLIA
    status: cancelled
  - id: get-eth
    content: 获取 Sepolia 测试 ETH（至少 0.5 ETH）
    status: cancelled
    dependencies:
      - env-setup
  - id: deploy-contracts
    content: 运行部署脚本将合约部署到 Sepolia
    status: cancelled
    dependencies:
      - get-eth
  - id: verify-deployment
    content: 验证部署并记录合约地址
    status: cancelled
    dependencies:
      - deploy-contracts
  - id: update-frontend-addresses
    content: 从部署报告提取合约地址并更新 contracts.ts
    status: completed
    dependencies:
      - verify-deployment
  - id: update-frontend-wagmi
    content: 更新 wagmi.ts 配置支持 Sepolia 网络
    status: completed
    dependencies:
      - update-frontend-addresses
  - id: test-frontend
    content: 本地测试前端连接 Sepolia 合约
    status: completed
    dependencies:
      - update-frontend-wagmi
---

# Sepolia 测试网部署计划

## 概述

将智能合约部署到 Sepolia 测试网，并配置前端连接到已部署的合约。---

## 一、准备工作

### 1.1 获取 Sepolia 测试 ETH

在部署前需要确保部署账户有足够的 Sepolia ETH（建议至少 0.5 ETH）：

- [Alchemy Sepolia Faucet](https://www.alchemy.com/faucets/ethereum-sepolia)
- [Infura Sepolia Faucet](https://www.infura.io/faucet/sepolia)
- [Google Cloud Sepolia Faucet](https://cloud.google.com/application/web3/faucet/ethereum/sepolia)

### 1.2 获取 Alchemy API Key

1. 注册/登录 [Alchemy Dashboard](https://dashboard.alchemy.com/)
2. 创建新应用，选择 **Ethereum** 网络，**Sepolia** 测试网
3. 复制 HTTPS RPC URL（格式：`https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY`）

### 1.3 获取 Etherscan API Key（用于合约验证）

1. 注册/登录 [Etherscan](https://etherscan.io/)
2. 在 API Keys 页面创建新的 API Key

---

## 二、环境配置

在项目根目录创建 `.env` 文件：

```bash
# Sepolia RPC URL (Alchemy)
RPC_SEPOLIA=https://eth-sepolia.g.alchemy.com/v2/YOUR_ALCHEMY_API_KEY

# 部署账户私钥（不要使用主网账户！）
PRIVATE_KEY=0xYOUR_PRIVATE_KEY

# Etherscan API Key（用于合约验证）
ETHERSCAN_API_KEY_SEPOLIA=YOUR_ETHERSCAN_API_KEY
```

> 重要：确保 `.env` 已在 `.gitignore` 中，不要提交私钥到代码仓库！---

## 三、智能合约部署

### 3.1 部署命令

使用现有部署脚本 [deploy/scripts/deploy.sh](deploy/scripts/deploy.sh)：

```bash
./deploy/scripts/deploy.sh sepolia
```

或手动使用 forge：

```bash
forge script scripts/DeployAaveV3MarketBatched.sol:Default \
  --rpc-url $RPC_SEPOLIA \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  -vvvv
```



### 3.2 部署后验证

```bash
./deploy/scripts/verify-deployment.sh sepolia
```



### 3.3 记录合约地址

部署完成后，从 `reports/` 目录获取关键合约地址：

```bash
cat reports/*-market-deployment.json | jq '{
  poolProxy,
  poolConfiguratorProxy,
  aclManager,
  aaveOracle,
  protocolDataProvider
}'
```

---

## 四、前端配置更新

### 4.1 从部署报告获取合约地址

部署完成后，从最新的部署报告中提取合约地址：

```bash
# 查看最新部署报告
LATEST_REPORT=$(ls -t reports/*-market-deployment.json | head -1)
cat $LATEST_REPORT | jq '{
  poolProxy: .poolProxy,
  poolConfiguratorProxy: .poolConfiguratorProxy,
  aclManager: .aclManager,
  aaveOracle: .aaveOracle,
  protocolDataProvider: .protocolDataProvider,
  poolAddressesProvider: .poolAddressesProvider
}'
```

**地址映射关系**：| 部署报告字段 | contracts.ts 字段 ||------------|------------------|| `poolProxy` | `POOL` || `poolConfiguratorProxy` | `POOL_CONFIGURATOR` || `poolAddressesProvider` | `POOL_ADDRESSES_PROVIDER` || `aclManager` | `ACL_MANAGER` || `protocolDataProvider` | `PROTOCOL_DATA_PROVIDER` || `aaveOracle` | `ORACLE` |

### 4.2 更新合约地址配置

修改 [frontend/src/config/contracts.ts](frontend/src/config/contracts.ts)：

```typescript
export const CONTRACT_ADDRESSES = {
  // Core Protocol - 更新为 Sepolia 部署的地址
  POOL_ADDRESSES_PROVIDER: '0x...' as Address, // 从部署报告的 poolAddressesProvider
  POOL: '0x...' as Address,                     // 从部署报告的 poolProxy
  POOL_CONFIGURATOR: '0x...' as Address,        // 从部署报告的 poolConfiguratorProxy
  ACL_MANAGER: '0x...' as Address,              // 从部署报告的 aclManager
  
  // Protocol Data
  PROTOCOL_DATA_PROVIDER: '0x...' as Address,   // 从部署报告的 protocolDataProvider
  ORACLE: '0x...' as Address,                   // 从部署报告的 aaveOracle
  
  // Test Tokens - 如果部署了测试代币，更新这些地址
  TOKENS: {
    DAI: '0x0000000000000000000000000000000000000000' as Address,
    USDC: '0x...' as Address, // Sepolia USDC 地址（如果已部署）
    WETH: '0x...' as Address, // Sepolia WETH 地址（如果已部署）
  },
} as const
```



### 4.3 配置 Wagmi 网络（Sepolia 测试网）

修改 [frontend/src/config/wagmi.ts](frontend/src/config/wagmi.ts)：配置为仅支持 Sepolia 测试网：

```typescript
import { http } from 'wagmi'
import { sepolia } from 'wagmi/chains'
import { getDefaultConfig } from '@rainbow-me/rainbowkit'

const WALLETCONNECT_PROJECT_ID = '3a8170812b534d0ff9d794f19a901d64'

export const config = getDefaultConfig({
  appName: 'Aave Bank Lending',
  projectId: WALLETCONNECT_PROJECT_ID,
  chains: [sepolia],
  transports: {
    [sepolia.id]: http('https://eth-sepolia.g.alchemy.com/v2/YOUR_ALCHEMY_API_KEY'),
  },
  ssr: false,
})
```

> **注意**：确保在 `contracts.ts` 中配置的合约地址是 Sepolia 测试网上部署的地址。用户需要在钱包中切换到 Sepolia 测试网才能使用应用。

### 4.4 本地测试前端

```bash
cd frontend

# 确保已安装依赖
npm install

# 启动开发服务器
npm run dev
```

前端将运行在 `http://localhost:3000`，连接 MetaMask 等钱包时需要切换到 Sepolia 测试网。

### 4.5 构建生产版本

```bash
cd frontend
npm run build
```

构建产物将输出到 `frontend/dist/` 目录。---

## 五、前端部署（可选）

构建后的 `dist/` 目录可部署到：

- **Vercel**: 连接 Git 仓库自动部署
- **Netlify**: 拖拽 `dist/` 目录上传
- **GitHub Pages**: 推送到 `gh-pages` 分支

---

## 六、部署后配置（银行借贷系统）

部署完成后需要配置角色权限：

1. **添加流动性管理员**（银行地址）：
   ```solidity
                                                                     aclManager.addLiquidityAdmin(BANK_ADDRESS);
   ```




2. **添加已批准用户**：
   ```solidity
                                                                     aclManager.addApprovedUser(USER_ADDRESS);
                              
                           
                        
                     
                  
               
            
         
      
   
   ```