// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { OwnableUpgradeable } from "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import { IGBeraAssetManager } from "./interfaces/IGBeraAssetManager.sol";
import { INodeRegistry } from "./interfaces/INodeRegistry.sol";
import { IDepositContract } from "./interfaces/external/IDepositContract.sol";

/**
 * @title NodeRegistry
 * @notice Contract to store validators data in the system.
 */
contract NodeRegistry is INodeRegistry, OwnableUpgradeable, UUPSUpgradeable {
    /// @notice Length in bytes of a BLS Public Key used for validator deposits
    uint256 internal constant PUBLIC_KEY_LENGTH = 48;

    /// @notice Length in bytes of a BLS Signature used for validator deposits
    uint256 internal constant SIGNATURE_LENGTH = 96;

    //////////    STORAGE     //////////

    /// @notice The bera manager.
    address public manager;

    /// @notice The address of the NodeWithdrawalVault.
    address public withdrawalVault;

    /// @notice The total amount staked over nodes.
    uint256 public deposits;

    /// @notice The validators list
    bytes[] public allValidators;

    /// @notice The maximum allocation amount
    uint256 public maxAllocation;

    /// @notice Whether a public key is associated to a validator
    mapping(bytes publicKey => INodeRegistry.Node node) public validators;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    //////////      INIT      //////////

    function initialize(address owner, address _withdrawalVault, address _manager) public initializer {
        __Ownable_init(owner);
        __UUPSUpgradeable_init();

        withdrawalVault = _withdrawalVault;
        manager = _manager;
        // Current max stake per validator = 10 million BERA (can set it later)
        maxAllocation = 10e6 ether - IGBeraAssetManager(manager).minDepositAmount();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner { }

    //////////   MODIFIERS    //////////

    /// @notice Only the bera manager can call the function
    modifier onlyManager() {
        if (msg.sender != manager) revert NotManager();
        _;
    }

    /////////// SETTERS ///////////

    function setMaxAllocation(uint256 _maxAllocation) external onlyOwner {
        emit MaxAllocationUpdated(maxAllocation, _maxAllocation);
        maxAllocation = _maxAllocation;
    }

    ////////// STATE CHANGING //////////

    /// @inheritdoc INodeRegistry
    function createNode(
        bytes calldata publicKey,
        bytes calldata signature,
        string calldata name
    )
        external
        payable
        onlyOwner
    {
        if (publicKey.length != PUBLIC_KEY_LENGTH) revert InconsistentPublicKey();
        if (signature.length != SIGNATURE_LENGTH) revert InconsistentSignature();

        // Check node existance on deposit contract.
        address operator = IDepositContract(IGBeraAssetManager(manager).depositContract()).getOperator(publicKey);
        if (validators[publicKey].lastUpdate > 0 || operator != address(0)) revert NodeAlreadyExists();

        // Minor: could be done one for all validators since using common withdrawalVault.
        // Stick to this since could upgrade to one vault per node.
        bytes memory withdrawalCredentials = _withdrawalAddressToCredentials(withdrawalVault);

        Node memory node = Node({
            name: name,
            publicKey: publicKey,
            withdrawalCredentials: withdrawalCredentials,
            signature: signature,
            stakeAmount: 0,
            isActive: false,
            lastUpdate: block.timestamp
        });
        validators[publicKey] = node;
        allValidators.push(publicKey);

        emit NodeCreated(publicKey, name);
    }

    function _withdrawalAddressToCredentials(address withdrawalAddress)
        internal
        pure
        returns (bytes memory withdrawalCredentials)
    {
        // credentials type 0x01 + 11 * 0x00 bytes
        uint96 withdrawalCredentialsPrefix = 0x010000000000000000000000;
        return abi.encodePacked(withdrawalCredentialsPrefix, withdrawalAddress);
    }

    // Owner can activate the node after validating the first deposit with APIs after ~ 2 epochs (10 minutes)
    /// @inheritdoc INodeRegistry
    function setNodeActivationStatus(bytes calldata publicKey, bool status) external onlyOwner {
        Node storage validator = validators[publicKey];
        if (validator.lastUpdate == 0) revert NodeNotFound();
        if (status && validator.stakeAmount == 0) revert FirstDepositNotPerformed();

        validator.isActive = status;
        validator.lastUpdate = block.timestamp;

        emit NodeActivationStatusUpdated(validator.publicKey, status);
    }

    /// @inheritdoc INodeRegistry
    function increaseNodeStake(bytes calldata publicKey, uint256 amount) external onlyManager {
        Node storage validator = validators[publicKey];
        if (validator.lastUpdate == 0) revert NodeNotFound();
        if (!validator.isActive && validator.stakeAmount > 0) revert NodeNotActive();
        if (validator.stakeAmount + amount > maxAllocation) revert AmountTooHigh();

        validator.stakeAmount += amount;
        validator.lastUpdate = block.timestamp;
        deposits += amount;
        emit NodeStakeAmountUpdated(validator.publicKey, validator.stakeAmount);
    }

    /// @inheritdoc INodeRegistry
    function deallocateNode(bytes calldata publicKey, uint256 amount) external onlyOwner {
        _decreaseNodeStake(publicKey, amount);
    }

    /// @inheritdoc INodeRegistry
    function registerWithdrawal(bytes calldata publicKey, uint256 amount) external onlyManager {
        _decreaseNodeStake(publicKey, amount);
    }

    /// @dev Internal function to decrease the node stake amount.
    function _decreaseNodeStake(bytes calldata publicKey, uint256 amount) internal {
        Node storage validator = validators[publicKey];
        if (validator.lastUpdate == 0) revert NodeNotFound();
        if (!validator.isActive && validator.stakeAmount > 0) revert NodeNotActive();
        if (amount > validator.stakeAmount) revert AmountTooHigh();

        validator.stakeAmount -= amount;
        validator.lastUpdate = block.timestamp;
        deposits -= amount;
        emit NodeStakeAmountUpdated(validator.publicKey, validator.stakeAmount);
    }

    //////////    GETTERS     //////////

    /// @inheritdoc INodeRegistry
    function getAllNodes() external view returns (bytes[] memory) {
        return allValidators;
    }

    /// @inheritdoc INodeRegistry
    function getLastNodePK() external view returns (bytes memory publicKey) {
        if (allValidators.length == 0) revert NodeNotFound();
        return allValidators[allValidators.length - 1];
    }

    /// @inheritdoc INodeRegistry
    function getNodeData(bytes calldata publicKey) external view returns (Node memory) {
        Node memory validator = validators[publicKey];
        if (validator.lastUpdate == 0) revert NodeNotFound();

        return validator;
    }
}
