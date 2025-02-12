// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import { IGBeraErrors } from "./IGBeraErrors.sol";

interface IWithdrawalQueue is IERC721, IGBeraErrors {
    //////////   EVENTS    //////////

    /**
     * @notice Event emitted when a withdrawal request is submitted.
     * @param requestId The id of the withdrawal request.
     * @param requester The address of the requester.
     * @param pooledBera The amount of pooled BERA corresponding to the request.
     * @param gBeraAmount The amount of GBera requested.
     * @param timestamp The timestamp of the request.
     */
    event WithdrawalRequestSubmitted(
        uint256 requestId, address requester, uint256 pooledBera, uint256 gBeraAmount, uint256 timestamp
    );

    /**
     * @notice Event emitted when the queue is processed.
     * @param batchIndex The index of the processed batch.
     * @param lowerIndex The index of the first processed request in the batch.
     * @param upperIndex The index of the last processed request in the batch.
     * @param assetsAmount The amount of Bera needed by processed queue.
     * @param sharesAmount The amount of GBera shares to burn for the processed the queue.
     */
    event QueueProcessed(
        uint256 batchIndex, uint256 lowerIndex, uint256 upperIndex, uint256 assetsAmount, uint256 sharesAmount
    );

    /**
     * @notice Event emitted when BERA is claimed.
     * @param requestId The id of the withdrawal request.
     * @param batchIndex The index of the batch where the request was processed.
     * @param receiver The address of the receiver.
     * @param beraAmount The amount of BERA claimed.
     */
    event BeraClaimed(uint256 requestId, uint256 batchIndex, address receiver, uint256 beraAmount);

    //////////   STRUCTS    //////////

    /**
     * @notice Storing a request for withdrawal.
     * @param receiver The receiver of the withdrawal.
     * @param shares The amount of GBera shares corresponding to the request.
     * @param time The time of the request.
     */
    struct WithdrawalRequest {
        address payable receiver;
        uint256 shares;
        uint256 time;
    }

    /**
     * @notice Saved when a batch of requests is processed. This avoids any search loop.
     * @param lowerIndex The index of the first processed request in the batch.
     * @param upperIndex The index of the last processed request in the batch.
     * @param beraAmount The aamount of BERA allocated in the processed batch.
     */
    struct ProcessedBatch {
        uint256 lowerIndex;
        uint256 upperIndex;
        uint256 beraAmount;
    }

    //////////   FUNCTIONS   //////////

    /**
     * @notice The id of the last withdrawal request made.
     * @return id The request id.
     */
    function lastRequestId() external view returns (uint256);

    /**
     * @notice The id of the last withdrawal request processed.
     * @return id The request id.
     */
    function lastProcessedId() external view returns (uint256);

    /**
     * @notice The index of the last batch processed.
     * @return index The batch index.
     */
    function lastBatchIndex() external view returns (uint256);

    /**
     * @notice Creates a request for withdrawal and mints the corresponding NFT to the receiver.
     * @param gBeraAmount The rebased amount of GBera requested for withdraw for event tracking.
     * @param sharesAmount The amount of GBera shares requested for withdraw.
     * @param receiver The receiver of the withdrawal.
     * @return requestId The NFT id of the created request.
     */
    function submitRequest(
        uint256 gBeraAmount,
        uint256 sharesAmount,
        address receiver
    )
        external
        returns (uint256 requestId);

    /**
     * @notice Processes the withdrawal queue.
     * @param requestId The id of the request you want to process up to.
     * @return beraAmount the (rebased) amount of gbera to transfer to make the processed queue claimable.
     * @return sharesAmount the amount of GBera shares to burn to make the processed queue claimable.
     */
    function processQueue(uint256 requestId) external returns (uint256 beraAmount, uint256 sharesAmount);

    /**
     * @notice Claim assets associated with a request.
     * @dev Reverts if the request has not been processed.
     * @param requestId The id of the claimed request.
     * @param batchIndex The index of the batch the request was processed in.
     */
    function claimBera(uint256 requestId, uint256 batchIndex) external;
}
