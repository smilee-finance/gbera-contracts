// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IBeraChef } from "./external/IBeraChef.sol";

/**
 * @title IBGTOperator
 * @notice Interface collecting the BGT operator methods.
 */
interface IBGTOperator {
    /**
     * @notice EMERGENCY FUNCTION to request a change of the operator for the specified validator.
     * @dev To be used in case GBeraAssetManager contract is substituted.
     * @param publicKey The public key of the validator.
     * @param newOperator The address of the new operator.
     */
    function requestOperatorChange(bytes calldata publicKey, address newOperator) external;

    /**
     * @notice Cancel an operator change request for a specified validator.
     * @param publicKey The public key of the validator.
     */
    function cancelOperatorChange(bytes calldata publicKey) external;

    /**
     * @notice Queues a boost for the specified validator.
     * @param publicKey The public key of the validator.
     * @param amount The amount to boost.
     */
    function queueBoost(bytes calldata publicKey, uint128 amount) external;

    /**
     * @notice Cancels a queued boost for the specified validator.
     * @param publicKey The public key of the validator.
     * @param amount The amount to cancel.
     */
    function cancelBoost(bytes calldata publicKey, uint128 amount) external;

    /**
     * @notice Activates a boost for the specified validator.
     * @param publicKey The public key of the validator.
     */
    function activateBoost(bytes calldata publicKey) external;

    /**
     * @notice Queues a drop boost for the specified validator.
     * @param publicKey The pubkey of the validator to remove boost from.
     * @param amount The amount of BGT to remove from the boost.
     */
    function queueDropBoost(bytes calldata publicKey, uint128 amount) external;

    /**
     * @notice Cancels a queued drop boost for the specified validator.
     * @param publicKey The pubkey of the validator to cancel drop boost for.
     * @param amount The amount of BGT to remove from the queued drop boost.
     */
    function cancelDropBoost(bytes calldata publicKey, uint128 amount) external;

    /**
     * @notice Drops a boost for the specified validator.
     * @param publicKey The public key of the validator.
     */
    function dropBoost(bytes calldata publicKey) external;

    /**
     * @notice Burns BGT tokens for BERA.
     * @param amount The amount of BGT tokens to burn.
     */
    function redeemBGT(uint256 amount) external;

    /**
     * @notice Queues a reward allocation for the specified validator.
     * @param valPubkey The public key of the validator.
     * @param startBlock The block number to start the allocation validity.
     * @param weights The allocation.
     */
    function queueNewRewardAllocation(
        bytes calldata valPubkey,
        uint64 startBlock,
        IBeraChef.Weight[] calldata weights
    )
        external;
}
