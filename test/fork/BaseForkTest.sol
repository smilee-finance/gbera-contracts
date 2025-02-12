// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseTest } from "./../Base.t.sol";

import { IBGT } from "../../src/interfaces/external/IBGT.sol";
import { IBeraChef } from "../../src/interfaces/external/IBeraChef.sol";

interface IDistributor {
    function beraChef() external view returns (address);
}

contract BaseForkTest is BaseTest {
    // bartio
    address public constant DEPOSIT_CONTRACT = 0x4242424242424242424242424242424242424242;
    address public constant BGT_ADDRESS = 0xbDa130737BDd9618301681329bF2e46A016ff9Ad;
    address public constant BGT_STAKER_ADDRESS = 0x791fb53432eED7e2fbE4cf8526ab6feeA604Eb6d;
    address public constant BERA_CHEF_ADDRESS = 0xfb81E39E3970076ab2693fA5C45A07Cc724C93c2;
    address public constant WBERA_ADDRESS = 0x7507c1dc16935B82698e4C63f2746A2fCf994dF8;
    address public constant DISTRIBUTOR_ADDRESS = 0x2C1F148Ee973a4cdA4aBEce2241DF3D3337b7319;

    // // cartio
    // address public constant DEPOSIT_CONTRACT = 0x4242424242424242424242424242424242424242;
    // address public constant BGT_ADDRESS = 0x289274787bAF083C15A45a174b7a8e44F0720660;
    // address public constant BGT_STAKER_ADDRESS = 0x7B4fba14B2eae33Dd9E780E4bD406fC0429c96af;
    // address public constant BERA_CHEF_ADDRESS = 0x2C2F301f380dDc9c36c206DC3df8EA8688419cC1;
    // address public constant WBERA_ADDRESS = 0x6969696969696969696969696969696969696969;
    // address public constant DISTRIBUTOR_ADDRESS = 0x211bE45338B7C6d5721B5543Eb868547088Aca39;

    IBGT public bgt;
    IBeraChef public berachef;
    IDistributor public distributor;

    error ForkingSetupFailed();

    constructor() {
        super._setAddresses(DEPOSIT_CONTRACT, BGT_ADDRESS, BGT_STAKER_ADDRESS, BERA_CHEF_ADDRESS, WBERA_ADDRESS);

        vm.createSelectFork(vm.envString("RPC_URL"));

        if (block.number == 0) revert ForkingSetupFailed();

        bgt = IBGT(bgtAddress);
        berachef = IBeraChef(beraChefAddress);
        distributor = IDistributor(DISTRIBUTOR_ADDRESS);

        address returnedDistributor = berachef.distributor();
        if (returnedDistributor != DISTRIBUTOR_ADDRESS) revert ForkingSetupFailed();

        address returnedBeraChef = distributor.beraChef();
        if (returnedBeraChef != beraChefAddress) revert ForkingSetupFailed();

        vm.label(wberaAddress, "WBERA");
        vm.label(bgtAddress, "BGT");
        vm.label(beraChefAddress, "BERACHEF");
        vm.label(DISTRIBUTOR_ADDRESS, "DISTRIBUTOR");
    }
}
