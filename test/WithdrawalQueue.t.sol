// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseTest } from "./Base.t.sol";

import { Test } from "forge-std/Test.sol";
import { IGBeraErrors } from "src/interfaces/IGBeraErrors.sol";
import { IWithdrawalQueue } from "src/interfaces/IWithdrawalQueue.sol";

contract WithdrawalQueueTest is BaseTest {
    function setUp() public override {
        super.setUp();
        _deployMockedContracts();
    }

    function test_owner() public view {
        assertEq(withdrawalQueue.owner(), OWNER);
    }

    function test_upgradeTo_NotOwner() public {
        vm.expectRevert();
        gbera.upgradeToAndCall(address(0x123), new bytes(0));
    }

    function testFuzz_submitRequest(uint256 amount) public {
        uint256 lastRequestId = withdrawalQueue.lastRequestId();
        uint256 prevUserBalance = withdrawalQueue.balanceOf(USER);
        vm.expectEmit(true, true, false, true);
        emit IWithdrawalQueue.WithdrawalRequestSubmitted(lastRequestId + 1, USER, amount, amount, block.timestamp);
        uint256 unrebasedAmount = gbera.getUnrebasedAmount(amount, false);
        vm.prank(address(gbera));
        withdrawalQueue.submitRequest(amount, unrebasedAmount, USER);
        assertEq(withdrawalQueue.lastRequestId(), lastRequestId + 1);
        lastRequestId = withdrawalQueue.lastRequestId();
        assertEq(
            withdrawalQueue.cumulativeWithdrawnShares(lastRequestId),
            withdrawalQueue.cumulativeWithdrawnShares(lastRequestId - 1) + amount
        );
        assertEq(withdrawalQueue.balanceOf(USER), prevUserBalance + 1);
    }

    function test_submitRequest_Fail_NotGBera() public {
        uint256 unrebasedAmount = gbera.getUnrebasedAmount(100 ether, false);
        vm.expectRevert(IGBeraErrors.NotGBera.selector);
        withdrawalQueue.submitRequest(100 ether, unrebasedAmount, USER);
    }

    function test_submitRequest_MultipleRequests() public {
        address user2 = makeAddr("user2");
        uint256 unrebasedAmount = gbera.getUnrebasedAmount(100 ether, false);
        vm.prank(address(gbera));
        withdrawalQueue.submitRequest(100 ether, unrebasedAmount, USER);
        unrebasedAmount = gbera.getUnrebasedAmount(200 ether, false);
        vm.prank(address(gbera));
        withdrawalQueue.submitRequest(200 ether, unrebasedAmount, USER);
        unrebasedAmount = gbera.getUnrebasedAmount(300 ether, false);
        vm.prank(address(gbera));
        withdrawalQueue.submitRequest(300 ether, unrebasedAmount, user2);
        assertEq(withdrawalQueue.lastRequestId(), 3);
        assertEq(withdrawalQueue.cumulativeWithdrawnShares(1), 100 ether);
        assertEq(withdrawalQueue.cumulativeWithdrawnShares(2), 300 ether);
        assertEq(withdrawalQueue.cumulativeWithdrawnShares(3), 600 ether);
        assertEq(withdrawalQueue.balanceOf(USER), 2);
        assertEq(withdrawalQueue.balanceOf(user2), 1);
    }

    function test_processQueue() public {
        testFuzz_submitRequest(100 ether);
        uint256 lastRequestId = withdrawalQueue.lastRequestId();
        vm.expectEmit(true, true, false, true);
        emit IWithdrawalQueue.QueueProcessed(1, 0, 1, 100 ether, 100 ether);
        vm.prank(address(manager));
        (uint256 beraToBurn,) = withdrawalQueue.processQueue(lastRequestId);
        assertEq(withdrawalQueue.lastProcessedId(), lastRequestId);
        assertEq(withdrawalQueue.cumulativeWithdrawnShares(withdrawalQueue.lastProcessedId()), 100 ether);
        assertEq(beraToBurn, 100 ether);
    }

    function test_processQueue_MultipleBatches() public {
        testFuzz_submitRequest(100 ether);
        testFuzz_submitRequest(200 ether);
        testFuzz_submitRequest(300 ether);

        assertEq(withdrawalQueue.lastRequestId(), 3);
        uint256 lastRequestId = withdrawalQueue.lastRequestId();
        vm.expectEmit(true, true, false, true);
        emit IWithdrawalQueue.QueueProcessed(1, 0, 3, 600 ether, 600 ether);
        vm.prank(address(manager));
        withdrawalQueue.processQueue(lastRequestId);
        assertEq(withdrawalQueue.lastProcessedId(), lastRequestId);
        assertEq(withdrawalQueue.cumulativeWithdrawnShares(withdrawalQueue.lastProcessedId()), 600 ether);
    }

    function test_processQueue_MultipleBatches_Splitted() public {
        testFuzz_submitRequest(100 ether);
        testFuzz_submitRequest(200 ether);

        assertEq(withdrawalQueue.lastRequestId(), 2);
        uint256 lastRequestId = withdrawalQueue.lastRequestId();
        vm.expectEmit(true, true, false, true);
        emit IWithdrawalQueue.QueueProcessed(1, 0, 2, 300 ether, 300 ether);
        vm.prank(address(manager));
        withdrawalQueue.processQueue(lastRequestId);
        assertEq(withdrawalQueue.lastProcessedId(), lastRequestId);
        assertEq(withdrawalQueue.cumulativeWithdrawnShares(withdrawalQueue.lastProcessedId()), 300 ether);

        testFuzz_submitRequest(300 ether);
        assertEq(withdrawalQueue.lastRequestId(), 3);
        lastRequestId = withdrawalQueue.lastRequestId();
        vm.expectEmit(true, true, false, true);
        emit IWithdrawalQueue.QueueProcessed(2, 2, 3, 300 ether, 300 ether);
        vm.prank(address(manager));
        withdrawalQueue.processQueue(lastRequestId);
        assertEq(withdrawalQueue.lastProcessedId(), lastRequestId);
        assertEq(withdrawalQueue.cumulativeWithdrawnShares(withdrawalQueue.lastProcessedId()), 600 ether);
    }

    function test_processQueue_Fail_NotManager() public {
        vm.expectRevert(IGBeraErrors.NotManager.selector);
        withdrawalQueue.processQueue(1);
    }

    function test_processQueue_Fail_OutsideRequestBounds() public {
        vm.expectRevert(IGBeraErrors.OutsideRequestBounds.selector);
        vm.prank(address(manager));
        withdrawalQueue.processQueue(1);

        testFuzz_submitRequest(100 ether);

        vm.expectRevert(IGBeraErrors.OutsideRequestBounds.selector);
        vm.prank(address(manager));
        withdrawalQueue.processQueue(2);
    }

    function test_claimBera() public {
        vm.deal(address(withdrawalQueue), 100 ether); // after the processQueue, the queue should have 100 ether
        test_processQueue();
        vm.expectEmit(true, true, false, true);
        emit IWithdrawalQueue.BeraClaimed(1, 1, USER, 100 ether);
        vm.prank(address(gbera));
        withdrawalQueue.claimBera(1, 1);
        assertEq(withdrawalQueue.balanceOf(USER), 0);
        assertEq(USER.balance, 100 ether);
    }

    function test_claimBera_Fail_TransferFailed() public {
        test_processQueue();
        vm.expectRevert(IGBeraErrors.TransferFailed.selector);
        vm.prank(address(gbera));
        withdrawalQueue.claimBera(1, 1);
    }

    function test_claimBera_Fail_NotGBera() public {
        vm.expectRevert(IGBeraErrors.NotGBera.selector);
        withdrawalQueue.claimBera(1, 1);
    }

    function test_claimBera_Fail_NotYetProcessed() public {
        testFuzz_submitRequest(100 ether);
        vm.expectRevert(IGBeraErrors.NotYetProcessed.selector);
        vm.prank(address(gbera));
        withdrawalQueue.claimBera(1, 1);
    }

    function test_claimBera_Fail_IndexNotBelongingToBatch() public {
        test_processQueue();
        vm.expectRevert(IGBeraErrors.IndexNotBelongingToBatch.selector);
        vm.prank(address(gbera));
        withdrawalQueue.claimBera(1, 2);
    }
}
