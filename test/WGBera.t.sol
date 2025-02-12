// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseTest } from "./Base.t.sol";

contract WGBeraTest is BaseTest {
    address gBeraAssetManagerOperator = makeAddr("gBeraAssetManagerOperator");

    function setUp() public override {
        super.setUp();
        _deployMockedContracts();

        bytes32 managerOperatorRole = manager.OPERATOR_ROLE();
        vm.prank(OWNER);
        manager.grantRole(managerOperatorRole, gBeraAssetManagerOperator);
    }

    function testDirectTransfer(uint256 amount) public {
        if (amount < 1 ether) amount = 1 ether;
        vm.deal(USER, amount);

        vm.prank(USER);
        (bool success,) = address(wgbera).call{ value: amount }("");

        assertTrue(success, "BERA direct transfer failed");
        assertEq(wgbera.balanceOf(USER), amount, "WGBera USER balance mismatch");
        assertEq(gbera.balanceOf(address(wgbera)), amount, "GBera balance mismatch");
    }

    function testConvertToShares(uint256 assets) public view {
        uint256 shares = wgbera.convertToShares(assets);
        uint256 expectedShares = gbera.getUnrebasedAmount(assets, false);
        assertEq(shares, expectedShares, "Shares conversion mismatch");
    }

    function testConvertToAssets(uint256 shares) public view {
        uint256 assets = wgbera.convertToAssets(shares);
        uint256 expectedAssets = gbera.getRebasedAmount(shares, false);
        assertEq(assets, expectedAssets, "Assets conversion mismatch");
    }

    function testgBeraAccrual(uint256 amount, uint256 accrual) public {
        // avoid overflow in ERC4626 and invalid amount
        amount = amount % (type(uint256).max / 2) + 1 ether;
        // amount + accrual < 2^256 to avoid EvmError: OverflowPayment and overflow at ERC4626
        accrual = accrual % (type(uint256).max - amount);
        vm.deal(USER, amount);
        vm.prank(USER);
        (bool success,) = address(wgbera).call{ value: amount }("");
        assertTrue(success, "BERA direct transfer failed");

        uint256 gberaInitialBalance = gbera.balanceOf(address(wgbera));
        uint256 wgberaInitialBalance = wgbera.balanceOf(USER);
        uint256 wgberaInitialRedemptionValue = wgbera.previewRedeem(wgberaInitialBalance);

        vm.deal(address(this), accrual);
        (success,) = address(manager).call{ value: accrual }("");

        assertTrue(success, "manager direct transfer failed");

        uint256 gberaFinalBalance = gbera.balanceOf(address(wgbera));
        uint256 wgberaFinalBalance = wgbera.balanceOf(USER);
        uint256 wgberaFinalRedemptionValue = wgbera.previewRedeem(wgberaInitialBalance);

        assertTrue(gberaFinalBalance >= gberaInitialBalance, "GBera balance should increase due to accrual");
        assertEq(wgberaFinalBalance, wgberaInitialBalance, "WGBera balance should not change due to GBera accrual");
        assertTrue(
            wgberaFinalRedemptionValue >= wgberaInitialRedemptionValue,
            "WGBera redemption value should increase due to GBera accrual"
        );
    }

    function testgBeraDonation(uint256 amount, uint256 donation) public {
        // avoid overflow in ERC4626 and invalid amount
        amount = amount % (type(uint256).max / 2) + 1 ether;
        // amount + accrual < 2^256 to avoid EvmError: OverflowPayment and overflow at ERC4626
        donation = donation % (type(uint256).max - amount);
        if (donation < 1 ether) donation += 1 ether;
        vm.deal(USER, amount);
        vm.prank(USER);
        (bool success,) = address(wgbera).call{ value: amount }("");
        assertTrue(success, "BERA direct transfer failed");

        uint256 gberaInitialBalance = gbera.balanceOf(address(wgbera));
        uint256 wgberaInitialBalance = wgbera.balanceOf(USER);
        uint256 wgberaInitialRedemptionValue = wgbera.previewRedeem(wgberaInitialBalance);

        vm.deal(address(this), donation);
        // mint gBERA and transfer directly to WGBera contract
        gbera.deposit{ value: donation }(address(wgbera));

        uint256 gberaFinalBalance = gbera.balanceOf(address(wgbera));
        uint256 wgberaFinalBalance = wgbera.balanceOf(USER);
        uint256 wgberaFinalRedemptionValue = wgbera.previewRedeem(wgberaInitialBalance);

        assertEq(gberaFinalBalance, gberaInitialBalance + donation, "GBera balance should increase due to accrual");
        assertEq(wgberaFinalBalance, wgberaInitialBalance, "WGBera balance should not change due to GBera accrual");
        assertTrue(
            wgberaFinalRedemptionValue >= wgberaInitialRedemptionValue,
            "WGBera redemption value should increase due to GBera accrual"
        );
    }
}
