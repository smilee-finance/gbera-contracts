// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseTest } from "./Base.t.sol";

import { MockDepositContract } from "./mock/MockDepositContract.sol";
import { MockNodeRegistry } from "./mock/MockNodeRegistry.sol";
import { Test } from "forge-std/Test.sol";
import { IGBera } from "src/interfaces/IGBera.sol";
import { IGBeraErrors } from "src/interfaces/IGBeraErrors.sol";
import { INodeRegistry } from "src/interfaces/INodeRegistry.sol";

contract NodeRegistryTest is BaseTest {
    uint256 firstDepositAmount = 10_000 ether;
    bytes publicKey = _create48Byte();
    bytes signature = _create96Byte();
    string name = "testNode";

    function setUp() public override {
        super.setUp();
        _deployMockedContracts();
    }

    function test_owner() public view {
        assertEq(registry.owner(), OWNER);
    }

    function test_upgradeTo_NotOwner() public {
        vm.expectRevert();
        gbera.upgradeToAndCall(address(0x123), new bytes(0));
    }

    function testFuzz_setMaxAllocation(uint256 newMaxAllocation) public {
        vm.expectEmit(true, true, false, true);
        emit INodeRegistry.MaxAllocationUpdated(registry.maxAllocation(), newMaxAllocation);
        vm.prank(OWNER);
        registry.setMaxAllocation(newMaxAllocation);
        assertEq(registry.maxAllocation(), newMaxAllocation);
    }

    function test_setMaxAllocation_Fail_NotOwner() public {
        vm.expectRevert();
        registry.setMaxAllocation(1 ether);
    }

    function test_createNode() public {
        uint256 oldLength = registry.getAllNodes().length;
        vm.expectEmit(true, true, false, true);
        emit INodeRegistry.NodeCreated(publicKey, name);
        vm.prank(OWNER);
        registry.createNode(publicKey, signature, name);
        assertEq(registry.getAllNodes().length, oldLength + 1);
    }

    function test_createNode_Fail_InconsistentPublicKey() public {
        vm.prank(OWNER);
        vm.expectRevert(IGBeraErrors.InconsistentPublicKey.selector);
        registry.createNode(_create96Byte(), _create96Byte(), "testNode");
    }

    function test_createNode_Fail_InconsistentSignature() public {
        vm.prank(OWNER);
        vm.expectRevert(IGBeraErrors.InconsistentSignature.selector);
        registry.createNode(_create48Byte(), _create48Byte(), "testNode");
    }

    function test_createNode_Fail_NotOwner() public {
        vm.expectRevert();
        registry.createNode(_create96Byte(), _create48Byte(), "testNode");
    }

    function test_createNode_Fail_NodeAlreadyExists() public {
        test_createNode();
        vm.expectRevert(IGBeraErrors.NodeAlreadyExists.selector);
        vm.prank(OWNER);
        registry.createNode(publicKey, signature, name);
    }

    function test_setNodeActivationStatus() public {
        test_createNode();
        // simulate first deposit
        vm.prank(address(manager));
        registry.increaseNodeStake(publicKey, firstDepositAmount);

        vm.expectEmit(true, true, false, true);
        emit INodeRegistry.NodeActivationStatusUpdated(publicKey, false);
        vm.prank(OWNER);
        registry.setNodeActivationStatus(publicKey, false);
        assertEq(registry.getNodeData(publicKey).isActive, false);

        vm.expectEmit(true, true, false, true);
        emit INodeRegistry.NodeActivationStatusUpdated(publicKey, true);
        vm.prank(OWNER);
        registry.setNodeActivationStatus(publicKey, true);
        assertEq(registry.getNodeData(publicKey).isActive, true);
    }

    function test_setNodeActivationStatus_Fail_NotOwner() public {
        vm.expectRevert();
        registry.setNodeActivationStatus(publicKey, false);
    }

    function test_setNodeActivationStatus_Fail_NodeNotFound() public {
        vm.expectRevert(IGBeraErrors.NodeNotFound.selector);
        vm.prank(OWNER);
        registry.setNodeActivationStatus(publicKey, false);
    }

    function test_setNodeActivationStatus_Fail_FirstDepositNotPerformed() public {
        test_createNode();

        vm.expectRevert(IGBeraErrors.FirstDepositNotPerformed.selector);
        vm.prank(OWNER);
        registry.setNodeActivationStatus(publicKey, true);
    }

    function testFuzz_increaseNodeStake(uint256 amount) public {
        amount = bound(amount, 1, registry.maxAllocation() - firstDepositAmount);
        test_createNode();
        // simulate first deposit
        vm.prank(address(manager));
        registry.increaseNodeStake(publicKey, firstDepositAmount);

        vm.prank(OWNER);
        registry.setNodeActivationStatus(publicKey, true);

        vm.prank(address(manager));
        vm.expectEmit(true, true, false, true);
        emit INodeRegistry.NodeStakeAmountUpdated(publicKey, firstDepositAmount + amount);
        registry.increaseNodeStake(publicKey, amount);
        assertEq(registry.getNodeData(publicKey).stakeAmount, firstDepositAmount + amount);
        assertEq(registry.getNodeData(publicKey).lastUpdate, block.timestamp);
    }

    function test_increaseNodeStake_Fail_NotManager() public {
        vm.expectRevert(IGBeraErrors.NotManager.selector);
        registry.increaseNodeStake(publicKey, 1 ether);
    }

    function test_increaseNodeStake_Fail_NodeNotFound() public {
        vm.expectRevert(IGBeraErrors.NodeNotFound.selector);
        vm.prank(address(manager));
        registry.increaseNodeStake(publicKey, 1 ether);
    }

    function test_increaseNodeStake_Fail_NodeNotActive() public {
        test_createNode();

        // simulate first deposit
        vm.prank(address(manager));
        registry.increaseNodeStake(publicKey, 1 ether);

        vm.expectRevert(IGBeraErrors.NodeNotActive.selector);
        vm.prank(address(manager));
        registry.increaseNodeStake(publicKey, 1 ether);
    }

    function test_increaseNodeStake_Fail_MaxAllocationReached() public {
        testFuzz_increaseNodeStake(registry.maxAllocation() - firstDepositAmount); // reach max allocation

        vm.expectRevert(IGBeraErrors.AmountTooHigh.selector);
        vm.prank(address(manager));
        registry.increaseNodeStake(publicKey, 1);
    }

    function testFuzz_deallocateNode(uint256 amount) public {
        testFuzz_increaseNodeStake(32 ether);
        amount = bound(amount, 1, 32 ether);

        vm.expectEmit(true, true, false, true);
        emit INodeRegistry.NodeStakeAmountUpdated(publicKey, firstDepositAmount + 32 ether - amount);
        vm.prank(OWNER);
        registry.deallocateNode(publicKey, amount);
        assertEq(registry.getNodeData(publicKey).stakeAmount, firstDepositAmount + 32 ether - amount);
        assertEq(registry.getNodeData(publicKey).lastUpdate, block.timestamp);
    }

    function test_deallocateNode_Fail_NotOwner() public {
        vm.expectRevert();
        registry.deallocateNode(publicKey, 1 ether);
    }

    function test_deallocateNode_Fail_NodeNotFound() public {
        vm.expectRevert(IGBeraErrors.NodeNotFound.selector);
        vm.prank(OWNER);
        registry.deallocateNode(publicKey, 1 ether);
    }

    function test_deallocateNode_Fail_NodeNotActive() public {
        testFuzz_increaseNodeStake(25 ether);
        vm.prank(OWNER);
        registry.setNodeActivationStatus(publicKey, false);

        vm.expectRevert(IGBeraErrors.NodeNotActive.selector);
        vm.prank(OWNER);
        registry.deallocateNode(publicKey, 25 ether);
    }

    function test_deallocateNode_Fail_AmountTooHigh() public {
        testFuzz_increaseNodeStake(25 ether);
        vm.expectRevert(IGBeraErrors.AmountTooHigh.selector);
        vm.prank(OWNER);
        registry.deallocateNode(publicKey, firstDepositAmount + 32 ether);
    }

    function testFuzz_registerWithdrawal(uint256 amount) public {
        testFuzz_increaseNodeStake(32 ether);
        amount = bound(amount, 1, 32 ether);

        vm.expectEmit(true, true, false, true);
        emit INodeRegistry.NodeStakeAmountUpdated(publicKey, firstDepositAmount + 32 ether - amount);
        vm.prank(address(manager));
        registry.registerWithdrawal(publicKey, amount);
        assertEq(registry.getNodeData(publicKey).stakeAmount, firstDepositAmount + 32 ether - amount);
        assertEq(registry.getNodeData(publicKey).lastUpdate, block.timestamp);
    }

    function test_registerWithdrawal_Fail_NotManager() public {
        vm.expectRevert();
        registry.registerWithdrawal(publicKey, 1 ether);
    }

    function test_registerWithdrawal_Fail_NodeNotFound() public {
        vm.expectRevert(IGBeraErrors.NodeNotFound.selector);
        vm.prank(address(manager));
        registry.registerWithdrawal(publicKey, 1 ether);
    }

    function test_registerWithdrawal_Fail_NodeNotActive() public {
        testFuzz_increaseNodeStake(25 ether);
        vm.prank(OWNER);
        registry.setNodeActivationStatus(publicKey, false);

        vm.expectRevert(IGBeraErrors.NodeNotActive.selector);
        vm.prank(address(manager));
        registry.registerWithdrawal(publicKey, 25 ether);
    }

    function test_registerWithdrawal_Fail_AmountTooHigh() public {
        testFuzz_increaseNodeStake(25 ether);
        vm.expectRevert(IGBeraErrors.AmountTooHigh.selector);
        vm.prank(address(manager));
        registry.registerWithdrawal(publicKey, firstDepositAmount + 32 ether);
    }

    function test_getNodeData() public {
        test_createNode();
        assertEq(registry.getNodeData(publicKey).name, name);
        assertEq(registry.getNodeData(publicKey).isActive, false);
        assertEq(registry.getNodeData(publicKey).stakeAmount, 0);
        assertEq(registry.getNodeData(publicKey).lastUpdate, block.timestamp);
        assertEq(registry.getNodeData(publicKey).publicKey, publicKey);
        assertEq(registry.getNodeData(publicKey).signature, signature);

        uint96 wcPrefix = 0x010000000000000000000000;
        bytes memory withdrawalCredentials = abi.encodePacked(wcPrefix, withdrawalVault);
        assertEq(registry.getNodeData(publicKey).withdrawalCredentials, withdrawalCredentials);
    }

    function test_getNodeData_Fail_NodeNotFound() public {
        vm.expectRevert(IGBeraErrors.NodeNotFound.selector);
        registry.getNodeData(publicKey);
    }

    function test_getAllNodes() public {
        test_createNode();
        assertEq(registry.getAllNodes().length, 1);
        assertEq(registry.getAllNodes()[0], publicKey);
    }

    function test_getAllNodes_No_Nodes() public view {
        assertEq(registry.getAllNodes().length, 0);
    }

    function test_getLastNodePK() public {
        test_createNode();
        assertEq(registry.getLastNodePK(), publicKey);
    }

    function test_getLastNodePK_Fail_NodeNotFound() public {
        vm.expectRevert(IGBeraErrors.NodeNotFound.selector);
        registry.getLastNodePK();
    }

    function test_WithdrawalCredentials() public {
        MockNodeRegistry mockRegistry = new MockNodeRegistry();
        address mockAddr = address(0x1234123412341234123412341234123412341234);
        uint256 expectedCredN = 0x0100000000000000000000001234123412341234123412341234123412341234;
        bytes memory expectedCred = abi.encodePacked(expectedCredN);
        assertEq(mockRegistry.withdrawalAddressToCredentials(mockAddr), expectedCred);
    }
}
