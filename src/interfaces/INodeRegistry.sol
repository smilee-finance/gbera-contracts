// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IGBeraErrors } from "./IGBeraErrors.sol";

interface INodeRegistry is IGBeraErrors {
    //////////    STRUCTS     //////////

    // no need for node operator (GBeraAssetManager contract)
    struct Node {
        string name;
        bytes publicKey;
        bytes withdrawalCredentials;
        bytes signature;
        uint256 stakeAmount;
        bool isActive;
        uint256 lastUpdate;
    }

    //////////     EVENTS     //////////

    /**
     * @notice Emitted when a node is created.
     * @param publicKey The public key of the node.
     * @param name The name of the node.
     */
    event NodeCreated(bytes publicKey, string name);

    /**
     * @notice Emitted when a node activation status is updated.
     * @param publicKey The public key of the node.
     * @param active The activation status of the node.
     */
    event NodeActivationStatusUpdated(bytes publicKey, bool active);

    /**
     * @notice Emitted when a node stake amount is updated.
     * @param publicKey The public key of the node.
     * @param stakeAmount The stake amount of the node.
     */
    event NodeStakeAmountUpdated(bytes publicKey, uint256 stakeAmount);

    /**
     * @notice Emitted when the max allocation is updated.
     * @param oldValue The old max allocation.
     * @param newValue The new max allocation.
     */
    event MaxAllocationUpdated(uint256 oldValue, uint256 newValue);

    //////////   FUNCTIONS    //////////

    /**
     * @notice Creates the node.
     * @param publicKey The public key of the node.
     * @param signature The signature of the first deposit of the node.
     * @param name A name for the node.
     * @dev First deposit for the created node must be performed otside of these contracts.
     */
    function createNode(bytes calldata publicKey, bytes calldata signature, string calldata name) external payable;

    /**
     * @notice Changes the activation status of a node.
     * @param publicKey The public key of the node.
     * @param status The new activation status.
     */
    function setNodeActivationStatus(bytes calldata publicKey, bool status) external;

    /**
     * @notice EMERGENCY FUNCTION to deallocate an amount of BERA from a node.
     * @dev This function can disrupt protocol accounting. Should only be called in
     * extreme circumstances where normal deallocation methods cannot be used.
     * @param publicKey The public key of the node.
     * @param amount The amount of BERA to be deallocated.
     */
    function deallocateNode(bytes calldata publicKey, uint256 amount) external;

    /**
     * @notice Increases the stake amount of the given validator.
     * @param publicKey The public key of the node.
     * @param amount The amount to increase the stake by.
     */
    function increaseNodeStake(bytes calldata publicKey, uint256 amount) external;

    /**
     * @notice Updates data after a vlaidator withdrawal.
     * @param publicKey The public key of the node.
     * @param amount The amount of BERA to be deallocated.
     */
    function registerWithdrawal(bytes calldata publicKey, uint256 amount) external;

    /**
     * @notice Gets the total amount staked over nodes through GBera.
     * @return amount The total allocated amount.
     */
    function deposits() external view returns (uint256 amount);

    /**
     * @notice Gets all nodes.
     * @return allNodes The array of all nodes.
     */
    function getAllNodes() external view returns (bytes[] memory allNodes);

    /**
     * @notice Gets the public key of the current node to stake to.
     * @return publicKey The public key of the last node created.
     */
    function getLastNodePK() external view returns (bytes memory publicKey);

    /**
     * @notice Gets full data of the node at given public key.
     * @param publicKey The public key of the node.
     * @return node node data.
     */
    function getNodeData(bytes calldata publicKey) external view returns (Node memory node);
}
