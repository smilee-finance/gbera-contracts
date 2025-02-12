// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

/**
 * @title BeraContractsLocator
 * @notice Helper contract to store the addresses of the Bera contracts for GBeraAssetManager initialization.
 * @dev Avoid storing hardcoded addresses since they can change depending on testing network environments.
 */
contract BeraContractsLocator {
    /// @notice The deposit contract
    address public depositContract;

    /// @notice The bgt contract
    address public bgt;

    /// @notice The bgt staker contract
    address public bgtStaker;

    /// @notice The bera chef contract
    address public beraChef;

    /// @notice The wbera contract
    address public wbera;

    constructor(address _depositContract, address _bgt, address _bgtStaker, address _beraChef, address _wbera) {
        depositContract = _depositContract;
        bgt = _bgt;
        bgtStaker = _bgtStaker;
        beraChef = _beraChef;
        wbera = _wbera;
    }
}
