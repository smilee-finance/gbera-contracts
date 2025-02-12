// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Vm } from "forge-std/Test.sol";

contract MockBGT {
    Vm public vm = Vm(address(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D)); // hevm cheat code (Base.sol)
    mapping(bytes key => uint256 queuedBoost) public queuedBoosts;
    mapping(bytes key => uint256 queuedDropBoost) public queuedDropBoosts;
    mapping(bytes key => uint256 boost) public boosts;
    mapping(address account => uint256 balance) public balances;
    uint256 public totalBoost;

    function queueBoost(bytes calldata publicKey, uint128 amount) external {
        queuedBoosts[publicKey] += amount;
    }

    function cancelBoost(bytes calldata publicKey, uint128 amount) external {
        queuedBoosts[publicKey] -= amount;
    }

    function activateBoost(bytes calldata publicKey) external {
        boosts[publicKey] += queuedBoosts[publicKey];
        queuedBoosts[publicKey] = 0;
        totalBoost += boosts[publicKey];
    }

    function queueDropBoost(bytes calldata publicKey, uint128 amount) external {
        queuedDropBoosts[publicKey] += amount;
    }

    function cancelDropBoost(bytes calldata publicKey, uint128 amount) external {
        queuedDropBoosts[publicKey] -= amount;
    }

    function dropBoost(bytes calldata publicKey) external {
        boosts[publicKey] -= queuedDropBoosts[publicKey];
        queuedDropBoosts[publicKey] = 0;
        totalBoost -= boosts[publicKey];
    }

    function redeem(address to, uint256 amount) external {
        balances[to] -= amount;
        vm.deal(to, to.balance + amount);
    }

    function unboostedBalanceOf(address account) external pure returns (uint256) {
        account;
        return 0;
    }

    function setBalance(address account, uint256 amount) external {
        balances[account] = amount;
    }

    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }
}
