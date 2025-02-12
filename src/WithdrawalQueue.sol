// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { OwnableUpgradeable } from "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ERC721EnumerableUpgradeable } from
    "@openzeppelin-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";

import { IGBera } from "./interfaces/IGBera.sol";
import { IGBeraAssetManager } from "./interfaces/IGBeraAssetManager.sol";
import { IWithdrawalQueue } from "./interfaces/IWithdrawalQueue.sol";

// REVIEW: either make the ERC-721 non transferable or update the receiver

/**
 * @title WithdrawalQueue
 * @notice Contract to manage scattered withdrawals of the GBera contract.
 */
contract WithdrawalQueue is IWithdrawalQueue, OwnableUpgradeable, ERC721EnumerableUpgradeable, UUPSUpgradeable {
    /// @notice NFT name.
    string private constant NAME = "gBERA withdrawal queue";

    /// @notice NFT symbol.
    string private constant SYMBOL = "GBWQ";

    //////////    STORAGE     //////////

    /// @notice The GBeraAssetManager contract.
    IGBeraAssetManager public beraManager;

    /// @notice The GBera contract.
    IGBera public gbera;

    /// @notice The id of the last withdrawal request made.
    uint256 public lastRequestId;

    /// @notice The id of the last withdrawal request processed.
    uint256 public lastProcessedId;

    /// @notice The index of the last batch of processed requests.
    uint256 public lastBatchIndex;

    /// @notice The withdrawal queue.
    mapping(uint256 requestId => WithdrawalRequest request) public withdrawalQueue;

    /// @notice The processed batches.
    mapping(uint256 batchId => ProcessedBatch batch) public processedBatches;

    /// @notice The cumulative shares requested for withdrawn by request id.
    mapping(uint256 requestId => uint256 cumShares) public cumulativeWithdrawnShares;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    //////////      INIT      //////////

    function initialize(address owner, address _beraManager, address _gBera) public initializer {
        __Ownable_init(owner);
        __ERC721_init(NAME, SYMBOL);
        __ERC721Enumerable_init();
        __UUPSUpgradeable_init();
        beraManager = IGBeraAssetManager(_beraManager);
        gbera = IGBera(_gBera);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner { }

    receive() external payable { }

    ////////// MODIFIERS //////////

    modifier onlyManager() {
        if (msg.sender != address(beraManager)) revert NotManager();
        _;
    }

    modifier onlyGBera() {
        if (msg.sender != address(gbera)) revert NotGBera();
        _;
    }

    ////////// STATE CHANGING //////////

    /// @inheritdoc IWithdrawalQueue
    function submitRequest(
        uint256 gBeraAmount,
        uint256 sharesAmount,
        address receiver
    )
        external
        override
        onlyGBera
        returns (uint256 requestId)
    {
        requestId = ++lastRequestId;
        withdrawalQueue[requestId] =
            WithdrawalRequest({ receiver: payable(receiver), shares: sharesAmount, time: block.timestamp });
        cumulativeWithdrawnShares[requestId] = cumulativeWithdrawnShares[requestId - 1] + sharesAmount;
        _mint(receiver, requestId);

        emit WithdrawalRequestSubmitted(requestId, receiver, sharesAmount, gBeraAmount, block.timestamp);
    }

    /// @inheritdoc IWithdrawalQueue
    function processQueue(uint256 refRequestId)
        external
        override
        onlyManager
        returns (uint256 beraAmount, uint256 sharesAmount)
    {
        // refRequestId which will be able to withdraw should not be already processed nor in the future
        if (refRequestId <= lastProcessedId || refRequestId > lastRequestId) revert OutsideRequestBounds();

        // calculate how many shares need to be burned for this batch
        sharesAmount = cumulativeWithdrawnShares[refRequestId] - cumulativeWithdrawnShares[lastProcessedId];
        // calculate how many BERA need to be transferred for this batch
        beraAmount = gbera.getRebasedAmount(sharesAmount, false);

        // since there is no way to retrieve the BERA needed after this time, we need to store them
        processedBatches[++lastBatchIndex] =
            ProcessedBatch({ lowerIndex: lastProcessedId + 1, upperIndex: refRequestId, beraAmount: beraAmount });

        emit QueueProcessed(lastBatchIndex, lastProcessedId, refRequestId, beraAmount, sharesAmount);

        lastProcessedId = refRequestId;
    }

    /// @inheritdoc IWithdrawalQueue
    function claimBera(uint256 requestId, uint256 batchIndex) external override onlyGBera {
        if (requestId > lastProcessedId) revert NotYetProcessed();
        ProcessedBatch memory batch = processedBatches[batchIndex];
        if (requestId < batch.lowerIndex || requestId > batch.upperIndex) revert IndexNotBelongingToBatch();
        WithdrawalRequest memory request = withdrawalQueue[requestId];

        // retrieve the shares corresponding to the batch
        uint256 batchSharesAmount =
            cumulativeWithdrawnShares[batch.upperIndex] - cumulativeWithdrawnShares[batch.lowerIndex - 1];

        // calculate proportional share of BERA of the index
        uint256 beraToTransfer = request.shares * batch.beraAmount / batchSharesAmount;
        // burn claimed NFT
        _burn(requestId);
        delete withdrawalQueue[requestId];

        (bool success,) = request.receiver.call{ value: beraToTransfer }("");
        if (!success) revert TransferFailed();
        emit BeraClaimed(requestId, batchIndex, request.receiver, beraToTransfer);
    }

    /// @dev Override the _update function to prevent transfers.
    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        address from = _ownerOf(tokenId);

        if (from != address(0) && to != address(0)) {
            revert TransfersNotAllowed();
        }

        return super._update(to, tokenId, auth);
    }
}
