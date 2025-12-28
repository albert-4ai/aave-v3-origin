import { useReadContracts } from 'wagmi'
import { ACLManagerABI } from '../abi'
import { CONTRACT_ADDRESSES } from '../config'
import { Address } from 'viem'

export function useACLRoles(address: Address | undefined) {
  const { data, isLoading, error, refetch } = useReadContracts({
    contracts: [
      {
        address: CONTRACT_ADDRESSES.ACL_MANAGER,
        abi: ACLManagerABI,
        functionName: 'isPoolAdmin',
        args: address ? [address] : undefined,
      },
      {
        address: CONTRACT_ADDRESSES.ACL_MANAGER,
        abi: ACLManagerABI,
        functionName: 'isLiquidityAdmin',
        args: address ? [address] : undefined,
      },
      {
        address: CONTRACT_ADDRESSES.ACL_MANAGER,
        abi: ACLManagerABI,
        functionName: 'isApprovedUser',
        args: address ? [address] : undefined,
      },
    ],
    query: {
      enabled: !!address && CONTRACT_ADDRESSES.ACL_MANAGER !== '0x0000000000000000000000000000000000000000',
    },
  })

  return {
    isPoolAdmin: data?.[0]?.result ?? false,
    isLiquidityAdmin: data?.[1]?.result ?? false,
    isApprovedUser: data?.[2]?.result ?? false,
    isLoading,
    error,
    refetch,
  }
}

