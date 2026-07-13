// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Ownable2Step } from "../security/Ownable2Step.sol";
import { NovaERC20 } from "./NovaERC20.sol";

contract NovaCollateralToken is NovaERC20, Ownable2Step {
    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address owner_
    ) NovaERC20(name_, symbol_, decimals_) Ownable2Step(owner_) { }

    function mint(
        address to,
        uint256 amount
    ) external onlyOwner {
        _mint(to, amount);
    }

    function burn(
        address from,
        uint256 amount
    ) external onlyOwner {
        _burn(from, amount);
    }
}
