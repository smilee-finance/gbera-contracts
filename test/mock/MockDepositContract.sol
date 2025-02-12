// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IDepositContract } from "../../src/interfaces/external/IDepositContract.sol";

contract MockDepositContract is IDepositContract {
    address public gBeraOperator;

    function deposit(
        bytes calldata publicKey,
        bytes calldata withdrawalCredentials,
        bytes calldata signature,
        address operator
    )
        external
        payable
    {
        publicKey;
        withdrawalCredentials;
        signature;
        operator;

        // burn msg.value
        address payable zero = payable(address(0));
        zero.transfer(msg.value);
    }

    function getOperator(bytes calldata pubkey) external view override returns (address) {
        pubkey;
        return gBeraOperator;
    }

    function requestOperatorChange(bytes calldata publicKey, address newOperator) external pure override {
        publicKey;
        newOperator;
    }

    function cancelOperatorChange(bytes calldata publicKey) external pure override {
        publicKey;
    }

    function setOperator(bytes memory pubkey, address operator) public {
        pubkey;
        gBeraOperator = operator;
    }
}
