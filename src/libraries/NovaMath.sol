// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

library NovaMath {
    uint256 internal constant WAD = 1e18;
    uint256 internal constant RAY = 1e27;
    uint256 internal constant BPS = 10_000;

    error DivisionByZero();
    error ValueTooLarge();

    function min(
        uint256 a,
        uint256 b
    ) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function max(
        uint256 a,
        uint256 b
    ) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    function clamp(
        uint256 value,
        uint256 low,
        uint256 high
    ) internal pure returns (uint256) {
        if (value < low) return low;
        if (value > high) return high;
        return value;
    }

    function absDiff(
        uint256 a,
        uint256 b
    ) internal pure returns (uint256) {
        return a > b ? a - b : b - a;
    }

    function ceilDiv(
        uint256 a,
        uint256 b
    ) internal pure returns (uint256) {
        if (b == 0) revert DivisionByZero();
        return a == 0 ? 0 : ((a - 1) / b) + 1;
    }

    function mulDivDown(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256) {
        if (denominator == 0) revert DivisionByZero();
        return (x * y) / denominator;
    }

    function mulDivUp(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256) {
        if (denominator == 0) revert DivisionByZero();
        if (x == 0 || y == 0) return 0;
        return ((x * y) - 1) / denominator + 1;
    }

    function mulWadDown(
        uint256 x,
        uint256 y
    ) internal pure returns (uint256) {
        return mulDivDown(x, y, WAD);
    }

    function mulWadUp(
        uint256 x,
        uint256 y
    ) internal pure returns (uint256) {
        return mulDivUp(x, y, WAD);
    }

    function divWadDown(
        uint256 x,
        uint256 y
    ) internal pure returns (uint256) {
        return mulDivDown(x, WAD, y);
    }

    function divWadUp(
        uint256 x,
        uint256 y
    ) internal pure returns (uint256) {
        return mulDivUp(x, WAD, y);
    }

    function mulRayDown(
        uint256 x,
        uint256 y
    ) internal pure returns (uint256) {
        return mulDivDown(x, y, RAY);
    }

    function mulRayUp(
        uint256 x,
        uint256 y
    ) internal pure returns (uint256) {
        return mulDivUp(x, y, RAY);
    }

    function divRayDown(
        uint256 x,
        uint256 y
    ) internal pure returns (uint256) {
        return mulDivDown(x, RAY, y);
    }

    function divRayUp(
        uint256 x,
        uint256 y
    ) internal pure returns (uint256) {
        return mulDivUp(x, RAY, y);
    }

    function bps(
        uint256 amount,
        uint256 bpsValue
    ) internal pure returns (uint256) {
        return mulDivDown(amount, bpsValue, BPS);
    }

    function bpsUp(
        uint256 amount,
        uint256 bpsValue
    ) internal pure returns (uint256) {
        return mulDivUp(amount, bpsValue, BPS);
    }

    function addBps(
        uint256 amount,
        uint256 bpsValue
    ) internal pure returns (uint256) {
        return amount + bps(amount, bpsValue);
    }

    function subBps(
        uint256 amount,
        uint256 bpsValue
    ) internal pure returns (uint256) {
        uint256 discount = bps(amount, bpsValue);
        return discount >= amount ? 0 : amount - discount;
    }

    function percentOf(
        uint256 amount,
        uint256 numerator,
        uint256 denominator
    ) internal pure returns (uint256) {
        return mulDivDown(amount, numerator, denominator);
    }

    function wadToRay(
        uint256 wad
    ) internal pure returns (uint256) {
        return wad * 1e9;
    }

    function rayToWadDown(
        uint256 ray
    ) internal pure returns (uint256) {
        return ray / 1e9;
    }

    function rayToWadUp(
        uint256 ray
    ) internal pure returns (uint256) {
        return ceilDiv(ray, 1e9);
    }

    function normalize(
        uint256 amount,
        uint8 decimals
    ) internal pure returns (uint256) {
        if (decimals == 18) return amount;
        if (decimals < 18) return amount * (10 ** (18 - decimals));
        return amount / (10 ** (decimals - 18));
    }

    function denormalize(
        uint256 amount,
        uint8 decimals
    ) internal pure returns (uint256) {
        if (decimals == 18) return amount;
        if (decimals < 18) return amount / (10 ** (18 - decimals));
        return amount * (10 ** (decimals - 18));
    }

    function boundedSub(
        uint256 a,
        uint256 b
    ) internal pure returns (uint256) {
        return b >= a ? 0 : a - b;
    }

    function toUint64(
        uint256 value
    ) internal pure returns (uint64) {
        if (value > type(uint64).max) revert ValueTooLarge();
        return uint64(value);
    }

    function toUint96(
        uint256 value
    ) internal pure returns (uint96) {
        if (value > type(uint96).max) revert ValueTooLarge();
        return uint96(value);
    }

    function toUint128(
        uint256 value
    ) internal pure returns (uint128) {
        if (value > type(uint128).max) revert ValueTooLarge();
        return uint128(value);
    }

    function scalePrice(
        uint256 price,
        uint8 priceDecimals
    ) internal pure returns (uint256) {
        if (priceDecimals == 18) return price;
        if (priceDecimals < 18) return price * (10 ** (18 - priceDecimals));
        return price / (10 ** (priceDecimals - 18));
    }

    function collateralValue(
        uint256 amount,
        uint256 priceWad,
        uint8 tokenDecimals
    ) internal pure returns (uint256) {
        uint256 normalizedAmount = normalize(amount, tokenDecimals);
        return mulWadDown(normalizedAmount, priceWad);
    }

    function collateralForDebt(
        uint256 debtAmount,
        uint256 priceWad,
        uint8 tokenDecimals
    ) internal pure returns (uint256) {
        uint256 normalized = divWadUp(debtAmount, priceWad);
        return denormalize(normalized, tokenDecimals);
    }

    function healthFactor(
        uint256 collateralValueAdjusted,
        uint256 debtValue
    ) internal pure returns (uint256) {
        if (debtValue == 0) return type(uint256).max;
        return divWadDown(collateralValueAdjusted, debtValue);
    }
}
