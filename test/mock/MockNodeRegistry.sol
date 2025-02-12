// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { NodeRegistry } from "../../src/NodeRegistry.sol";

// Only for testing purposes of internal functions
contract MockNodeRegistry is NodeRegistry {
    function withdrawalAddressToCredentials(address withdrawalAddress)
        public
        pure
        returns (bytes memory withdrawalCredentials)
    {
        return _withdrawalAddressToCredentials(withdrawalAddress);
    }
}
