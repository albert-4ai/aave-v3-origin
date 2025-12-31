import { useState, useEffect } from 'react'
import { useAccount, useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { parseUnits } from 'viem'
import { PoolABI, ERC20ABI } from '../abi'
import { CONTRACT_ADDRESSES, TOKEN_CONFIG, REFERRAL_CODE, INTEREST_RATE_MODE, MAX_UINT256 } from '../config'
import { useACLRoles, useTokenBalance, useTokenAllowance, useUserAccountData } from '../hooks'

type ActionType = 'supply' | 'withdraw' | 'borrow' | 'repay'

// Parse error message for user-friendly display
function parseErrorMessage(error: Error | null): string {
  if (!error) return ''
  
  const message = error.message || ''
  const errorString = JSON.stringify(error)
  
  // Check for CallerNotApprovedUser error code (0x29c0ce0c)
  // This is the selector for CallerNotApprovedUser() custom error
  if (message.includes('0x29c0ce0c') || errorString.includes('0x29c0ce0c')) {
    return '该地址没有权限进行此操作。请联系管理员获取 Approved User 权限。'
  }
  
  // Common Aave error patterns
  if (message.includes('TRANSFER_AMOUNT_EXCEEDS_BALANCE')) {
    return 'Insufficient token balance'
  }
  if (message.includes('INSUFFICIENT_BALANCE')) {
    return 'Insufficient balance to complete this operation'
  }
  if (message.includes('HEALTH_FACTOR_LOWER_THAN_LIQUIDATION_THRESHOLD')) {
    return 'This operation would put your position at risk of liquidation'
  }
  if (message.includes('COLLATERAL_CANNOT_COVER_NEW_BORROW')) {
    return 'Not enough collateral to borrow this amount'
  }
  if (message.includes('NOT_ENOUGH_AVAILABLE_USER_BALANCE')) {
    return 'Not enough available balance'
  }
  if (message.includes('CALLER_NOT_APPROVED_USER')) {
    return '该地址没有权限进行此操作。请联系管理员获取 Approved User 权限。'
  }
  if (message.includes('User rejected') || message.includes('user rejected')) {
    return 'Transaction was rejected by user'
  }
  if (message.includes('execution reverted')) {
    // Check for custom error codes in the message
    if (message.includes('custom error 0x29c0ce0c')) {
      return '该地址没有权限进行此操作。请联系管理员获取 Approved User 权限。'
    }
    // Try to extract the revert reason
    const match = message.match(/reason: ([^"]+)/) || message.match(/reverted: ([^"]+)/)
    if (match) {
      return match[1]
    }
    return 'Transaction failed - the contract reverted the operation'
  }
  
  // Default: show first 100 chars of error
  return message.length > 100 ? message.slice(0, 100) + '...' : message
}

export default function UserLending() {
  const { address } = useAccount()
  const { isApprovedUser } = useACLRoles(address)
  const [selectedToken, setSelectedToken] = useState<keyof typeof TOKEN_CONFIG>('USDC')
  const [amount, setAmount] = useState('')
  const [action, setAction] = useState<ActionType>('supply')
  const [showError, setShowError] = useState(false)
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
  const { data: accountData, refetch: refetchAccountData } = useUserAccountData(address)

  // Write contract hooks
  const { data: approveHash, writeContract: writeApprove, isPending: isApproving, error: approveError, reset: resetApprove } = useWriteContract()
  const { data: actionHash, writeContract: writeAction, isPending: isActioning, error: actionError, reset: resetAction } = useWriteContract()
  
  const { isLoading: isApprovingTx, isSuccess: approveSuccess, error: approveTxError } = useWaitForTransactionReceipt({ hash: approveHash })
  const { isLoading: isActioningTx, isSuccess: actionSuccess, error: actionTxError } = useWaitForTransactionReceipt({ hash: actionHash })

  // Combined error state
  const currentError = actionError || approveError || actionTxError || approveTxError

  // Refetch data after successful transaction
  useEffect(() => {
    if (approveSuccess || actionSuccess) {
      refetchBalance()
      refetchAllowance()
      refetchAccountData()
    }
  }, [approveSuccess, actionSuccess, refetchBalance, refetchAllowance, refetchAccountData])

  // Show error when it occurs
  useEffect(() => {
    if (currentError) {
      setShowError(true)
      console.error('Transaction error:', currentError)
    }
  }, [currentError])

  // Auto-hide permission warning after 5 seconds
  useEffect(() => {
    if (showPermissionWarning) {
      const timer = setTimeout(() => {
        setShowPermissionWarning(false)
      }, 5000)
      return () => clearTimeout(timer)
    }
  }, [showPermissionWarning])

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

  const parsedAmount = amount ? parseUnits(amount, decimals) : 0n
  const needsApproval = (action === 'supply' || action === 'repay') && parsedAmount > allowance

  const handleApprove = () => {
    if (!isApprovedUser) {
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
    
    // Check permission before sending transaction
    if (!isApprovedUser) {
      setShowPermissionWarning(true)
      return
    }

    switch (action) {
      case 'supply':
        writeAction({
          address: CONTRACT_ADDRESSES.POOL,
          abi: PoolABI,
          functionName: 'supply',
          args: [tokenAddress, parsedAmount, address, REFERRAL_CODE],
        })
        break
      case 'withdraw':
        writeAction({
          address: CONTRACT_ADDRESSES.POOL,
          abi: PoolABI,
          functionName: 'withdraw',
          args: [tokenAddress, parsedAmount, address],
        })
        break
      case 'borrow':
        writeAction({
          address: CONTRACT_ADDRESSES.POOL,
          abi: PoolABI,
          functionName: 'borrow',
          args: [tokenAddress, parsedAmount, INTEREST_RATE_MODE.VARIABLE, REFERRAL_CODE, address],
        })
        break
      case 'repay':
        writeAction({
          address: CONTRACT_ADDRESSES.POOL,
          abi: PoolABI,
          functionName: 'repay',
          args: [tokenAddress, parsedAmount, INTEREST_RATE_MODE.VARIABLE, address],
        })
        break
    }
  }

  if (!isApprovedUser) {
    return (
      <div className="card">
        <div className="flex flex-col items-center justify-center py-12">
          <div className="w-16 h-16 mb-4 rounded-full bg-yellow-500/10 flex items-center justify-center">
            <span className="text-3xl">👤</span>
          </div>
          <h3 className="text-xl font-semibold mb-2">Approval Required</h3>
          <p className="text-gray-400 text-center max-w-md">
            You need to be an Approved User to use this lending system.
            Contact your bank administrator to get approved.
          </p>
        </div>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      {/* Permission Warning Alert */}
      {showPermissionWarning && (
        <div className="p-4 rounded-xl bg-red-500/10 border border-red-500/30 animate-in">
          <div className="flex items-start justify-between gap-3">
            <div className="flex items-start gap-3">
              <div className="w-10 h-10 rounded-full bg-red-500/20 flex items-center justify-center flex-shrink-0">
                <span className="text-xl">⚠️</span>
              </div>
              <div>
                <div className="font-semibold text-red-400 mb-1">权限不足</div>
                <div className="text-sm text-gray-400">
                  该地址没有权限进行 {action === 'supply' ? 'supply' : action === 'withdraw' ? 'withdraw' : action === 'borrow' ? 'borrow' : 'repay'} 操作。请联系管理员获取 Approved User 权限。
                </div>
              </div>
            </div>
            <button
              onClick={() => setShowPermissionWarning(false)}
              className="text-gray-500 hover:text-white transition-colors"
            >
              ✕
            </button>
          </div>
        </div>
      )}

      {/* Account Overview */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="card">
          <div className="text-sm text-gray-400 mb-1">Total Collateral</div>
          <div className="text-2xl font-semibold gradient-text">
            ${accountData?.totalCollateralBase ?? '0'}
          </div>
        </div>
        <div className="card">
          <div className="text-sm text-gray-400 mb-1">Total Debt</div>
          <div className="text-2xl font-semibold text-red-400">
            ${accountData?.totalDebtBase ?? '0'}
          </div>
        </div>
        <div className="card">
          <div className="text-sm text-gray-400 mb-1">Available to Borrow</div>
          <div className="text-2xl font-semibold text-aave-green">
            ${accountData?.availableBorrowsBase ?? '0'}
          </div>
        </div>
        <div className="card">
          <div className="text-sm text-gray-400 mb-1">Health Factor</div>
          <div className={`text-2xl font-semibold ${
            accountData?.healthFactor === '∞' ? 'text-aave-green' :
            parseFloat(accountData?.healthFactor ?? '0') > 1.5 ? 'text-aave-green' :
            parseFloat(accountData?.healthFactor ?? '0') > 1 ? 'text-yellow-400' : 'text-red-400'
          }`}>
            {accountData?.healthFactor ?? '∞'}
          </div>
        </div>
      </div>

      {/* Main Action Card */}
      <div className="card">
        <h2 className="text-xl font-display font-semibold mb-2">Lending Operations</h2>
        <p className="text-gray-400 text-sm mb-6">
          Supply collateral, borrow assets, repay loans, or withdraw your funds.
        </p>

        {/* Action Toggle */}
        <div className="grid grid-cols-4 gap-1 p-1 bg-white/5 rounded-lg mb-6">
          {(['supply', 'withdraw', 'borrow', 'repay'] as ActionType[]).map((a) => (
            <button
              key={a}
              onClick={() => setAction(a)}
              className={`py-2 rounded-md font-medium text-sm transition-all capitalize ${
                action === a
                  ? a === 'supply' || a === 'repay'
                    ? 'bg-aave-green text-white'
                    : 'bg-aave-purple text-white'
                  : 'text-gray-400 hover:text-white'
              }`}
            >
              {a}
            </button>
          ))}
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
            Wallet Balance: {parseFloat(formattedBalance).toLocaleString()} {TOKEN_CONFIG[selectedToken].symbol}
          </div>
        </div>

        {/* Action Info */}
        <div className="p-4 rounded-lg bg-white/5 border border-white/10 mb-6">
          <div className="text-sm text-gray-400">
            {action === 'supply' && '📥 Supplying collateral will enable you to borrow other assets.'}
            {action === 'withdraw' && '📤 Withdrawing will reduce your collateral and borrowing power.'}
            {action === 'borrow' && '💸 Borrowing will create debt that accrues interest over time.'}
            {action === 'repay' && '✅ Repaying will reduce your debt and improve your health factor.'}
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
              `${action.charAt(0).toUpperCase() + action.slice(1)} ${TOKEN_CONFIG[selectedToken].symbol}`
            )}
          </button>
        </div>

        {/* Status Messages */}
        {actionSuccess && (
          <div className="mt-4 p-4 rounded-lg bg-aave-green/10 border border-aave-green/30 text-aave-green">
            <div className="flex items-center gap-2">
              <span className="text-xl">✓</span>
              <span>{action.charAt(0).toUpperCase() + action.slice(1)} successful!</span>
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
            
            {/* Helpful suggestions based on error */}
            <div className="mt-3 pt-3 border-t border-red-500/20">
              <div className="text-xs text-gray-500">
                💡 <strong>Suggestions:</strong>
                <ul className="mt-1 ml-4 list-disc space-y-1">
                  <li>Check if you have sufficient token balance</li>
                  <li>Ensure the token is approved for the Pool contract</li>
                  <li>Verify you have the required role (Approved User)</li>
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
