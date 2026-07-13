// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

abstract contract Pausable {
    error Paused();
    error NotPaused();

    bool public paused;

    event PausedStateChanged(bool paused);

    modifier whenNotPaused() {
        if (paused) revert Paused();
        _;
    }

    modifier whenPaused() {
        if (!paused) revert NotPaused();
        _;
    }

    function _setPaused(
        bool value
    ) internal {
        paused = value;
        emit PausedStateChanged(value);
    }
}
