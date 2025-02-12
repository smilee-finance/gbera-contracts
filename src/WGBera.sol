// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { IGBera } from "./interfaces/IGBera.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC4626 } from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title Wrapped gBERA
 * @notice ERC4626 vault for GBera contract, to allow wrapping of rebasing token.
 * @dev Unlike typical ERC4626 vaults, totalAssets() is externally determined by the underlying GBera
 * contract rebasedAmount() function, called on the total amount of shares minted by this contract
 * and corresponding to GBera's internal shares (unrebased amounts).
 */
contract WGBera is ERC4626 {
    error InvalidAmount();

    constructor(IERC20 _gBera) ERC20("Wrapped gBERA", "wgBERA") ERC4626(_gBera) { }

    /**
     * @notice Shortcut to stake BERA and auto-wrap returned GBera
     */
    receive() external payable {
        uint256 shares = IGBera(asset()).deposit{ value: msg.value }(address(this));
        _mint(msg.sender, shares);
    }

    function _convertToShares(uint256 assets, Math.Rounding rounding) internal view override returns (uint256) {
        bool roundUp = rounding == Math.Rounding.Ceil;
        return IGBera(asset()).getUnrebasedAmount(assets, roundUp);
    }

    function _convertToAssets(uint256 shares, Math.Rounding rounding) internal view override returns (uint256) {
        bool roundUp = rounding == Math.Rounding.Ceil;
        return IGBera(asset()).getRebasedAmount(shares, roundUp);
    }
}
