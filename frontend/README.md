# Aave Bank Lending Frontend

A React-based frontend for the Aave V3 private bank lending system. This application allows banks to manage liquidity and authorized users to borrow against collateral.

## Features

- **Admin Panel**: Pool administrators can grant/revoke roles
  - Liquidity Admin: Can supply/withdraw bank liquidity
  - Approved User: Can use the lending protocol

- **Bank Supply**: Liquidity admins can manage bank funds
  - Supply assets to enable user borrowing
  - Withdraw excess liquidity

- **User Lending**: Approved users can interact with the protocol
  - Supply collateral
  - Borrow against collateral
  - Repay loans
  - Withdraw funds

## Prerequisites

- Node.js 18+
- MetaMask or other Web3 wallet
- Sepolia testnet ETH (for gas fees)
- Deployed Aave V3 contracts on Sepolia testnet

## Setup

1. **Install dependencies:**

```bash
cd frontend
npm install
```

2. **Configure environment variables (optional):**

Create a `.env` file in the frontend directory for better RPC performance:

```bash
# Optional: Use your own Sepolia RPC endpoint for better performance
# Get API key from https://www.alchemy.com/ or https://www.infura.io/
VITE_SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY

# Optional: Use your own WalletConnect project ID
# Get from https://cloud.walletconnect.com (free)
VITE_WALLETCONNECT_PROJECT_ID=your_project_id

# Debug logging
VITE_DEBUG=false
```

Vite will automatically load this `.env` file when running the development server.

3. **Contract addresses are pre-configured:**

The contract addresses are already configured for Sepolia testnet deployment:

```typescript
export const CONTRACT_ADDRESSES = {
  POOL_ADDRESSES_PROVIDER: '0xaE233EF86d57401e6604a75f7de2D39A0aF9e4F1',
  POOL: '0x404B2FCb457687aaCE9fe40B03f70E5223f23D1d',
  POOL_CONFIGURATOR: '0x48524e095f383a7A9a6cd116b1F196D3248dA065',
  ACL_MANAGER: '0xd67ABBf84c2f70259c23Cc3170D53C162c4f0AB3',
  PROTOCOL_DATA_PROVIDER: '0xa309160cC7564C9c1E582f11f7098E820622734c',
  ORACLE: '0x703c3b23FA26C70E749c703CF08d99a595CBCb85',
  // ... other addresses
}
```

**USDC is already registered** in the Aave pool with the following configuration:
- Asset: `0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238`
- LTV: 82.5%
- Liquidation Threshold: 86%
- Reserve Factor: 10%

4. **Start the development server:**

```bash
npm run dev
```

The app will be available at `http://localhost:3000`

## Development Workflow

### 1. Get Sepolia Testnet ETH

Get testnet ETH from a Sepolia faucet:
- [Alchemy Sepolia Faucet](https://sepoliafaucet.com/)
- [Infura Sepolia Faucet](https://www.infura.io/faucet/sepolia)

### 2. Configure MetaMask for Sepolia

Add Sepolia testnet to MetaMask:
- Network Name: Sepolia
- RPC URL: https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY
- Chain ID: 11155111
- Currency Symbol: SepoliaETH

### 3. Import Test Account

Import one of the test accounts from your deployment into MetaMask to get admin privileges.

### 4. Start Frontend

```bash
cd frontend
npm run dev
```

## Architecture

```
frontend/
├── src/
│   ├── abi/           # Contract ABIs
│   ├── components/    # React components
│   │   ├── AdminPanel.tsx    # Role management
│   │   ├── BankSupply.tsx    # Liquidity management
│   │   └── UserLending.tsx   # User lending operations
│   ├── config/        # Configuration
│   │   ├── contracts.ts      # Contract addresses
│   │   └── wagmi.ts          # Wagmi/RainbowKit config
│   ├── hooks/         # Custom React hooks
│   │   ├── useACLRoles.ts    # Role checking
│   │   └── usePoolData.ts    # Pool data fetching
│   ├── App.tsx
│   ├── main.tsx
│   └── index.css
├── package.json
├── vite.config.ts
├── tailwind.config.js
└── tsconfig.json
```

## Connecting Wallet

The app uses RainbowKit for wallet connection. For Sepolia testnet:

1. Ensure MetaMask is configured for Sepolia testnet
2. Import your deployment account or any account with testnet ETH
3. Connect via the app's Connect button
4. The app will automatically detect and use the Sepolia network

### Getting Admin Roles

To access admin features, your connected account needs appropriate roles:

- **Pool Admin**: Can grant/revoke other roles (automatically has this if you deployed the contracts)
- **Liquidity Admin**: Can supply/withdraw bank liquidity
- **Approved User**: Can use lending/borrowing features

Use the Admin Panel in the app to manage roles.

## Getting Test Tokens

### USDC on Sepolia

USDC is already configured in the protocol at: `0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238`

To get USDC test tokens:
```bash
# In project root, run the mint script
./deploy/scripts/mint-usdc.sh [amount]
```

Or manually mint using cast:
```bash
cast send 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238 \
  "mint(address,uint256)" $YOUR_ADDRESS $AMOUNT \
  --rpc-url sepolia \
  --private-key $PRIVATE_KEY
```

### Sepolia ETH

Use Sepolia faucets to get test ETH for gas fees.

## Role Hierarchy

```
Pool Admin (Default: Deployer)
├── Can grant/revoke Liquidity Admin
└── Can grant/revoke Approved User

Liquidity Admin
└── Can supply/withdraw liquidity

Approved User
└── Can supply/borrow/repay/withdraw
```

## Tech Stack

- **React 18** - UI framework
- **Vite** - Build tool
- **TypeScript** - Type safety
- **wagmi + viem** - Ethereum interactions
- **RainbowKit** - Wallet connection
- **TailwindCSS** - Styling
- **React Query** - Data fetching

## License

BUSL-1.1 (same as Aave V3)

