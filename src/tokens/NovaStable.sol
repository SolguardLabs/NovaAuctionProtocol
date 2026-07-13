// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Ownable2Step } from "../security/Ownable2Step.sol";
import { NovaERC20 } from "./NovaERC20.sol";

contract NovaStable is NovaERC20, Ownable2Step {
    error NotMinter();

    mapping(address => bool) public isMinter;

    event MinterUpdated(address indexed account, bool enabled);

    constructor(
        address owner_
    ) NovaERC20("Nova Stable Debt", "nUSD", 18) Ownable2Step(owner_) { }

    modifier onlyMinter() {
        if (!isMinter[msg.sender]) revert NotMinter();
        _;
    }

    function setMinter(
        address account,
        bool enabled
    ) external onlyOwner {
        isMinter[account] = enabled;
        emit MinterUpdated(account, enabled);
    }

    function mint(
        address to,
        uint256 amount
    ) external onlyMinter {
        _mint(to, amount);
    }

    function burn(
        address from,
        uint256 amount
    ) external onlyMinter {
        _burn(from, amount);
    }
}
