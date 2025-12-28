import { useState, useEffect } from 'react'
import { useAccount, useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { parseUnits, formatUnits } from 'viem'
import { PoolABI, ERC20ABI } from '../abi'
import { CONTRACT_ADDRESSES, TOKEN_CONFIG, REFERRAL_CODE, MAX_UINT256 } from '../config'
import { useACLRoles, useTokenBalance, useTokenAllowance, useReservesList } from '../hooks'

type ActionType = 'supply' | 'withdraw'

export default function BankSupply() {
  const { address } = useAccount()
  const { isLiquidityAdmin } = useACLRoles(address)
  const [selectedToken, setSelectedToken] = useState<keyof typeof TOKEN_CONFIG>('DAI')
  const [amount, setAmount] = useState('')
  const [action, setAction] = useState<ActionType>('supply')

  const tokenAddress = CONTRACT_ADDRESSES.TOKENS[selectedToken]
  const { formattedBalance, decimals, refetch: refetchBalance } = useTokenBalance(
    tokenAddress,
    address
  )
  const { allowance, refetch: refetchAllowance } = useTokenAllowance(
    tokenAddress,
    address,
    CONTRACT_ADDRESSES.POOL
  )

  const { reserves } = useReservesList()

  // Write contract hooks
  const { data: approveHash, writeContract: writeApprove, isPending: isApproving } = useWriteContract()
  const { data: actionHash, writeContract: writeAction, isPending: isActioning, error: actionError } = useWriteContract()
  
  const { isLoading: isApprovingTx, isSuccess: approveSuccess } = useWaitForTransactionReceipt({ hash: approveHash })
  const { isLoading: isActioningTx, isSuccess: actionSuccess } = useWaitForTransactionReceipt({ hash: actionHash })

  // Refetch data after successful transaction
  useEffect(() => {
    if (approveSuccess || actionSuccess) {
      refetchBalance()
      refetchAllowance()
    }
  }, [approveSuccess, actionSuccess, refetchBalance, refetchAllowance])

  const parsedAmount = amount ? parseUnits(amount, decimals) : 0n
  const needsApproval = action === 'supply' && parsedAmount > allowance

  const handleApprove = () => {
    writeApprove({
      address: tokenAddress,
      abi: ERC20ABI,
      functionName: 'approve',
      args: [CONTRACT_ADDRESSES.POOL, MAX_UINT256],
    })
  }

  const handleAction = () => {
    if (!address) return

    if (action === 'supply') {
      writeAction({
        address: CONTRACT_ADDRESSES.POOL,
        abi: PoolABI,
        functionName: 'supply',
        args: [tokenAddress, parsedAmount, address, REFERRAL_CODE],
      })
    } else {
      writeAction({
        address: CONTRACT_ADDRESSES.POOL,
        abi: PoolABI,
        functionName: 'withdraw',
        args: [tokenAddress, parsedAmount, address],
      })
    }
  }

  if (!isLiquidityAdmin) {
    return (
      <div className="card">
        <div className="flex flex-col items-center justify-center py-12">
          <div className="w-16 h-16 mb-4 rounded-full bg-yellow-500/10 flex items-center justify-center">
            <span className="text-3xl">🏦</span>
          </div>
          <h3 className="text-xl font-semibold mb-2">Liquidity Admin Required</h3>
          <p className="text-gray-400 text-center max-w-md">
            You need Liquidity Admin privileges to supply or withdraw liquidity.
            Contact your Pool Admin to get access.
          </p>
        </div>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      {/* Stats Overview */}
      <div className="grid grid-cols-3 gap-4">
        <div className="card">
          <div className="text-sm text-gray-400 mb-1">Your Balance</div>
          <div className="text-2xl font-semibold">
            {parseFloat(formattedBalance).toLocaleString(undefined, { maximumFractionDigits: 4 })}
          </div>
          <div className="text-sm text-gray-500">{TOKEN_CONFIG[selectedToken].symbol}</div>
        </div>
        <div className="card">
          <div className="text-sm text-gray-400 mb-1">Current Allowance</div>
          <div className="text-2xl font-semibold">
            {allowance >= MAX_UINT256 / 2n ? '∞' : formatUnits(allowance, decimals)}
          </div>
          <div className="text-sm text-gray-500">{TOKEN_CONFIG[selectedToken].symbol}</div>
        </div>
        <div className="card">
          <div className="text-sm text-gray-400 mb-1">Listed Reserves</div>
          <div className="text-2xl font-semibold">{reserves.length}</div>
          <div className="text-sm text-gray-500">Assets</div>
        </div>
      </div>

      {/* Main Action Card */}
      <div className="card">
        <h2 className="text-xl font-display font-semibold mb-2">Bank Liquidity Management</h2>
        <p className="text-gray-400 text-sm mb-6">
          Supply liquidity to enable user borrowing or withdraw excess liquidity.
        </p>

        {/* Action Toggle */}
        <div className="flex gap-2 p-1 bg-white/5 rounded-lg mb-6">
          <button
            onClick={() => setAction('supply')}
            className={`flex-1 py-2 rounded-md font-medium transition-all ${
              action === 'supply'
                ? 'bg-aave-green text-white'
                : 'text-gray-400 hover:text-white'
            }`}
          >
            Supply
          </button>
          <button
            onClick={() => setAction('withdraw')}
            className={`flex-1 py-2 rounded-md font-medium transition-all ${
              action === 'withdraw'
                ? 'bg-aave-purple text-white'
                : 'text-gray-400 hover:text-white'
            }`}
          >
            Withdraw
          </button>
        </div>

        {/* Token Selection */}
        <div className="mb-6">
          <label className="label">Select Asset</label>
          <div className="grid grid-cols-3 gap-3">
            {(Object.keys(TOKEN_CONFIG) as (keyof typeof TOKEN_CONFIG)[]).map((token) => (
              <button
                key={token}
                onClick={() => setSelectedToken(token)}
                className={`p-4 rounded-lg border transition-all flex items-center gap-3 ${
                  selectedToken === token
                    ? 'border-aave-teal bg-aave-teal/10'
                    : 'border-white/10 hover:border-white/20'
                }`}
              >
                <span className="text-2xl">{TOKEN_CONFIG[token].icon}</span>
                <div className="text-left">
                  <div className="font-medium">{TOKEN_CONFIG[token].symbol}</div>
                  <div className="text-xs text-gray-400">{TOKEN_CONFIG[token].name}</div>
                </div>
              </button>
            ))}
          </div>
        </div>

        {/* Amount Input */}
        <div className="mb-6">
          <label className="label">Amount</label>
          <div className="relative">
            <input
              type="number"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              placeholder="0.00"
              className="input-field pr-24"
            />
            <button
              onClick={() => setAmount(formattedBalance)}
              className="absolute right-3 top-1/2 -translate-y-1/2 text-sm text-aave-teal hover:text-aave-green"
            >
              MAX
            </button>
          </div>
          <div className="text-sm text-gray-500 mt-2">
            Balance: {parseFloat(formattedBalance).toLocaleString()} {TOKEN_CONFIG[selectedToken].symbol}
          </div>
        </div>

        {/* Action Buttons */}
        <div className="space-y-3">
          {needsApproval && (
            <button
              onClick={handleApprove}
              disabled={isApproving || isApprovingTx}
              className="btn-secondary w-full"
            >
              {isApproving || isApprovingTx ? (
                <span className="flex items-center justify-center gap-2">
                  <svg className="animate-spin h-5 w-5" viewBox="0 0 24 24">
                    <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" fill="none" />
                    <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
                  </svg>
                  Approving...
                </span>
              ) : (
                `Approve ${TOKEN_CONFIG[selectedToken].symbol}`
              )}
            </button>
          )}

          <button
            onClick={handleAction}
            disabled={isActioning || isActioningTx || !amount || (needsApproval && !approveSuccess)}
            className="btn-primary w-full"
          >
            {isActioning || isActioningTx ? (
              <span className="flex items-center justify-center gap-2">
                <svg className="animate-spin h-5 w-5" viewBox="0 0 24 24">
                  <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" fill="none" />
                  <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
                </svg>
                Processing...
              </span>
            ) : (
              `${action === 'supply' ? 'Supply' : 'Withdraw'} ${TOKEN_CONFIG[selectedToken].symbol}`
            )}
          </button>
        </div>

        {/* Status Messages */}
        {actionSuccess && (
          <div className="mt-4 p-4 rounded-lg bg-aave-green/10 border border-aave-green/30 text-aave-green">
            ✓ {action === 'supply' ? 'Supply' : 'Withdrawal'} successful!
          </div>
        )}
        {actionError && (
          <div className="mt-4 p-4 rounded-lg bg-red-500/10 border border-red-500/30 text-red-400">
            ✗ Error: {actionError.message}
          </div>
        )}
      </div>
    </div>
  )
}

