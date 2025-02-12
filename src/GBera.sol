// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { OwnableUpgradeable } from "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ERC20Upgradeable } from "@openzeppelin-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { IGBera } from "./interfaces/IGBera.sol";
import { IGBeraAssetManager } from "./interfaces/IGBeraAssetManager.sol";
import { IWithdrawalQueue } from "./interfaces/IWithdrawalQueue.sol";

/**
 * @title GBera Token
 * @notice ERC20 rebasing token representing a share of the underlying assets managed by the gBeraAssetManager.
 */
contract GBera is IGBera, ERC20Upgradeable, OwnableUpgradeable, UUPSUpgradeable {
    using Math for uint256;

    string private constant NAME = "gBERA Token";
    string private constant SYMBOL = "gBERA";

    /// @notice The bera manager contract
    IGBeraAssetManager public manager;

    /// @notice The withdrawal queue contract
    IWithdrawalQueue public withdrawalQueue;

    /// @notice Flag to enable or disable withdrawals
    bool public withdrawalEnabled;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address owner, address _manager, address _withdrawalQueue) public initializer {
        __ERC20_init(NAME, SYMBOL);
        __Ownable_init(owner);
        __UUPSUpgradeable_init();

        withdrawalEnabled = false;
        manager = IGBeraAssetManager(_manager);
        withdrawalQueue = IWithdrawalQueue(_withdrawalQueue);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner { }

    receive() external payable {
        deposit(msg.sender);
    }

    //////////   MODIFIERS    //////////

    /// @notice Only the bera manager can call the function
    modifier onlyManager() {
        if (msg.sender != address(manager)) revert NotManager();
        _;
    }

    //////////    SETTERS     //////////

    /// @inheritdoc IGBera
    function setAssetManager(address _manager) external onlyOwner {
        if (_manager == address(0)) revert AddressZero();
        emit GBeraAssetManagerUpdated(address(manager), _manager);
        manager = IGBeraAssetManager(_manager);
    }

    /// @inheritdoc IGBera
    function setWithdrawalQueue(address _withdrawalQueue) external onlyOwner {
        if (_withdrawalQueue == address(0)) revert AddressZero();
        emit NodeWithdrawalQueueUpdated(address(withdrawalQueue), _withdrawalQueue);
        withdrawalQueue = IWithdrawalQueue(_withdrawalQueue);
    }

    /// @inheritdoc IGBera
    function setWithdrawalEnabled(bool flag) external onlyOwner {
        withdrawalEnabled = flag;
        emit WithdrawalEnabledUpdated(flag);
    }

    //////////      VIEW      //////////

    /// @inheritdoc IERC20
    function totalSupply() public view override(ERC20Upgradeable, IGBera) returns (uint256) {
        // safer to round up total supply
        return _sharesToAssets(super.totalSupply(), true);
    }

    /// @inheritdoc IERC20
    function balanceOf(address account) public view override(ERC20Upgradeable, IGBera) returns (uint256) {
        // safer to round down balances
        return _sharesToAssets(super.balanceOf(account), false);
    }

    /// @inheritdoc IGBera
    function totalShares() public view returns (uint256) {
        return super.totalSupply();
    }

    /// @inheritdoc IGBera
    function balanceOfShares(address account) public view returns (uint256) {
        return super.balanceOf(account);
    }

    /// @inheritdoc IGBera
    function getRebasedAmount(uint256 amount, bool roundUp) external view returns (uint256) {
        return _sharesToAssets(amount, roundUp);
    }

    /// @inheritdoc IGBera
    function getUnrebasedAmount(uint256 amount, bool roundUp) external view returns (uint256) {
        return _assetsToShares(amount, roundUp);
    }

    /// @inheritdoc IGBera
    function sharePrice() external view returns (uint256) {
        return (_totalAssets() * 1e18) / super.totalSupply();
    }

    ////////// STATE CHANGING //////////

    /// @inheritdoc IGBera
    function deposit(address receiver) public payable returns (uint256) {
        if (msg.value == 0 || (totalSupply() == 0 && msg.value < 1e18)) revert InvalidAmount();

        // this ensures that balanceOf of receiver will grow by msg.value (+- rounding)
        uint256 sharesToMint = _assetsToShares(msg.value, false);
        super._update(address(0), receiver, sharesToMint);

        (bool success,) = address(manager).call{ value: msg.value }("");
        if (!success) revert BeraTransferFailed();

        emit Deposit(receiver, sharesToMint, msg.value);
        return sharesToMint;
    }

    /// @inheritdoc IGBera
    function requestWithdrawal(uint256 amount, address receiver) external returns (uint256 requestId) {
        if (!withdrawalEnabled) revert WithdrawalDisabled();
        if (amount == 0) revert InvalidAmount();

        address queue = address(withdrawalQueue);

        // amount here is in gBERA units (rebased) and we round down to avoid eventual reversals
        // user could keep some dust, but will be able to simply withdraw its balanceOf
        uint256 sharesAmount = _assetsToShares(amount, false);
        if (totalShares() - balanceOfShares(queue) - sharesAmount < 1e18) revert InvalidAmount();

        transferShares(queue, sharesAmount);

        requestId = IWithdrawalQueue(queue).submitRequest(amount, sharesAmount, receiver);
    }

    /// @inheritdoc IGBera
    function completeWithdrawal(uint256 id, uint256 batchIndex) external {
        withdrawalQueue.claimBera(id, batchIndex);
    }

    /// @inheritdoc IGBera
    function transferShares(address to, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        _transferShares(owner, to, value);
        return true;
    }

    /// @inheritdoc IGBera
    function approveShares(address spender, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 tokenAmount = _sharesToAssets(value, true); // Round up since when spending ww do the same
        _approve(owner, spender, tokenAmount);
        return true;
    }

    /// @inheritdoc IGBera
    function transferSharesFrom(address from, address to, uint256 value) public virtual returns (bool) {
        address spender = _msgSender();
        // Since allowance is managed in rebased amounts, get the conversion to update the allowance
        uint256 tokenAmount = _sharesToAssets(value, true); // Round up for safety

        _spendAllowance(from, spender, tokenAmount);
        _transferShares(from, to, value);
        return true;
    }

    /// @inheritdoc IGBera
    /// @dev Only the bera manager can burn GBera from the withdrawal queue
    /// @dev amount here is in BERA units (unrebased)
    function burnShares(address account, uint256 value) public onlyManager {
        if (account == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        super._update(account, address(0), value);
    }

    //////////    INTERNAL    //////////

    /// @dev Override to transform "value" in unrebased amount to match current shares value.
    /// @dev the "transfer" and "transferFrom" functions should only called by EOAs to avoid rounding errors
    function _update(address from, address to, uint256 value) internal override {
        super._update(from, to, _assetsToShares(value, false));
    }

    /// @dev ref. ERC20 "_transfer" function
    function _transferShares(address from, address to, uint256 value) internal {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        super._update(from, to, value);
    }

    function _sharesToAssets(uint256 amount, bool roundUp) internal view returns (uint256) {
        uint256 assets = _totalAssets();
        uint256 supply = super.totalSupply();
        // If first minting, mint 1:1
        if (supply == 0) return amount;
        // Return [assets / supply] proportion computed on amount
        return amount.mulDiv(assets, supply, roundUp ? Math.Rounding.Ceil : Math.Rounding.Floor);
    }

    function _assetsToShares(uint256 amount, bool roundUp) internal view returns (uint256) {
        uint256 assets = _totalAssets();
        uint256 supply = super.totalSupply();
        // If minting when supply > 0 and assets = 0, mint 1:1 (sharing `amount` with outstanding holders)
        if (assets == 0 || supply == 0) return amount;
        // Return [supply / assets] proportion computed on amount
        return amount.mulDiv(supply, assets, roundUp ? Math.Rounding.Ceil : Math.Rounding.Floor);
    }

    function _totalAssets() internal view returns (uint256) {
        return manager.totalAssets();
    }
}
