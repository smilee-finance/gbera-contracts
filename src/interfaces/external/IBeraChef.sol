// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IBeraChef {
    struct Weight {
        address receiver;
        uint96 percentageNumerator;
    }

    function distributor() external view returns (address);

    function queueNewRewardAllocation(
        bytes calldata valPubkey,
        uint64 startBlock,
        Weight[] calldata weights
    )
        external;
}
