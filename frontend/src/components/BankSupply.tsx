import { useState, useEffect } from 'react'
import { useAccount, useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { parseUnits, formatUnits } from 'viem'
import { PoolABI, ERC20ABI } from '../abi'
import { CONTRACT_ADDRESSES, TOKEN_CONFIG, REFERRAL_CODE, MAX_UINT256 } from '../config'
import { useACLRoles, useTokenBalance, useTokenAllowance, useReservesList } from '../hooks'

type ActionType = 'supply' | 'withdraw'

// Parse error message for user-friendly display
function parseErrorMessage(error: Error | null): string {
  if (!error) return ''
  
  const message = error.message || ''
  
  // Common Aave error patterns
  if (message.includes('TRANSFER_AMOUNT_EXCEEDS_BALANCE')) {
    return 'Insufficient token balance'
  }
  if (message.includes('INSUFFICIENT_BALANCE')) {
    return 'Insufficient balance to complete this operation'
  }
  if (message.includes('CALLER_NOT_LIQUIDITY_ADMIN')) {
    return 'You are not a liquidity admin. Contact the Pool Admin.'
  }
  if (message.includes('User rejected') || message.includes('user rejected')) {
    return 'Transaction was rejected by user'
  }
  if (message.includes('execution reverted')) {
    const match = message.match(/reason: ([^"]+)/) || message.match(/reverted: ([^"]+)/)
    if (match) {
      return match[1]
    }
    return 'Transaction failed - the contract reverted the operation'
  }
  
  return message.length > 100 ? message.slice(0, 100) + '...' : message
}

export default function BankSupply() {
  const { address } = useAccount()
  const { isLiquidityAdmin, isLoading: isLoadingRole } = useACLRoles(address)
  const [selectedToken, setSelectedToken] = useState<keyof typeof TOKEN_CONFIG>('USDC')
  const [amount, setAmount] = useState('')
  const [action, setAction] = useState<ActionType>('supply')
  const [showPermissionWarning, setShowPermissionWarning] = useState(false)

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
  const { data: approveHash, writeContract: writeApprove, isPending: isApproving, error: approveError, reset: resetApprove } = useWriteContract()
  const { data: actionHash, writeContract: writeAction, isPending: isActioning, error: actionError, reset: resetAction } = useWriteContract()
  
  const { isLoading: isApprovingTx, isSuccess: approveSuccess, error: approveTxError } = useWaitForTransactionReceipt({ hash: approveHash })
  const { isLoading: isActioningTx, isSuccess: actionSuccess, error: actionTxError } = useWaitForTransactionReceipt({ hash: actionHash })

  // Combined error state
  const [showError, setShowError] = useState(false)
  const currentError = actionError || approveError || actionTxError || approveTxError

  // Refetch data after successful transaction
  useEffect(() => {
    if (approveSuccess || actionSuccess) {
      refetchBalance()
      refetchAllowance()
    }
  }, [approveSuccess, actionSuccess, refetchBalance, refetchAllowance])

  // Show error when it occurs
  useEffect(() => {
    if (currentError) {
      setShowError(true)
      console.error('Transaction error:', currentError)
    }
  }, [currentError])

  // Clear error after 10 seconds
  useEffect(() => {
    if (showError) {
      const timer = setTimeout(() => {
        setShowError(false)
        resetApprove()
        resetAction()
      }, 10000)
      return () => clearTimeout(timer)
    }
  }, [showError, resetApprove, resetAction])

  // Hide warning after 5 seconds
  useEffect(() => {
    if (showPermissionWarning) {
      const timer = setTimeout(() => setShowPermissionWarning(false), 5000)
      return () => clearTimeout(timer)
    }
  }, [showPermissionWarning])

  const parsedAmount = amount ? parseUnits(amount, decimals) : 0n
  const needsApproval = action === 'supply' && parsedAmount > allowance

  const handleApprove = () => {
    if (!isLiquidityAdmin) {
      setShowPermissionWarning(true)
      return
    }
    writeApprove({
      address: tokenAddress,
      abi: ERC20ABI,
      functionName: 'approve',
      args: [CONTRACT_ADDRESSES.POOL, MAX_UINT256],
    })
  }

  const handleAction = () => {
    if (!address) return
    
    // Check permission before action
    if (!isLiquidityAdmin) {
      setShowPermissionWarning(true)
      return
    }

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

  return (
    <div className="space-y-6">
      {/* Role Status Banner */}
      <div className={`p-4 rounded-xl border ${
        isLiquidityAdmin 
          ? 'bg-aave-green/10 border-aave-green/30' 
          : 'bg-yellow-500/10 border-yellow-500/30'
      }`}>
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className={`w-10 h-10 rounded-full flex items-center justify-center ${
              isLiquidityAdmin ? 'bg-aave-green/20' : 'bg-yellow-500/20'
            }`}>
              <span className="text-xl">{isLiquidityAdmin ? '✓' : '⚠️'}</span>
            </div>
            <div>
              <div className="font-semibold">
                {isLoadingRole ? 'Checking role...' : (
                  isLiquidityAdmin ? 'Liquidity Admin Access' : 'No Liquidity Admin Role'
                )}
              </div>
              <div className="text-sm text-gray-400">
                {isLiquidityAdmin 
                  ? 'You can supply and withdraw liquidity from the pool'
                  : 'You need Liquidity Admin role to perform supply/withdraw operations'
                }
              </div>
            </div>
          </div>
          <div className={`px-3 py-1 rounded-full text-sm font-medium ${
            isLiquidityAdmin 
              ? 'bg-aave-green/20 text-aave-green' 
              : 'bg-yellow-500/20 text-yellow-400'
          }`}>
            {isLiquidityAdmin ? 'LIQUIDITY_ADMIN' : 'NO ROLE'}
          </div>
        </div>
      </div>

      {/* Permission Warning Alert */}
      {showPermissionWarning && (
        <div className="p-4 rounded-xl bg-red-500/10 border border-red-500/30 animate-in">
          <div className="flex items-center gap-3">
            <span className="text-2xl">🚫</span>
            <div>
              <div className="font-semibold text-red-400">Permission Denied</div>
              <div className="text-sm text-gray-400">
                You need <span className="text-red-400 font-mono">LIQUIDITY_ADMIN</span> role to perform this action. 
                Contact the Pool Admin to get access.
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Stats Overview */}
      <div className="grid grid-cols-4 gap-4">
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
        <div className="card">
          <div className="text-sm text-gray-400 mb-1">Role Status</div>
          <div className={`text-2xl font-semibold ${isLiquidityAdmin ? 'text-aave-green' : 'text-yellow-400'}`}>
            {isLiquidityAdmin ? '✓ Active' : '✗ None'}
          </div>
          <div className="text-sm text-gray-500">Liquidity Admin</div>
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

        {/* No Permission Notice */}
        {!isLiquidityAdmin && (
          <div className="p-3 rounded-lg bg-yellow-500/10 border border-yellow-500/20 mb-4">
            <div className="flex items-center gap-2 text-yellow-400 text-sm">
              <span>⚠️</span>
              <span>You need <span className="font-mono font-semibold">LIQUIDITY_ADMIN</span> role to execute transactions</span>
            </div>
          </div>
        )}

        {/* Action Buttons */}
        <div className="space-y-3">
          {needsApproval && (
            <button
              onClick={handleApprove}
              disabled={isApproving || isApprovingTx}
              className={`w-full ${isLiquidityAdmin ? 'btn-secondary' : 'btn-secondary opacity-60 cursor-not-allowed'}`}
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
                <>
                  {!isLiquidityAdmin && <span className="mr-2">🔒</span>}
                  Approve {TOKEN_CONFIG[selectedToken].symbol}
                </>
              )}
            </button>
          )}

          <button
            onClick={handleAction}
            disabled={isActioning || isActioningTx || !amount || (needsApproval && !approveSuccess)}
            className={`w-full ${isLiquidityAdmin ? 'btn-primary' : 'btn-primary opacity-60'}`}
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
              <>
                {!isLiquidityAdmin && <span className="mr-2">🔒</span>}
                {action === 'supply' ? 'Supply' : 'Withdraw'} {TOKEN_CONFIG[selectedToken].symbol}
              </>
            )}
          </button>
        </div>

        {/* Status Messages */}
        {actionSuccess && (
          <div className="mt-4 p-4 rounded-lg bg-aave-green/10 border border-aave-green/30 text-aave-green">
            <div className="flex items-center gap-2">
              <span className="text-xl">✓</span>
              <span>{action === 'supply' ? 'Supply' : 'Withdrawal'} successful!</span>
            </div>
          </div>
        )}
        
        {/* Error Alert */}
        {showError && currentError && (
          <div className="mt-4 p-4 rounded-xl bg-red-500/10 border border-red-500/30 animate-in">
            <div className="flex items-start justify-between gap-3">
              <div className="flex items-start gap-3">
                <div className="w-10 h-10 rounded-full bg-red-500/20 flex items-center justify-center flex-shrink-0">
                  <span className="text-xl">❌</span>
                </div>
                <div>
                  <div className="font-semibold text-red-400 mb-1">Transaction Failed</div>
                  <div className="text-sm text-gray-400">
                    {parseErrorMessage(currentError)}
                  </div>
                </div>
              </div>
              <button
                onClick={() => {
                  setShowError(false)
                  resetApprove()
                  resetAction()
                }}
                className="text-gray-500 hover:text-white transition-colors"
              >
                ✕
              </button>
            </div>
            
            {/* Helpful suggestions */}
            <div className="mt-3 pt-3 border-t border-red-500/20">
              <div className="text-xs text-gray-500">
                💡 <strong>Suggestions:</strong>
                <ul className="mt-1 ml-4 list-disc space-y-1">
                  <li>Check if you have sufficient token balance</li>
                  <li>Ensure the token is approved for the Pool contract</li>
                  <li>Verify you have the LIQUIDITY_ADMIN role</li>
                  <li>Check the browser console for detailed error info</li>
                </ul>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}

