// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Ownable2Step } from "../security/Ownable2Step.sol";

contract NovaTimelock is Ownable2Step {
    error DelayTooShort();
    error DelayTooLong();
    error OperationAlreadyQueued(bytes32 id);
    error OperationMissing(bytes32 id);
    error OperationNotReady(bytes32 id, uint256 readyAt);
    error OperationExpired(bytes32 id);
    error ExecutionFailed(bytes32 id, bytes data);
    error InvalidTarget();

    struct Operation {
        address target;
        uint256 value;
        bytes data;
        bytes32 predecessor;
        bytes32 salt;
        uint64 readyAt;
        uint64 expiresAt;
        bool executed;
        bool cancelled;
    }

    uint64 public minDelay;
    uint64 public maxDelay;
    uint64 public gracePeriod;

    mapping(bytes32 => Operation) private _operations;

    event DelayConfigUpdated(uint64 minDelay, uint64 maxDelay, uint64 gracePeriod);
    event OperationQueued(
        bytes32 indexed id,
        address indexed target,
        uint256 value,
        bytes32 predecessor,
        bytes32 salt,
        uint64 readyAt,
        uint64 expiresAt
    );
    event OperationCancelled(bytes32 indexed id);
    event OperationExecuted(bytes32 indexed id, address indexed target, uint256 value);

    constructor(
        address owner_,
        uint64 minDelay_,
        uint64 maxDelay_,
        uint64 gracePeriod_
    ) Ownable2Step(owner_) {
        _setDelays(minDelay_, maxDelay_, gracePeriod_);
    }

    receive() external payable { }

    function setDelays(
        uint64 minDelay_,
        uint64 maxDelay_,
        uint64 gracePeriod_
    ) external onlyOwner {
        _setDelays(minDelay_, maxDelay_, gracePeriod_);
    }

    function queue(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt,
        uint64 delay
    ) external onlyOwner returns (bytes32 id) {
        if (target == address(0)) revert InvalidTarget();
        if (delay < minDelay) revert DelayTooShort();
        if (delay > maxDelay) revert DelayTooLong();

        id = hashOperation(target, value, data, predecessor, salt);
        Operation storage operation = _operations[id];
        if (operation.readyAt != 0 && !operation.cancelled) revert OperationAlreadyQueued(id);

        uint64 readyAt = uint64(block.timestamp) + delay;
        uint64 expiresAt = readyAt + gracePeriod;
        _operations[id] = Operation({
            target: target,
            value: value,
            data: data,
            predecessor: predecessor,
            salt: salt,
            readyAt: readyAt,
            expiresAt: expiresAt,
            executed: false,
            cancelled: false
        });

        emit OperationQueued(id, target, value, predecessor, salt, readyAt, expiresAt);
    }

    function cancel(
        bytes32 id
    ) external onlyOwner {
        Operation storage operation = _operations[id];
        if (operation.readyAt == 0 || operation.cancelled || operation.executed) {
            revert OperationMissing(id);
        }
        operation.cancelled = true;
        emit OperationCancelled(id);
    }

    function execute(
        bytes32 id
    ) external payable onlyOwner returns (bytes memory result) {
        Operation storage operation = _operations[id];
        if (operation.readyAt == 0 || operation.cancelled || operation.executed) {
            revert OperationMissing(id);
        }
        if (block.timestamp < operation.readyAt) revert OperationNotReady(id, operation.readyAt);
        if (block.timestamp > operation.expiresAt) revert OperationExpired(id);
        if (operation.predecessor != bytes32(0)) {
            Operation storage predecessor = _operations[operation.predecessor];
            if (!predecessor.executed) {
                revert OperationNotReady(operation.predecessor, predecessor.readyAt);
            }
        }

        operation.executed = true;
        (bool success, bytes memory data) =
            operation.target.call{ value: operation.value }(operation.data);
        if (!success) revert ExecutionFailed(id, data);
        emit OperationExecuted(id, operation.target, operation.value);
        return data;
    }

    function getOperation(
        bytes32 id
    ) external view returns (Operation memory operation) {
        return _operations[id];
    }

    function isOperationReady(
        bytes32 id
    ) external view returns (bool) {
        Operation memory operation = _operations[id];
        return operation.readyAt != 0 && !operation.cancelled && !operation.executed
            && block.timestamp >= operation.readyAt && block.timestamp <= operation.expiresAt;
    }

    function hashOperation(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt
    ) public pure returns (bytes32) {
        return keccak256(abi.encode(target, value, keccak256(data), predecessor, salt));
    }

    function _setDelays(
        uint64 minDelay_,
        uint64 maxDelay_,
        uint64 gracePeriod_
    ) private {
        if (minDelay_ == 0) revert DelayTooShort();
        if (maxDelay_ < minDelay_) revert DelayTooLong();
        if (gracePeriod_ == 0) revert DelayTooShort();
        minDelay = minDelay_;
        maxDelay = maxDelay_;
        gracePeriod = gracePeriod_;
        emit DelayConfigUpdated(minDelay_, maxDelay_, gracePeriod_);
    }
}
