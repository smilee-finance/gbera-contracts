// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { console2 } from "forge-std/console2.sol";

import { BaseTest } from "./Base.t.sol";
import { MockBGT } from "./mock/MockBGT.sol";
import { MockBGTStaker } from "./mock/MockBGTStaker.sol";
import { MockDepositContract } from "./mock/MockDepositContract.sol";
import { MockWBERA } from "./mock/MockWBERA.sol";

import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { Test } from "forge-std/Test.sol";
import { IGBera } from "src/interfaces/IGBera.sol";
import { IGBeraAssetManager } from "src/interfaces/IGBeraAssetManager.sol";
import { IGBeraErrors } from "src/interfaces/IGBeraErrors.sol";
import { IBGT } from "src/interfaces/external/IBGT.sol";

contract GBeraAssetManagerTest is BaseTest {
    bytes publicKey = _create48Byte();
    address gBeraAssetManagerOperator = makeAddr("gBeraAssetManagerOperator");
    bytes notOwnerSel;
    bytes notOperatorSel;

    function setUp() public override {
        super.setUp();
        _deployMockedContracts();

        bytes32 managerOperatorRole = manager.OPERATOR_ROLE();
        vm.prank(OWNER);
        manager.grantRole(managerOperatorRole, gBeraAssetManagerOperator);

        notOwnerSel = abi.encodeWithSelector(
            IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), manager.DEFAULT_ADMIN_ROLE()
        );
        notOperatorSel = abi.encodeWithSelector(
            IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), manager.OPERATOR_ROLE()
        );
    }

    function test_admin() public view {
        assertEq(manager.hasRole(manager.DEFAULT_ADMIN_ROLE(), OWNER), true);
    }

    function test_upgradeTo_NotAdmin() public {
        vm.expectRevert();
        gbera.upgradeToAndCall(address(0x123), new bytes(0));
    }

    function testFuzz_setNodeFeeReceiver(address newNodeFeeReceiver) public {
        vm.assume(newNodeFeeReceiver != address(0));
        address oldNodeFeeReceiver = address(manager.nodeFeeReceiver());
        vm.expectEmit(true, true, false, true);
        emit IGBeraAssetManager.NodeFeeReceiverUpdated(oldNodeFeeReceiver, newNodeFeeReceiver);
        vm.prank(OWNER);
        manager.setNodeFeeReceiver(newNodeFeeReceiver);
        assertEq(address(manager.nodeFeeReceiver()), newNodeFeeReceiver);
    }

    function test_setNodeFeeReceiver_Fail_ZeroAddress() public {
        vm.prank(OWNER);
        vm.expectRevert(IGBeraErrors.AddressZero.selector);
        manager.setNodeFeeReceiver(address(0));
    }

    function test_setNodeFeeReceiver_Fail_NotOwner() public {
        vm.expectRevert();
        manager.setNodeFeeReceiver(address(0x123));
    }

    function test_firstDepositFailsIfInvalidAmount() public {
        _createNode(publicKey);
        uint256 amount = manager.minDepositAmount() + 1;
        vm.deal(address(manager), amount);
        vm.prank(OWNER);

        vm.expectRevert(IGBeraErrors.InvalidDepositAmount.selector);
        manager.deposit(publicKey, amount);
    }

    function test_firstDeposit() public {
        _createNode(publicKey);
        uint256 amount = manager.minDepositAmount();
        vm.deal(address(manager), amount);
        vm.prank(OWNER);

        vm.expectEmit(true, true, false, true);
        emit IGBeraAssetManager.Deposit(publicKey, amount);
        manager.deposit(publicKey, amount);

        assertEq(registry.getNodeData(publicKey).stakeAmount, amount);
    }

    /// @notice Also performs a first deposit, comprised in the given amount.
    function testFuzz_deposit(uint256 amountInGwei) public {
        amountInGwei = bound(amountInGwei, 20_000 gwei, 1_000_000_000 gwei);

        // make first deposit and activate node to enable testing fuzz deposit
        test_firstDeposit();
        vm.prank(OWNER);
        registry.setNodeActivationStatus(publicKey, true);

        uint256 iniStakeGwei = manager.minDepositAmount() / 1 gwei;
        vm.prank(OWNER);
        registry.setMaxAllocation(1_000_000_000 ether); // increase max allocation to 1000000000 ether
        uint256 amount = 1 gwei * (amountInGwei - iniStakeGwei);

        vm.deal(address(manager), amount);
        uint256 oldBalance = address(manager).balance;

        vm.expectEmit(true, true, false, true);
        emit IGBeraAssetManager.Deposit(publicKey, amount);
        vm.prank(OWNER);
        manager.deposit(publicKey, amount);

        assertEq(address(manager).balance, oldBalance - amount);
        assertEq(registry.getNodeData(publicKey).stakeAmount, amountInGwei * 1 gwei);
    }

    function test_deposit_Fail_NotMultipleOfGwei() public {
        uint256 amount = 2 * manager.minDepositAmount() + 1;
        testFuzz_deposit(amount);
    }

    function test_deposit_Fail_InvalidAmount() public {
        uint256 amount = manager.minDepositAmount() - 1; // less than minDepositAmount

        vm.deal(address(manager), amount);
        vm.prank(OWNER);
        vm.expectRevert(IGBeraErrors.InvalidDepositAmount.selector);
        manager.deposit(publicKey, amount);
    }

    function test_deposit_Fail_NotEnoughBalance() public {
        uint256 amount = manager.minDepositAmount() + 10 gwei;
        vm.deal(address(manager), amount - 1);
        assertLt(address(manager).balance, amount);

        vm.prank(OWNER);
        vm.expectRevert(IGBeraErrors.NotEnoughBalance.selector);
        manager.deposit(publicKey, amount);
    }

    function test_deposit_Fail_NotOwner() public {
        uint256 amount = manager.minDepositAmount() + 10 gwei;
        vm.deal(address(manager), amount);
        vm.expectRevert();
        manager.deposit(publicKey, amount);
    }

    function test_collectStakerRewards() public {
        // Send WBERA to BGT staker
        _setStakerReward(100e18);

        uint256 oldBalance = address(manager).balance;

        vm.expectEmit(true, true, false, true);
        emit IGBeraAssetManager.StakerRewardCollected(100e18);
        vm.prank(OWNER);
        manager.collectStakerRewards();

        assertEq(address(manager).balance, oldBalance + 100e18);
    }

    function test_withdrawWithdrawals() public {
        // Deposit 50_000e18
        testFuzz_deposit(50_000e9);
        vm.prank(OWNER);
        registry.setNodeActivationStatus(publicKey, true);

        vm.deal(address(withdrawalVault), 1000e18);

        vm.expectEmit(true, true, false, true);
        emit IGBeraAssetManager.WithdrawFromVault(100e18, publicKey);
        vm.prank(OWNER);
        manager.withdrawWithdrawals(100e18, publicKey);
    }

    function test_withdrawWithdrawals_Fail_NotOwner() public {
        vm.expectRevert();
        manager.withdrawWithdrawals(100e18, publicKey);
    }

    function test_processWithdrawalQueue() public {
        _mintGBera(100e18);
        _enableWithdrawal();
        _requestWithdrawal(10e18);

        uint256 oldBalance = address(manager).balance;

        vm.expectEmit(true, true, false, true);
        emit IGBeraAssetManager.WithdrawalQueueProcessed(1, 10e18, 10e18);
        manager.processWithdrawalQueue(1);

        assertEq(address(withdrawalQueue).balance, 10e18);
        assertEq(address(manager).balance, oldBalance - 10e18);
    }

    function test_processWithdrawalQueue_Fail_NotEnoughBalance() public {
        _mintGBera(100e18);
        _enableWithdrawal();
        _requestWithdrawal(10e18);
        testFuzz_deposit(5000e9);

        // Reduce manager balance to make processWithdrawalQueue fail
        vm.deal(address(manager), 1);
        vm.expectRevert(IGBeraErrors.NotEnoughBalance.selector);
        manager.processWithdrawalQueue(1);
    }

    function testFuzz_queueBoost(uint128 amount) public {
        // assume manager has enough BGT unboostedbalance
        vm.prank(gBeraAssetManagerOperator);
        manager.queueBoost(publicKey, amount);
    }

    function test_queueBoost_Fail_NotOperator() public {
        vm.expectRevert(notOperatorSel);
        manager.queueBoost(publicKey, 100e18);
    }

    function test_cancelBoost(uint128 cancelAmount) public {
        uint128 queuedAmount = 100e18;
        cancelAmount = uint128(_bound(uint256(cancelAmount), 1, uint256(queuedAmount)));
        testFuzz_queueBoost(queuedAmount);

        vm.prank(gBeraAssetManagerOperator);
        manager.cancelBoost(publicKey, 100e18);
    }

    function test_cancelBoost_Fail_NotOperator() public {
        vm.expectRevert(notOperatorSel);
        manager.cancelBoost(publicKey, 100e18);
    }

    function testFuzz_queueDropBoost(uint128 amount) public {
        uint128 queuedAmount = 100e18;
        amount = uint128(_bound(uint256(amount), 1, uint256(queuedAmount)));
        testFuzz_queueBoost(queuedAmount);
        vm.prank(gBeraAssetManagerOperator);
        manager.queueDropBoost(publicKey, amount);
    }

    function test_queueDropBoost_Fail_NotOperator() public {
        vm.expectRevert(notOperatorSel);
        manager.queueDropBoost(publicKey, 100e18);
    }

    function test_cancelDropBoost(uint128 cancelAmount) public {
        uint128 queuedAmount = 100e18;
        cancelAmount = uint128(_bound(uint256(cancelAmount), 1, uint256(queuedAmount)));
        testFuzz_queueDropBoost(queuedAmount);

        vm.prank(gBeraAssetManagerOperator);
        manager.cancelDropBoost(publicKey, cancelAmount);
    }

    function test_cancelDropBoost_Fail_NotOperator() public {
        vm.expectRevert(notOperatorSel);
        manager.cancelDropBoost(publicKey, 100e18);
    }

    function test_redeemBGT(uint128 amount) public {
        MockBGT(bgtAddress).setBalance(address(manager), amount);
        vm.prank(gBeraAssetManagerOperator);
        manager.redeemBGT(amount);
    }

    function test_redeemBGT_Fail_NotOperator() public {
        vm.expectRevert(notOperatorSel);
        manager.redeemBGT(100e18);
    }

    function test_totalAssets() public {
        // initial state
        assertEq(manager.totalAssets(), 0);

        // distribute balances
        vm.deal(address(manager), 100_000e18);
        // registry deposits is 0
        MockBGT(bgtAddress).setBalance(address(manager), 100e18); // manager has 100e18 BGT
        _setStakerReward(100e18); // means that manager has farmed 100e18 WBERA from the BGT staker
        vm.deal(address(nodeFeeReceiver), 100e18);

        // total available assets is 400e18
        assertEq(manager.totalAssets(), 100_300e18);

        // fi deposit, total assets should not change
        _createNode(publicKey);
        uint256 firstDepoAmount = manager.minDepositAmount();
        vm.prank(OWNER);
        manager.deposit(publicKey, firstDepoAmount);
        assertEq(manager.totalAssets(), 100_300e18);

        // if redeem BGT, total assets should not change
        vm.prank(gBeraAssetManagerOperator);
        manager.redeemBGT(50e18);
        assertEq(MockBGT(bgtAddress).balanceOf(address(manager)), 50e18);
        assertEq(manager.totalAssets(), 100_300e18);

        // if claim reward from BGT staker, total assets should not change
        manager.collectStakerRewards();
        assertEq(manager.totalAssets(), 100_300e18);

        // if withdraw from fee receiver, total assets should not change
        manager.collectNodeFeeRewards();
        assertEq(manager.totalAssets(), 100_300e18);
    }

    function testFuzz_setFeePercentage_Fail_InvalidValue(uint256 feePerc) public {
        feePerc = bound(feePerc, 1e18 + 1, type(uint256).max);
        vm.prank(OWNER);
        vm.expectRevert(IGBeraErrors.InvalidFeePercentage.selector);
        manager.setFeePercentage(feePerc);
    }

    function testFuzz_setFeePercentage_Fail_NotOwner(uint256 feePerc) public {
        feePerc = bound(feePerc, 0, 1e18);
        vm.expectRevert(notOwnerSel);
        manager.setFeePercentage(feePerc);
    }

    function testFuzz_setFeePercentage(uint256 feePerc) public {
        feePerc = bound(feePerc, 0, 1e18);
        assertEq(manager.feePercentage(), 0);

        vm.prank(OWNER);
        vm.expectEmit(true, true, false, true);
        emit IGBeraAssetManager.FeePercentageUpdated(0, feePerc);
        manager.setFeePercentage(feePerc);
        assertEq(manager.feePercentage(), feePerc);
    }

    function test_protocolFeesOnStakerReward() public {
        assertEq(manager.totalAssets(), 0);
        testFuzz_deposit(100_000e9); // deposit 100 K

        _setStakerReward(100e18);
        testFuzz_setFeePercentage(0.15e18);
        assertEq(manager.protocolFees(), 0);
        assertEq(manager.totalAssets(), 100_100e18); // 100K + 100

        _setStakerReward(100e18);
        assertEq(manager.protocolFees(), 15e18); // 100 * 0.15
        assertEq(manager.totalAssets(), 100_185e18); // 100K + 100 + 100 * 0.85
    }

    function test_protocolFeesOnNodeFeeReceiverReward() public {
        assertEq(manager.totalAssets(), 0);
        testFuzz_deposit(100_000e9); // deposit 100 K

        vm.deal(address(nodeFeeReceiver), 100e18);
        testFuzz_setFeePercentage(0.15e18);
        assertEq(manager.protocolFees(), 0);
        assertEq(manager.totalAssets(), 100_100e18); // 100K + 100

        vm.deal(address(nodeFeeReceiver), 100e18);
        assertEq(manager.protocolFees(), 15e18); // 100 * 0.15
        assertEq(manager.totalAssets(), 100_185e18); // 100K + 100 + 100 * 0.85
    }

    function test_protocolFeesOnBgtRewards() public {
        assertEq(manager.totalAssets(), 0);
        testFuzz_deposit(100_000e9); // deposit 100 K

        MockBGT(bgtAddress).setBalance(address(manager), 100e18);
        testFuzz_setFeePercentage(0.15e18);
        assertEq(manager.protocolFees(), 0);
        assertEq(manager.totalAssets(), 100_100e18); // 100K + 100

        MockBGT(bgtAddress).setBalance(address(manager), 200e18);
        assertEq(manager.protocolFees(), 15e18); // 100 * 0.15
        assertEq(manager.totalAssets(), 100_185e18); // 100K + 100 + 100 * 0.85
    }

    function test_protocolFeesOnAllRewards() public {
        assertEq(manager.totalAssets(), 0);

        testFuzz_deposit(50_000e9); // deposit 50 K
        vm.deal(address(manager), 50_000e18); // add 50 K more to manager balance

        MockBGT(bgtAddress).setBalance(address(manager), 100e18);
        _setStakerReward(100e18);
        vm.deal(address(nodeFeeReceiver), 100e18);
        testFuzz_setFeePercentage(0.15e18);
        assertEq(manager.protocolFees(), 0);
        assertEq(manager.totalAssets(), 100_300e18); // 100K + 300

        MockBGT(bgtAddress).setBalance(address(manager), 200e18);
        _setStakerReward(100e18);
        vm.deal(address(nodeFeeReceiver), 100e18);
        assertEq(manager.protocolFees(), 45e18); // 300 * 0.15
        assertEq(manager.totalAssets(), 100_555e18); // 100K + 300 + 300 * 0.85
    }

    function test_withdrawProtocolFees_Fail_NotOwner() public {
        test_protocolFeesOnAllRewards();
        vm.expectRevert(notOwnerSel);
        manager.withdrawProtocolFees(OWNER);
    }

    function test_withdrawProtocolFees_Fail_NotEnoughBalance() public {
        test_protocolFeesOnBgtRewards();
        manager.updateBgtFees(); // freeze protocol fees

        assertEq(address(manager).balance, 0); // everything is staked
        assertEq(IBGT(bgtAddress).balanceOf(address(manager)), 200 ether);

        // Since fees are only deriving from BGT rewards, fees will not be available if not redeemed
        vm.expectRevert(IGBeraErrors.NotEnoughBalance.selector);
        vm.prank(OWNER);
        manager.withdrawProtocolFees(OWNER);
    }

    function test_withdrawProtocolFees() public {
        test_protocolFeesOnStakerReward();
        manager.collectStakerRewards(); // freeze protocol fees

        uint256 vaultBalance0 = address(manager).balance;
        uint256 ownerBalance0 = OWNER.balance;

        vm.expectEmit(true, true, false, true);
        emit IGBeraAssetManager.ProtocolFeesWithdrawn(OWNER, 15e18);
        vm.prank(OWNER);
        manager.withdrawProtocolFees(OWNER);

        assertEq(address(manager).balance, vaultBalance0 - 15e18);
        assertEq(OWNER.balance, ownerBalance0 + 15e18);
        assertEq(manager.protocolFees(), 0);
    }

    //////////    HELPERS     //////////

    function _createNode(bytes memory _publicKey) internal {
        // MockDepositContract(depositContract).setOperator(_create48Byte(), address(manager));
        bytes memory signature = _create96Byte();
        string memory name = "testNode";

        vm.prank(OWNER);
        registry.createNode(_publicKey, signature, name);
    }

    function _mintGBera(uint256 amount) internal {
        vm.deal(USER, amount);
        vm.prank(USER);
        gbera.deposit{ value: amount }(USER);
    }

    function _requestWithdrawal(uint256 amount) internal {
        vm.prank(USER);
        gbera.requestWithdrawal(amount, USER);
    }

    function _enableWithdrawal() internal {
        vm.prank(OWNER);
        gbera.setWithdrawalEnabled(true);
    }

    function _setStakerReward(uint256 amount) internal {
        MockBGTStaker bgtStaker = MockBGTStaker(bgtStakerAddress);
        bgtStaker.setRewardValue(amount);
        _dealWbera(bgtStakerAddress, amount);
    }
}
