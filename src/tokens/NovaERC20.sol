// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IERC20 } from "../interfaces/IERC20.sol";

contract NovaERC20 is IERC20 {
    error InsufficientBalance();
    error InsufficientAllowance();
    error InvalidReceiver();
    error InvalidSender();

    string public name;
    string public symbol;
    uint8 public immutable decimals;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) {
        name = name_;
        symbol = symbol_;
        decimals = decimals_;
    }

    function approve(
        address spender,
        uint256 amount
    ) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(
        address to,
        uint256 amount
    ) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            if (allowed < amount) revert InsufficientAllowance();
            allowance[from][msg.sender] = allowed - amount;
            emit Approval(from, msg.sender, allowed - amount);
        }
        _transfer(from, to, amount);
        return true;
    }

    function increaseAllowance(
        address spender,
        uint256 amount
    ) external returns (bool) {
        uint256 next = allowance[msg.sender][spender] + amount;
        allowance[msg.sender][spender] = next;
        emit Approval(msg.sender, spender, next);
        return true;
    }

    function decreaseAllowance(
        address spender,
        uint256 amount
    ) external returns (bool) {
        uint256 current = allowance[msg.sender][spender];
        if (current < amount) revert InsufficientAllowance();
        uint256 next = current - amount;
        allowance[msg.sender][spender] = next;
        emit Approval(msg.sender, spender, next);
        return true;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal {
        if (from == address(0)) revert InvalidSender();
        if (to == address(0)) revert InvalidReceiver();
        uint256 balance = balanceOf[from];
        if (balance < amount) revert InsufficientBalance();
        unchecked {
            balanceOf[from] = balance - amount;
            balanceOf[to] += amount;
        }
        emit Transfer(from, to, amount);
    }

    function _mint(
        address to,
        uint256 amount
    ) internal {
        if (to == address(0)) revert InvalidReceiver();
        totalSupply += amount;
        unchecked {
            balanceOf[to] += amount;
        }
        emit Transfer(address(0), to, amount);
    }

    function _burn(
        address from,
        uint256 amount
    ) internal {
        if (from == address(0)) revert InvalidSender();
        uint256 balance = balanceOf[from];
        if (balance < amount) revert InsufficientBalance();
        unchecked {
            balanceOf[from] = balance - amount;
            totalSupply -= amount;
        }
        emit Transfer(from, address(0), amount);
    }
}
