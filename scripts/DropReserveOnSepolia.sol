// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Script, console} from 'forge-std/Script.sol';
import {IPoolConfigurator} from '../src/contracts/interfaces/IPoolConfigurator.sol';
import {IPool} from '../src/contracts/interfaces/IPool.sol';
import {IERC20} from '../src/contracts/dependencies/openzeppelin/contracts/IERC20.sol';
import {ACLManager} from '../src/contracts/protocol/configuration/ACLManager.sol';
import {IPoolAddressesProvider} from '../src/contracts/interfaces/IPoolAddressesProvider.sol';
import {DataTypes} from '../src/contracts/protocol/libraries/types/DataTypes.sol';

/**
 * @title DropReservePayload
 * @notice Payload contract to drop/remove a reserve from the Aave pool on Sepolia
 */
contract DropReservePayload {
  address public immutable POOL_CONFIGURATOR;
  address public immutable POOL;
  address public immutable ASSET_TO_DROP;

  constructor(address poolConfigurator, address pool, address assetToDrop) {
    POOL_CONFIGURATOR = poolConfigurator;
    POOL = pool;
    ASSET_TO_DROP = assetToDrop;
  }

  function execute() external {
    console.log("Dropping reserve:", ASSET_TO_DROP);

    // Get reserve data before dropping
    DataTypes.ReserveDataLegacy memory reserveData = IPool(POOL).getReserveData(ASSET_TO_DROP);
    address aTokenAddress = reserveData.aTokenAddress;
    address variableDebtTokenAddress = reserveData.variableDebtTokenAddress;

    // Check conditions before dropping
    if (aTokenAddress != address(0)) {
      uint256 aTokenSupply = IERC20(aTokenAddress).totalSupply();
      console.log("aToken supply:", aTokenSupply);
      require(aTokenSupply == 0, "Cannot drop reserve with outstanding aTokens");
    }

    if (variableDebtTokenAddress != address(0)) {
      uint256 debtSupply = IERC20(variableDebtTokenAddress).totalSupply();
      console.log("Variable debt supply:", debtSupply);
      require(debtSupply == 0, "Cannot drop reserve with outstanding variable debt");
    }

    // Execute drop reserve
    IPoolConfigurator(POOL_CONFIGURATOR).dropReserve(ASSET_TO_DROP);
    console.log("Reserve dropped successfully!");
  }
}

/**
 * @title DropReserveOnSepolia
 * @notice Complete script to drop/remove a reserve from Aave Pool on Sepolia testnet
 * @dev This script performs comprehensive validation before dropping a reserve:
 *   1. Performs basic contract validation tests
 *   2. Checks if the asset is currently listed in the pool
 *   3. Validates that no users have outstanding positions (aTokens or variable debt)
 *   4. Checks that treasury has no accrued interest for this reserve
 *   5. Creates and executes a payload to drop the reserve
 *   6. Cleans up temporary permissions
 *
 * @notice Prerequisites:
 *   - POOL_ADDRESSES_PROVIDER environment variable must be set
 *   - CONFIG_ENGINE environment variable must be set
 *   - POOL_ADDRESS environment variable (optional, will be derived if not set)
 *   - ASSET_ADDRESS environment variable must be set (the asset to drop)
 *   - Deployer must have DEFAULT_ADMIN_ROLE in ACLManager (typically ACL_ADMIN)
 *
 * @notice Safety Requirements:
 *   - The asset must have no outstanding aTokens
 *   - The asset must have no outstanding variable debt
 *   - The asset must have no accrued interest in treasury
 *   - The asset must currently be listed in the pool
 */
contract DropReserveOnSepolia is Script {
  /**
   * @notice Perform basic contract validation tests
   * @param poolAddress The address of the Pool contract
   * @param assetAddress The address of the asset to drop
   * @return true if all tests pass, false otherwise
   */
  function testBasicConnection(address poolAddress, address assetAddress) internal view returns (bool) {
    // Test 1: Try to call pool.getReserveData()
    try IPool(poolAddress).getReserveData(assetAddress) returns (DataTypes.ReserveDataLegacy memory) {
      // Just verify we can call it
    } catch {
      return false;
    }

    return true;
  }

  /**
   * @notice Check if asset is currently listed in the pool
   * @param poolAddress The address of the Pool contract
   * @param assetAddress The address of the asset to check
   * @return true if asset is listed, false otherwise
   */
  function isAssetListed(address poolAddress, address assetAddress) internal view returns (bool) {
    try IPool(poolAddress).getReservesList() returns (address[] memory reserves) {
      for (uint256 i = 0; i < reserves.length; i++) {
        if (reserves[i] == assetAddress) {
          return true;
        }
      }
      return false;
    } catch {
      return false;
    }
  }

  /**
   * @notice Validate that the reserve can be safely dropped
   * @param poolAddress The address of the Pool contract
   * @param assetAddress The address of the asset to validate
   * @return true if the reserve can be dropped, false otherwise
   */
  function canDropReserve(address poolAddress, address assetAddress) internal view returns (bool) {
    IPool pool = IPool(poolAddress);

    DataTypes.ReserveDataLegacy memory reserveData = pool.getReserveData(assetAddress);
    address aTokenAddress = reserveData.aTokenAddress;
    address variableDebtTokenAddress = reserveData.variableDebtTokenAddress;

    console.log("Reserve Data:");
    console.log("  aToken Address:", aTokenAddress);
    console.log("  Variable Debt Token Address:", variableDebtTokenAddress);
    console.log("");

    bool canDrop = true;

    // Check aToken supply
    if (aTokenAddress != address(0)) {
      uint256 aTokenSupply = IERC20(aTokenAddress).totalSupply();
      console.log("aToken Total Supply:", aTokenSupply);
      if (aTokenSupply > 0) {
        console.log("ERROR: Cannot drop reserve - aToken supply is not zero!");
        canDrop = false;
      }
    }

    // Check variable debt supply
    if (variableDebtTokenAddress != address(0)) {
      uint256 debtSupply = IERC20(variableDebtTokenAddress).totalSupply();
      console.log("Variable Debt Total Supply:", debtSupply);
      if (debtSupply > 0) {
        console.log("ERROR: Cannot drop reserve - variable debt supply is not zero!");
        canDrop = false;
      }
    }

    // Check accrued to treasury (from CheckReserveCanDrop logic)
    if (reserveData.accruedToTreasury > 0) {
      console.log("Accrued to Treasury:", uint256(reserveData.accruedToTreasury));
      console.log("WARNING: Treasury has accrued interest - cannot drop reserve");
      canDrop = false;
    }

    return canDrop;
  }

  function run() external {
    // Get required addresses from environment
    address poolAddressesProvider;
    address configEngine;
    address assetAddress;
    address poolAddress;

    try vm.envAddress('POOL_ADDRESSES_PROVIDER') returns (address envProvider) {
      poolAddressesProvider = envProvider;
    } catch {
      revert('POOL_ADDRESSES_PROVIDER required');
    }

    try vm.envAddress('CONFIG_ENGINE') returns (address envEngine) {
      configEngine = envEngine;
    } catch {
      revert('CONFIG_ENGINE required');
    }

    try vm.envAddress('ASSET_ADDRESS') returns (address envAsset) {
      assetAddress = envAsset;
    } catch {
      revert('ASSET_ADDRESS required (asset to drop)');
    }

    try vm.envAddress('POOL_ADDRESS') returns (address envPool) {
      poolAddress = envPool;
    } catch {
      IPoolAddressesProvider provider = IPoolAddressesProvider(poolAddressesProvider);
      poolAddress = provider.getPool();
    }

    console.log("Asset to drop:", assetAddress);
    console.log("Pool address:", poolAddress);

    // Perform basic contract validation tests
    bool validationTestsPassed = testBasicConnection(poolAddress, assetAddress);
    if (!validationTestsPassed) {
      revert('Contract validation failed');
    }

    // Check if asset is listed
    bool isListed = isAssetListed(poolAddress, assetAddress);
    if (!isListed) {
      revert('Asset is not currently listed in the pool');
    }

    console.log("Asset is currently listed in the pool");

    // Validate that the reserve can be safely dropped
    bool canDrop = canDropReserve(poolAddress, assetAddress);
    if (!canDrop) {
      revert('Cannot drop reserve: safety conditions not met');
    }

    console.log("Reserve can be safely dropped (no outstanding positions)");

    // Get ACL Manager
    IPoolAddressesProvider addressesProvider = IPoolAddressesProvider(poolAddressesProvider);
    ACLManager aclManager = ACLManager(address(addressesProvider.getACLManager()));

    vm.startBroadcast();

    // Get pool configurator address
    address poolConfiguratorAddress = addressesProvider.getPoolConfigurator();

    // Step 1: Deploy payload contract
    console.log("Step 1: Deploying DropReservePayload...");
    DropReservePayload payload = new DropReservePayload(
      poolConfiguratorAddress,
      poolAddress,
      assetAddress
    );
    console.log("Payload deployed at:", address(payload));

    // Step 2: Grant POOL_ADMIN_ROLE to the payload contract
    console.log("Step 2: Granting POOL_ADMIN_ROLE to payload...");
    aclManager.addPoolAdmin(address(payload));
    console.log("POOL_ADMIN_ROLE granted");

    // Step 3: Execute the payload
    console.log("Step 3: Executing payload...");
    payload.execute();
    console.log("Payload executed successfully!");

    // Step 4: Revoke POOL_ADMIN_ROLE from payload after execution (cleanup)
    console.log("Step 4: Revoking POOL_ADMIN_ROLE from payload...");
    aclManager.removePoolAdmin(address(payload));
    console.log("POOL_ADMIN_ROLE revoked");

    vm.stopBroadcast();

    console.log("");
    console.log("=== RESERVE DROP COMPLETE ===");
    console.log("Dropped asset:", assetAddress);
    console.log("Payload:", address(payload));

    // Verify the reserve was dropped
    bool stillListed = isAssetListed(poolAddress, assetAddress);
    if (!stillListed) {
      console.log("Verification: Asset successfully removed from pool");
    } else {
      console.log("Warning: Asset may still be listed (check manually)");
    }
  }
}

