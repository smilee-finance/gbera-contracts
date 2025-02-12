// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Bera Deposit Contract Interface
 * Inspired to https://github.com/ethereum/consensus-specs/blob/dev/solidity_deposit_contract/deposit_contract.sol
 */
interface IDepositContract {
    function deposit(
        bytes calldata publicKey,
        bytes calldata withdrawalCredentials,
        bytes calldata signature,
        address operator
    )
        external
        payable;

    function getOperator(bytes calldata pubkey) external returns (address);

    function requestOperatorChange(bytes calldata publicKey, address newOperator) external;

    function cancelOperatorChange(bytes calldata publicKey) external;
}
