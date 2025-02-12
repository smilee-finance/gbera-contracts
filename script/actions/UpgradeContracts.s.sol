// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import { console2 } from "forge-std/console2.sol";

import { BaseScript } from "../base/BaseScript.s.sol";
import { Deployer } from "src/Deployer.sol";
import { GBera } from "src/GBera.sol";
import { GBeraAssetManager } from "src/GBeraAssetManager.sol";
import { NodeRegistry } from "src/NodeRegistry.sol";
import { NodeWithdrawalVault } from "src/NodeWithdrawalVault.sol";
import { WithdrawalQueue } from "src/WithdrawalQueue.sol";

contract UpgradeContractsScript is BaseScript {
    Deployer public immutable DEPLOYER = Deployer(_envAddress("DEPLOYER"));

    function run() public pure {
        console2.log("Please run specific functions");
    }

    /// @notice Upgrade the GBera contract
    function upgradeGBera() public broadcast {
        _upgradeGBera();
    }

    function _upgradeGBera() internal {
        GBera newGBera = new GBera();
        console2.log(address(DEPLOYER.gbera()));
        GBera gBera_ = DEPLOYER.gbera();
        gBera_.upgradeToAndCall(address(newGBera), "");
    }

    /// @notice Upgrade the GBeraAssetManager contract
    function upgradeGBeraAssetManager() public broadcast {
        _upgradeGBeraAssetManager();
    }

    function _upgradeGBeraAssetManager() internal {
        GBeraAssetManager newGBeraAssetManager = new GBeraAssetManager(
            address(DEPLOYER.locator()),
            address(DEPLOYER.gbera()),
            address(DEPLOYER.registry()),
            address(DEPLOYER.withdrawalQueue())
        );
        GBeraAssetManager gBeraAssetManager = GBeraAssetManager(DEPLOYER.manager());
        gBeraAssetManager.upgradeToAndCall(address(newGBeraAssetManager), "");
    }

    /// @notice Upgrade the NodeRegistry contract
    function upgradeNodeRegistry() public broadcast {
        _upgradeNodeRegistry();
    }

    function _upgradeNodeRegistry() internal {
        NodeRegistry newNodeRegistry = new NodeRegistry();
        NodeRegistry nodeRegistry = NodeRegistry(DEPLOYER.registry());
        nodeRegistry.upgradeToAndCall(address(newNodeRegistry), "");
    }

    /// @notice Upgrade the WithdrawalQueue contract
    function upgradeWithdrawalQueue() public broadcast {
        _upgradeWithdrawalQueue();
    }

    function _upgradeWithdrawalQueue() internal {
        WithdrawalQueue newWithdrawalQueue = new WithdrawalQueue();
        WithdrawalQueue withdrawalQueue = WithdrawalQueue(DEPLOYER.withdrawalQueue());
        withdrawalQueue.upgradeToAndCall(address(newWithdrawalQueue), "");
    }

    /// @notice Upgrade all contracts
    function upgradeAll() public broadcast {
        _upgradeGBera();
        _upgradeGBeraAssetManager();
        _upgradeNodeRegistry();
        _upgradeWithdrawalQueue();
    }
}
