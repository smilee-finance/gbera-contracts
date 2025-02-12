// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { console } from "forge-std/console.sol";

import { BaseForkTest } from "./BaseForkTest.sol";

contract GBeraForkTest is BaseForkTest {
    receive() external payable { }

    uint256 private depositAmount = 1 ether;

    //////////// USERS //////////////

    address internal constant USER_1 = address(0xbeef1);
    address internal constant USER_2 = address(0xbeef2);
    address internal constant USER_3 = address(0xbeef3);
    /// OWNER already defined in Base.t.sol

    //////////// UTILITY FUNCTIONS ////////////
    // Due to rounding we cannot expect an exact match every time
    function _assertEqWithTol(uint256 amount1, uint256 amount2, uint256 tol, string memory message) internal pure {
        return
            amount1 < amount2 ? assertLe(amount2 - amount1, tol, message) : assertLe(amount1 - amount2, tol, message);
    }

    //////////// USER ACTIONS //////////////

    function _user1ApprovesUser3(uint256 amount) internal {
        console.log("_user1ApprovesUser3");
        uint256 allowance = gbera.allowance(USER_1, USER_3);

        vm.startPrank(USER_1);

        gbera.approve(USER_3, amount);

        assertEq(gbera.allowance(USER_1, USER_3), allowance + amount, "gBERA allowance mismatch in 1 to 3 approval");

        vm.stopPrank();
    }

    function _user2ApprovesUser3(uint256 amount) internal {
        console.log("_user2ApprovesUser3");
        uint256 allowance = gbera.allowance(USER_2, USER_3);

        vm.startPrank(USER_2);

        gbera.approve(USER_3, amount);

        assertEq(gbera.allowance(USER_2, USER_3), allowance + amount, "gBERA allowance mismatch in 2 to 3 approval");

        vm.stopPrank();
    }

    function _user1TransfersGberaTo2(uint256 amount) internal {
        console.log("_user1TransfersGberaTo2");
        uint256 user1Balance = gbera.balanceOf(USER_1);
        uint256 user2Balance = gbera.balanceOf(USER_2);
        uint256 totalSupply = gbera.totalSupply();

        vm.startPrank(USER_1);

        if (amount > user1Balance) {
            vm.expectRevert();
            gbera.transfer(USER_2, amount);
        } else {
            gbera.transfer(USER_2, amount);
            _assertEqWithTol(
                gbera.balanceOf(USER_1), user1Balance - amount, 100, "gBERA user1 balance mismatch in 1 to 2 transfer"
            );
            _assertEqWithTol(
                gbera.balanceOf(USER_2), user2Balance + amount, 100, "gBERA user2 balance mismatch in 1 to 2 transfer"
            );
            _assertEqWithTol(gbera.totalSupply(), totalSupply, 100, "gBERA total supply mismatch in 1 to 2 transfer");
        }

        vm.stopPrank();
    }

    function _user2TransfersGberaTo1(uint256 amount) internal {
        console.log("_user2TransfersGberaTo1");
        uint256 user1Balance = gbera.balanceOf(USER_1);
        uint256 user2Balance = gbera.balanceOf(USER_2);
        uint256 totalSupply = gbera.totalSupply();

        vm.startPrank(USER_2);

        if (amount > user2Balance) {
            vm.expectRevert();
            gbera.transfer(USER_1, amount);
        } else {
            gbera.transfer(USER_1, amount);
            _assertEqWithTol(
                gbera.balanceOf(USER_1), user1Balance + amount, 100, "gBERA user1 balance mismatch in 2 to 1 transfer"
            );
            _assertEqWithTol(
                gbera.balanceOf(USER_2), user2Balance - amount, 100, "gBERA user2 balance mismatch in 2 to 1 transfer"
            );
            _assertEqWithTol(gbera.totalSupply(), totalSupply, 100, "gBERA total supply mismatch in 2 to 1 transfer");
        }

        vm.stopPrank();
    }

    function _user3TransfersGberaFromUser1ToUser2(uint256 amount) internal {
        console.log("_user3TransfersGberaFromUser1ToUser2");
        uint256 allowance = gbera.allowance(USER_1, USER_3);
        uint256 user1Balance = gbera.balanceOf(USER_1);
        uint256 user2Balance = gbera.balanceOf(USER_2);
        uint256 totalSupply = gbera.totalSupply();

        vm.startPrank(USER_3);

        if (amount > allowance) {
            vm.expectRevert();
            gbera.transferFrom(USER_1, USER_2, amount);
        } else {
            if (amount > user1Balance) {
                vm.expectRevert();
                gbera.transferFrom(USER_1, USER_2, amount);
            } else {
                gbera.transferFrom(USER_1, USER_2, amount);
                _assertEqWithTol(
                    gbera.balanceOf(USER_1),
                    user1Balance - amount,
                    100,
                    "gBERA user1 balance mismatch in 3 transferring from 1 to 2"
                );
                _assertEqWithTol(
                    gbera.balanceOf(USER_2),
                    user2Balance + amount,
                    100,
                    "gBERA user2 balance mismatch in 3 transferring from 1 to 2"
                );
                _assertEqWithTol(
                    gbera.allowance(USER_1, USER_3),
                    allowance - amount,
                    100,
                    "gBERA allowance mismatch in 3 transferring from 1 to 2"
                );
                _assertEqWithTol(
                    gbera.totalSupply(), totalSupply, 100, "gBERA total supply mismatch in 3 transferring from 1 to 2"
                );
            }
        }

        vm.stopPrank();
    }

    function _user3TransfersGberaFromUser2ToUser1(uint256 amount) internal {
        console.log("_user3TransfersGberaFromUser2ToUser1");
        uint256 allowance = gbera.allowance(USER_2, USER_3);
        uint256 user1Balance = gbera.balanceOf(USER_1);
        uint256 user2Balance = gbera.balanceOf(USER_2);
        uint256 totalSupply = gbera.totalSupply();

        vm.startPrank(USER_3);
        if (amount > allowance) {
            vm.expectRevert();
            gbera.transferFrom(USER_2, USER_1, amount);
        } else {
            if (amount > user2Balance) {
                vm.expectRevert();
                gbera.transferFrom(USER_2, USER_1, amount);
            } else {
                gbera.transferFrom(USER_2, USER_1, amount);
                _assertEqWithTol(
                    gbera.balanceOf(USER_2),
                    user2Balance - amount,
                    100,
                    "gBERA user2 balance mismatch in 3 transferring from 2 to 1"
                );
                _assertEqWithTol(
                    gbera.balanceOf(USER_1),
                    user1Balance + amount,
                    100,
                    "gBERA user1 balance mismatch in 3 transferring from 2 to 1"
                );
                assertEq(
                    gbera.allowance(USER_2, USER_3),
                    allowance - amount,
                    "gBERA allowance mismatch in 3 transferring from 2 to 1"
                );
                _assertEqWithTol(
                    gbera.totalSupply(), totalSupply, 100, "gBERA total supply mismatch in 3 transferring from 2 to 1"
                );
            }
        }

        vm.stopPrank();
    }

    function _user1MintsGberaToUser2(uint256 amount) internal {
        console.log("_user1MintsGberaToUser2");
        uint256 balance = USER_1.balance;
        uint256 managerBalance = address(manager).balance;
        uint256 user2Balance = gbera.balanceOf(USER_2);
        uint256 totalSupply = gbera.totalSupply();
        uint256 gberaValue = gbera.getRebasedAmount(1 ether, false);
        uint256 totalAssets = manager.totalAssets();

        vm.startPrank(USER_1);

        if (amount > balance) {
            vm.expectRevert();
            gbera.deposit{ value: amount }(USER_2);
        } else {
            gbera.deposit{ value: amount }(USER_2);
            _assertEqWithTol(
                gbera.balanceOf(USER_2), user2Balance + amount, 100, "gBERA user2 balance mismatch in 1 minting to 2"
            );
            assertEq(USER_1.balance, balance - amount, "BERA user1 balance mismatch in 1 minting to 2");
            assertEq(address(manager).balance, managerBalance + amount, "BERA manager balance mismatch 1 minting to 2");
            assertEq(gbera.totalSupply(), totalSupply + amount, "gBERA total supply mismatch 1 minting to 2");
            assertEq(manager.totalAssets(), totalAssets + amount, "manager total assets mismatch 1 minting to 2");
            _assertEqWithTol(
                gbera.getRebasedAmount(1 ether, false), gberaValue, 1e10, "gBERA value mismatch 1 minting to 2"
            );
        }

        vm.stopPrank();
    }

    function _user2MintsGberaToUser1(uint256 amount) internal {
        console.log("_user2MintsGberaToUser1");
        uint256 balance = USER_2.balance;
        uint256 managerBalance = address(manager).balance;
        uint256 user1Balance = gbera.balanceOf(USER_1);
        uint256 totalSupply = gbera.totalSupply();
        uint256 gberaValue = gbera.getRebasedAmount(1 ether, false);
        uint256 gberaInverseValue = gbera.getUnrebasedAmount(1 ether, false);
        uint256 totalAssets = manager.totalAssets();

        vm.startPrank(USER_2);

        if (amount > balance) {
            vm.expectRevert();
            gbera.deposit{ value: amount }(USER_1);
        } else {
            gbera.deposit{ value: amount }(USER_1);
            _assertEqWithTol(
                gbera.balanceOf(USER_1), user1Balance + amount, 100, "gBERA user1 balance mismatch in 2 minting to 1"
            );
            assertEq(USER_2.balance, balance - amount, "BERA user2 balance mismatch in 2 minting to 1");
            assertEq(address(manager).balance, managerBalance + amount, "BERA manager balance mismatch 2 minting to 1");
            assertEq(gbera.totalSupply(), totalSupply + amount, "gBERA total supply mismatch 2 minting to 1");
            assertEq(manager.totalAssets(), totalAssets + amount, "manager total assets mismatch 2 minting to 1");
            _assertEqWithTol(
                gbera.getRebasedAmount(1 ether, false), gberaValue, 1e10, "gBERA value mismatch 2 minting to 1"
            );
            _assertEqWithTol(
                gbera.getUnrebasedAmount(1 ether, false),
                gberaInverseValue,
                1e10,
                "gBERA inverse value mismatch 2 minting to 1"
            );
        }

        vm.stopPrank();
    }

    function _user1RequestsWithdrawalForUser2(uint256 amount) internal {
        console.log("_user1RequestsWithdrawalForUser2");
        uint256 user1Balance = gbera.balanceOf(USER_1);
        uint256 withdrawalQueueBalance = gbera.balanceOf(address(withdrawalQueue));
        uint256 user2WQBalance = withdrawalQueue.balanceOf(USER_2);
        uint256 lastRequestId = withdrawalQueue.lastRequestId();
        uint256 cumulativeWithdrawnShares = withdrawalQueue.cumulativeWithdrawnShares(lastRequestId);
        uint256 totalSupply = gbera.totalSupply();
        uint256 totalAssets = manager.totalAssets();

        vm.startPrank(USER_1);

        if (amount > user1Balance) {
            vm.expectRevert();
            gbera.requestWithdrawal(amount, USER_2);
        } else {
            gbera.requestWithdrawal(amount, USER_2);
            _assertEqWithTol(
                gbera.balanceOf(USER_1),
                user1Balance - amount,
                100,
                "gBERA user1 balance mismatch in 1 requesting withdrawal for 2"
            );
            _assertEqWithTol(
                gbera.balanceOf(address(withdrawalQueue)),
                withdrawalQueueBalance + amount,
                100,
                "gBERA withdrawalQueue balance mismatch in 1 requesting withdrawal for 2"
            );
            assertEq(
                withdrawalQueue.balanceOf(USER_2),
                user2WQBalance + 1,
                "withdrawalQueue user2 balance mismatch in 1 requesting withdrawal for 2"
            );
            assertEq(
                withdrawalQueue.lastRequestId(),
                lastRequestId + 1,
                "withdrawalQueue lastRequestId mismatch in 1 requesting withdrawal for 2"
            );
            assertEq(gbera.totalSupply(), totalSupply, "gBERA total supply mismatch in 1 requesting withdrawal for 2");
            assertEq(
                manager.totalAssets(), totalAssets, "MANAGER total assets mismatch in 1 requesting withdrawal for 2"
            );

            (address payable requester, uint256 pooled,) = withdrawalQueue.withdrawalQueue(lastRequestId + 1);
            assertEq(requester, USER_2, "requester mismatch in 1 requesting withdrawal for 2");
            _assertEqWithTol(
                pooled,
                gbera.getUnrebasedAmount(amount, false),
                1e10,
                "pooled mismatch in 1 requesting withdrawal for 2"
            );
            assertEq(
                withdrawalQueue.cumulativeWithdrawnShares(lastRequestId + 1),
                cumulativeWithdrawnShares + pooled,
                "cumulativeWithdrawnShares mismatch in 1 requesting withdrawal for 2"
            );
        }

        vm.stopPrank();
    }

    function _user2RequestsWithdrawalForUser1(uint256 amount) internal {
        console.log("_user2RequestsWithdrawalForUser1");
        uint256 user2Balance = gbera.balanceOf(USER_2);
        uint256 withdrawalQueueBalance = gbera.balanceOf(address(withdrawalQueue));
        uint256 user1WQBalance = withdrawalQueue.balanceOf(USER_1);
        uint256 lastRequestId = withdrawalQueue.lastRequestId();
        uint256 cumulativeWithdrawnShares = withdrawalQueue.cumulativeWithdrawnShares(lastRequestId);
        uint256 totalSupply = gbera.totalSupply();
        uint256 totalAssets = manager.totalAssets();

        vm.startPrank(USER_2);

        if (amount > user2Balance) {
            vm.expectRevert();
            gbera.requestWithdrawal(amount, USER_1);
        } else {
            gbera.requestWithdrawal(amount, USER_1);
            _assertEqWithTol(
                gbera.balanceOf(USER_2),
                user2Balance - amount,
                100,
                "gBERA user2 balance mismatch in 2 requesting withdrawal for 1"
            );
            _assertEqWithTol(
                gbera.balanceOf(address(withdrawalQueue)),
                withdrawalQueueBalance + amount,
                100,
                "gBERA withdrawalQueue balance mismatch in 2 requesting withdrawal for 1"
            );
            assertEq(
                withdrawalQueue.balanceOf(USER_1),
                user1WQBalance + 1,
                "withdrawalQueue user1 balance mismatch in 2 requesting withdrawal for 1"
            );
            assertEq(
                withdrawalQueue.lastRequestId(),
                lastRequestId + 1,
                "withdrawalQueue lastRequestId mismatch in 2 requesting withdrawal for 1"
            );
            assertEq(gbera.totalSupply(), totalSupply, "gBERA total supply mismatch in 2 requesting withdrawal for 1");
            assertEq(
                manager.totalAssets(), totalAssets, "MANAGER total assets mismatch in 2 requesting withdrawal for 1"
            );

            (address payable requester, uint256 pooled,) = withdrawalQueue.withdrawalQueue(lastRequestId + 1);
            assertEq(requester, USER_1, "requester mismatch in 2 requesting withdrawal for 1");
            _assertEqWithTol(
                pooled,
                gbera.getUnrebasedAmount(amount, false),
                1e10,
                "pooled mismatch in 2 requesting withdrawal for 1"
            );
            assertEq(
                withdrawalQueue.cumulativeWithdrawnShares(lastRequestId + 1),
                cumulativeWithdrawnShares + pooled,
                "cumulativeWithdrawnShares mismatch in 2 requesting withdrawal for 1"
            );
        }

        vm.stopPrank();
    }

    /// Since who completes withdrawal is irrelevant, we just need one of these tests
    function _user3CompletesWithdrawal(uint256 id, uint256 batchIndex) internal {
        console.log("_user3CompletesWithdrawal");
        (uint256 lowerIndex, uint256 upperIndex, uint256 beraAmount) = withdrawalQueue.processedBatches(batchIndex);
        (address requester, uint256 pooled,) = withdrawalQueue.withdrawalQueue(id);
        uint256 requesterBalance = requester.balance;
        uint256 wqBalance = address(withdrawalQueue).balance;
        uint256 totalSupply = gbera.totalSupply();
        uint256 totalAssets = manager.totalAssets();

        vm.startPrank(USER_3);
        if (id < lowerIndex || id > upperIndex) {
            vm.expectRevert("IndexNotBelongingToBatch()");
            gbera.completeWithdrawal(id, batchIndex);
        } else {
            uint256 pooledBeraOfBatch = withdrawalQueue.cumulativeWithdrawnShares(upperIndex)
                - withdrawalQueue.cumulativeWithdrawnShares(lowerIndex - 1);
            uint256 toTransfer = pooled * beraAmount / pooledBeraOfBatch;
            assertGe(wqBalance, toTransfer, "Withdrawal queue should have enough BERA at this point, but it doesn't");
            gbera.completeWithdrawal(id, batchIndex);
            assertEq(
                requester.balance,
                requesterBalance + toTransfer,
                "Requester BERA balance mismatch in user 1 completing withdrawal"
            );
            assertEq(
                address(withdrawalQueue).balance,
                wqBalance - toTransfer,
                "WithdrawalQueue BERA balance mismatch in user 1 completing withdrawal"
            );
            assertEq(gbera.totalSupply(), totalSupply, "gBERA totalSupply mismatch in user 1 completing withdrawal");
            assertEq(
                manager.totalAssets(), totalAssets, "manager totalAssets mismatch in user 1 completing withdrawal"
            );
            vm.expectRevert();
            withdrawalQueue.ownerOf(id);
        }

        vm.stopPrank();
    }

    //////////// ADMIN ACTIONS //////////////

    function _adminProcessesWithdrawalQueue(uint256 reqId) internal {
        console.log("_adminProcessesWithdrawalQueue");
        vm.startPrank(OWNER);
        manager.processWithdrawalQueue(reqId);
        vm.stopPrank();
    }

    function _adminWithdrawFromVault(uint256 amount, bytes calldata pk) internal {
        console.log("_adminWithdrawFromVault");
        vm.startPrank(OWNER);
        manager.withdrawWithdrawals(amount, pk);
        vm.stopPrank();
    }

    function _adminDeposits(bytes calldata pk, uint256 amount) internal {
        console.log("_adminDeposits");
        vm.startPrank(OWNER);
        manager.deposit(pk, amount);
        vm.stopPrank();
    }

    //////////// EXTERNAL ACTIONS //////////////

    function _user3TransfersBeraToManager(uint256 amount) internal {
        console.log("_user3TransfersBeraToManager");
        uint256 managerBalance = address(manager).balance;
        uint256 totalSupply = gbera.totalSupply();
        uint256 gberaValue = gbera.getRebasedAmount(1 ether, false);
        uint256 gberaInverseValue = gbera.getUnrebasedAmount(1 ether, false);
        uint256 totalAssets = manager.totalAssets();
        vm.deal(USER_3, amount);
        vm.prank(USER_3);
        (bool success,) = payable(address(manager)).call{ value: amount }("");
        if (!success) revert("BERA transfer to manager failed");

        assertEq(address(manager).balance, managerBalance + amount, "BERA manager balance mismatch 2 minting to 1");
        assertEq(gbera.totalSupply(), totalSupply + amount, "gBERA total supply mismatch 2 minting to 1");
        assertEq(manager.totalAssets(), totalAssets + amount, "manager total assets mismatch 2 minting to 1");
        (gbera.getRebasedAmount(1 ether, false), gberaValue, "gBERA value mismatch 2 minting to 1");
        assertLe(
            gbera.getUnrebasedAmount(1 ether, false), gberaInverseValue, "gBERA inverse value mismatch 2 minting to 1"
        );
    }

    /////////////////////////////////////
    /////////////////////////////////////
    ////////////// TESTS ////////////////
    /////////////////////////////////////
    /////////////////////////////////////

    function testMultipleMintsAndTransfers(uint256 amount, uint256 seed) public {
        amount = amount % 1_000_000 ether + 1e18;
        seed = seed % 1_000_000 + 1e10;
        uint256 initialAmount = amount;
        uint256 initialSeed = seed;
        vm.deal(USER_1, initialAmount);
        vm.deal(USER_2, initialAmount);
        vm.deal(USER_3, initialAmount);
        _user1MintsGberaToUser2(amount);
        amount = uint256(keccak256(abi.encodePacked(amount * seed + 15))) % initialAmount;
        seed = uint256(keccak256(abi.encodePacked(amount * seed + 13))) % initialSeed;
        _user2TransfersGberaTo1(amount);
        amount = uint256(keccak256(abi.encodePacked(amount * seed + 15))) % initialAmount;
        seed = uint256(keccak256(abi.encodePacked(amount * seed + 13))) % initialSeed;
        _user3TransfersBeraToManager(amount);
        amount = uint256(keccak256(abi.encodePacked(amount * seed + 15))) % initialAmount;
        seed = uint256(keccak256(abi.encodePacked(amount * seed + 13))) % initialSeed;
        _user2MintsGberaToUser1(amount);
        amount = uint256(keccak256(abi.encodePacked(amount * seed + 15))) % initialAmount;
        seed = uint256(keccak256(abi.encodePacked(amount * seed + 13))) % initialSeed;
        _user3TransfersBeraToManager(amount);
        amount = uint256(keccak256(abi.encodePacked(amount * seed + 15))) % initialAmount;
        seed = uint256(keccak256(abi.encodePacked(amount * seed + 13))) % initialSeed;
        _user2TransfersGberaTo1(amount);
        amount = uint256(keccak256(abi.encodePacked(amount * seed + 15))) % initialAmount;
        seed = uint256(keccak256(abi.encodePacked(amount * seed + 13))) % initialSeed;
        _user1ApprovesUser3(amount);
        _user3TransfersGberaFromUser1ToUser2(amount);
    }

    function testWithdrawalQueue(uint256 amount, uint256 seed) public {
        vm.prank(OWNER);
        gbera.setWithdrawalEnabled(true);

        amount = amount % 1_000_000 ether + 1e18;
        seed = seed % 1_000_000 + 1e10;
        uint256 initialAmount = amount;
        uint256 initialSeed = seed;
        vm.deal(USER_1, initialAmount * 1e10);
        vm.deal(USER_2, initialAmount * 1e10);
        vm.deal(USER_3, initialAmount * 1e10);
        _user1MintsGberaToUser2(amount);
        amount = uint256(keccak256(abi.encodePacked(amount * seed + 15))) % initialAmount;
        seed = uint256(keccak256(abi.encodePacked(amount * seed + 13))) % initialSeed;
        _user3TransfersBeraToManager(amount);
        amount = uint256(keccak256(abi.encodePacked(amount * seed + 15))) % initialAmount;
        seed = uint256(keccak256(abi.encodePacked(amount * seed + 13))) % initialSeed;
        _user1MintsGberaToUser2(amount);
        amount = uint256(keccak256(abi.encodePacked(amount * seed + 15))) % initialAmount;
        seed = uint256(keccak256(abi.encodePacked(amount * seed + 13))) % initialSeed;
        _user2MintsGberaToUser1(amount);
        amount = uint256(keccak256(abi.encodePacked(amount * seed + 15))) % initialAmount;
        seed = uint256(keccak256(abi.encodePacked(amount * seed + 13))) % initialSeed;
        _user3TransfersBeraToManager(amount);
        // Requests withdrawal
        uint256 bal = gbera.balanceOf(USER_1);
        amount = bal == 0 ? 0 : amount % bal;
        _user1RequestsWithdrawalForUser2(amount);
        amount = uint256(keccak256(abi.encodePacked(amount * seed + 15))) % initialAmount;
        seed = uint256(keccak256(abi.encodePacked(amount * seed + 13))) % initialSeed;
        _user3TransfersBeraToManager(amount);
        // Withdrawal Queue Processing
        _adminProcessesWithdrawalQueue(1);
        _user3CompletesWithdrawal(1, 1);
    }

    /// from audit
    function test_submitRequest_lowerBound() public {
        vm.prank(OWNER);
        gbera.setWithdrawalEnabled(true);

        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");
        uint256 amount1 = 1e18;
        uint256 amount2 = 10e18;

        vm.deal(user1, amount1);
        vm.deal(user2, amount2);
        vm.prank(user1);
        gbera.deposit{ value: amount1 }(user1);
        vm.prank(user2);
        gbera.deposit{ value: amount2 }(user2);

        vm.prank(user1);
        gbera.requestWithdrawal(amount1, user1);

        vm.prank(address(user1));
        manager.processWithdrawalQueue(1);

        // user1 withdrawal requestId = 1, batch = 1 (lower=1, upper=1)

        // donate, this increases assets (share price increases)
        vm.deal(address(manager), address(manager).balance + 10e18);

        vm.prank(user2);
        gbera.requestWithdrawal(amount2, user2);

        vm.prank(address(user2));
        manager.processWithdrawalQueue(2);

        // user2 withdrawal requestId = 2, batch = 2 (lower=2, upper=2)

        vm.startPrank(address(user1));

        vm.expectRevert(abi.encodeWithSignature("IndexNotBelongingToBatch()"));
        gbera.completeWithdrawal(1, 2); // use incorrect batch (2) for requestId = 1 reverts

        gbera.completeWithdrawal(1, 1);

        vm.stopPrank();

        assertEq(user1.balance, 1e18);

        vm.prank(user2);
        gbera.completeWithdrawal(2, 2);

        assertEq(user2.balance, 10e18);
    }
}
