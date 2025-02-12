// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { INodeFeeReceiver } from "./interfaces/INodeFeeReceiver.sol";

/**
 * @title NodeFeeReceiver
 * @notice Contract to receive priority fees from nodes.
 * @dev Not upgradable since can be substituted in asset manager.
 */
contract NodeFeeReceiver is INodeFeeReceiver {
    //////////    STORAGE     //////////

    /// @notice Address of the gBeraManager to send funds to.
    address public gBeraManager;

    //////////  CONSTRUCTOR   //////////

    constructor(address _gBeraManager) {
        gBeraManager = _gBeraManager;
    }

    //////////   FUNCTIONS    //////////

    /// @inheritdoc INodeFeeReceiver
    function collectRewards() external returns (uint256 amount) {
        amount = address(this).balance;
        (bool success,) = gBeraManager.call{ value: amount }("");
        if (!success) revert BeraTransferFailed();
        emit RewardCollected(amount);
    }

    /// @inheritdoc INodeFeeReceiver
    function earned() external view returns (uint256) {
        return address(this).balance;
    }

    /// @inheritdoc INodeFeeReceiver
    function updateReward() external { }

    /// @inheritdoc INodeFeeReceiver
    function setUnlockTime(uint256 unlockTime) external { }
}
