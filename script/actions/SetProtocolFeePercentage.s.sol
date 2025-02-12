// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import { console2 } from "forge-std/console2.sol";

import { BaseScript } from "../base/BaseScript.s.sol";
import { Deployer } from "src/Deployer.sol";
import { GBeraAssetManager } from "src/GBeraAssetManager.sol";

contract SetProtocolFeePercentageScript is BaseScript {
    Deployer public immutable DEPLOYER = Deployer(_envAddress("DEPLOYER"));

    function run() public broadcast {
        console2.log("Please run specific function to set fees.");
    }

    function setProtocolFeePercentage(uint256 value) public broadcast {
        console2.log("\n\nSetting protocol fee percentage in GBeraAssetManager contract...");
        console2.log("\n\nNote that percentage is denominated id wei (100% = 1e18)");
        console2.log(
            "\n\nNote that calling this function will force the update of GBeraAssetManager.storedProtocolFee with current fee percentage."
        );

        GBeraAssetManager manager = GBeraAssetManager(DEPLOYER.manager());
        console2.log("\n\nCurrent value: GBeraAssetManager.feePercentage = ", manager.feePercentage());
        console2.log("\n\nCurrent value: GBeraAssetManager.storedProtocolFees = ", manager.storedProtocolFees());
        console2.log("\n\nCurrent value: GBeraAssetManager.protocolFees() = ", manager.protocolFees());

        manager.setFeePercentage(value);
        if (manager.feePercentage() != value) revert("GBeraAssetManager feePercentage is not the new feePercentage");

        console2.log("\n\nfeePercentage set");
        console2.log("\n\nNew value: GBeraAssetManager.feePercentage = ", manager.feePercentage());
        console2.log("\n\nNew value: GBeraAssetManager.storedProtocolFees = ", manager.storedProtocolFees());
        console2.log("\n\nNew value: GBeraAssetManager.protocolFees() = ", manager.protocolFees());
    }
}
