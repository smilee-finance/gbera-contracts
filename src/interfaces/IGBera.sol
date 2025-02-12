// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IGBeraErrors } from "./IGBeraErrors.sol";

/**
 * @title IGBera
 * @notice Interface for the GBera token contract.
 */
interface IGBera is IERC20, IGBeraErrors {
    //////////     EVENTS     //////////

    /**
     * @notice Emitted when a deposit is made.
     * @param account The account that made the deposit.
     * @param shares The amount of shares minted.
     * @param assets The amount of assets deposited.
     */
    event Deposit(address indexed account, uint256 shares, uint256 assets);

    /**
     * @notice Emitted when the NodeWithdrawalQueue contract is updated.
     * @param oldAddr The old withdrawal queue address.
     * @param newAddr The new withdrawal queue address.
     */
    event NodeWithdrawalQueueUpdated(address oldAddr, address newAddr);

    /**
     * @notice Emitted when the GBeraAssetManager contract is updated.
     * @param oldAddr The old manager address.
     * @param newAddr The new manager address.
     */
    event GBeraAssetManagerUpdated(address oldAddr, address newAddr);

    /**
     * @notice Emitted when the withdrawal enabled flag is updated.
     * @param flag The new flag value.
     */
    event WithdrawalEnabledUpdated(bool flag);

    //////////   FUNCTIONS    //////////

    /**
     * @notice Gets the rebased total supply of gBERA.
     * @return totalSupply The total supply.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @notice Gets the rebased balance of given account.
     * @param account The address to know balance of.
     * @return balance The balance owned by the account.
     */
    function balanceOf(address account) external view returns (uint256 balance);

    /**
     * @notice Sets the GBeraAssetManager contract.
     * @param _manager The new contract address.
     */
    function setAssetManager(address _manager) external;

    /**
     * @notice Sets the NodeWithdrawalQueue contract.
     * @param _withdrawalQueue The new contract address.
     */
    function setWithdrawalQueue(address _withdrawalQueue) external;

    /**
     * @notice Withdrawal enabled flag.
     * @return true if withdrawals are enabled.
     */
    function withdrawalEnabled() external view returns (bool);

    /**
     * @notice Sets the withdrawal enabled flag.
     * @dev Starting state is false.
     * @param flag The new flag value.
     */
    function setWithdrawalEnabled(bool flag) external;

    /**
     * @notice Preview the expected rebased amount.
     * @param amount The given shares amount.
     * @param roundUp Whether to round up or down.
     * @return The rebased amount (BERA value of the given share).
     */
    function getRebasedAmount(uint256 amount, bool roundUp) external view returns (uint256);

    /**
     * @notice Preview the expected unrebased amount.
     * @param amount The gBERA amount.
     * @param roundUp Whether to round up or down.
     * @return The unrebased amount (shares amount for the given gBERA).
     */
    function getUnrebasedAmount(uint256 amount, bool roundUp) external view returns (uint256);

    /**
     * @notice Mints an amount of gBERA shares corresponding to the assets brought to the contract.
     * @param receiver The receiver of the gBERA.
     * @return shares amount minted to the receiver
     */
    function deposit(address receiver) external payable returns (uint256 shares);

    /**
     * @notice Requests a withdrawal of the given amount of gBERA to the receiver.
     * @dev Mints a withdrawal NFT to the receiver.
     * @param amount The amount of assets to withdraw.
     * @param receiver The receiver of the withdrawal NFT.
     * @return requestId The id of the withdrawal NFT request.
     */
    function requestWithdrawal(uint256 amount, address receiver) external returns (uint256 requestId);

    /**
     * @notice Completes a withdrawal request sending the amount of BERA to the receiver.
     * @param id The id of the withdrawal NFT request.
     * @param batchIndex The batch index which processed the withdrawal.
     */
    function completeWithdrawal(uint256 id, uint256 batchIndex) external;

    /**
     * @notice Returns the total number of shares in existence.
     * @return The total supply of shares.
     */
    function totalShares() external view returns (uint256);

    /**
     * @notice Returns the current share price, i.e. amount of bera to mint 1 share of GBera.
     * @return price The share price
     */
    function sharePrice() external view returns (uint256 price);

    /**
     * @notice Retrieves the share balance of a given account.
     * @param account The address of the account whose share balance is being queried.
     * @return The number of shares owned by the specified account.
     */
    function balanceOfShares(address account) external view returns (uint256);

    /**
     * @notice Transfers shares from the caller's account to another account.
     * @dev This function allows the sender to transfer their shares to another address.
     * @param to The recipient address.
     * @param value The amount of shares to transfer.
     * @return A boolean indicating whether the transfer was successful.
     */
    function transferShares(address to, uint256 value) external returns (bool);

    /**
     * @notice Approves an amount of shares to trasnfer from a spender.
     * @dev Notice that underlying allowance is managed in rebased amounts.
     * This function is supposed to be called before transferSharesFrom.
     * @param spender The address of the spender.
     * @param value The amount of shares to approve for transfer.
     * @return true if the approval was successful.
     */
    function approveShares(address spender, uint256 value) external returns (bool);

    /**
     * @notice Transfers shares from one account to another, given sufficient allowance.
     * @dev Notice that, since underlying allowance is managed in rebased amounts, the caller must
     * have an allowance from the `from` address that is at least `getRebasedAmount(value)`.
     * @param from The address of the sender.
     * @param to The address of the recipient.
     * @param value The amount of shares to transfer.
     * @return A boolean indicating whether the transfer was successful.
     */
    function transferSharesFrom(address from, address to, uint256 value) external returns (bool);

    /**
     * @notice Burns a specified amount of shares from an account.
     * @dev This function decreases the total supply by burning shares from `account`.
     * @param account The address whose shares will be burned.
     * @param value The number of shares to burn.
     */
    function burnShares(address account, uint256 value) external;
}
