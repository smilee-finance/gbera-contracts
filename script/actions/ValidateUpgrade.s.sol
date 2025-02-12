// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import { Options, Upgrades } from "@openzeppelin-foundry-upgrades/Upgrades.sol";
import { Script, console2 } from "forge-std/Script.sol";

/// @notice This script is used to validate the upgrade of any upgradeable contract.
/// @dev This will fail if any storage collisions are detected.
/// @dev Need to run forge clean && forge compile before running this script.
contract ValidateUpgrade is Script {
    function run() public {
        vm.startBroadcast();
        _validateUpgrade("ContractV2.sol");
        vm.stopBroadcast();
    }

    function runSingle(string memory upgradedContract) public {
        vm.startBroadcast();
        console2.log("Validating contract: ", upgradedContract);
        _validateUpgrade(upgradedContract);
        vm.stopBroadcast();
    }

    function _validateUpgrade(string memory upgradedContract) internal {
        Options memory options; // create an empty options object.
        // options.referenceContract = referenceContract;
        // options.referenceBuildInfoDir // Empty because build dir is the same.
        // options.constructorData // Empty because every constructor parameters are empty.
        // options.exclude = exclude; // Empty because every contract name is unique.
        // options.unsafeAllow // Empty because no unsafeAllow is needed.
        // options.unsafeAllowRenames // false because no storage renames allowed.
        // options.unsafeSkipProxyAdminCheck // false because no proxy admin check is needed.
        // options.unsafeSkipStorageCheck // false because no storage check is needed.
        // options.unsafeSkipAllChecks // false because no all checks are needed.
        Upgrades.validateUpgrade(upgradedContract, options);
        console2.log("contract can be upgraded successfully.");
    }
}
