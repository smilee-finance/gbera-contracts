// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseTest } from "./Base.t.sol";

import { Test } from "forge-std/Test.sol";

import { IGBeraAssetManager } from "src/interfaces/IGBeraAssetManager.sol";
import { IGBeraErrors } from "src/interfaces/IGBeraErrors.sol";
import { INodeWithdrawalVault } from "src/interfaces/INodeWithdrawalVault.sol";

contract NodeWithdrawalVaultTest is BaseTest {
    uint256 public constant WITHDRAWAL_VAULT_BALANCE = 1_000_000 ether; // 1 million ether

    function setUp() public override {
        super.setUp();
        vm.deal(address(withdrawalVault), WITHDRAWAL_VAULT_BALANCE);
    }

    function testFuzz_withdrawWithdrawals(uint256 amount) public {
        amount = bound(amount, 1, WITHDRAWAL_VAULT_BALANCE);
        vm.expectEmit(true, true, false, true);
        emit INodeWithdrawalVault.WithdrawalsWithdrawn(amount);
        vm.prank(address(manager));
        withdrawalVault.withdrawWithdrawals(amount);
        assertEq(address(withdrawalVault).balance, WITHDRAWAL_VAULT_BALANCE - amount);
        assertEq(address(manager).balance, amount);
    }

    function test_withdrawWithdrawals_Fail_ZeroAmount() public {
        vm.expectRevert(IGBeraErrors.ZeroAmount.selector);
        vm.prank(address(manager));
        withdrawalVault.withdrawWithdrawals(0);
    }

    function test_withdrawWithdrawals_Fail_NotManager() public {
        vm.expectRevert();
        withdrawalVault.withdrawWithdrawals(10 ether);
    }

    function test_withdrawWithdrawals_Fail_WithdrawalTransferFailed() public {
        vm.expectRevert(IGBeraErrors.WithdrawalTransferFailed.selector);
        vm.prank(address(manager));
        withdrawalVault.withdrawWithdrawals(WITHDRAWAL_VAULT_BALANCE + 1);
    }

    function testFuzz_donationIsTransferredToAssetManager(uint256 amount) public {
        amount = bound(amount, 1, 100_000_000 ether);
        uint256 managerBalanceBefore = address(manager).balance;
        address donator = makeAddr("donator");
        vm.deal(donator, amount);

        vm.prank(donator);
        vm.expectEmit(true, true, false, true);
        emit IGBeraAssetManager.Received(address(withdrawalVault), amount);
        (bool success,) = address(withdrawalVault).call{ value: amount }("");
        assert(success);
        assertEq(address(manager).balance, managerBalanceBefore + amount);
    }
}
