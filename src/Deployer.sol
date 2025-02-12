// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { BeraContractsLocator } from "./BeraContractsLocator.sol";
import { GBera } from "./GBera.sol";
import { GBeraAssetManager } from "./GBeraAssetManager.sol";
import { NodeFeeReceiver } from "./NodeFeeReceiver.sol";
import { NodeRegistry } from "./NodeRegistry.sol";
import { NodeWithdrawalVault } from "./NodeWithdrawalVault.sol";

import { WGBera } from "./WGBera.sol";
import { WithdrawalQueue } from "./WithdrawalQueue.sol";

/**
 * @title Deployer
 * @notice Helper contract to deploy and access contracts in the system.
 */
contract Deployer {
    error AddressZero();

    BeraContractsLocator public locator;
    NodeRegistry public registry;
    GBeraAssetManager public manager;
    WithdrawalQueue public withdrawalQueue;
    GBera public gbera;
    NodeWithdrawalVault public withdrawalVault;
    NodeFeeReceiver public nodeFeeReceiver;
    WGBera public wgbera;
    address public depositContract;
    address public bgtStaker;
    address public bgt;
    address public beraChef;
    address public wbera;

    constructor(
        address admin,
        address _depositContract,
        address _bgtStaker,
        address _bgt,
        address _beraChef,
        address _wbera
    ) {
        _checkAddressZero(_depositContract);
        _checkAddressZero(_bgtStaker);
        _checkAddressZero(_bgt);
        _checkAddressZero(_beraChef);
        _checkAddressZero(_wbera);

        depositContract = _depositContract;
        bgtStaker = _bgtStaker;
        beraChef = _beraChef;
        bgt = _bgt;
        wbera = _wbera;
        _deployContracts(admin);
    }

    function _deployContracts(address owner) internal {
        bytes memory empty = new bytes(0);

        locator = new BeraContractsLocator(depositContract, bgt, bgtStaker, beraChef, wbera);

        address payable registryProxy = payable(new ERC1967Proxy(address(new NodeRegistry()), empty));
        registry = NodeRegistry(registryProxy);

        address payable withdrawalQueueProxy = payable(new ERC1967Proxy(address(new WithdrawalQueue()), empty));
        withdrawalQueue = WithdrawalQueue(withdrawalQueueProxy);

        address payable gberaProxy = payable(new ERC1967Proxy(address(new GBera()), empty));
        gbera = GBera(gberaProxy);

        address gBeraAssetManagerImpl = address(
            new GBeraAssetManager(address(locator), address(gbera), address(registry), address(withdrawalQueue))
        );
        address payable managerProxy = payable(new ERC1967Proxy(gBeraAssetManagerImpl, empty));
        manager = GBeraAssetManager(managerProxy);

        withdrawalVault = new NodeWithdrawalVault(address(manager), address(registry));
        nodeFeeReceiver = new NodeFeeReceiver(address(manager));

        gbera.initialize(owner, address(manager), address(withdrawalQueue));
        registry.initialize(owner, address(withdrawalVault), address(manager));
        withdrawalQueue.initialize(owner, address(manager), address(gbera));
        manager.initialize(owner, address(withdrawalVault), address(nodeFeeReceiver));

        wgbera = new WGBera(IERC20(address(gbera)));
    }

    function _checkAddressZero(address addr) internal pure {
        if (addr == address(0)) revert AddressZero();
    }
}
