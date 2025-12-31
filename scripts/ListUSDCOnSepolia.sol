// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Script, console} from 'forge-std/Script.sol';
import {IPool} from '../src/contracts/interfaces/IPool.sol';
import {IERC20Detailed} from '../src/contracts/dependencies/openzeppelin/contracts/IERC20Detailed.sol';
import {AaveV3Payload} from '../src/contracts/extensions/v3-config-engine/AaveV3Payload.sol';
import {IAaveV3ConfigEngine as IEngine} from '../src/contracts/extensions/v3-config-engine/IAaveV3ConfigEngine.sol';
import {EngineFlags} from '../src/contracts/extensions/v3-config-engine/EngineFlags.sol';
import {MockAggregator} from '../src/contracts/mocks/oracle/CLAggregators/MockAggregator.sol';
import {ACLManager} from '../src/contracts/protocol/configuration/ACLManager.sol';
import {IPoolAddressesProvider} from '../src/contracts/interfaces/IPoolAddressesProvider.sol';

/**
 * @title USDCListingPayload
 * @notice Payload contract to list USDC in the Aave pool on Sepolia
 */
contract USDCListingPayload is AaveV3Payload {
  address public immutable USDC_ADDRESS;
  address public immutable USDC_PRICE_FEED;

  constructor(IEngine engine, address usdcAddress, address usdcPriceFeed) AaveV3Payload(engine) {
    USDC_ADDRESS = usdcAddress;
    USDC_PRICE_FEED = usdcPriceFeed;
  }

  function newListings() public view override returns (IEngine.Listing[] memory) {
    IEngine.Listing[] memory listings = new IEngine.Listing[](1);

    listings[0] = IEngine.Listing({
      asset: USDC_ADDRESS,
      assetSymbol: 'USDC',
      priceFeed: USDC_PRICE_FEED,
      rateStrategyParams: IEngine.InterestRateInputData({
        optimalUsageRatio: 80_00, // 80% optimal usage
        baseVariableBorrowRate: 0, // 0% base rate
        variableRateSlope1: 4_00, // 4% slope 1
        variableRateSlope2: 60_00 // 60% slope 2
      }),
      enabledToBorrow: EngineFlags.ENABLED,
      borrowableInIsolation: EngineFlags.DISABLED,
      withSiloedBorrowing: EngineFlags.DISABLED,
      flashloanable: EngineFlags.ENABLED,
      ltv: 82_50, // 82.5% Loan-to-Value
      liqThreshold: 86_00, // 86% Liquidation Threshold
      liqBonus: 5_00, // 5% Liquidation Bonus
      reserveFactor: 10_00, // 10% Reserve Factor
      supplyCap: 0, // No supply cap
      borrowCap: 0, // No borrow cap
      debtCeiling: 0, // No debt ceiling
      liqProtocolFee: 10_00 // 10% Liquidation Protocol Fee
    });

    return listings;
  }

  function getPoolContext() public pure override returns (IEngine.PoolContext memory) {
    return IEngine.PoolContext({networkName: 'Sepolia', networkAbbreviation: 'Sep'});
  }
}

/**
 * @title USDCPriceFeedUpdatePayload
 * @notice Payload contract to update USDC price feed for existing reserve on Sepolia
 */
contract USDCPriceFeedUpdatePayload is AaveV3Payload {
  address public immutable USDC_ADDRESS;
  address public immutable USDC_PRICE_FEED;

  constructor(IEngine engine, address usdcAddress, address usdcPriceFeed) AaveV3Payload(engine) {
    USDC_ADDRESS = usdcAddress;
    USDC_PRICE_FEED = usdcPriceFeed;
  }

  // Return empty listings for existing reserves (only update price feed)
  function newListings() public pure override returns (IEngine.Listing[] memory) {
    return new IEngine.Listing[](0);
  }

  // Override to only update price feeds for existing reserves
  function priceFeedsUpdates() public view override returns (IEngine.PriceFeedUpdate[] memory) {
    IEngine.PriceFeedUpdate[] memory updates = new IEngine.PriceFeedUpdate[](1);
    updates[0] = IEngine.PriceFeedUpdate({
      asset: USDC_ADDRESS,
      priceFeed: USDC_PRICE_FEED
    });
    return updates;
  }

  function getPoolContext() public pure override returns (IEngine.PoolContext memory) {
    return IEngine.PoolContext({networkName: 'Sepolia', networkAbbreviation: 'Sep'});
  }
}

/**
 * @title ListUSDCOnSepolia
 * @notice Complete script to list USDC token in Aave Pool on Sepolia testnet
 * @dev This script performs all steps in one transaction:
 *   1. Performs basic contract validation tests
 *   2. Checks if USDC is already listed in the pool
 *   3. Deploys a mock price feed for USDC ($1.00)
 *   4. Creates and executes a payload to list USDC in the Aave pool
 *   5. Cleans up temporary permissions
 *
 * @notice Prerequisites:
 *   - POOL_ADDRESSES_PROVIDER environment variable must be set
 *   - CONFIG_ENGINE environment variable must be set
 *   - POOL_ADDRESS environment variable (optional, will be derived if not set)
 *   - USDC_ADDRESS environment variable (optional, defaults to Circle USDC: 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238)
 *   - Deployer must have DEFAULT_ADMIN_ROLE in ACLManager (typically ACL_ADMIN)
 */
contract ListUSDCOnSepolia is Script {
  // Circle USDC address on Sepolia
  address constant SEPOLIA_USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;

  // USDC price: $1 (in 8 decimals, Chainlink format)
  int256 constant USDC_PRICE = 1e8;

  /**
   * @notice Perform basic contract validation tests
   * @param poolAddress The address of the Pool contract
   * @param usdcAddress The address of USDC token
   * @return true if all tests pass, false otherwise
   */
  function testBasicConnection(address poolAddress, address usdcAddress) internal view returns (bool) {
    // Test 1: Try to call USDC methods to verify contract exists
    try IERC20Detailed(usdcAddress).symbol() returns (string memory) {
      uint8 decimals = IERC20Detailed(usdcAddress).decimals();
      if (decimals != 6) return false;
    } catch {
      return false;
    }

    // Test 2: Try to call pool.getReservesList()
    try IPool(poolAddress).getReservesList() returns (address[] memory) {
      // Just verify we can call it
    } catch {
      return false;
    }

    return true;
  }

  /**
   * @notice Check if USDC is already listed in the pool
   * @param poolAddress The address of the Pool contract
   * @param usdcAddress The address of USDC token
   * @return true if USDC is already listed, false otherwise
   */
  function isUSDCListed(address poolAddress, address usdcAddress) internal view returns (bool) {
    try IPool(poolAddress).getReservesList() returns (address[] memory reserves) {
      for (uint256 i = 0; i < reserves.length; i++) {
        if (reserves[i] == usdcAddress) {
          return true;
        }
      }
      return false;
    } catch {
      return false;
    }
  }

  function run() external {
    // Get required addresses from environment
    address poolAddressesProvider;
    address configEngine;
    address usdcAddress;
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

    try vm.envAddress('POOL_ADDRESS') returns (address envPool) {
      poolAddress = envPool;
    } catch {
      IPoolAddressesProvider provider = IPoolAddressesProvider(poolAddressesProvider);
      poolAddress = provider.getPool();
    }

    // Get USDC address (use environment variable or default to Sepolia USDC)
    try vm.envAddress('USDC_ADDRESS') returns (address envUsdc) {
      usdcAddress = envUsdc;
    } catch {
      usdcAddress = SEPOLIA_USDC;
    }

    // Perform basic contract validation tests
    bool validationTestsPassed = testBasicConnection(poolAddress, usdcAddress);
    if (!validationTestsPassed) {
      revert('Contract validation failed');
    }

    // Check if USDC is already listed
    bool isListed = isUSDCListed(poolAddress, usdcAddress);

    // Get ACL Manager
    IPoolAddressesProvider addressesProvider = IPoolAddressesProvider(poolAddressesProvider);
    ACLManager aclManager = ACLManager(address(addressesProvider.getACLManager()));

    vm.startBroadcast();

    // Step 1: Deploy mock price feed for USDC ($1.00)
    console.log("Step 1: Deploying MockAggregator price feed...");
    MockAggregator usdcPriceFeed = new MockAggregator(USDC_PRICE);
    console.log("Price feed deployed at:", address(usdcPriceFeed));

    // Step 2: Deploy appropriate payload contract based on whether USDC is already listed
    AaveV3Payload payload;
    if (isListed) {
      console.log("USDC is already listed in the pool - deploying price feed update payload");
      console.log("Step 2: Deploying USDCPriceFeedUpdatePayload...");
      payload = new USDCPriceFeedUpdatePayload(
        IEngine(configEngine),
        usdcAddress,
        address(usdcPriceFeed)
      );
    } else {
      console.log("USDC not listed - performing full registration");
      console.log("Step 2: Deploying USDCListingPayload...");
      payload = new USDCListingPayload(
        IEngine(configEngine),
        usdcAddress,
        address(usdcPriceFeed)
      );
    }
    console.log("Payload deployed at:", address(payload));

    // Step 3: Grant POOL_ADMIN_ROLE to the payload contract
    console.log("Step 3: Granting POOL_ADMIN_ROLE to payload...");
    aclManager.addPoolAdmin(address(payload));
    console.log("POOL_ADMIN_ROLE granted");

    // Step 4: Execute the payload
    console.log("Step 4: Executing payload...");
    payload.execute();
    console.log("Payload executed successfully!");

    // Step 5: Revoke POOL_ADMIN_ROLE from payload after execution (cleanup)
    console.log("Step 5: Revoking POOL_ADMIN_ROLE from payload...");
    aclManager.removePoolAdmin(address(payload));
    console.log("POOL_ADMIN_ROLE revoked");

    vm.stopBroadcast();

    console.log("");
    console.log("=== USDC LISTING COMPLETE ===");
    console.log("USDC Address:", usdcAddress);
    console.log("Price Feed:", address(usdcPriceFeed));
    console.log("Payload:", address(payload));
  }
}
