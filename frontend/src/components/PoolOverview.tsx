import { useState, useEffect } from 'react'
import { useReadContracts } from 'wagmi'
import { formatUnits, Address } from 'viem'
import { PoolABI, ERC20ABI } from '../abi'
import { CONTRACT_ADDRESSES } from '../config'
import { useReservesList } from '../hooks'

interface ReserveData {
  configuration: { data: bigint }
  liquidityIndex: bigint
  currentLiquidityRate: bigint
  variableBorrowIndex: bigint
  currentVariableBorrowRate: bigint
  currentStableBorrowRate: bigint
  lastUpdateTimestamp: number
  id: number
  aTokenAddress: Address
  stableDebtTokenAddress: Address
  variableDebtTokenAddress: Address
  interestRateStrategyAddress: Address
  accruedToTreasury: bigint
  unbacked: bigint
}

interface ReserveInfo {
  address: Address
  symbol: string
  decimals: number
  totalSupply: bigint
  totalBorrow: bigint
  supplyAPY: string
  borrowAPY: string
  availableLiquidity: bigint
  utilizationRate: string
}

function ReserveCard({ reserve }: { reserve: ReserveInfo }) {
  const formattedSupply = formatUnits(reserve.totalSupply, reserve.decimals)
  const formattedBorrow = formatUnits(reserve.totalBorrow, reserve.decimals)
  const formattedAvailable = formatUnits(reserve.availableLiquidity, reserve.decimals)

  return (
    <div className="card hover:border-aave-teal/50 transition-all">
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-full bg-gradient-to-br from-aave-purple/30 to-aave-teal/30 flex items-center justify-center">
            <span className="text-lg font-bold">{reserve.symbol.charAt(0)}</span>
          </div>
          <div>
            <h3 className="font-semibold text-lg">{reserve.symbol}</h3>
            <p className="text-xs text-gray-500 font-mono">
              {reserve.address.slice(0, 6)}...{reserve.address.slice(-4)}
            </p>
          </div>
        </div>
        <div className="text-right">
          <div className="text-sm text-gray-400">Utilization</div>
          <div className={`text-lg font-semibold ${
            parseFloat(reserve.utilizationRate) > 80 ? 'text-red-400' :
            parseFloat(reserve.utilizationRate) > 50 ? 'text-yellow-400' : 'text-aave-green'
          }`}>
            {reserve.utilizationRate}%
          </div>
        </div>
      </div>

      <div className="grid grid-cols-2 gap-4 mb-4">
        <div className="p-3 rounded-lg bg-white/5">
          <div className="text-xs text-gray-400 mb-1">Total Supplied</div>
          <div className="text-lg font-semibold text-aave-green">
            {parseFloat(formattedSupply).toLocaleString(undefined, { maximumFractionDigits: 2 })}
          </div>
          <div className="text-xs text-gray-500">{reserve.symbol}</div>
        </div>
        <div className="p-3 rounded-lg bg-white/5">
          <div className="text-xs text-gray-400 mb-1">Total Borrowed</div>
          <div className="text-lg font-semibold text-aave-purple">
            {parseFloat(formattedBorrow).toLocaleString(undefined, { maximumFractionDigits: 2 })}
          </div>
          <div className="text-xs text-gray-500">{reserve.symbol}</div>
        </div>
      </div>

      <div className="grid grid-cols-3 gap-3">
        <div className="text-center p-2 rounded bg-white/5">
          <div className="text-xs text-gray-400">Available</div>
          <div className="font-medium text-sm">
            {parseFloat(formattedAvailable).toLocaleString(undefined, { maximumFractionDigits: 2 })}
          </div>
        </div>
        <div className="text-center p-2 rounded bg-aave-green/10">
          <div className="text-xs text-gray-400">Supply APY</div>
          <div className="font-medium text-sm text-aave-green">{reserve.supplyAPY}%</div>
        </div>
        <div className="text-center p-2 rounded bg-aave-purple/10">
          <div className="text-xs text-gray-400">Borrow APY</div>
          <div className="font-medium text-sm text-aave-purple">{reserve.borrowAPY}%</div>
        </div>
      </div>
    </div>
  )
}

export default function PoolOverview() {
  const { reserves, isLoading: isLoadingReserves } = useReservesList()
  const [reserveInfos, setReserveInfos] = useState<ReserveInfo[]>([])

  // Fetch data for all reserves
  const reserveContracts = reserves.flatMap((address) => [
    // Token symbol
    {
      address: address as Address,
      abi: ERC20ABI,
      functionName: 'symbol' as const,
    },
    // Token decimals
    {
      address: address as Address,
      abi: ERC20ABI,
      functionName: 'decimals' as const,
    },
    // Reserve data from Pool
    {
      address: CONTRACT_ADDRESSES.POOL,
      abi: PoolABI,
      functionName: 'getReserveData' as const,
      args: [address],
    },
  ])

  const { data: reserveData, isLoading: isLoadingData } = useReadContracts({
    contracts: reserveContracts,
    query: {
      enabled: reserves.length > 0,
    },
  })

  // Note: aToken balances fetching can be added here if needed

  useEffect(() => {
    if (!reserveData || reserves.length === 0) return

    const infos: ReserveInfo[] = []
    
    for (let i = 0; i < reserves.length; i++) {
      const baseIndex = i * 3
      const symbol = reserveData[baseIndex]?.result as string || 'Unknown'
      const decimals = reserveData[baseIndex + 1]?.result as number || 18
      const data = reserveData[baseIndex + 2]?.result as ReserveData

      if (!data) continue

      // Parse rates from RAY (1e27)
      const liquidityRate = data.currentLiquidityRate || 0n
      const borrowRate = data.currentVariableBorrowRate || 0n
      
      const supplyAPY = (Number(liquidityRate) / 1e25).toFixed(2)
      const borrowAPY = (Number(borrowRate) / 1e25).toFixed(2)

      infos.push({
        address: reserves[i] as Address,
        symbol,
        decimals,
        totalSupply: 0n, // Will be updated
        totalBorrow: 0n, // Will be updated
        supplyAPY,
        borrowAPY,
        availableLiquidity: 0n,
        utilizationRate: '0',
      })
    }

    setReserveInfos(infos)
  }, [reserveData, reserves])

  // Fetch aToken and debt token balances
  const tokenBalanceContracts = reserveInfos.flatMap((_info, i) => {
    const baseIndex = i * 3
    const data = reserveData?.[baseIndex + 2]?.result as ReserveData
    if (!data) return []

    return [
      // aToken total supply (total supplied)
      {
        address: data.aTokenAddress as Address,
        abi: ERC20ABI,
        functionName: 'totalSupply' as const,
      },
      // Variable debt token total supply (total borrowed)
      {
        address: data.variableDebtTokenAddress as Address,
        abi: ERC20ABI,
        functionName: 'totalSupply' as const,
      },
    ]
  })

  const { data: balanceData } = useReadContracts({
    contracts: tokenBalanceContracts,
    query: {
      enabled: tokenBalanceContracts.length > 0 && reserveInfos.length > 0,
    },
  })

  // Update reserve infos with balance data
  useEffect(() => {
    if (!balanceData || reserveInfos.length === 0) return

    const updatedInfos = reserveInfos.map((info, i) => {
      const baseIndex = i * 2
      const totalSupply = (balanceData[baseIndex]?.result as bigint) || 0n
      const totalBorrow = (balanceData[baseIndex + 1]?.result as bigint) || 0n
      const availableLiquidity = totalSupply > totalBorrow ? totalSupply - totalBorrow : 0n
      
      // Calculate utilization rate
      let utilizationRate = '0'
      if (totalSupply > 0n) {
        utilizationRate = ((Number(totalBorrow) / Number(totalSupply)) * 100).toFixed(2)
      }

      return {
        ...info,
        totalSupply,
        totalBorrow,
        availableLiquidity,
        utilizationRate,
      }
    })

    // Only update if values changed
    const hasChanges = updatedInfos.some((info, i) => 
      info.totalSupply !== reserveInfos[i].totalSupply ||
      info.totalBorrow !== reserveInfos[i].totalBorrow
    )

    if (hasChanges) {
      setReserveInfos(updatedInfos)
    }
  }, [balanceData, reserveInfos])

  const isLoading = isLoadingReserves || isLoadingData

  // Calculate totals
  const totalSuppliedUSD = reserveInfos.reduce((acc, info) => {
    // Assume 1:1 USD for simplicity (in production, use oracle prices)
    return acc + Number(formatUnits(info.totalSupply, info.decimals))
  }, 0)

  const totalBorrowedUSD = reserveInfos.reduce((acc, info) => {
    return acc + Number(formatUnits(info.totalBorrow, info.decimals))
  }, 0)

  return (
    <div className="space-y-6">
      {/* Pool Stats Overview */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <div className="card">
          <div className="flex items-center gap-3 mb-2">
            <div className="w-10 h-10 rounded-xl bg-aave-green/20 flex items-center justify-center">
              <span className="text-xl">📊</span>
            </div>
            <div>
              <div className="text-sm text-gray-400">Total Market Size</div>
              <div className="text-2xl font-semibold gradient-text">
                ${totalSuppliedUSD.toLocaleString(undefined, { maximumFractionDigits: 0 })}
              </div>
            </div>
          </div>
        </div>

        <div className="card">
          <div className="flex items-center gap-3 mb-2">
            <div className="w-10 h-10 rounded-xl bg-aave-purple/20 flex items-center justify-center">
              <span className="text-xl">💸</span>
            </div>
            <div>
              <div className="text-sm text-gray-400">Total Borrowed</div>
              <div className="text-2xl font-semibold text-aave-purple">
                ${totalBorrowedUSD.toLocaleString(undefined, { maximumFractionDigits: 0 })}
              </div>
            </div>
          </div>
        </div>

        <div className="card">
          <div className="flex items-center gap-3 mb-2">
            <div className="w-10 h-10 rounded-xl bg-aave-teal/20 flex items-center justify-center">
              <span className="text-xl">💰</span>
            </div>
            <div>
              <div className="text-sm text-gray-400">Available Liquidity</div>
              <div className="text-2xl font-semibold text-aave-teal">
                ${(totalSuppliedUSD - totalBorrowedUSD).toLocaleString(undefined, { maximumFractionDigits: 0 })}
              </div>
            </div>
          </div>
        </div>

        <div className="card">
          <div className="flex items-center gap-3 mb-2">
            <div className="w-10 h-10 rounded-xl bg-white/10 flex items-center justify-center">
              <span className="text-xl">🪙</span>
            </div>
            <div>
              <div className="text-sm text-gray-400">Listed Assets</div>
              <div className="text-2xl font-semibold">
                {reserves.length}
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Reserves List */}
      <div className="card">
        <div className="flex items-center justify-between mb-6">
          <div>
            <h2 className="text-xl font-display font-semibold">Pool Reserves</h2>
            <p className="text-gray-400 text-sm">All assets available in the lending pool</p>
          </div>
          {isLoading && (
            <div className="flex items-center gap-2 text-gray-400">
              <svg className="animate-spin h-5 w-5" viewBox="0 0 24 24">
                <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" fill="none" />
                <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
              </svg>
              Loading...
            </div>
          )}
        </div>

        {reserves.length === 0 ? (
          <div className="text-center py-12">
            <div className="w-16 h-16 mx-auto mb-4 rounded-full bg-white/5 flex items-center justify-center">
              <span className="text-3xl">📭</span>
            </div>
            <h3 className="text-lg font-semibold mb-2">No Assets Listed</h3>
            <p className="text-gray-400 text-sm">
              The pool doesn't have any assets listed yet.<br />
              Contact the Pool Admin to list assets.
            </p>
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {reserveInfos.map((reserve) => (
              <ReserveCard key={reserve.address} reserve={reserve} />
            ))}
          </div>
        )}
      </div>

      {/* Pool Info */}
      <div className="card">
        <h3 className="text-lg font-semibold mb-4">Pool Contract Info</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div className="p-3 rounded-lg bg-white/5">
            <div className="text-xs text-gray-400 mb-1">Pool Address</div>
            <div className="font-mono text-sm break-all">{CONTRACT_ADDRESSES.POOL}</div>
          </div>
          <div className="p-3 rounded-lg bg-white/5">
            <div className="text-xs text-gray-400 mb-1">Pool Addresses Provider</div>
            <div className="font-mono text-sm break-all">{CONTRACT_ADDRESSES.POOL_ADDRESSES_PROVIDER}</div>
          </div>
          <div className="p-3 rounded-lg bg-white/5">
            <div className="text-xs text-gray-400 mb-1">ACL Manager</div>
            <div className="font-mono text-sm break-all">{CONTRACT_ADDRESSES.ACL_MANAGER}</div>
          </div>
          <div className="p-3 rounded-lg bg-white/5">
            <div className="text-xs text-gray-400 mb-1">Oracle</div>
            <div className="font-mono text-sm break-all">{CONTRACT_ADDRESSES.ORACLE}</div>
          </div>
        </div>
      </div>
    </div>
  )
}

