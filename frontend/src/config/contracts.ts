import { Address } from 'viem'

/**
 * Contract addresses for the deployed Aave V3 protocol
 * 
 * NOTE: These addresses need to be updated after deploying the contracts locally.
 * Run the deployment script and update these values from the deployment output.
 * 
 * Example deployment command:
 * ```bash
 * forge script scripts/DeployAaveV3MarketBatched.sol --rpc-url http://localhost:8545 --broadcast
 * ```
 */
export const CONTRACT_ADDRESSES = {
  // Core Protocol
  POOL_ADDRESSES_PROVIDER: '0x9bd03768a7DCc129555dE410FF8E85528A4F88b5' as Address,
  POOL: '0xb14D33721D921fA72Eae56EfE9149caF7C7f2736' as Address, // poolProxy
  POOL_CONFIGURATOR: '0xcdA074FebAd146910539E2B12D0Fc80acF4359d9' as Address, // poolConfiguratorProxy
  ACL_MANAGER: '0x0433d874a28147DB0b330C000fcC50C0f0BaF425' as Address,
  
  // Protocol Data
  PROTOCOL_DATA_PROVIDER: '0x32467b43BFa67273FC7dDda0999Ee9A12F2AaA08' as Address,
  ORACLE: '0x6F1216D1BFe15c98520CA1434FC1d9D57AC95321' as Address,
  
  // Test Tokens
  // NOTE: Token addresses need to be obtained from Pool.getReservesList() after listing assets
  // Or check the test listing contract deployment output
  // You can query them using: await poolContract.getReservesList()
  TOKENS: {
    DAI: '0x0000000000000000000000000000000000000000' as Address, // Update after asset listing
    USDC: '0x0000000000000000000000000000000000000000' as Address, // Update after asset listing
    WETH: '0x0000000000000000000000000000000000000000' as Address, // Update after asset listing
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

