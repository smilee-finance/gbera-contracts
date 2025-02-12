# gBERA

gBERA is a rebasing token based on BERA.

The structure is as follows:
- an ERC20 rebasing GBera (token symbol `gBERA`)contract which keeps the BERA, deals with deposits and withdrawals, and calculates rebased balances.
- an ERC4626 wrapped GBera WGBera (token symbol `wgBERA`) contract to make building on DeFi easier (inspiration from Lido).
- a GBeraAssetManager which keeps the allocated BERA from the main token GBera, and deals with allocation of rewards, deposit to the validator contract, liquidity buffers,
queueing and all other things (to be implemented).

## Upgradeability

### Validation

To validate the upgradeability of a contract, run the following command:

```bash
forge script script/actions/ValidateUpgrade.s.sol -vvv --sig "run(string memory)" <CONTRACT_NAME.sol>
```

> Contract should have following notation:
>
> "V1": `/// @custom:oz-upgrades`
>
> "V2": `/// @custom:oz-upgrades-from src/<CONTRACT_NAME>.sol:<CONTRACT_NAME>`

### Upgrade

To upgrade a contract, run the following command:

```bash
forge script script/actions/UpgradeContracts.s.sol -vvv
```
