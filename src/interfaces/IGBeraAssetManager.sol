// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IBGTOperator } from "./IBGTOperator.sol";
import { IGBeraErrors } from "./IGBeraErrors.sol";

interface IGBeraAssetManager is IBGTOperator, IGBeraErrors {
    //////////   EVENTS    //////////

    /**
     * @notice Emitted when the node fee receiver is updated.
     * @param oldValue The old node fee receiver address.
     * @param newValue The new node fee receiver address.
     */
    event NodeFeeReceiverUpdated(address oldValue, address newValue);

    /**
     * @notice Emitted when a deposit is made.
     * @param publicKey The public key of the validator.
     * @param amount The amount deposited.
     */
    event Deposit(bytes publicKey, uint256 amount);

    /**
     * @notice Emitted when a withdrawal queue is processed.
     * @param refRequestId The ID of the withdrawal request to process up to.
     * @param assetsAmount The amount of Bera transfered to WithdrawalQueue.
     * @param sharesAmount The amount of GBera shares burnt to process the queue.
     */
    event WithdrawalQueueProcessed(uint256 refRequestId, uint256 assetsAmount, uint256 sharesAmount);

    /**
     * @notice Emitted when a withdrawal is made from the withdrawal vault.
     * @param amount The amount of BERA withdrawn.
     * @param publicKey The public key of the validator in the node registry.
     */
    event WithdrawFromVault(uint256 amount, bytes publicKey);

    /**
     * @notice Emitted when a due amount of tokens is withdrawn from the BGTStaker
     * @param amount The amount collected after protocol fees.
     */
    event StakerRewardCollected(uint256 amount);

    /**
     * @notice Emitted when the node fee rewards are collected.
     * @param amount The amount collected after protocol fees.
     */
    event NodeFeeRewardCollected(uint256 amount);

    /**
     * @notice Emitted when manager receives funds.
     * @param sender The address of the sender.
     * @param amount The amount received.
     */
    event Received(address sender, uint256 amount);

    /**
     * @notice Emitted when the protocol fees amount is increased upon rewards collection.
     * @param amount The amount of fees accrued.
     */
    event ProtocolFeesAccrued(uint256 amount);

    /**
     * @notice Emitted when the fee percentage is updated.
     * @param oldValue The old fee percentage.
     * @param newValue The new fee percentage.
     */
    event FeePercentageUpdated(uint256 oldValue, uint256 newValue);

    /**
     * @notice Emitted when the protocol fees are withdrawn.
     * @param receiver The address of the receiver of the withdrawn amount.
     * @param amount The amount withdrawn.
     */
    event ProtocolFeesWithdrawn(address receiver, uint256 amount);

    //////////      VIEW      //////////

    /**
     * @notice Get the protocol fee percentage charged on node rewards.
     * @return perc The fee percentage denominated in wei (100% = 1e18).
     */
    function feePercentage() external view returns (uint256 perc);

    /**
     * @notice Get the current amount of BERA owed to the protocol as fees.
     * @return fees The amount of fees.
     */
    function protocolFees() external view returns (uint256 fees);

    /**
     * @notice Get the minimum amount of native token that can be deposited.
     * @return amount The amount.
     */
    function minDepositAmount() external view returns (uint256 amount);

    /**
     * @notice Get the stored address of depositContract.
     * @return deposit The address of the deposit contract.
     */
    function depositContract() external view returns (address deposit);

    /**
     * @notice Get the total amount of assets managed by the contract.
     * @return amount The total assets amount.
     */
    function totalAssets() external view returns (uint256 amount);

    ////////// STATE CHANGERS //////////

    /**
     * @notice Sets the unlockTime to the nodeFeeReceiver.
     * @param _unlockTime The new unlock time.
     */
    function setNodeFeeUnlockTime(uint256 _unlockTime) external;

    /**
     * @notice Sets the node fee receiver.
     * @param _nodeFeeReceiver The address of the node fee receiver.
     * @dev Only the owner can call this function.
     */
    function setNodeFeeReceiver(address _nodeFeeReceiver) external;

    /**
     * @notice Deposits the specified amount into the deposit contract.
     * @dev Admin function to deposit cumulated assets into the deposit contract.
     * @param publicKey The public key of the node to deposit to.
     * @param amount The amount to deposit.
     */
    function deposit(bytes calldata publicKey, uint256 amount) external payable;

    /**
     * @notice Withdraws BERA from the withdrawal vault.
     * @dev Admin function to wipe an amount of assets from the withdrawal vault.
     * @param amount The amount of BERA to withdraw.
     * @param publicKey The public key of the validator in the node registry.
     * @dev Need to be permissioned since it's used to adjust nodes stake.
     */
    function withdrawWithdrawals(uint256 amount, bytes calldata publicKey) external;

    /**
     * @notice Collects the fees from the nodeFeeReceiver contract.
     * @dev Permissionless.
     */
    function collectNodeFeeRewards() external;

    /**
     * @notice Claims rewards from the BGTStaker (WBERA) and converts them to BERA.
     * @dev Permissionless.
     */
    function collectStakerRewards() external;

    /**
     * @notice Updates the protocol fees amount relative to bgt rewards.
     * @dev Permissionless.
     */
    function updateBgtFees() external;

    /**
     * @notice Processes the withdrawal queue burning GBera and sending BERA to the withdrawal queue contract.
     * @dev Reverts if there is not enough Bera to process the withdrawal queue.
     * @param refRequestId The ID of the withdrawal request to process up to.
     */
    function processWithdrawalQueue(uint256 refRequestId) external;

    /**
     * @notice Sets the protocol fee percentage.
     * @dev Also forces the update of stored fees amount with pre-change fee percentage.
     * @param _feePercentage The new fee percentage.
     */
    function setFeePercentage(uint256 _feePercentage) external;

    /**
     * @notice Withdraws the protocol fees from the contract to the given receiver.
     * @dev Only the owner can call this function.
     * @dev Only withdraws the storedProtocolFees, i.e. does not update fees on current rewards before withdrawing.
     * If want to withdraw to update storedProtocolFees upon withdraw, call
     *   - updateBgtFees()
     *   - collectStakerRewards()
     *   - collectNodeFeeRewards() before this function.
     * before this function.
     * @param receiver The address to send the amount to.
     */
    function withdrawProtocolFees(address receiver) external;
}
