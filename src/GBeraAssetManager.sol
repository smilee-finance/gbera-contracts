// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { BeraContractsLocator } from "./BeraContractsLocator.sol";
import { IBGTOperator } from "./interfaces/IBGTOperator.sol";
import { IGBera } from "./interfaces/IGBera.sol";
import { IGBeraAssetManager } from "./interfaces/IGBeraAssetManager.sol";
import { INodeFeeReceiver } from "./interfaces/INodeFeeReceiver.sol";
import { INodeRegistry } from "./interfaces/INodeRegistry.sol";
import { INodeWithdrawalVault } from "./interfaces/INodeWithdrawalVault.sol";
import { IWithdrawalQueue } from "./interfaces/IWithdrawalQueue.sol";
import { IBGT } from "./interfaces/external/IBGT.sol";
import { IBGTStaker } from "./interfaces/external/IBGTStaker.sol";
import { IBeraChef } from "./interfaces/external/IBeraChef.sol";
import { IDepositContract } from "./interfaces/external/IDepositContract.sol";
import { IWBERA } from "./interfaces/external/IWBERA.sol";
import { AccessControlUpgradeable } from "@openzeppelin-upgradeable/access/AccessControlUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title GBeraAssetManager
 * @notice Contract to manage the underlying assets of the GBera token.
 */
contract GBeraAssetManager is IGBeraAssetManager, AccessControlUpgradeable, UUPSUpgradeable {
    /// @notice empty 32 bytes to be used as credentials when depositing.
    bytes internal constant EMPTY_CREDENTIALS = abi.encodePacked(bytes32(""));

    /// @notice empty 96 bytes to be used as signature when depositing.
    bytes internal constant EMPTY_SIGNATURE = abi.encodePacked(bytes32(""), bytes32(""), bytes32(""));

    /// @notice Role to manage bgts in this contract.
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    //////////    STORAGE     //////////

    /// @notice The minimum deposit amount.
    uint256 public immutable minDepositAmount;

    /// @notice The deposit contract.
    address public immutable depositContract;

    /// @notice The bgt contract.
    address public immutable bgt;

    /// @notice The bgt staker contract.
    address public immutable bgtStaker;

    /// @notice The bera chef contract.
    address public immutable beraChef;

    /// @notice The wbera contract.
    address public immutable wbera;

    /// @notice The GBera contract.
    IGBera public immutable gbera;

    /// @notice The node registry contract.
    INodeRegistry public immutable nodeRegistry;

    /// @notice Address of the withdrawal queue.
    IWithdrawalQueue public immutable withdrawalQueue;

    /// @notice The withdrawal vault contract.
    INodeWithdrawalVault public withdrawalVault;

    /// @notice Address of the node fee receiver.
    INodeFeeReceiver public nodeFeeReceiver;

    /// @inheritdoc IGBeraAssetManager
    uint256 public feePercentage = 0;

    /// @notice The stored fees amount for accountability; note that this is not the "live" fees value.
    uint256 public storedProtocolFees = 0;

    /// @notice The balance of bgt already charged with fees.
    uint256 internal _bgtBalanceAlreaadyCharged = 0;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _beraLocator, address _gBera, address _nodeRegistry, address _withdrawalQueue) {
        _disableInitializers();
        gbera = IGBera(_gBera);
        nodeRegistry = INodeRegistry(_nodeRegistry);
        withdrawalQueue = IWithdrawalQueue(_withdrawalQueue);

        BeraContractsLocator locator = BeraContractsLocator(_beraLocator);
        depositContract = locator.depositContract();
        beraChef = locator.beraChef();
        bgt = locator.bgt();
        bgtStaker = locator.bgtStaker();
        wbera = locator.wbera();

        // Current minimum value in deposit contract (can set it later)
        minDepositAmount = 10_000 ether;
    }

    //////////      INIT      //////////

    function initialize(address _admin, address _withdrawalVault, address _nodeFeeReceiver) public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);

        withdrawalVault = INodeWithdrawalVault(_withdrawalVault);
        nodeFeeReceiver = INodeFeeReceiver(_nodeFeeReceiver);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) { }

    receive() external payable {
        // emit event only for donations
        if (msg.sender != address(gbera) && msg.sender != address(nodeFeeReceiver)) {
            emit Received(msg.sender, msg.value);
        }
    }

    ////////// STATE CHANGING //////////

    /// @inheritdoc IGBeraAssetManager
    function setFeePercentage(uint256 _feePercentage) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_feePercentage > 1e18) revert InvalidFeePercentage();
        emit FeePercentageUpdated(feePercentage, _feePercentage);

        // Update fees with current percentage before updating
        updateBgtFees();
        collectStakerRewards();
        collectNodeFeeRewards();

        feePercentage = _feePercentage;
    }

    /// @inheritdoc IGBeraAssetManager
    function withdrawProtocolFees(address receiver) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 amount = storedProtocolFees;
        if (amount > address(this).balance) revert NotEnoughBalance();

        storedProtocolFees = 0;
        (bool success,) = receiver.call{ value: amount }("");
        if (!success) revert BeraTransferFailed();

        emit ProtocolFeesWithdrawn(receiver, amount);
    }

    /// @inheritdoc IGBeraAssetManager
    function setNodeFeeUnlockTime(uint256 _unlockTime) external onlyRole(DEFAULT_ADMIN_ROLE) {
        nodeFeeReceiver.setUnlockTime(_unlockTime);
    }

    /// @inheritdoc IGBeraAssetManager
    function setNodeFeeReceiver(address _nodeFeeReceiver) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_nodeFeeReceiver == address(0)) revert AddressZero();

        emit NodeFeeReceiverUpdated(address(nodeFeeReceiver), _nodeFeeReceiver);
        nodeFeeReceiver = INodeFeeReceiver(_nodeFeeReceiver);
    }

    /// @inheritdoc IGBeraAssetManager
    function deposit(bytes calldata publicKey, uint256 amount) external payable onlyRole(DEFAULT_ADMIN_ROLE) {
        if (amount < minDepositAmount) revert InvalidDepositAmount();
        if (amount > address(this).balance) revert NotEnoughBalance();

        // Get validator from registry
        INodeRegistry.Node memory nodeData = nodeRegistry.getNodeData(publicKey);
        if (nodeData.lastUpdate == 0) revert NodeNotFound(); // Node not created yet

        // Manage first deposit
        if (!nodeData.isActive && nodeData.stakeAmount == 0) {
            // Limit first deposit to minimum deposit amount
            if (amount != minDepositAmount) revert InvalidDepositAmount();
            _deposit(nodeData.publicKey, nodeData.withdrawalCredentials, nodeData.signature, address(this), amount);
        }
        // Manage standard deposit
        else if (nodeData.stakeAmount > 0) {
            // If the node is not active, it means the first deposit has not been verified yet
            if (!nodeData.isActive) revert NodeNotActive();
            // Use empty credentials and signature since they do not get verified after first deposit
            // Use 0 as operator on subsequent deposits
            _deposit(nodeData.publicKey, EMPTY_CREDENTIALS, EMPTY_SIGNATURE, address(0), amount);
        }
    }

    /// @inheritdoc IGBeraAssetManager
    function withdrawWithdrawals(uint256 amount, bytes calldata publicKey) external onlyRole(DEFAULT_ADMIN_ROLE) {
        // NOTE: shall the input be incorrect, it may mess up the accounting in NodeRegistry.
        withdrawalVault.withdrawWithdrawals(amount);

        // reverts if a node for publicKey does not exists or amount is more than currently registered deposit
        nodeRegistry.registerWithdrawal(publicKey, amount);

        emit WithdrawFromVault(amount, publicKey);
    }

    /// @inheritdoc IGBeraAssetManager
    function processWithdrawalQueue(uint256 refRequestId) external {
        if (!gbera.withdrawalEnabled()) revert WithdrawalDisabled();
        (uint256 beraToTransfer, uint256 sharesToBurn) = withdrawalQueue.processQueue(refRequestId);

        if (beraToTransfer > address(this).balance) revert NotEnoughBalance();

        gbera.burnShares(address(withdrawalQueue), sharesToBurn);
        (bool success,) = address(withdrawalQueue).call{ value: beraToTransfer }("");
        if (!success) revert BeraTransferFailed();

        emit WithdrawalQueueProcessed(refRequestId, beraToTransfer, sharesToBurn);
    }

    /// @inheritdoc IGBeraAssetManager
    function collectStakerRewards() public {
        uint256 reward = IBGTStaker(bgtStaker).getReward();
        if (reward == 0) return;

        IWBERA(wbera).withdraw(reward);
        uint256 fees = _accrueProtocolFees(reward);

        emit StakerRewardCollected(reward - fees);
    }

    /// @inheritdoc IGBeraAssetManager
    function collectNodeFeeRewards() public {
        uint256 reward = nodeFeeReceiver.collectRewards();
        if (reward == 0) return;

        uint256 fees = _accrueProtocolFees(reward);
        emit NodeFeeRewardCollected(reward - fees);
    }

    /// @inheritdoc IGBeraAssetManager
    function updateBgtFees() public {
        // Get uncharged portion of the bgt balance
        uint256 bgtBalance = IBGT(bgt).balanceOf(address(this));
        uint256 bgtBalanceToCharge = bgtBalance - _bgtBalanceAlreaadyCharged;
        _accrueProtocolFees(bgtBalanceToCharge);
        _bgtBalanceAlreaadyCharged = bgtBalance;
    }

    //////////     VIEW       //////////

    /// @inheritdoc IGBeraAssetManager
    function protocolFees() external view returns (uint256) {
        uint256 bgtBalanceToCharge = IBGT(bgt).balanceOf(address(this)) - _bgtBalanceAlreaadyCharged;
        uint256 rewardsToCharge =
            bgtBalanceToCharge + IBGTStaker(bgtStaker).earned(address(this)) + nodeFeeReceiver.earned();
        return storedProtocolFees + (rewardsToCharge * feePercentage / 1e18);
    }

    /// @inheritdoc IGBeraAssetManager
    function totalAssets() external view returns (uint256) {
        uint256 bgtBalance = IBGT(bgt).balanceOf(address(this));
        uint256 r1 = IBGTStaker(bgtStaker).earned(address(this));
        uint256 r2 = nodeFeeReceiver.earned();
        uint256 fees = 0;

        if (feePercentage > 0) {
            uint256 rewardsToCharge = (bgtBalance - _bgtBalanceAlreaadyCharged) + r1 + r2;
            fees = storedProtocolFees + (rewardsToCharge * feePercentage / 1e18);
        }

        uint256 rewards_ = bgtBalance + r1 + r2;
        return address(this).balance + nodeRegistry.deposits() + rewards_ - fees;
    }

    //////////    INTERNAL    //////////

    function _deposit(
        bytes memory publicKey,
        bytes memory credentials,
        bytes memory signature,
        address operator,
        uint256 amount
    )
        internal
    {
        IDepositContract(depositContract).deposit{ value: amount }(publicKey, credentials, signature, operator);
        nodeRegistry.increaseNodeStake(publicKey, amount);
        emit Deposit(publicKey, amount);
    }

    function _accrueProtocolFees(uint256 reward) internal returns (uint256 feeAmount) {
        feeAmount = feePercentage * reward / 1e18;
        storedProtocolFees += feeAmount;

        emit ProtocolFeesAccrued(feeAmount);
    }

    ////////// BGT MANAGEMENT //////////

    /// @inheritdoc IBGTOperator
    function requestOperatorChange(bytes calldata publicKey, address newOperator) external onlyRole(OPERATOR_ROLE) {
        IDepositContract(depositContract).requestOperatorChange(publicKey, newOperator);
    }

    /// @inheritdoc IBGTOperator
    function cancelOperatorChange(bytes calldata publicKey) external onlyRole(OPERATOR_ROLE) {
        IDepositContract(depositContract).cancelOperatorChange(publicKey);
    }

    /// @inheritdoc IBGTOperator
    function queueBoost(bytes calldata publicKey, uint128 amount) external onlyRole(OPERATOR_ROLE) {
        IBGT(bgt).queueBoost(publicKey, amount);
    }

    /// @inheritdoc IBGTOperator
    function cancelBoost(bytes calldata publicKey, uint128 amount) external onlyRole(OPERATOR_ROLE) {
        IBGT(bgt).cancelBoost(publicKey, amount);
    }

    /// @inheritdoc IBGTOperator
    function activateBoost(bytes calldata publicKey) external {
        IBGT(bgt).activateBoost(address(this), publicKey);
    }

    /// @inheritdoc IBGTOperator
    function queueDropBoost(bytes calldata publicKey, uint128 amount) external onlyRole(OPERATOR_ROLE) {
        IBGT(bgt).queueDropBoost(publicKey, amount);
    }

    /// @inheritdoc IBGTOperator
    function cancelDropBoost(bytes calldata publicKey, uint128 amount) external onlyRole(OPERATOR_ROLE) {
        IBGT(bgt).cancelDropBoost(publicKey, amount);
    }

    /// @inheritdoc IBGTOperator
    function dropBoost(bytes calldata publicKey) external {
        IBGT(bgt).dropBoost(address(this), publicKey);
    }

    /// @inheritdoc IBGTOperator
    function redeemBGT(uint256 amount) external onlyRole(OPERATOR_ROLE) {
        // Since redeeming will affect the balance, need to update the fees before
        // Note that this will affect the available balance of bgt
        // Ex.: if redeeming 1 bgt, to enable withdrawal of 1 storedProtocolFees, this may
        // increase storedProtocolFees by 0.5 and still prevent withdrawal for missing balance.
        updateBgtFees();

        // Reverts with IBGT.NotEnoughBalance if not enough unboosted balance
        IBGT(bgt).redeem(address(this), amount);

        // Update value after redeem
        _bgtBalanceAlreaadyCharged = IBGT(bgt).balanceOf(address(this));
    }

    /// @inheritdoc IBGTOperator
    function queueNewRewardAllocation(
        bytes calldata valPubkey,
        uint64 startBlock,
        IBeraChef.Weight[] calldata weights
    )
        external
        onlyRole(OPERATOR_ROLE)
    {
        IBeraChef(beraChef).queueNewRewardAllocation(valPubkey, startBlock, weights);
    }
}
