// SPDX-License-Identifier: MIT
pragma solidity >=0.8.10;

import { Script, console2 } from "forge-std/Script.sol";

abstract contract BaseScript is Script {
    /// @dev Included to enable compilation of the script without a $MNEMONIC environment variable.
    string internal constant TEST_MNEMONIC = "test test test test test test test test test test test junk";

    /// @dev Needed for the deterministic deployments.
    bytes32 internal constant ZERO_SALT = bytes32(0);

    /// @dev The address of the transaction broadcaster.
    address internal _broadcaster;

    /// @dev The private key of the transaction broadcaster.
    uint256 internal _broadcasterPrivateKey;

    /// @dev Used to derive the broadcaster's address if $ETH_FROM is not defined.
    string internal _mnemonic;

    /// @dev Used to determine if the transactions can be signed without using an external hardware wallet.
    bool internal _useSoftwareWallet;

    /// @dev Initializes the transaction broadcaster like this:
    ///
    /// - If $ETH_FROM is defined, use it.
    /// - Otherwise, derive the broadcaster address from $MNEMONIC or a test default one.
    /// - If $USE_SOFTWARE_WALLET allows to not use an external hardware wallet, use the $ETH_FROM_PK private key.
    ///
    /// The use case is to specify the broadcaster via the command line.
    constructor() {
        _useSoftwareWallet = vm.envOr({ name: "USE_SOFTWARE_WALLET", defaultValue: false });

        _broadcaster = _envAddress("ETH_FROM");

        if (_broadcaster == address(0)) {
            _mnemonic = vm.envOr({ name: "MNEMONIC", defaultValue: TEST_MNEMONIC });
            (_broadcaster, _broadcasterPrivateKey) = deriveRememberKey({ mnemonic: _mnemonic, index: 0 });
            return;
        }

        _broadcasterPrivateKey = 0;
        if (_useSoftwareWallet) {
            _broadcasterPrivateKey = _envPrivateKey("ETH_FROM_PK");
        }
    }

    modifier broadcast() {
        console2.log("Using hardware wallet: ", !_useSoftwareWallet);
        console2.log("Broadcaster address: ", msg.sender);

        // NOTE: vm.broadcast and vm.startBroadcast does not override the scripts caller,
        // but only the sender when an external call is made.
        // --sender param is required to override the caller
        require(msg.sender != address(0) && msg.sender != DEFAULT_SENDER, "Missing --sender param");

        if (_useSoftwareWallet) {
            vm.startBroadcast(_broadcasterPrivateKey);
        } else {
            vm.startBroadcast();
        }
        _;
        vm.stopBroadcast();
    }

    /// @notice Read an address from the environment.
    function _envAddress(string memory key) internal view returns (address value) {
        // NOTE: vm.envAddress crashes Foundry if the value is empty or the key not defined
        value = vm.envOr(key, address(0));
    }

    /// @notice Read a private key from the environment.
    function _envPrivateKey(string memory key) internal view returns (uint256 value) {
        value = vm.envOr(key, uint256(0));
        require(value != 0, string.concat("Missing private key in env: ", key));
    }

    function _checkDeploymentAddress(string memory contractName, address deployed, address predicted) internal pure {
        string memory deployedStr = string.concat(contractName, " deployed at: ");
        console2.log(deployedStr, deployed);
        require(deployed == predicted, string.concat(contractName, " address does not match the predicted address"));
    }

    function _validateCode(string memory contractName, address contractAddress) internal view {
        require(contractAddress.code.length > 0, string.concat(contractName, ": invalid code at this address"));
    }
}
