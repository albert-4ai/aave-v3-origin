// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Script, console} from 'forge-std/Script.sol';
import {IPool} from '../src/contracts/interfaces/IPool.sol';
import {IERC20} from '../src/contracts/dependencies/openzeppelin/contracts/IERC20.sol';
import {DataTypes} from '../src/contracts/protocol/libraries/types/DataTypes.sol';

/**
 * @title CheckReserveCanDrop
 * @notice Script to check if a reserve can be safely dropped
 */
contract CheckReserveCanDrop is Script {
  function run() external view {
    // Get required addresses from environment
    address poolAddress;
    address assetAddress;

    try vm.envAddress('POOL_ADDRESS') returns (address envPool) {
      poolAddress = envPool;
    } catch {
      revert('POOL_ADDRESS required');
    }

    try vm.envAddress('ASSET_ADDRESS') returns (address envAsset) {
      assetAddress = envAsset;
    } catch {
      revert('ASSET_ADDRESS required');
    }

    console.log("Pool Address:", poolAddress);
    console.log("Asset Address:", assetAddress);
    console.log("");

    // Get reserve data
    IPool pool = IPool(poolAddress);
    DataTypes.ReserveDataLegacy memory reserveData = pool.getReserveData(assetAddress);

    console.log("Reserve Data:");
    console.log("  aToken Address:", reserveData.aTokenAddress);
    console.log("  Variable Debt Token Address:", reserveData.variableDebtTokenAddress);
    console.log("");

    // Check aToken supply
    bool canDrop = true;
    if (reserveData.aTokenAddress != address(0)) {
      uint256 aTokenSupply = IERC20(reserveData.aTokenAddress).totalSupply();
      console.log("aToken Total Supply:", aTokenSupply);
      if (aTokenSupply > 0) {
        console.log("ERROR: Cannot drop reserve - aToken supply is not zero!");
        canDrop = false;
      }
    }

    // Check variable debt supply
    if (reserveData.variableDebtTokenAddress != address(0)) {
      uint256 debtSupply = IERC20(reserveData.variableDebtTokenAddress).totalSupply();
      console.log("Variable Debt Total Supply:", debtSupply);
      if (debtSupply > 0) {
        console.log("ERROR: Cannot drop reserve - variable debt supply is not zero!");
        canDrop = false;
      }
    }

    // Check accrued to treasury
    if (reserveData.accruedToTreasury > 0) {
      console.log("Accrued to Treasury:", uint256(reserveData.accruedToTreasury));
      console.log("WARNING: Treasury has accrued interest");
      canDrop = false;
    }

    console.log("");
    if (canDrop) {
      console.log("SUCCESS: Reserve can be safely dropped!");
    } else {
      console.log("FAILED: Reserve cannot be dropped - safety conditions not met");
      revert("Cannot drop reserve");
    }
  }
}
