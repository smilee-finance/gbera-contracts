// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IGBeraErrors } from "./IGBeraErrors.sol";

interface INodeWithdrawalVault is IGBeraErrors {
    //////////   EVENTS    //////////

    /**
     * @notice Emitted when withdrawals are withdrawn for a validator.
     * @param amount The amount of withdrawals withdrawn.
     */
    event WithdrawalsWithdrawn(uint256 amount);

    //////////   FUNCTIONS    //////////

    /**
     * @notice Withdraw given amount of accumulated withdrawals.
     * @dev Can be called only by the BeraManger contract.
     * @param amount The amount to withdraw.
     */
    function withdrawWithdrawals(uint256 amount) external;
}
