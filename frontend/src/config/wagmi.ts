import { http } from 'wagmi'
import { sepolia } from 'wagmi/chains'
import { getDefaultConfig } from '@rainbow-me/rainbowkit'

// WalletConnect Cloud projectId
// Get your own at https://cloud.walletconnect.com (free)
// Using a valid projectId for proper wallet connection/disconnection
const WALLETCONNECT_PROJECT_ID = '3a8170812b534d0ff9d794f19a901d64'

// Sepolia RPC URL
// For better performance, configure your own Alchemy/Infura API key via environment variable VITE_SEPOLIA_RPC_URL
// Or use the public RPC endpoint below
const SEPOLIA_RPC_URL = import.meta.env.VITE_SEPOLIA_RPC_URL || 'https://ethereum-sepolia-rpc.publicnode.com'

export const config = getDefaultConfig({
  appName: 'Aave Bank Lending',
  projectId: WALLETCONNECT_PROJECT_ID,
  chains: [sepolia],
  transports: {
    [sepolia.id]: http(SEPOLIA_RPC_URL),
  },
  ssr: false,
})

