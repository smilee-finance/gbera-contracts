// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { INodeRegistry } from "./interfaces/INodeRegistry.sol";
import { INodeWithdrawalVault } from "./interfaces/INodeWithdrawalVault.sol";

/**
 * @title NodeWithdrawalVault
 * @notice A vault for temporary storage of validators withdrawals.
 * @dev Inspired by Lido https://github.com/lidofinance/core/blob/master/contracts/0.8.9/WithdrawalVault.sol
 */
contract NodeWithdrawalVault is INodeWithdrawalVault {
    /// @notice The address of the GBeraAssetManager contract
    address public immutable gBeraManager;
    address public immutable nodeRegistry;

    constructor(address _gBeraManager, address nodeRegistry_) {
        gBeraManager = _gBeraManager;
        nodeRegistry = nodeRegistry_;
    }

    /// @dev If the vault receives a donation of native tokens, it is transferred to the GBeraAssetManager.
    receive() external payable {
        (bool success,) = gBeraManager.call{ value: msg.value }("");
        if (!success) revert TransferFailed();
    }

    ////////// MODIFIERS //////////

    /// @notice Only the GBeraAssetManager can call the function
    modifier onlyManager() {
        if (msg.sender != gBeraManager) {
            revert NotManager();
        }
        _;
    }

    ////////// STATE CHANGING //////////

    /// @inheritdoc INodeWithdrawalVault
    function withdrawWithdrawals(uint256 amount) external onlyManager {
        if (amount == 0) revert ZeroAmount();

        (bool success,) = gBeraManager.call{ value: amount }("");
        if (!success) revert WithdrawalTransferFailed();
        emit WithdrawalsWithdrawn(amount);
    }
}
