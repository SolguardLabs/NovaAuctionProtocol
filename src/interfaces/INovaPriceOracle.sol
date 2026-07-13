// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { NovaTypes } from "../libraries/NovaTypes.sol";

interface INovaPriceOracle {
    function getPrice(
        address token
    ) external view returns (uint256 priceWad);
    function getObservation(
        address token
    ) external view returns (NovaTypes.PriceObservation memory observation);
    function valueOf(
        address token,
        uint256 amount
    ) external view returns (uint256 valueWad);
    function tokenAmountForValue(
        address token,
        uint256 valueWad
    ) external view returns (uint256 amount);
}
