// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockWBERA is ERC20 {
    constructor() ERC20("MockedWBERA", "MWBERA") { }

    /// @dev The ETH (BERA) transfer has failed.
    error ETHTransferFailed();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                            WBERA                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Deposits `amount` BERA of the caller and mints `amount` WBERA to the caller.
    function deposit() public payable virtual {
        _mint(msg.sender, msg.value);
    }

    /// @dev Burns `amount` WBERA of the caller and sends `amount` BERA to the caller.
    function withdraw(uint256 amount) public virtual {
        _burn(msg.sender, amount);
        /// @solidity memory-safe-assembly
        assembly {
            // Transfer the BERA and check if it succeeded or not.
            if iszero(call(gas(), caller(), amount, codesize(), 0x00, codesize(), 0x00)) {
                mstore(0x00, 0xb12d13eb) // `ETHTransferFailed()`.
                revert(0x1c, 0x04)
            }
        }
    }

    /// @dev Equivalent to `deposit()`.
    receive() external payable virtual {
        deposit();
    }
}
