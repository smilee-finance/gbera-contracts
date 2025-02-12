// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseTest } from "./Base.t.sol";

import { Test } from "forge-std/Test.sol";
import { IGBeraErrors } from "src/interfaces/IGBeraErrors.sol";
import { INodeFeeReceiver } from "src/interfaces/INodeFeeReceiver.sol";

contract NodeFeeReceiverTest is BaseTest {
    uint256 public constant NODE_FEE_RECEIVER_BALANCE = 1_000_000 ether; // 1 million ether

    function setUp() public override {
        super.setUp();
        vm.deal(address(nodeFeeReceiver), NODE_FEE_RECEIVER_BALANCE);
    }

    function test_upgradeTo_NotOwner() public {
        vm.expectRevert();
        gbera.upgradeToAndCall(address(0x123), new bytes(0));
    }

    function test_collectReward() public {
        vm.expectEmit(true, true, false, true);
        emit INodeFeeReceiver.RewardCollected(NODE_FEE_RECEIVER_BALANCE);
        nodeFeeReceiver.collectRewards();
        assertEq(address(nodeFeeReceiver).balance, 0);
        assertEq(address(manager).balance, NODE_FEE_RECEIVER_BALANCE);
    }

    function test_earnedReward() public view {
        assertEq(nodeFeeReceiver.earned(), NODE_FEE_RECEIVER_BALANCE);
    }
}
