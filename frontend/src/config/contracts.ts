import { Address } from 'viem'

/**
 * Contract addresses for the deployed Aave V3 protocol on Sepolia testnet
 * 
 * IMPORTANT: Update these addresses after deploying contracts to Sepolia testnet.
 * 
 * Steps to update:
 * 1. Deploy contracts to Sepolia:
 *    ```bash
 *    ./deploy/scripts/deploy.sh sepolia
 *    ```
 * 
 * 2. Extract addresses from the latest deployment report:
 *    ```bash
 *    LATEST_REPORT=$(ls -t reports/*-market-deployment.json | head -1)
 *    cat $LATEST_REPORT | jq '{
 *      poolProxy: .poolProxy,
 *      poolConfiguratorProxy: .poolConfiguratorProxy,
 *      aclManager: .aclManager,
 *      aaveOracle: .aaveOracle,
 *      protocolDataProvider: .protocolDataProvider,
 *      poolAddressesProvider: .poolAddressesProvider
 *    }'
 *    ```
 * 
 * 3. Update the addresses below with the values from the deployment report.
 * 
 * Address mapping:
 * - poolAddressesProvider -> POOL_ADDRESSES_PROVIDER
 * - poolProxy -> POOL
 * - poolConfiguratorProxy -> POOL_CONFIGURATOR
 * - aclManager -> ACL_MANAGER
 * - protocolDataProvider -> PROTOCOL_DATA_PROVIDER
 * - aaveOracle -> ORACLE
 */
export const CONTRACT_ADDRESSES = {
  // Core Protocol - Sepolia deployment addresses
  POOL_ADDRESSES_PROVIDER: '0xaE233EF86d57401e6604a75f7de2D39A0aF9e4F1' as Address, // From deployment report: poolAddressesProvider
  POOL: '0x404B2FCb457687aaCE9fe40B03f70E5223f23D1d' as Address,                     // From deployment report: poolProxy
  POOL_CONFIGURATOR: '0x48524e095f383a7A9a6cd116b1F196D3248dA065' as Address,        // From deployment report: poolConfiguratorProxy
  ACL_MANAGER: '0xd67ABBf84c2f70259c23Cc3170D53C162c4f0AB3' as Address,              // From deployment report: aclManager
  
  // Protocol Data
  PROTOCOL_DATA_PROVIDER: '0xa309160cC7564C9c1E582f11f7098E820622734c' as Address,   // From deployment report: protocolDataProvider
  ORACLE: '0x703c3b23FA26C70E749c703CF08d99a595CBCb85' as Address,                   // From deployment report: aaveOracle
  
  // Test Tokens - Sepolia testnet token addresses
  // IMPORTANT: Use token addresses deployed on Sepolia testnet, not mainnet addresses
  // 
  // Option 1: Use official test tokens on Sepolia (if available)
  // Option 2: Deploy your own test tokens to Sepolia and use those addresses
  // 
  // To find or verify Sepolia token addresses:
  // - Check Sepolia Etherscan: https://sepolia.etherscan.io
  // - Search for token contracts on Sepolia
  // - Or deploy test tokens using scripts/MintUSDC.sol
  TOKENS: {
    // WETH9 on Sepolia (official wrapped ETH contract)
    // This is the standard WETH9 contract address on Sepolia testnet
    WETH: '0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9' as Address,
    // USDC on Sepolia testnet - Circle Official USDC
    // This is the official Circle USDC that was listed in the Aave Pool
    // Verify on Sepolia Etherscan: https://sepolia.etherscan.io/address/0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238
    USDC: '0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238' as Address,
    // DAI on Sepolia
    // If you need DAI, either:
    // 1. Find an existing DAI test token on Sepolia (check Etherscan)
    // 2. Deploy your own test DAI token
    DAI: '0x0000000000000000000000000000000000000000' as Address, // Update with Sepolia DAI address
  },
} as const

/**
 * Token configurations for display
 */
export const TOKEN_CONFIG = {
  DAI: {
    symbol: 'DAI',
    name: 'Dai Stablecoin',
    decimals: 18,
    icon: '💵',
  },
  USDC: {
    symbol: 'USDC',
    name: 'USD Coin',
    decimals: 6,
    icon: '💲',
  },
  WETH: {
    symbol: 'WETH',
    name: 'Wrapped Ether',
    decimals: 18,
    icon: '⧫',
  },
} as const

/**
 * Role constants for ACL Manager
 */
export const ROLES = {
  POOL_ADMIN: 'POOL_ADMIN_ROLE',
  LIQUIDITY_ADMIN: 'LIQUIDITY_ADMIN_ROLE',
  APPROVED_USER: 'APPROVED_USER_ROLE',
} as const

/**
 * Interest rate mode for borrowing (Variable rate only in V3.5)
 */
export const INTEREST_RATE_MODE = {
  NONE: 0n,
  VARIABLE: 2n,
} as const

/**
 * Default referral code
 */
export const REFERRAL_CODE = 0

/**
 * Max uint256 for unlimited approvals/withdrawals
 */
export const MAX_UINT256 = BigInt('0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff')

