// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import { console2 } from "forge-std/console2.sol";

import { BaseScript } from "./base/BaseScript.s.sol";
import { Deployer } from "src/Deployer.sol";

import { GBera } from "src/GBera.sol";
import { GBeraAssetManager } from "src/GBeraAssetManager.sol";
import { NodeFeeReceiver } from "src/NodeFeeReceiver.sol";
import { NodeRegistry } from "src/NodeRegistry.sol";
import { NodeWithdrawalVault } from "src/NodeWithdrawalVault.sol";
import { WGBera } from "src/WGBera.sol";
import { WithdrawalQueue } from "src/WithdrawalQueue.sol";

contract DeployGBeraScript is BaseScript {
    address public immutable DEPOSIT_CONTRACT = _envAddress("DEPOSIT_CONTRACT");
    address public immutable WBERA = _envAddress("WBERA");
    address public immutable BGT = _envAddress("BGT");
    address public immutable BERA_CHEF = _envAddress("BERA_CHEF");
    address public immutable BGT_STAKER = _envAddress("BGT_STAKER");

    Deployer public deployer;
    NodeRegistry public registry;
    GBeraAssetManager public manager;
    WithdrawalQueue public withdrawalQueue;
    GBera public gbera;
    NodeWithdrawalVault public withdrawalVault;
    NodeFeeReceiver public nodeFeeReceiver;
    WGBera public wgbera;

    function run() public broadcast {
        _addressZeroCheck(DEPOSIT_CONTRACT);
        _addressZeroCheck(WBERA);
        _addressZeroCheck(BGT);
        _addressZeroCheck(BERA_CHEF);
        _addressZeroCheck(BGT_STAKER);

        deployer = new Deployer(msg.sender, DEPOSIT_CONTRACT, BGT_STAKER, BGT, BERA_CHEF, WBERA);
        console2.log("\n\nDeploying GBera contracts...");
        deployer = new Deployer(msg.sender, DEPOSIT_CONTRACT, BGT_STAKER, BGT, BERA_CHEF, WBERA);
        console2.log("GBeraDeployer address: %s", address(deployer));

        gbera = deployer.gbera();
        if (gbera.owner() != msg.sender) revert("GBera owner is not the deployer");
        console2.log("GBera address: %s", address(gbera));

        manager = deployer.manager();
        if (!manager.hasRole(manager.DEFAULT_ADMIN_ROLE(), msg.sender)) {
            revert("GBeraAssetManager owner is not the deployer");
        }
        manager.grantRole(manager.OPERATOR_ROLE(), msg.sender);
        if (!manager.hasRole(manager.OPERATOR_ROLE(), msg.sender)) {
            revert("GBeraAssetManager operator role is not the deployer");
        }
        console2.log("GBeraAssetManager address: %s", address(manager));

        registry = deployer.registry();
        if (registry.owner() != msg.sender) revert("NodeRegistry owner is not the deployer");
        console2.log("NodeRegistry address: %s", address(registry));

        withdrawalQueue = deployer.withdrawalQueue();
        if (withdrawalQueue.owner() != msg.sender) revert("WithdrawalQueue owner is not the deployer");
        console2.log("WithdrawalQueue address: %s", address(withdrawalQueue));

        nodeFeeReceiver = deployer.nodeFeeReceiver();
        console2.log("NodeFeeReceiver address: %s", address(nodeFeeReceiver));

        withdrawalVault = deployer.withdrawalVault();
        console2.log("NodeWithdrawalVault address: %s", address(withdrawalVault));

        wgbera = deployer.wgbera();
        console2.log("WGbera address: %s", address(wgbera));

        console2.log("GBera contracts deployed successfully!");
    }

    function _addressZeroCheck(address addr) internal pure {
        if (addr == address(0)) revert("Address is zero");
    }
}
