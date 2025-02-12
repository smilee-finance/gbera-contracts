// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";

import { BaseTest } from "./Base.t.sol";
import { IGBera } from "src/interfaces/IGBera.sol";
import { IGBeraAssetManager } from "src/interfaces/IGBeraAssetManager.sol";
import { IGBeraErrors } from "src/interfaces/IGBeraErrors.sol";

contract GBeraTest is BaseTest {
    function setUp() public override {
        super.setUp();
        _deployMockedContracts();
    }

    function test_owner() public view {
        assertEq(gbera.owner(), OWNER);
    }

    function test_upgradeTo_NotOwner() public {
        vm.expectRevert();
        gbera.upgradeToAndCall(address(0x123), new bytes(0));
    }

    function testFuzz_setBeraManager(address newBeraManager) public {
        vm.assume(newBeraManager != address(0));
        vm.prank(OWNER);
        gbera.setAssetManager(newBeraManager);
    }

    function test_setBeraManager_Fail_ZeroAddress() public {
        vm.prank(OWNER);
        vm.expectRevert(IGBeraErrors.AddressZero.selector);
        gbera.setAssetManager(address(0));
    }

    function test_setBeraManager_Fail_NotOwner() public {
        vm.expectRevert();
        gbera.setAssetManager(address(0x123));
    }

    function testFuzz_setWithdrawalQueue(address newWithdrawalQueue) public {
        vm.assume(newWithdrawalQueue != address(0));
        vm.prank(OWNER);
        gbera.setWithdrawalQueue(newWithdrawalQueue);
    }

    function test_setWithdrawalQueue_Fail_ZeroAddress() public {
        vm.prank(OWNER);
        vm.expectRevert(IGBeraErrors.AddressZero.selector);
        gbera.setWithdrawalQueue(address(0));
    }

    function test_setWithdrawalQueue_Fail_NotOwner() public {
        vm.expectRevert();
        gbera.setWithdrawalQueue(address(0x123));
    }

    function testFuzz_mint(uint256 amount) public returns (uint256) {
        amount = _bound(amount, 1e18 + 1, 1_000_000e18);
        vm.deal(USER, amount);
        vm.prank(USER);
        gbera.deposit{ value: amount }(USER);
        assertEq(gbera.balanceOf(USER), amount);
        assertEq(gbera.totalSupply(), amount);
        assertEq(address(manager).balance, amount);
        return amount;
    }

    function test_multiple_mint() public {
        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");
        uint256 amount = 100e18;

        vm.deal(user1, amount);
        vm.prank(user1);
        gbera.deposit{ value: amount }(user1);
        console2.log("user1 balance", gbera.balanceOf(user1));
        // donate
        vm.deal(address(manager), address(manager).balance + 50e18);

        vm.deal(user2, amount);
        vm.prank(user2);
        gbera.deposit{ value: amount }(user2);
        console2.log("user2 balance", gbera.balanceOf(user2));
    }

    function test_mint_Fail_NotEnoughBera() public {
        vm.prank(USER);
        vm.expectRevert();
        gbera.deposit{ value: 1000 }(USER);
    }

    function test_mint_Fail_InvalidAmount() public {
        vm.prank(USER);
        vm.expectRevert(IGBeraErrors.InvalidAmount.selector);
        // 0 value
        gbera.deposit(USER);
    }

    function testFuzz_burnShares(uint256 amount) public {
        amount = testFuzz_mint(amount);
        vm.prank(address(manager));
        gbera.burnShares(USER, amount);
        assertEq(gbera.balanceOf(USER), 0);
    }

    function test_burn_Fail_NotBeraManager() public {
        uint256 amount = testFuzz_mint(100e18);
        vm.expectRevert(IGBeraErrors.NotManager.selector);
        gbera.burnShares(USER, amount);
    }

    function testFuzz_requestWithdrawal(
        uint256 mintAmount,
        uint256 withdrawalAmount
    )
        public
        returns (uint256, uint256)
    {
        mintAmount = bound(mintAmount, 1e18 + 1, type(uint256).max);
        withdrawalAmount = bound(withdrawalAmount, 0, mintAmount - 1e18 - 1);

        vm.prank(OWNER);
        gbera.setWithdrawalEnabled(true);

        uint256 amount = testFuzz_mint(mintAmount);
        withdrawalAmount = _bound(withdrawalAmount, 1, amount - 1e18);
        vm.prank(USER);
        gbera.requestWithdrawal(withdrawalAmount, USER);

        assertEq(gbera.balanceOf(address(withdrawalQueue)), withdrawalAmount);
        assertEq(gbera.balanceOf(USER), amount - withdrawalAmount);

        (address receiver, uint256 pooled,) = withdrawalQueue.withdrawalQueue(1);
        assertEq(pooled, withdrawalAmount);
        assertEq(receiver, USER);
        assertEq(withdrawalQueue.balanceOf(USER), 1);

        return (amount, withdrawalAmount);
    }

    function test_requestWithdrawal_Fail_InvalidAmount() public {
        vm.prank(OWNER);
        gbera.setWithdrawalEnabled(true);

        vm.prank(USER);
        vm.expectRevert(IGBeraErrors.InvalidAmount.selector);
        gbera.requestWithdrawal(0, USER);
    }

    function testFuzz_completeWithdrawal(uint256 mintAmount, uint256 withdrawalAmount) public {
        mintAmount = bound(mintAmount, 1e18 + 1, type(uint256).max);
        withdrawalAmount = bound(withdrawalAmount, 0, mintAmount - 1e18 - 1);
        (mintAmount, withdrawalAmount) = testFuzz_requestWithdrawal(mintAmount, withdrawalAmount);

        // process the queue batch
        vm.prank(OWNER);
        manager.processWithdrawalQueue(1);

        gbera.completeWithdrawal(1, 1);

        assertEq(gbera.balanceOf(address(withdrawalQueue)), 0);
        assertEq(USER.balance, withdrawalAmount);
        assertEq(address(manager).balance, mintAmount - withdrawalAmount);
        assertEq(withdrawalQueue.balanceOf(USER), 0);
    }

    function test_completeWithdrawal_Fail_IdAlreadyProcessed() public {
        testFuzz_completeWithdrawal(100e18, 100e18);
        vm.expectRevert();
        gbera.completeWithdrawal(1, 1);
    }

    function test_MintWhenAssetsGoingToZero() public {
        uint256 amount = 1e18;

        vm.deal(USER, amount);
        vm.prank(USER);
        gbera.deposit{ value: amount }(USER);

        assertEq(gbera.balanceOf(USER), amount);
        assertEq(gbera.totalSupply(), amount);

        // Wipe balance of the asset manager.
        vm.deal(address(manager), 0);

        // Underlying asset is 0, so user balance should be 0.
        assertEq(gbera.balanceOf(USER), 0);

        address USER_2 = makeAddr("user_2");
        vm.deal(USER_2, amount);
        vm.prank(USER_2);
        gbera.deposit{ value: amount }(USER_2);

        // User 2 is bringing money in a 0 valued shares container.
        // Will split the total supply between the two users.
        assertEq(gbera.balanceOf(USER_2), amount / 2);
        assertEq(gbera.balanceOf(USER), amount / 2);

        // Total supply is returning rebased amount -> 1
        assertEq(gbera.totalSupply(), 1e18);
    }

    function testFuzz_MintOnReceive(uint256 amount) public {
        amount = bound(amount, 1e18, type(uint256).max);
        vm.deal(USER, amount);
        vm.prank(USER);
        (bool success,) = address(gbera).call{ value: amount }("");
        assertTrue(success, "gbera direct call failed");

        assertEq(gbera.balanceOf(USER), amount);
        assertEq(gbera.totalSupply(), amount);
        assertEq(gbera.totalShares(), amount);
        assertEq(address(manager).balance, amount);
    }

    function test_transferShares() public {
        address USER2 = makeAddr("user2");

        testFuzz_MintOnReceive(1e18);
        vm.prank(USER);
        gbera.transferShares(USER2, 0.1e18);
        assertEq(gbera.balanceOfShares(USER), 0.9e18);
        assertEq(gbera.balanceOfShares(USER2), 0.1e18);
    }

    function test_transferSharesFrom() public {
        address SPENDER = makeAddr("spender");
        address USER2 = makeAddr("user2");

        testFuzz_MintOnReceive(1e18);
        vm.prank(USER);
        gbera.approveShares(SPENDER, 0.1e18);
        vm.prank(SPENDER);
        gbera.transferSharesFrom(USER, USER2, 0.1e18);
        assertEq(gbera.balanceOfShares(USER), 0.9e18);
        assertEq(gbera.balanceOfShares(USER2), 0.1e18);
    }

    function testFuzz_transferSharesFromSharePriceChangeCheckAllowance(uint256 sharePrice) public {
        sharePrice = bound(sharePrice, 1, type(uint128).max);
        address SPENDER = makeAddr("spender");
        address USER2 = makeAddr("user2");

        testFuzz_MintOnReceive(1e18);

        vm.deal(address(manager), sharePrice);
        assertEq(gbera.sharePrice(), sharePrice);
        assertEq(gbera.balanceOf(USER), gbera.sharePrice());

        uint256 sharesToTransfer = 0.1e18; // 10% of total shares
        vm.prank(USER);
        gbera.approveShares(SPENDER, sharesToTransfer);

        uint256 approvalBefore = gbera.allowance(USER, SPENDER);
        assertEq(approvalBefore, gbera.getRebasedAmount(sharesToTransfer, true));

        vm.prank(SPENDER);
        gbera.transferSharesFrom(USER, USER2, sharesToTransfer);

        uint256 approvalAfter = gbera.allowance(USER, SPENDER);
        uint256 expectedAllowanceDelta = (sharesToTransfer * gbera.sharePrice()) / 1e18;
        uint256 expectedAllowanceDeltaRound = (sharesToTransfer * gbera.sharePrice()) % 1e18 == 0 ? 0 : 1;
        expectedAllowanceDelta += expectedAllowanceDeltaRound;

        assertEq(approvalAfter, approvalBefore - expectedAllowanceDelta);
        assertEq(gbera.balanceOfShares(USER), 1e18 - sharesToTransfer);
        assertEq(gbera.balanceOfShares(USER2), sharesToTransfer);
    }

    function testFuzz_gBeraSharePriceInflation(uint256 capital, uint256 withdrawAmount) public {
        capital = bound(capital, 100e18, 100_000e18);
        withdrawAmount = bound(withdrawAmount, (capital * 80) / 100, (capital * 99) / 100);
        address bob = makeAddr("b0b");
        vm.prank(OWNER);
        gbera.setWithdrawalEnabled(true);

        vm.startPrank(bob);
        vm.deal(bob, capital + 1e18);
        (bool success,) = address(manager).call{ value: capital }("");
        require(success, "!OK");
        // Bob mints an initial GBera amount
        gbera.deposit{ value: 1e18 }(bob);

        vm.expectRevert(IGBeraErrors.InvalidAmount.selector);
        gbera.requestWithdrawal(withdrawAmount, bob);
    }
}
