import { useState, useEffect } from 'react'
import { useAccount, useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { parseUnits } from 'viem'
import { PoolABI, ERC20ABI } from '../abi'
import { CONTRACT_ADDRESSES, TOKEN_CONFIG, REFERRAL_CODE, INTEREST_RATE_MODE, MAX_UINT256 } from '../config'
import { useACLRoles, useTokenBalance, useTokenAllowance, useUserAccountData } from '../hooks'

type ActionType = 'supply' | 'withdraw' | 'borrow' | 'repay'

export default function UserLending() {
  const { address } = useAccount()
  const { isApprovedUser } = useACLRoles(address)
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
  const { data: accountData, refetch: refetchAccountData } = useUserAccountData(address)

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
      refetchAccountData()
    }
  }, [approveSuccess, actionSuccess, refetchBalance, refetchAllowance, refetchAccountData])

  const parsedAmount = amount ? parseUnits(amount, decimals) : 0n
  const needsApproval = (action === 'supply' || action === 'repay') && parsedAmount > allowance

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
            ✓ {action.charAt(0).toUpperCase() + action.slice(1)} successful!
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

