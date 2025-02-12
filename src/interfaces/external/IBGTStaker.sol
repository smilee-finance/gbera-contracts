// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IBGTStaker {
    /**
     * @notice Claim the reward of the caller.
     */
    function getReward() external returns (uint256);

    /**
     * @notice Get what the address earned.
     * @param owner The owner of the reward.
     */
    function earned(address owner) external view returns (uint256);
}
