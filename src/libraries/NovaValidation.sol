// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { NovaMath } from "./NovaMath.sol";
import { NovaTypes } from "./NovaTypes.sol";

library NovaValidation {
    error InvalidAddress();
    error InvalidAmount();
    error InvalidRiskParameters();
    error InvalidAuctionParameters();
    error PausedAction(bytes32 action);
    error HealthFactorTooLow(uint256 healthFactor);
    error DebtOutsideBounds(uint256 debt);

    bytes32 internal constant ACTION_DEPOSIT = keccak256("DEPOSIT");
    bytes32 internal constant ACTION_BORROW = keccak256("BORROW");
    bytes32 internal constant ACTION_LIQUIDATE = keccak256("LIQUIDATE");
    bytes32 internal constant ACTION_AUCTION = keccak256("AUCTION");
    bytes32 internal constant ACTION_CLAIM = keccak256("CLAIM");

    function requireAddress(
        address account
    ) internal pure {
        if (account == address(0)) revert InvalidAddress();
    }

    function requireAmount(
        uint256 amount
    ) internal pure {
        if (amount == 0) revert InvalidAmount();
    }

    function requireHealthy(
        uint256 healthFactor
    ) internal pure {
        if (healthFactor < NovaMath.WAD) revert HealthFactorTooLow(healthFactor);
    }

    function requireDebtBounds(
        NovaTypes.RiskConfig memory risk,
        uint256 debt
    ) internal pure {
        if (debt == 0) return;
        if (debt < risk.minDebt) revert DebtOutsideBounds(debt);
        if (risk.maxDebt != 0 && debt > risk.maxDebt) revert DebtOutsideBounds(debt);
    }

    function requireNotPaused(
        NovaTypes.PauseState memory state,
        bytes32 action
    ) internal pure {
        if (action == ACTION_DEPOSIT && state.depositsPaused) revert PausedAction(action);
        if (action == ACTION_BORROW && state.borrowsPaused) revert PausedAction(action);
        if (action == ACTION_LIQUIDATE && state.liquidationsPaused) revert PausedAction(action);
        if (action == ACTION_AUCTION && state.auctionsPaused) revert PausedAction(action);
        if (action == ACTION_CLAIM && state.claimsPaused) revert PausedAction(action);
    }

    function validateRiskConfig(
        NovaTypes.RiskConfig memory risk
    ) internal pure returns (bool valid) {
        if (!risk.enabled) return true;
        if (risk.loanToValueBps == 0 || risk.loanToValueBps > 10_000) return false;
        if (risk.liquidationThresholdBps < risk.loanToValueBps) return false;
        if (risk.liquidationThresholdBps > 10_000) return false;
        if (risk.liquidationPenaltyBps > 5000) return false;
        if (risk.protocolPenaltyShareBps > 10_000) return false;
        if (risk.maxDebt != 0 && risk.maxDebt < risk.minDebt) return false;
        return true;
    }

    function validateAuctionConfig(
        NovaTypes.AuctionConfig memory config
    ) internal pure returns (bool valid) {
        if (config.defaultDuration == 0) return false;
        if (config.extensionWindow > config.defaultDuration) return false;
        if (config.extensionDuration == 0) return false;
        if (config.reserveFloorBps > config.startFloorBps) return false;
        if (config.startFloorBps > 20_000) return false;
        if (config.minIncrementBps == 0 || config.minIncrementBps > 5000) return false;
        if (config.extensionPremiumBps > 10_000) return false;
        return true;
    }

    function liquidationAllowed(
        uint256 healthFactor
    ) internal pure returns (bool) {
        return healthFactor < NovaMath.WAD;
    }

    function safeDebtTarget(
        uint256 requested,
        uint256 debt
    ) internal pure returns (uint256) {
        if (requested == 0) return debt;
        return NovaMath.min(requested, debt);
    }
}
