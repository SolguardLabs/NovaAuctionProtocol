// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IERC20 } from "../interfaces/IERC20.sol";
import { INovaPriceOracle } from "../interfaces/INovaPriceOracle.sol";
import { NovaMath } from "../libraries/NovaMath.sol";
import { NovaTypes } from "../libraries/NovaTypes.sol";
import { Ownable2Step } from "../security/Ownable2Step.sol";

contract NovaPriceOracle is INovaPriceOracle, Ownable2Step {
    using NovaMath for uint256;

    error InvalidPrice();
    error InvalidToken();
    error StalePrice(address token);
    error InactivePrice(address token);

    mapping(address => NovaTypes.PriceObservation) private _observations;
    address[] private _tokens;
    mapping(address => bool) private _listed;

    event PriceUpdated(
        address indexed token, uint256 priceWad, uint64 updatedAt, uint64 heartbeat, string source
    );
    event PriceStatusUpdated(address indexed token, bool active);

    constructor(
        address owner_
    ) Ownable2Step(owner_) { }

    function setPrice(
        address token,
        uint256 price,
        uint8 priceDecimals,
        uint64 heartbeat,
        string calldata source
    ) external onlyOwner {
        if (token == address(0)) revert InvalidToken();
        if (price == 0) revert InvalidPrice();
        uint256 priceWad = NovaMath.scalePrice(price, priceDecimals);
        if (!_listed[token]) {
            _listed[token] = true;
            _tokens.push(token);
        }
        _observations[token] = NovaTypes.PriceObservation({
            priceWad: priceWad,
            updatedAt: uint64(block.timestamp),
            heartbeat: heartbeat,
            decimals: priceDecimals,
            active: true,
            source: source
        });
        emit PriceUpdated(token, priceWad, uint64(block.timestamp), heartbeat, source);
    }

    function setActive(
        address token,
        bool active
    ) external onlyOwner {
        _observations[token].active = active;
        emit PriceStatusUpdated(token, active);
    }

    function getPrice(
        address token
    ) public view returns (uint256 priceWad) {
        NovaTypes.PriceObservation memory observation = _observations[token];
        if (!observation.active) revert InactivePrice(token);
        if (observation.priceWad == 0) revert InvalidPrice();
        if (
            observation.heartbeat != 0
                && block.timestamp > observation.updatedAt + observation.heartbeat
        ) {
            revert StalePrice(token);
        }
        return observation.priceWad;
    }

    function getObservation(
        address token
    ) external view returns (NovaTypes.PriceObservation memory observation) {
        observation = _observations[token];
    }

    function valueOf(
        address token,
        uint256 amount
    ) external view returns (uint256 valueWad) {
        uint256 priceWad = getPrice(token);
        uint8 tokenDecimals = IERC20(token).decimals();
        return NovaMath.collateralValue(amount, priceWad, tokenDecimals);
    }

    function tokenAmountForValue(
        address token,
        uint256 valueWad
    ) external view returns (uint256 amount) {
        uint256 priceWad = getPrice(token);
        uint8 tokenDecimals = IERC20(token).decimals();
        return NovaMath.collateralForDebt(valueWad, priceWad, tokenDecimals);
    }

    function tokenCount() external view returns (uint256) {
        return _tokens.length;
    }

    function tokenAt(
        uint256 index
    ) external view returns (address) {
        return _tokens[index];
    }
}
