import { useState } from 'react'
import { useAccount, useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { isAddress } from 'viem'
import { ACLManagerABI } from '../abi'
import { CONTRACT_ADDRESSES } from '../config'
import { useACLRoles } from '../hooks'

type RoleType = 'liquidityAdmin' | 'approvedUser'

const roleConfig = {
  liquidityAdmin: {
    label: 'Liquidity Admin',
    description: 'Can supply and withdraw liquidity on behalf of the bank',
    addFunction: 'addLiquidityAdmin' as const,
    removeFunction: 'removeLiquidityAdmin' as const,
  },
  approvedUser: {
    label: 'Approved User',
    description: 'Can borrow and use the lending protocol',
    addFunction: 'addApprovedUser' as const,
    removeFunction: 'removeApprovedUser' as const,
  },
}

export default function AdminPanel() {
  const { address } = useAccount()
  const { isPoolAdmin } = useACLRoles(address)
  const [targetAddress, setTargetAddress] = useState('')
  const [selectedRole, setSelectedRole] = useState<RoleType>('approvedUser')
  const [action, setAction] = useState<'grant' | 'revoke'>('grant')

  const { data: hash, writeContract, isPending, error: writeError } = useWriteContract()
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash })

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    if (!isAddress(targetAddress)) {
      alert('Please enter a valid address')
      return
    }

    const config = roleConfig[selectedRole]
    const functionName = action === 'grant' ? config.addFunction : config.removeFunction

    writeContract({
      address: CONTRACT_ADDRESSES.ACL_MANAGER,
      abi: ACLManagerABI,
      functionName,
      args: [targetAddress as `0x${string}`],
    })
  }

  if (!isPoolAdmin) {
    return (
      <div className="card">
        <div className="flex flex-col items-center justify-center py-12">
          <div className="w-16 h-16 mb-4 rounded-full bg-red-500/10 flex items-center justify-center">
            <span className="text-3xl">🔒</span>
          </div>
          <h3 className="text-xl font-semibold mb-2">Access Denied</h3>
          <p className="text-gray-400 text-center max-w-md">
            You need Pool Admin privileges to access this panel. 
            Contact your system administrator for access.
          </p>
        </div>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      <div className="card">
        <h2 className="text-xl font-display font-semibold mb-2">Role Management</h2>
        <p className="text-gray-400 text-sm mb-6">
          As a Pool Admin, you can grant or revoke roles to manage access to the lending system.
        </p>

        <form onSubmit={handleSubmit} className="space-y-6">
          {/* Address Input */}
          <div>
            <label className="label">Target Address</label>
            <input
              type="text"
              value={targetAddress}
              onChange={(e) => setTargetAddress(e.target.value)}
              placeholder="0x..."
              className="input-field font-mono"
            />
          </div>

          {/* Role Selection */}
          <div>
            <label className="label">Role</label>
            <div className="grid grid-cols-2 gap-3">
              {(Object.keys(roleConfig) as RoleType[]).map((role) => (
                <button
                  key={role}
                  type="button"
                  onClick={() => setSelectedRole(role)}
                  className={`p-4 rounded-lg border transition-all text-left ${
                    selectedRole === role
                      ? 'border-aave-teal bg-aave-teal/10'
                      : 'border-white/10 hover:border-white/20'
                  }`}
                >
                  <div className="font-medium mb-1">{roleConfig[role].label}</div>
                  <div className="text-xs text-gray-400">{roleConfig[role].description}</div>
                </button>
              ))}
            </div>
          </div>

          {/* Action Selection */}
          <div>
            <label className="label">Action</label>
            <div className="flex gap-3">
              <button
                type="button"
                onClick={() => setAction('grant')}
                className={`flex-1 py-3 rounded-lg border transition-all ${
                  action === 'grant'
                    ? 'border-aave-green bg-aave-green/10 text-aave-green'
                    : 'border-white/10 text-gray-400 hover:border-white/20'
                }`}
              >
                ✓ Grant Role
              </button>
              <button
                type="button"
                onClick={() => setAction('revoke')}
                className={`flex-1 py-3 rounded-lg border transition-all ${
                  action === 'revoke'
                    ? 'border-red-500 bg-red-500/10 text-red-400'
                    : 'border-white/10 text-gray-400 hover:border-white/20'
                }`}
              >
                ✗ Revoke Role
              </button>
            </div>
          </div>

          {/* Submit Button */}
          <button
            type="submit"
            disabled={isPending || isConfirming || !targetAddress}
            className={action === 'grant' ? 'btn-primary w-full' : 'btn-danger w-full'}
          >
            {isPending || isConfirming ? (
              <span className="flex items-center justify-center gap-2">
                <svg className="animate-spin h-5 w-5" viewBox="0 0 24 24">
                  <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" fill="none" />
                  <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
                </svg>
                {isPending ? 'Confirming...' : 'Processing...'}
              </span>
            ) : (
              `${action === 'grant' ? 'Grant' : 'Revoke'} ${roleConfig[selectedRole].label}`
            )}
          </button>

          {/* Status Messages */}
          {isSuccess && (
            <div className="p-4 rounded-lg bg-aave-green/10 border border-aave-green/30 text-aave-green">
              ✓ Transaction successful! Role has been {action === 'grant' ? 'granted' : 'revoked'}.
            </div>
          )}
          {writeError && (
            <div className="p-4 rounded-lg bg-red-500/10 border border-red-500/30 text-red-400">
              ✗ Error: {writeError.message}
            </div>
          )}
        </form>
      </div>

      {/* Role Check Card */}
      <RoleCheckCard />
    </div>
  )
}

function RoleCheckCard() {
  const [checkAddress, setCheckAddress] = useState('')
  const { isPoolAdmin, isLiquidityAdmin, isApprovedUser, refetch } = useACLRoles(
    isAddress(checkAddress) ? checkAddress as `0x${string}` : undefined
  )

  return (
    <div className="card">
      <h3 className="text-lg font-semibold mb-4">Check User Roles</h3>
      <div className="flex gap-3 mb-4">
        <input
          type="text"
          value={checkAddress}
          onChange={(e) => setCheckAddress(e.target.value)}
          placeholder="Enter address to check..."
          className="input-field flex-1 font-mono text-sm"
        />
        <button
          onClick={() => refetch()}
          className="btn-secondary"
          disabled={!isAddress(checkAddress)}
        >
          Check
        </button>
      </div>

      {isAddress(checkAddress) && (
        <div className="grid grid-cols-3 gap-3">
          <div className={`p-3 rounded-lg border ${isPoolAdmin ? 'border-aave-green/50 bg-aave-green/10' : 'border-white/5 bg-white/5'}`}>
            <div className="text-xs text-gray-400 mb-1">Pool Admin</div>
            <div className={isPoolAdmin ? 'text-aave-green' : 'text-gray-500'}>{isPoolAdmin ? '✓ Yes' : '✗ No'}</div>
          </div>
          <div className={`p-3 rounded-lg border ${isLiquidityAdmin ? 'border-aave-green/50 bg-aave-green/10' : 'border-white/5 bg-white/5'}`}>
            <div className="text-xs text-gray-400 mb-1">Liquidity Admin</div>
            <div className={isLiquidityAdmin ? 'text-aave-green' : 'text-gray-500'}>{isLiquidityAdmin ? '✓ Yes' : '✗ No'}</div>
          </div>
          <div className={`p-3 rounded-lg border ${isApprovedUser ? 'border-aave-green/50 bg-aave-green/10' : 'border-white/5 bg-white/5'}`}>
            <div className="text-xs text-gray-400 mb-1">Approved User</div>
            <div className={isApprovedUser ? 'text-aave-green' : 'text-gray-500'}>{isApprovedUser ? '✓ Yes' : '✗ No'}</div>
          </div>
        </div>
      )}
    </div>
  )
}

