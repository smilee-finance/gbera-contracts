// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IGBeraErrors {
    //////////       Common         //////////

    /// @notice Reverts if the address is zero.
    error AddressZero();
    /// @notice Reverts if native token transfer fails.
    error BeraTransferFailed();
    /// @notice Reverts when the caller is not the GBeraAssetManager.
    error NotManager();

    //////////        GBera         //////////

    /// @notice Reverts if the caller is not GBeraAssetManager.
    error OnlyManager();
    /// @notice Reverts if the amount is zero or out of bounds.
    error InvalidAmount();
    /// @notice Reverts if trying to burn GBera when withdrawal not enabled.
    error WithdrawalDisabled();

    //////////  GBeraAssetManager   //////////

    /// @notice Reverts if the deposit amount is not a multiple of Gwei or too low.
    error InvalidDepositAmount();
    /// @notice Reverts if there is not enough native token to complete operation.
    error NotEnoughBalance();
    /// @notice Reverts if the protocol fee percentage is set to invalid value.
    error InvalidFeePercentage();

    //////////     NodeRegistry     //////////

    /// @notice Thrown if the public key lenght is not valid.
    error InconsistentPublicKey();
    /// @notice Thrown if the signature lenght is not valid.
    error InconsistentSignature();
    /// @notice Thrown if the node is not found.
    error NodeNotFound();
    /// @notice Thrown if the caller is not the withdrawal vault.
    error NotWithdrawalVault();
    /// @notice Thrown if the withdrawal amount is greater than the staked amount.
    error WithdrawalAmountTooHigh();
    /// @notice Thrown if the node already exists
    error NodeAlreadyExists();
    /// @notice Thrown if the node is not active
    error NodeNotActive();
    /// @notice Thrown if the amount is greater than the staked amount.
    error AmountTooHigh();
    /// @notice Thrown if the admin try to activate a node before the first deposit.
    error FirstDepositNotPerformed();

    ////////// NodeWithdrawalVault  //////////

    /// @notice Reverts when the amount is zero.
    error ZeroAmount();
    /// @notice Reverts when the withdrawal transfer fails.
    error WithdrawalTransferFailed();
    /// @notice Reverts when the transferred amount drains the nodes deposits.
    error AmountDrainsDeposits();

    //////////   WithdrawalQueue    //////////

    /// @notice Reverts if the caller is not the GBera contract.
    error NotGBera();
    /// @notice Reverts if the request id is outside the bounds of the queue.
    error OutsideRequestBounds();
    /// @notice Reverts if the request id is not yet processed.
    error NotYetProcessed();
    /// @notice Reverts if the index does not belong to the batch.
    error IndexNotBelongingToBatch();
    /// @notice Reverts if the BERA transfer failed.
    error TransferFailed();
    /// @notice Reverts if the withdrawal queue NFT is being transferred.
    error TransfersNotAllowed();
}
