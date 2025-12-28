import { useReadContract } from 'wagmi'
import { PoolABI, ERC20ABI } from '../abi'
import { CONTRACT_ADDRESSES } from '../config'
import { Address, formatUnits } from 'viem'

export function useUserAccountData(address: Address | undefined) {
  const { data, isLoading, error, refetch } = useReadContract({
    address: CONTRACT_ADDRESSES.POOL,
    abi: PoolABI,
    functionName: 'getUserAccountData',
    args: address ? [address] : undefined,
    query: {
      enabled: !!address && CONTRACT_ADDRESSES.POOL !== '0x0000000000000000000000000000000000000000',
    },
  })

  const parseData = () => {
    if (!data) return null
    const [
      totalCollateralBase,
      totalDebtBase,
      availableBorrowsBase,
      currentLiquidationThreshold,
      ltv,
      healthFactor,
    ] = data

    return {
      totalCollateralBase: formatUnits(totalCollateralBase, 8),
      totalDebtBase: formatUnits(totalDebtBase, 8),
      availableBorrowsBase: formatUnits(availableBorrowsBase, 8),
      currentLiquidationThreshold: (Number(currentLiquidationThreshold) / 100).toFixed(2),
      ltv: (Number(ltv) / 100).toFixed(2),
      healthFactor: healthFactor > 0n ? formatUnits(healthFactor, 18) : '∞',
    }
  }

  return {
    data: parseData(),
    rawData: data,
    isLoading,
    error,
    refetch,
  }
}

export function useTokenBalance(
  tokenAddress: Address | undefined,
  userAddress: Address | undefined
) {
  const { data: balance, isLoading, error, refetch } = useReadContract({
    address: tokenAddress,
    abi: ERC20ABI,
    functionName: 'balanceOf',
    args: userAddress ? [userAddress] : undefined,
    query: {
      enabled: !!tokenAddress && !!userAddress,
    },
  })

  const { data: decimals } = useReadContract({
    address: tokenAddress,
    abi: ERC20ABI,
    functionName: 'decimals',
    query: {
      enabled: !!tokenAddress,
    },
  })

  const { data: symbol } = useReadContract({
    address: tokenAddress,
    abi: ERC20ABI,
    functionName: 'symbol',
    query: {
      enabled: !!tokenAddress,
    },
  })

  return {
    balance,
    formattedBalance: balance && decimals ? formatUnits(balance, decimals) : '0',
    decimals: decimals ?? 18,
    symbol: symbol ?? '',
    isLoading,
    error,
    refetch,
  }
}

export function useTokenAllowance(
  tokenAddress: Address | undefined,
  ownerAddress: Address | undefined,
  spenderAddress: Address | undefined
) {
  const { data, isLoading, error, refetch } = useReadContract({
    address: tokenAddress,
    abi: ERC20ABI,
    functionName: 'allowance',
    args: ownerAddress && spenderAddress ? [ownerAddress, spenderAddress] : undefined,
    query: {
      enabled: !!tokenAddress && !!ownerAddress && !!spenderAddress,
    },
  })

  return {
    allowance: data ?? 0n,
    isLoading,
    error,
    refetch,
  }
}

export function useReservesList() {
  const { data, isLoading, error, refetch } = useReadContract({
    address: CONTRACT_ADDRESSES.POOL,
    abi: PoolABI,
    functionName: 'getReservesList',
    query: {
      enabled: CONTRACT_ADDRESSES.POOL !== '0x0000000000000000000000000000000000000000',
    },
  })

  return {
    reserves: data ?? [],
    isLoading,
    error,
    refetch,
  }
}

