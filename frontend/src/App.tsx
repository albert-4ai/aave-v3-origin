import { useState } from 'react'
import { useAccount } from 'wagmi'
import { ConnectButton } from '@rainbow-me/rainbowkit'
import AdminPanel from './components/AdminPanel'
import BankSupply from './components/BankSupply'
import UserLending from './components/UserLending'
import { useACLRoles } from './hooks/useACLRoles'

type TabType = 'admin' | 'bank' | 'user'

function App() {
  const [activeTab, setActiveTab] = useState<TabType>('user')
  const { isConnected, address } = useAccount()
  const { isPoolAdmin, isLiquidityAdmin, isApprovedUser } = useACLRoles(address)

  const tabs = [
    { id: 'user' as const, label: 'User Lending', icon: '💰' },
    { id: 'bank' as const, label: 'Bank Supply', icon: '🏦' },
    { id: 'admin' as const, label: 'Admin Panel', icon: '⚙️' },
  ]

  return (
    <div className="min-h-screen">
      {/* Header */}
      <header className="border-b border-white/5 backdrop-blur-md bg-aave-dark/50 sticky top-0 z-50">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between h-16">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-aave-purple to-aave-teal flex items-center justify-center">
                <span className="text-white font-bold text-lg">A</span>
              </div>
              <div>
                <h1 className="font-display text-xl font-semibold gradient-text">
                  Aave Bank Lending
                </h1>
                <p className="text-xs text-gray-500">Private Lending System</p>
              </div>
            </div>
            
            <div className="flex items-center gap-4">
              {isConnected && (
                <div className="flex items-center gap-2 text-xs">
                  {isPoolAdmin && (
                    <span className="status-success">Pool Admin</span>
                  )}
                  {isLiquidityAdmin && (
                    <span className="status-success">Liquidity Admin</span>
                  )}
                  {isApprovedUser && (
                    <span className="status-success">Approved User</span>
                  )}
                </div>
              )}
              <ConnectButton 
                showBalance={false}
                chainStatus="icon"
                accountStatus="address"
              />
            </div>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {!isConnected ? (
          <div className="flex flex-col items-center justify-center min-h-[60vh] animate-in">
            <div className="card max-w-md w-full text-center">
              <div className="w-20 h-20 mx-auto mb-6 rounded-2xl bg-gradient-to-br from-aave-purple/20 to-aave-teal/20 flex items-center justify-center animate-float">
                <span className="text-4xl">🔐</span>
              </div>
              <h2 className="font-display text-2xl font-semibold mb-3">
                Connect Your Wallet
              </h2>
              <p className="text-gray-400 mb-6">
                Connect your wallet to access the Aave Bank Lending System. 
                Manage your assets, supply liquidity, or borrow funds.
              </p>
              <div className="flex justify-center">
                <ConnectButton />
              </div>
            </div>
          </div>
        ) : (
          <div className="space-y-6 animate-in">
            {/* Tab Navigation */}
            <div className="flex gap-1 p-1 bg-white/5 rounded-xl w-fit">
              {tabs.map((tab) => (
                <button
                  key={tab.id}
                  onClick={() => setActiveTab(tab.id)}
                  className={`flex items-center gap-2 px-5 py-2.5 rounded-lg font-medium transition-all duration-300 ${
                    activeTab === tab.id
                      ? 'bg-gradient-to-r from-aave-purple to-aave-teal text-white shadow-lg'
                      : 'text-gray-400 hover:text-white hover:bg-white/5'
                  }`}
                >
                  <span>{tab.icon}</span>
                  <span>{tab.label}</span>
                </button>
              ))}
            </div>

            {/* Tab Content */}
            <div className="animate-in">
              {activeTab === 'admin' && <AdminPanel />}
              {activeTab === 'bank' && <BankSupply />}
              {activeTab === 'user' && <UserLending />}
            </div>
          </div>
        )}
      </main>

      {/* Footer */}
      <footer className="border-t border-white/5 mt-auto py-6">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <p className="text-center text-gray-500 text-sm">
            Built on Aave V3 Protocol • Local Development Environment
          </p>
        </div>
      </footer>
    </div>
  )
}

export default App

