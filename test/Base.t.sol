// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";

import { Deployer } from "../src/Deployer.sol";
import { GBeraAssetManager } from "../src/GBeraAssetManager.sol";
import { NodeRegistry } from "../src/NodeRegistry.sol";

import { GBera } from "../src/GBera.sol";
import { NodeFeeReceiver } from "../src/NodeFeeReceiver.sol";
import { NodeWithdrawalVault } from "../src/NodeWithdrawalVault.sol";

import { WGBera } from "../src/WGBera.sol";
import { WithdrawalQueue } from "../src/WithdrawalQueue.sol";
import { WithdrawalQueue } from "../src/WithdrawalQueue.sol";

import { MockBGT } from "./mock/MockBGT.sol";
import { MockBGTStaker } from "./mock/MockBGTStaker.sol";
import { MockDepositContract } from "./mock/MockDepositContract.sol";
import { MockWBERA } from "./mock/MockWBERA.sol";

/// @notice A base contract for collecting useful properties in the system

contract BaseTest is Test {
    address public immutable OWNER = makeAddr("owner");
    address public immutable USER = makeAddr("user");

    NodeRegistry public registry;
    GBeraAssetManager public manager;
    GBera public gbera;
    WithdrawalQueue public withdrawalQueue;
    NodeWithdrawalVault public withdrawalVault;
    NodeFeeReceiver public nodeFeeReceiver;
    WGBera public wgbera;

    address internal depositContract = makeAddr("depositContract");
    address internal bgtAddress = makeAddr("bgtAddress");
    address internal bgtStakerAddress = makeAddr("bgtStakerAddress");
    address internal beraChefAddress = makeAddr("beraChefAddress");
    address internal wberaAddress = makeAddr("wberaAddress");

    function setUp() public virtual {
        Deployer deployer =
            new Deployer(OWNER, depositContract, bgtStakerAddress, bgtAddress, beraChefAddress, wberaAddress);

        manager = deployer.manager();
        registry = deployer.registry();
        gbera = deployer.gbera();
        withdrawalQueue = WithdrawalQueue(payable(address(deployer.withdrawalQueue())));
        withdrawalVault = deployer.withdrawalVault();
        nodeFeeReceiver = deployer.nodeFeeReceiver();
        wgbera = deployer.wgbera();
    }

    /// @notice Addresses are set by BaseForkTest to match deployed ones.
    function _setAddresses(
        address _depositContract,
        address _bgtAddress,
        address _bgtStakerAddress,
        address _beraChefAddress,
        address _wberaAddress
    )
        internal
    {
        depositContract = _depositContract;
        bgtAddress = _bgtAddress;
        bgtStakerAddress = _bgtStakerAddress;
        beraChefAddress = _beraChefAddress;
        wberaAddress = _wberaAddress;
    }

    /// @notice Since this class is used as base test also for forked tests, call this function from test files who
    /// need mocks.
    function _deployMockedContracts() internal {
        deployCodeTo("MockDepositContract.sol", depositContract);
        deployCodeTo("MockBGTStaker.sol", bgtStakerAddress);
        deployCodeTo("MockBGT.sol", bgtAddress);
        deployCodeTo("MockWBERA.sol", wberaAddress);

        MockBGTStaker bgtStaker = MockBGTStaker(bgtStakerAddress);
        bgtStaker.setWbera(wberaAddress);
    }

    function _create96Byte() internal pure returns (bytes memory) {
        return abi.encodePacked(bytes32("32"), bytes32("32"), bytes32("32"));
    }

    function _create48Byte() internal pure returns (bytes memory) {
        return abi.encodePacked(bytes32("32"), bytes16("16"));
    }

    function _dealWbera(address to, uint256 amount) internal {
        vm.deal(msg.sender, amount);
        MockWBERA wbera = MockWBERA(payable(wberaAddress));
        wbera.deposit{ value: amount }();
        wbera.transfer(to, amount);
        assertEq(wbera.balanceOf(to), amount);
    }
}
