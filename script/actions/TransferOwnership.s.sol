// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import { console2 } from "forge-std/console2.sol";

import { BaseScript } from "../base/BaseScript.s.sol";
import { Deployer } from "src/Deployer.sol";

import { GBeraAssetManager } from "src/GBeraAssetManager.sol";

import { GBera } from "src/GBera.sol";
import { NodeFeeReceiver } from "src/NodeFeeReceiver.sol";
import { NodeRegistry } from "src/NodeRegistry.sol";
import { NodeWithdrawalVault } from "src/NodeWithdrawalVault.sol";
import { WithdrawalQueue } from "src/WithdrawalQueue.sol";

contract TransferOwnershipScript is BaseScript {
    Deployer public immutable DEPLOYER = Deployer(_envAddress("DEPLOYER"));

    function run() public broadcast {
        console2.log("Please run specific function to transfer ownership");
    }

    function transferOwnership(address newOwner) public broadcast {
        GBera gbera = DEPLOYER.gbera();
        GBeraAssetManager manager = DEPLOYER.manager();
        NodeRegistry registry = DEPLOYER.registry();
        WithdrawalQueue withdrawalQueue = DEPLOYER.withdrawalQueue();

        console2.log("\n\nTransferring ownership of GBera contracts...");

        gbera.transferOwnership(newOwner);
        if (gbera.owner() != newOwner) revert("GBera owner is not the new owner");
        console2.log("GBera owner transferred to %s", newOwner);

        manager.grantRole(manager.DEFAULT_ADMIN_ROLE(), newOwner);
        if (!manager.hasRole(manager.DEFAULT_ADMIN_ROLE(), newOwner)) {
            revert("GBeraAssetManager new owner is not the new owner");
        }
        manager.revokeRole(manager.DEFAULT_ADMIN_ROLE(), msg.sender);
        if (manager.hasRole(manager.DEFAULT_ADMIN_ROLE(), msg.sender)) {
            revert("GBeraAssetManager old owner does not renouce ownership");
        }
        console2.log("GBeraAssetManager default admin role transferred to %s", newOwner);

        registry.transferOwnership(newOwner);
        if (registry.owner() != newOwner) revert("NodeRegistry owner is not the new owner");
        console2.log("NodeRegistry owner transferred to %s", newOwner);

        withdrawalQueue.transferOwnership(newOwner);
        if (withdrawalQueue.owner() != newOwner) revert("WithdrawalQueue owner is not the new owner");
        console2.log("WithdrawalQueue owner transferred to %s", newOwner);

        console2.log("Ownership transferred successfully!");
    }
}
