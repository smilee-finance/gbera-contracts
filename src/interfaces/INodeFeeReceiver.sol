// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IGBeraErrors } from "./IGBeraErrors.sol";

/**
 * @title INodeFeeReceiver
 * @notice Contract to receive priority fees from nodes and reaggregate them into node deposits.
 * @dev Could send fees directly to GBeraManager but may need to do some accounting in future.
 */
interface INodeFeeReceiver is IGBeraErrors {
    //////////     EVENTS     //////////

    /**
     * @notice Emitted when the balance is wiped to the asset manager.
     * @param amount The amount wiped.
     */
    event RewardCollected(uint256 amount);

    /**
     * @notice Emitted when the unlock time is updated.
     * @param oldValue The old value.
     * @param newValue The new value.
     */
    event UnlockTimeUpdated(uint256 oldValue, uint256 newValue);

    /**
     * @notice Emitted when the locked rewards is updated.
     * @param lockedRewards The new reward value.
     */
    event RewardUpdated(uint256 lockedRewards);

    //////////   FUNCTIONS    //////////

    /**
     * @notice Collects unlocked rewards into asset manager.
     * @return amount The amount of BERA transferred to manager.
     */
    function collectRewards() external returns (uint256 amount);

    /**
     * @notice Returns the amount of BERA earned by the receiver.
     * @return amount The amount of BERA earned.
     */
    function earned() external view returns (uint256);

    /**
     * @notice Updates the rewards to start locking.
     */
    function updateReward() external;

    /**
     * @notice Updates the unlock time.
     */
    function setUnlockTime(uint256 unlockTime) external;
}
