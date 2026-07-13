// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { NovaTypes } from "../libraries/NovaTypes.sol";

interface INovaRiskEngine {
    function canBorrow(
        address collateralToken,
        address account,
        uint256 additionalDebt
    ) external view returns (bool allowed, uint256 capacity, uint256 nextDebt);
    function canWithdraw(
        address collateralToken,
        address account,
        uint256 collateralAmount
    ) external view returns (bool allowed, uint256 healthAfter);
    function liquidationQuote(
        address borrower,
        address collateralToken,
        uint256 requestedDebtToCover
    ) external view returns (NovaTypes.LiquidationQuote memory quote);
    function borrowerView(
        address collateralToken,
        address borrower
    ) external view returns (NovaTypes.BorrowerView memory viewData);
}
