// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { NovaTypes } from "../libraries/NovaTypes.sol";

interface INovaConfigurator {
    function AUCTIONEER_ROLE() external view returns (bytes32);
    function KEEPER_ROLE() external view returns (bytes32);
    function LIQUIDATION_ROLE() external view returns (bytes32);
    function PAUSER_ROLE() external view returns (bytes32);
    function RISK_ROLE() external view returns (bytes32);
    function hasRole(
        bytes32 role,
        address account
    ) external view returns (bool);
    function requireRole(
        bytes32 role,
        address account
    ) external view;
    function debtToken() external view returns (address);
    function treasury() external view returns (address);
    function oracle() external view returns (address);
    function auctionHouse() external view returns (address);
    function vault() external view returns (address);
    function liquidationEngine() external view returns (address);
    function getAuctionConfig() external view returns (NovaTypes.AuctionConfig memory);
    function getRiskConfig(
        address collateralToken
    ) external view returns (NovaTypes.RiskConfig memory);
    function pauseState() external view returns (NovaTypes.PauseState memory);
}
