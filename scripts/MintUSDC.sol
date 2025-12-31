// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';
import 'forge-std/console.sol';

import {TestnetERC20} from '../src/contracts/mocks/testnet-helpers/TestnetERC20.sol';
import {IPool} from '../src/contracts/interfaces/IPool.sol';
import {IERC20Detailed} from '../src/contracts/dependencies/openzeppelin/contracts/IERC20Detailed.sol';
import {AaveV3Payload} from '../src/contracts/extensions/v3-config-engine/AaveV3Payload.sol';
import {IAaveV3ConfigEngine as IEngine} from '../src/contracts/extensions/v3-config-engine/IAaveV3ConfigEngine.sol';
import {EngineFlags} from '../src/contracts/extensions/v3-config-engine/EngineFlags.sol';
import {MockAggregator} from '../src/contracts/mocks/oracle/CLAggregators/MockAggregator.sol';
import {ACLManager} from '../src/contracts/protocol/configuration/ACLManager.sol';
import {IPoolAddressesProvider} from '../src/contracts/interfaces/IPoolAddressesProvider.sol';

/**
 * @title MintUSDC
 * @notice Script to initialize USDC (if needed) and mint 10000 USDC to all Anvil default accounts
 * @dev This script:
 *   1. Finds or initializes USDC token in the pool
 *   2. Mints USDC tokens to the 10 default Anvil accounts
 */
contract MintUSDC is Script {
  // 10000 USDC (6 decimals)
  uint256 constant MINT_AMOUNT = 10_000e6;
  
  // USDC configuration
  uint8 constant USDC_DECIMALS = 6;
  int256 constant USDC_PRICE = 1e8; // $1 in 8 decimals (Chainlink format)
  
  // Anvil default accounts (10 accounts)
  function getAnvilAccounts() internal pure returns (address[10] memory) {
    return [
      0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
      0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
      0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC,
      0x90F79bf6EB2c4f870365E785982E1f101E93b906,
      0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65,
      0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc,
      0x976EA74026E726554dB657fA54763abd0C3a0aa9,
      0x14dC79964da2C08b23698B3D3cc7Ca32193d9955,
      0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f,
      0xa0eE7a142d267c1F36714E4A8f75612f20A797e8
    ];
  }

  /**
   * @notice Find USDC token address from pool reserves
   * @param poolAddress The address of the Pool contract
   * @return usdcAddress The address of USDC token, or address(0) if not found
   */
  function findUSDC(address poolAddress) internal view returns (address) {
    IPool pool = IPool(poolAddress);
    address[] memory reserves = pool.getReservesList();
    
    console.log('Total reserves:', reserves.length);
    
    for (uint256 i = 0; i < reserves.length; i++) {
      try IERC20Detailed(reserves[i]).symbol() returns (string memory symbol) {
        // Check for USDC or USDX
        if (
          keccak256(bytes(symbol)) == keccak256(bytes('USDC')) ||
          keccak256(bytes(symbol)) == keccak256(bytes('USDX'))
        ) {
          console.log('Found USDC/USDX:');
          console.log('  Address:', reserves[i]);
          console.log('  Symbol:', symbol);
          return reserves[i];
        }
      } catch {
        // Skip if symbol() fails
      }
    }
    
    console.log('USDC/USDX not found in reserves');
    return address(0);
  }

  /**
   * @notice Initialize USDC token in the pool
   * @param poolAddressesProvider The address of PoolAddressesProvider
   * @param configEngine The address of AaveV3ConfigEngine
   * @return usdcAddress The address of deployed USDC token
   */
  function initializeUSDC(
    address poolAddressesProvider,
    address configEngine
  ) internal returns (address) {
    address deployer = msg.sender;
    
    console.log('Initializing USDC in pool...');
    
    // Step 1: Deploy USDC test token
    console.log('1. Deploying USDC test token...');
    TestnetERC20 usdc = new TestnetERC20('USD Coin', 'USDC', USDC_DECIMALS, deployer);
    console.log('USDC Token deployed at:', address(usdc));
    
    // Step 2: Deploy mock price feed
    console.log('2. Deploying mock price feed...');
    MockAggregator usdcPriceFeed = new MockAggregator(USDC_PRICE);
    console.log('USDC Price Feed deployed at:', address(usdcPriceFeed));
    
    // Step 3: Deploy payload contract
    console.log('3. Deploying USDC listing payload...');
    USDCListingPayload payload = new USDCListingPayload(
      IEngine(configEngine),
      address(usdc),
      address(usdcPriceFeed)
    );
    console.log('Payload deployed at:', address(payload));
    
    // Step 4: Grant POOL_ADMIN_ROLE to payload
    IPoolAddressesProvider addressesProvider = IPoolAddressesProvider(poolAddressesProvider);
    ACLManager aclManager = ACLManager(addressesProvider.getACLManager());
    
    console.log('4. Granting POOL_ADMIN_ROLE to payload...');
    aclManager.addPoolAdmin(address(payload));
    
    // Step 5: Execute payload to list USDC
    console.log('5. Executing payload to list USDC...');
    payload.execute();
    console.log('USDC listed successfully!');
    
    // Step 6: Remove role (cleanup)
    console.log('6. Cleaning up...');
    aclManager.removePoolAdmin(address(payload));
    console.log('Role removed');
    
    return address(usdc);
  }

  function run() external {
    address usdcAddress;
    address deployer = msg.sender;
    
    console.log('=== Minting USDC to Anvil Accounts ===');
    console.log('Deployer (Owner):', deployer);
    console.log('Mint Amount per Account: 10,000 USDC');
    console.log('');
    
    // Try to get USDC address from environment first
    try vm.envAddress('USDC_ADDRESS') returns (address envUsdc) {
      usdcAddress = envUsdc;
      console.log('USDC Address from environment:', usdcAddress);
    } catch {
      // If not in environment, try to find from pool
      console.log('USDC_ADDRESS not in environment, searching in pool...');
      
      address poolAddress;
      try vm.envAddress('POOL_ADDRESS') returns (address envPool) {
        poolAddress = envPool;
      } catch {
        console.log('');
        console.log('ERROR: Missing required environment variables');
        console.log('');
        console.log('Please use one of the following methods:');
        console.log('');
        console.log('Method 1 (Recommended): Use the shell script');
        console.log('  ./deploy/scripts/mint-usdc.sh');
        console.log('');
        console.log('Method 2: Set environment variables manually');
        console.log('  export POOL_ADDRESS=0x...');
        console.log('  forge script scripts/MintUSDC.sol:MintUSDC --rpc-url http://127.0.0.1:8545 --broadcast');
        console.log('');
        console.log('Method 3: Provide USDC address directly');
        console.log('  export USDC_ADDRESS=0x...');
        console.log('  forge script scripts/MintUSDC.sol:MintUSDC --rpc-url http://127.0.0.1:8545 --broadcast');
        console.log('');
        revert('POOL_ADDRESS must be provided if USDC_ADDRESS is not set. See instructions above.');
      }
      
      console.log('Pool Address:', poolAddress);
      usdcAddress = findUSDC(poolAddress);
      
      // If not found, initialize USDC
      if (usdcAddress == address(0)) {
        console.log('');
        console.log('USDC not found in pool, initializing...');
        
        address poolAddressesProvider;
        address configEngine;
        
        try vm.envAddress('POOL_ADDRESSES_PROVIDER') returns (address envProvider) {
          poolAddressesProvider = envProvider;
        } catch {
          revert('POOL_ADDRESSES_PROVIDER must be provided to initialize USDC');
        }
        
        try vm.envAddress('CONFIG_ENGINE') returns (address envEngine) {
          configEngine = envEngine;
        } catch {
          revert('CONFIG_ENGINE must be provided to initialize USDC');
        }
        
        vm.startBroadcast();
        usdcAddress = initializeUSDC(poolAddressesProvider, configEngine);
        vm.stopBroadcast();
        
        console.log('');
        console.log('USDC initialized at:', usdcAddress);
      }
    }
    
    console.log('');
    console.log('Using USDC Address:', usdcAddress);
    console.log('');
    
    vm.startBroadcast();
    
    TestnetERC20 usdc = TestnetERC20(usdcAddress);
    
    // Verify deployer is the owner
    address owner = usdc.owner();
    require(owner == deployer, 'Deployer is not the owner of USDC token');
    console.log('Verified: Deployer is the owner');
    console.log('');
    
    console.log('Minting USDC to accounts...');
    console.log('');
    
    address[10] memory accounts = getAnvilAccounts();
    uint256 totalMinted = 0;
    
    for (uint256 i = 0; i < accounts.length; i++) {
      address account = accounts[i];
      
      // Mint USDC to account
      usdc.mint(account, MINT_AMOUNT);
      
      // Verify balance
      uint256 balance = usdc.balanceOf(account);
      require(balance >= MINT_AMOUNT, 'Mint failed');
      
      totalMinted += MINT_AMOUNT;
      
      console.log('Account %d:', i);
      console.log('  Address:', account);
      console.log('  Balance:', balance / 1e6, 'USDC');
    }
    
    vm.stopBroadcast();
    
    console.log('');
    console.log('=== Minting Complete ===');
    console.log('Total USDC Minted:', totalMinted / 1e6, 'USDC');
    console.log('Number of Accounts:', accounts.length);
    console.log('Amount per Account: 10,000 USDC');
  }
}

/**
 * @title USDCListingPayload
 * @notice Payload contract to list USDC in the Aave pool
 */
contract USDCListingPayload is AaveV3Payload {
  address public immutable USDC_ADDRESS;
  address public immutable USDC_PRICE_FEED;

  constructor(
    IEngine engine,
    address usdcAddress,
    address usdcPriceFeed
  ) AaveV3Payload(engine) {
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
        optimalUsageRatio: 80_00,
        baseVariableBorrowRate: 0,
        variableRateSlope1: 4_00,
        variableRateSlope2: 60_00
      }),
      enabledToBorrow: EngineFlags.ENABLED,
      borrowableInIsolation: EngineFlags.DISABLED,
      withSiloedBorrowing: EngineFlags.DISABLED,
      flashloanable: EngineFlags.ENABLED,
      ltv: 82_50,
      liqThreshold: 86_00,
      liqBonus: 5_00,
      reserveFactor: 10_00,
      supplyCap: 0,
      borrowCap: 0,
      debtCeiling: 0,
      liqProtocolFee: 10_00
    });

    return listings;
  }

  function getPoolContext() public pure override returns (IEngine.PoolContext memory) {
    return IEngine.PoolContext({networkName: 'Local', networkAbbreviation: 'Loc'});
  }
}
