// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

abstract contract Ownable2Step {
    error NotOwner();
    error NotPendingOwner();
    error ZeroOwner();

    address public owner;
    address public pendingOwner;

    event OwnershipTransferStarted(address indexed previousOwner, address indexed nextOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed nextOwner);

    constructor(
        address initialOwner
    ) {
        if (initialOwner == address(0)) revert ZeroOwner();
        owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    function transferOwnership(
        address nextOwner
    ) external onlyOwner {
        if (nextOwner == address(0)) revert ZeroOwner();
        pendingOwner = nextOwner;
        emit OwnershipTransferStarted(owner, nextOwner);
    }

    function acceptOwnership() external {
        if (msg.sender != pendingOwner) revert NotPendingOwner();
        address previousOwner = owner;
        owner = msg.sender;
        pendingOwner = address(0);
        emit OwnershipTransferred(previousOwner, msg.sender);
    }
}
