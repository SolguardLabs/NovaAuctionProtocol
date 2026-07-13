// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { NovaTypes } from "../libraries/NovaTypes.sol";

interface INovaVault {
    function depositCollateral(
        address collateralToken,
        uint256 amount,
        address account
    ) external;
    function withdrawCollateral(
        address collateralToken,
        uint256 amount,
        address recipient
    ) external;
    function borrow(
        address collateralToken,
        uint256 amount,
        address recipient
    ) external;
    function repay(
        address collateralToken,
        uint256 amount,
        address account
    ) external returns (uint256 paid);
    function seizeCollateral(
        address borrower,
        address collateralToken,
        uint256 amount,
        address recipient
    ) external;
    function debtOf(
        address collateralToken,
        address account
    ) external view returns (uint256);
    function collateralOf(
        address collateralToken,
        address account
    ) external view returns (uint256);
    function healthFactor(
        address collateralToken,
        address account
    ) external view returns (uint256);
    function borrowerView(
        address collateralToken,
        address account
    ) external view returns (NovaTypes.BorrowerView memory viewData);
}
