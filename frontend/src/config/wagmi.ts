import { http } from 'wagmi'
import { localhost } from 'wagmi/chains'
import { getDefaultConfig } from '@rainbow-me/rainbowkit'

// Define local Anvil chain
const anvilChain = {
  ...localhost,
  id: 31337,
  name: 'Anvil Local',
  nativeCurrency: {
    decimals: 18,
    name: 'Ether',
    symbol: 'ETH',
  },
  rpcUrls: {
    default: {
      http: ['http://127.0.0.1:8545'],
    },
    public: {
      http: ['http://127.0.0.1:8545'],
    },
  },
} as const

export const config = getDefaultConfig({
  appName: 'Aave Bank Lending',
  projectId: 'aave-bank-lending-local', // Required for WalletConnect
  chains: [anvilChain],
  transports: {
    [anvilChain.id]: http('http://127.0.0.1:8545'),
  },
  ssr: false,
})

export { anvilChain }

