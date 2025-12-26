// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* solhint-disable */

import 'forge-std/Test.sol';

import {IPool} from '../../src/contracts/interfaces/IPool.sol';
import {IAToken, IERC20} from '../../src/contracts/interfaces/IAToken.sol';
import {IVariableDebtToken} from '../../src/contracts/interfaces/IVariableDebtToken.sol';
import {Errors} from '../../src/contracts/protocol/libraries/helpers/Errors.sol';
import {TestnetProcedures} from '../utils/TestnetProcedures.sol';
import {IACLManager} from '../../src/contracts/interfaces/IACLManager.sol';
import {DataTypes} from '../../src/contracts/protocol/libraries/types/DataTypes.sol';

/**
 * @dev Integration test for Bank Lending System
 * @dev Tests the complete workflow of bank-only liquidity provision and user borrowing
 */
contract BankLendingSystemIntegrationTest is TestnetProcedures {
  IPool internal pool;
  IACLManager internal aclManager;

  address internal aUSDX;
  address internal aWBTC;
  address internal variableDebtUSDX;

  address internal bank;
  address internal user1;
  address internal user2;

  uint256 constant BANK_INITIAL_USDX = 10_000_000e6; // 10M USDC
  uint256 constant USER_INITIAL_WBTC = 100e8; // 100 WBTC

  function setUp() public {
    initTestEnvironment();

    pool = contracts.poolProxy;
    aclManager = IACLManager(contracts.aclManager);

    aUSDX = pool.getReserveAToken(tokenList.usdx);
    aWBTC = pool.getReserveAToken(tokenList.wbtc);
    variableDebtUSDX = pool.getReserveData(tokenList.usdx).variableDebtTokenAddress;

    // Create accounts
    bank = makeAddr('BANK');
    user1 = makeAddr('USER_1');
    user2 = makeAddr('USER_2');

    // Configure USDX as borrowable asset (lending asset, borrowingEnabled = true)
    vm.prank(poolAdmin);
    contracts.poolConfiguratorProxy.setReserveBorrowing(tokenList.usdx, true);

    // Configure WBTC as collateral-only asset (borrowingEnabled = false)
    vm.prank(poolAdmin);
    contracts.poolConfiguratorProxy.setReserveBorrowing(tokenList.wbtc, false);

    // Grant LIQUIDITY_ADMIN_ROLE to bank
    vm.prank(poolAdmin);
    aclManager.addLiquidityAdmin(bank);

    // Grant APPROVED_USER_ROLE to users (user admission)
    vm.prank(poolAdmin);
    aclManager.addApprovedUser(user1);

    vm.prank(poolAdmin);
    aclManager.addApprovedUser(user2);

    // Fund accounts
    deal(tokenList.usdx, bank, BANK_INITIAL_USDX);
    deal(tokenList.wbtc, user1, USER_INITIAL_WBTC);
    deal(tokenList.wbtc, user2, USER_INITIAL_WBTC);

    // Approve pool
    vm.prank(bank);
    IERC20(tokenList.usdx).approve(address(pool), type(uint256).max);

    vm.prank(user1);
    IERC20(tokenList.wbtc).approve(address(pool), type(uint256).max);

    vm.prank(user2);
    IERC20(tokenList.wbtc).approve(address(pool), type(uint256).max);
  }

  /**
   * @dev Test complete workflow: bank supplies → user collateralizes → user borrows
   */
  function test_complete_lending_workflow() public {
    // ============ Step 1: Bank supplies lending asset (USDX) ============
    uint256 bankSupplyAmount = 5_000_000e6; // 5M USDC

    vm.prank(bank);
    pool.supply(tokenList.usdx, bankSupplyAmount, bank, 0);

    assertEq(IERC20(tokenList.usdx).balanceOf(bank), BANK_INITIAL_USDX - bankSupplyAmount);
    assertEq(IAToken(aUSDX).scaledBalanceOf(bank), bankSupplyAmount);

    // ============ Step 2: User1 supplies collateral (WBTC) ============
    uint256 user1CollateralAmount = 10e8; // 10 WBTC

    vm.prank(user1);
    pool.supply(tokenList.wbtc, user1CollateralAmount, user1, 0);

    assertEq(IERC20(tokenList.wbtc).balanceOf(user1), USER_INITIAL_WBTC - user1CollateralAmount);
    assertEq(IAToken(aWBTC).scaledBalanceOf(user1), user1CollateralAmount);

    // ============ Step 3: User1 borrows USDX ============
    // WBTC price ~$27k, 10 WBTC = $270k collateral, LTV 70%, user can borrow ~$189k
    uint256 user1BorrowAmount = 150_000e6; // 150k USDC (safe margin)

    uint256 user1USDXBefore = IERC20(tokenList.usdx).balanceOf(user1);

    vm.prank(user1);
    pool.borrow(tokenList.usdx, user1BorrowAmount, 2, 0, user1); // interestRateMode = 2 (variable)

    assertEq(IERC20(tokenList.usdx).balanceOf(user1), user1USDXBefore + user1BorrowAmount);
    assertGt(IVariableDebtToken(variableDebtUSDX).scaledBalanceOf(user1), 0);

    // ============ Step 4: User2 supplies collateral and borrows ============
    uint256 user2CollateralAmount = 5e8; // 5 WBTC = $135k collateral
    uint256 user2BorrowAmount = 80_000e6; // 80k USDC (safe margin)

    vm.prank(user2);
    pool.supply(tokenList.wbtc, user2CollateralAmount, user2, 0);

    vm.prank(user2);
    pool.borrow(tokenList.usdx, user2BorrowAmount, 2, 0, user2);

    assertEq(IERC20(tokenList.usdx).balanceOf(user2), user2BorrowAmount);

    // ============ Step 5: Verify total liquidity ============
    uint256 totalBorrowed = user1BorrowAmount + user2BorrowAmount;
    uint256 availableLiquidity = IERC20(tokenList.usdx).balanceOf(aUSDX);

    assertEq(
      availableLiquidity + totalBorrowed,
      bankSupplyAmount,
      'Total liquidity should equal bank supply'
    );
  }

  /**
   * @dev Test that regular users cannot supply lending assets
   */
  function test_user_cannot_supply_lending_asset() public {
    // Give user1 some USDX
    deal(tokenList.usdx, user1, 10_000e6);
    vm.prank(user1);
    IERC20(tokenList.usdx).approve(address(pool), type(uint256).max);

    // User1 tries to supply USDX (borrowingEnabled = true)
    vm.expectRevert(abi.encodeWithSelector(Errors.CallerNotLiquidityAdmin.selector));

    vm.prank(user1);
    pool.supply(tokenList.usdx, 10_000e6, user1, 0);
  }

  /**
   * @dev Test repayment workflow with interest accrual
   */
  function test_borrow_and_repay_with_interest() public {
    // Bank supplies
    uint256 bankSupplyAmount = 1_000_000e6; // 1M USDC
    vm.prank(bank);
    pool.supply(tokenList.usdx, bankSupplyAmount, bank, 0);

    // User supplies collateral
    uint256 collateralAmount = 10e8; // 10 WBTC
    vm.prank(user1);
    pool.supply(tokenList.wbtc, collateralAmount, user1, 0);

    // User borrows
    uint256 borrowAmount = 100_000e6; // 100k USDC
    vm.prank(user1);
    pool.borrow(tokenList.usdx, borrowAmount, 2, 0, user1);

    uint256 debtBefore = IERC20(variableDebtUSDX).balanceOf(user1);

    // Time passes (simulate interest accrual)
    vm.warp(block.timestamp + 365 days);
    vm.roll(block.number + 1);

    uint256 debtAfter = IERC20(variableDebtUSDX).balanceOf(user1);

    // Interest should have accrued
    assertGt(debtAfter, debtBefore, 'Interest should accrue over time');

    // User repays with interest
    deal(tokenList.usdx, user1, debtAfter); // Give user enough to repay
    vm.prank(user1);
    IERC20(tokenList.usdx).approve(address(pool), type(uint256).max);

    vm.prank(user1);
    pool.repay(tokenList.usdx, type(uint256).max, 2, user1);

    // Debt should be cleared
    assertEq(IERC20(variableDebtUSDX).balanceOf(user1), 0);

    // Bank's aToken balance should have increased (interest earned)
    assertGt(
      IAToken(aUSDX).balanceOf(bank),
      bankSupplyAmount,
      'Bank should earn interest from user repayment'
    );
  }

  /**
   * @dev Test bank withdraws liquidity including earned interest
   */
  function test_bank_withdraws_with_interest() public {
    // Bank supplies
    uint256 bankSupplyAmount = 1_000_000e6;
    vm.prank(bank);
    pool.supply(tokenList.usdx, bankSupplyAmount, bank, 0);

    // User borrows and time passes
    uint256 collateralAmount = 10e8;
    vm.prank(user1);
    pool.supply(tokenList.wbtc, collateralAmount, user1, 0);

    uint256 borrowAmount = 100_000e6;
    vm.prank(user1);
    pool.borrow(tokenList.usdx, borrowAmount, 2, 0, user1);

    // Time passes
    vm.warp(block.timestamp + 365 days);
    vm.roll(block.number + 1);

    // User repays
    uint256 totalDebt = IERC20(variableDebtUSDX).balanceOf(user1);
    deal(tokenList.usdx, user1, totalDebt);
    vm.prank(user1);
    IERC20(tokenList.usdx).approve(address(pool), type(uint256).max);
    vm.prank(user1);
    pool.repay(tokenList.usdx, type(uint256).max, 2, user1);

    // Bank withdraws all liquidity
    uint256 bankUSDXBefore = IERC20(tokenList.usdx).balanceOf(bank);

    vm.prank(bank);
    pool.withdraw(tokenList.usdx, type(uint256).max, bank);

    uint256 bankUSDXAfter = IERC20(tokenList.usdx).balanceOf(bank);
    uint256 withdrawn = bankUSDXAfter - bankUSDXBefore;

    // Bank should withdraw more than initial supply (earned interest)
    assertGt(withdrawn, bankSupplyAmount, 'Bank should withdraw principal + interest');
    assertEq(IAToken(aUSDX).balanceOf(bank), 0, 'Bank aToken balance should be zero');
  }

  /**
   * @dev Test multiple users borrowing from bank's liquidity pool
   */
  function test_multiple_users_borrow_from_bank() public {
    // Bank supplies large amount
    uint256 bankSupplyAmount = 5_000_000e6; // 5M USDC
    vm.prank(bank);
    pool.supply(tokenList.usdx, bankSupplyAmount, bank, 0);

    // User1 borrows
    vm.prank(user1);
    pool.supply(tokenList.wbtc, 10e8, user1, 0);
    vm.prank(user1);
    pool.borrow(tokenList.usdx, 150_000e6, 2, 0, user1);

    // User2 borrows
    vm.prank(user2);
    pool.supply(tokenList.wbtc, 10e8, user2, 0);
    vm.prank(user2);
    pool.borrow(tokenList.usdx, 150_000e6, 2, 0, user2);

    // Verify both users have debt
    assertGt(IERC20(variableDebtUSDX).balanceOf(user1), 0);
    assertGt(IERC20(variableDebtUSDX).balanceOf(user2), 0);

    // Verify available liquidity
    uint256 availableLiquidity = IERC20(tokenList.usdx).balanceOf(aUSDX);
    uint256 totalBorrowed = 300_000e6;
    assertEq(availableLiquidity, bankSupplyAmount - totalBorrowed, 'Available liquidity should equal supply minus borrows');
  }

  /**
   * @dev Test user withdrawal of collateral after repaying debt
   */
  function test_user_withdraws_collateral_after_repay() public {
    // Setup: bank supplies, user borrows
    vm.prank(bank);
    pool.supply(tokenList.usdx, 1_000_000e6, bank, 0);

    uint256 collateralAmount = 10e8;
    vm.prank(user1);
    pool.supply(tokenList.wbtc, collateralAmount, user1, 0);

    uint256 borrowAmount = 100_000e6;
    vm.prank(user1);
    pool.borrow(tokenList.usdx, borrowAmount, 2, 0, user1);

    // User repays debt
    uint256 totalDebt = IERC20(variableDebtUSDX).balanceOf(user1);
    deal(tokenList.usdx, user1, totalDebt);
    vm.prank(user1);
    IERC20(tokenList.usdx).approve(address(pool), type(uint256).max);
    vm.prank(user1);
    pool.repay(tokenList.usdx, type(uint256).max, 2, user1);

    // User withdraws collateral
    uint256 user1WBTCBefore = IERC20(tokenList.wbtc).balanceOf(user1);

    vm.prank(user1);
    pool.withdraw(tokenList.wbtc, type(uint256).max, user1);

    uint256 user1WBTCAfter = IERC20(tokenList.wbtc).balanceOf(user1);

    assertEq(user1WBTCAfter - user1WBTCBefore, collateralAmount);
    assertEq(IAToken(aWBTC).balanceOf(user1), 0);
  }

  /**
   * @dev Test that removed liquidity admin cannot supply lending assets
   */
  function test_removed_liquidity_admin_cannot_supply() public {
    // Bank supplies successfully
    vm.prank(bank);
    pool.supply(tokenList.usdx, 1_000_000e6, bank, 0);

    // Remove bank's liquidity provider role
    vm.prank(poolAdmin);
    aclManager.removeLiquidityAdmin(bank);

    // Bank tries to supply more
    vm.expectRevert(abi.encodeWithSelector(Errors.CallerNotLiquidityAdmin.selector));

    vm.prank(bank);
    pool.supply(tokenList.usdx, 1_000_000e6, bank, 0);
  }

  /**
   * @dev Test that bank can still withdraw after role removal
   */
  function test_bank_can_withdraw_after_role_removal() public {
    // Bank supplies
    uint256 supplyAmount = 1_000_000e6;
    vm.prank(bank);
    pool.supply(tokenList.usdx, supplyAmount, bank, 0);

    // Remove role
    vm.prank(poolAdmin);
    aclManager.removeLiquidityAdmin(bank);

    // Bank should still be able to withdraw their funds
    uint256 bankUSDXBefore = IERC20(tokenList.usdx).balanceOf(bank);

    vm.prank(bank);
    pool.withdraw(tokenList.usdx, supplyAmount, bank);

    uint256 bankUSDXAfter = IERC20(tokenList.usdx).balanceOf(bank);

    assertEq(bankUSDXAfter - bankUSDXBefore, supplyAmount);
  }

  /**
   * @dev Test asset configuration change workflow
   */
  function test_asset_configuration_change() public {
    // Initial: WBTC is collateral-only (borrowingEnabled = false)
    // Bank customers can supply
    vm.prank(user1);
    pool.supply(tokenList.wbtc, 1e8, user1, 0);

    // Change WBTC to borrowable (borrowingEnabled = true)
    vm.prank(poolAdmin);
    contracts.poolConfiguratorProxy.setReserveBorrowing(tokenList.wbtc, true);

    // Now bank customers cannot supply WBTC (need LIQUIDITY_ADMIN_ROLE)
    vm.expectRevert(abi.encodeWithSelector(Errors.CallerNotLiquidityAdmin.selector));

    vm.prank(user2);
    pool.supply(tokenList.wbtc, 1e8, user2, 0);

    // But bank (liquidity provider) can supply
    deal(tokenList.wbtc, bank, 10e8);
    vm.prank(bank);
    IERC20(tokenList.wbtc).approve(address(pool), type(uint256).max);

    vm.prank(bank);
    pool.supply(tokenList.wbtc, 1e8, bank, 0);
  }

  /**
   * @dev Test bank supplies on behalf of another address
   */
  function test_bank_supply_on_behalf() public {
    address beneficiary = makeAddr('BENEFICIARY');

    uint256 supplyAmount = 1_000_000e6;

    vm.prank(bank);
    pool.supply(tokenList.usdx, supplyAmount, beneficiary, 0);

    // Beneficiary should receive aTokens
    assertEq(IAToken(aUSDX).scaledBalanceOf(beneficiary), supplyAmount);
    // Bank's underlying balance should decrease
    assertEq(IERC20(tokenList.usdx).balanceOf(bank), BANK_INITIAL_USDX - supplyAmount);
  }

  /**
   * @dev Test scenario: insufficient liquidity for borrow
   */
  function test_insufficient_liquidity_for_borrow() public {
    // Bank supplies limited amount
    uint256 bankSupplyAmount = 100_000e6; // 100k USDC
    vm.prank(bank);
    pool.supply(tokenList.usdx, bankSupplyAmount, bank, 0);

    // User supplies large collateral
    vm.prank(user1);
    pool.supply(tokenList.wbtc, 50e8, user1, 0); // 50 WBTC = $1.35M collateral

    // User tries to borrow more than available liquidity
    uint256 excessiveBorrowAmount = 200_000e6; // 200k USDC (more than 100k available)

    vm.expectRevert(abi.encodeWithSelector(Errors.InvalidAmount.selector));

    vm.prank(user1);
    pool.borrow(tokenList.usdx, excessiveBorrowAmount, 2, 0, user1);
  }

  /**
   * @dev Test complete business cycle: supply → borrow → time passes → repay → withdraw
   */
  function test_complete_business_cycle() public {
    // ============ Setup Phase ============
    uint256 bankInitialSupply = 2_000_000e6; // 2M USDC
    uint256 userCollateral = 20e8; // 20 WBTC = $540k collateral
    uint256 borrowAmount = 300_000e6; // 300k USDC (safe margin)

    // Bank supplies lending capital
    vm.prank(bank);
    pool.supply(tokenList.usdx, bankInitialSupply, bank, 0);

    uint256 bankATokenInitial = IAToken(aUSDX).balanceOf(bank);

    // ============ User Interaction Phase ============
    // User supplies collateral
    vm.prank(user1);
    pool.supply(tokenList.wbtc, userCollateral, user1, 0);

    // User borrows
    vm.prank(user1);
    pool.borrow(tokenList.usdx, borrowAmount, 2, 0, user1);

    uint256 userUSDXBalance = IERC20(tokenList.usdx).balanceOf(user1);
    assertEq(userUSDXBalance, borrowAmount, 'User should receive borrowed amount');

    // ============ Time Passes (Interest Accrues) ============
    vm.warp(block.timestamp + 180 days); // 6 months
    vm.roll(block.number + 1);

    uint256 accruedDebt = IERC20(variableDebtUSDX).balanceOf(user1);
    assertGt(accruedDebt, borrowAmount, 'Debt should include interest');

    uint256 interestAmount = accruedDebt - borrowAmount;

    // ============ Repayment Phase ============
    // User repays full debt
    deal(tokenList.usdx, user1, accruedDebt);
    vm.prank(user1);
    IERC20(tokenList.usdx).approve(address(pool), type(uint256).max);

    vm.prank(user1);
    pool.repay(tokenList.usdx, type(uint256).max, 2, user1);

    // User withdraws collateral
    vm.prank(user1);
    pool.withdraw(tokenList.wbtc, type(uint256).max, user1);

    uint256 userFinalWBTC = IERC20(tokenList.wbtc).balanceOf(user1);
    assertEq(userFinalWBTC, USER_INITIAL_WBTC, 'User should recover all collateral');

    // ============ Bank Profit Phase ============
    uint256 bankATokenFinal = IAToken(aUSDX).balanceOf(bank);
    uint256 bankEarnedInterest = bankATokenFinal - bankATokenInitial;

    assertGt(bankEarnedInterest, 0, 'Bank should earn interest');

    // Bank withdraws all funds
    uint256 bankUSDXBefore = IERC20(tokenList.usdx).balanceOf(bank);

    vm.prank(bank);
    pool.withdraw(tokenList.usdx, type(uint256).max, bank);

    uint256 bankUSDXAfter = IERC20(tokenList.usdx).balanceOf(bank);
    uint256 bankTotalWithdrawn = bankUSDXAfter - bankUSDXBefore;

    assertGt(
      bankTotalWithdrawn,
      bankInitialSupply,
      'Bank should withdraw more than initial supply'
    );

    // Verify profit
    uint256 bankProfit = bankTotalWithdrawn - bankInitialSupply;
    // Note: Bank profit may be slightly less than interest paid due to reserve factor
    // Reserve factor takes a portion of interest for the protocol treasury
    assertGt(bankProfit, 0, 'Bank should have earned profit');
    assertLe(bankProfit, interestAmount, 'Bank profit should not exceed interest paid');
  }

  // ========== APPROVED_USER_ROLE Tests ==========

  /**
   * @dev Test that non-approved users cannot supply collateral assets
   */
  function test_non_approved_user_cannot_supply_collateral() public {
    address stranger = makeAddr('STRANGER');
    deal(tokenList.wbtc, stranger, 10e8);

    vm.prank(stranger);
    IERC20(tokenList.wbtc).approve(address(pool), type(uint256).max);

    // Stranger tries to supply WBTC (collateral asset, borrowingEnabled = false)
    vm.expectRevert(abi.encodeWithSelector(Errors.CallerNotApprovedUser.selector));

    vm.prank(stranger);
    pool.supply(tokenList.wbtc, 1e8, stranger, 0);
  }

  /**
   * @dev Test that non-approved users cannot borrow
   */
  function test_non_approved_user_cannot_borrow() public {
    // Bank supplies lending asset
    vm.prank(bank);
    pool.supply(tokenList.usdx, 1_000_000e6, bank, 0);

    // Create a stranger who is not an approved user
    address stranger = makeAddr('STRANGER');

    // Give stranger approved user role temporarily to supply collateral
    vm.prank(poolAdmin);
    aclManager.addApprovedUser(stranger);

    deal(tokenList.wbtc, stranger, 10e8);
    vm.prank(stranger);
    IERC20(tokenList.wbtc).approve(address(pool), type(uint256).max);

    vm.prank(stranger);
    pool.supply(tokenList.wbtc, 10e8, stranger, 0);

    // Remove approved user role
    vm.prank(poolAdmin);
    aclManager.removeApprovedUser(stranger);

    // Stranger tries to borrow
    vm.expectRevert(abi.encodeWithSelector(Errors.CallerNotApprovedUser.selector));

    vm.prank(stranger);
    pool.borrow(tokenList.usdx, 50_000e6, 2, 0, stranger);
  }

  /**
   * @dev Test that approved users can supply collateral and borrow
   */
  function test_approved_user_can_supply_and_borrow() public {
    // Bank supplies lending asset
    vm.prank(bank);
    pool.supply(tokenList.usdx, 1_000_000e6, bank, 0);

    // User1 is already an approved user (added in setUp)
    // User1 supplies collateral
    uint256 collateralAmount = 10e8;
    vm.prank(user1);
    pool.supply(tokenList.wbtc, collateralAmount, user1, 0);

    assertEq(IAToken(aWBTC).scaledBalanceOf(user1), collateralAmount);

    // User1 borrows
    uint256 borrowAmount = 100_000e6;
    vm.prank(user1);
    pool.borrow(tokenList.usdx, borrowAmount, 2, 0, user1);

    assertEq(IERC20(tokenList.usdx).balanceOf(user1), borrowAmount);
  }

  /**
   * @dev Test that POOL_ADMIN can add approved users
   */
  function test_pool_admin_can_add_approved_user() public {
    address newUser = makeAddr('NEW_USER');

    // Pool admin adds new user
    vm.prank(poolAdmin);
    aclManager.addApprovedUser(newUser);

    assertTrue(aclManager.isApprovedUser(newUser));

    // New user can now supply collateral
    deal(tokenList.wbtc, newUser, 10e8);
    vm.prank(newUser);
    IERC20(tokenList.wbtc).approve(address(pool), type(uint256).max);

    vm.prank(newUser);
    pool.supply(tokenList.wbtc, 1e8, newUser, 0);

    assertEq(IAToken(aWBTC).scaledBalanceOf(newUser), 1e8);
  }

  /**
   * @dev Test that removed approved user cannot supply or borrow
   */
  function test_removed_user_cannot_supply_or_borrow() public {
    // Bank supplies lending asset
    vm.prank(bank);
    pool.supply(tokenList.usdx, 1_000_000e6, bank, 0);

    // User1 supplies some collateral first
    vm.prank(user1);
    pool.supply(tokenList.wbtc, 5e8, user1, 0);

    // Remove user1's approved user role
    vm.prank(poolAdmin);
    aclManager.removeApprovedUser(user1);

    assertFalse(aclManager.isApprovedUser(user1));

    // User1 cannot supply more collateral
    vm.expectRevert(abi.encodeWithSelector(Errors.CallerNotApprovedUser.selector));
    vm.prank(user1);
    pool.supply(tokenList.wbtc, 1e8, user1, 0);

    // User1 cannot borrow
    vm.expectRevert(abi.encodeWithSelector(Errors.CallerNotApprovedUser.selector));
    vm.prank(user1);
    pool.borrow(tokenList.usdx, 50_000e6, 2, 0, user1);
  }

  /**
   * @dev Test that removed approved user can still withdraw their collateral
   */
  function test_removed_user_can_withdraw_collateral() public {
    // User1 supplies collateral
    uint256 collateralAmount = 5e8;
    vm.prank(user1);
    pool.supply(tokenList.wbtc, collateralAmount, user1, 0);

    // Remove user1's approved user role
    vm.prank(poolAdmin);
    aclManager.removeApprovedUser(user1);

    // User1 should still be able to withdraw their collateral
    uint256 user1WBTCBefore = IERC20(tokenList.wbtc).balanceOf(user1);

    vm.prank(user1);
    pool.withdraw(tokenList.wbtc, collateralAmount, user1);

    uint256 user1WBTCAfter = IERC20(tokenList.wbtc).balanceOf(user1);

    assertEq(user1WBTCAfter - user1WBTCBefore, collateralAmount);
  }

  /**
   * @dev Test complete user admission workflow
   */
  function test_complete_user_admission_workflow() public {
    address newUser = makeAddr('NEW_USER');

    // 1. New user is not yet admitted
    assertFalse(aclManager.isApprovedUser(newUser));

    // 2. New user cannot supply collateral
    deal(tokenList.wbtc, newUser, 10e8);
    vm.prank(newUser);
    IERC20(tokenList.wbtc).approve(address(pool), type(uint256).max);

    vm.expectRevert(abi.encodeWithSelector(Errors.CallerNotApprovedUser.selector));
    vm.prank(newUser);
    pool.supply(tokenList.wbtc, 1e8, newUser, 0);

    // 3. Pool admin admits new user
    vm.prank(poolAdmin);
    aclManager.addApprovedUser(newUser);
    assertTrue(aclManager.isApprovedUser(newUser));

    // 4. New user can now supply and borrow
    vm.prank(bank);
    pool.supply(tokenList.usdx, 1_000_000e6, bank, 0);

    vm.prank(newUser);
    pool.supply(tokenList.wbtc, 5e8, newUser, 0);

    vm.prank(newUser);
    pool.borrow(tokenList.usdx, 50_000e6, 2, 0, newUser);

    assertGt(IERC20(tokenList.usdx).balanceOf(newUser), 0);
  }
}

