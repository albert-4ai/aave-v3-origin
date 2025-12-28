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
- Running Anvil instance (local Ethereum node)
- Deployed Aave V3 contracts

## Setup

1. **Install dependencies:**

```bash
cd frontend
npm install
```

2. **Configure contract addresses:**

After deploying contracts, update the addresses in `src/config/contracts.ts`:

```typescript
export const CONTRACT_ADDRESSES = {
  POOL_ADDRESSES_PROVIDER: '0x...',
  POOL: '0x...',
  ACL_MANAGER: '0x...',
  // ... other addresses
}
```

3. **Start the development server:**

```bash
npm run dev
```

The app will be available at `http://localhost:3000`

## Development Workflow

### 1. Start Anvil (Local Blockchain)

```bash
# In project root
anvil --host 0.0.0.0 --port 8545
```

### 2. Deploy Contracts

```bash
# In project root
forge script scripts/DeployAaveV3MarketBatched.sol --rpc-url http://localhost:8545 --broadcast
```

### 3. Update Contract Addresses

Copy the deployed contract addresses from the deployment output to `src/config/contracts.ts`.

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

The app uses RainbowKit for wallet connection. For local development with Anvil:

1. Import one of Anvil's test accounts into MetaMask
2. Add the local network (Chain ID: 31337, RPC: http://127.0.0.1:8545)
3. Connect via the app's Connect button

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

