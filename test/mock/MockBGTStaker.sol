// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { MockWBERA } from "./MockWBERA.sol";

contract MockBGTStaker {
    uint256 internal rewards;
    uint256 internal earnings;
    address public wberaAddress;

    function setWbera(address _wberaAddress) external {
        wberaAddress = _wberaAddress;
    }

    function setRewardValue(uint256 _rewards) external {
        rewards = _rewards;
    }

    /// @dev Should provide WBERA to this contract before calling this function
    function getReward() external returns (uint256) {
        MockWBERA(payable(wberaAddress)).transfer(msg.sender, rewards);
        return rewards;
    }

    function earned(address owner) external view returns (uint256) {
        owner;
        return MockWBERA(payable(wberaAddress)).balanceOf(address(this));
    }
}
