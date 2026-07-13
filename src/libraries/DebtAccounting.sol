// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { NovaMath } from "./NovaMath.sol";
import { NovaTypes } from "./NovaTypes.sol";

library DebtAccounting {
    using NovaMath for uint256;

    error InvalidIndex();
    error RepayExceedsDebt();

    function currentDebt(
        NovaTypes.VaultAccount memory account,
        uint256 currentIndex
    ) internal pure returns (uint256) {
        if (account.normalizedDebt == 0) return 0;
        if (account.debtIndex == 0 || currentIndex == 0) revert InvalidIndex();
        return account.normalizedDebt.mulDivUp(currentIndex, account.debtIndex);
    }

    function normalizeDebt(
        uint256 debt,
        uint256 currentIndex
    ) internal pure returns (uint256) {
        if (currentIndex == 0) revert InvalidIndex();
        return debt.mulDivUp(NovaMath.RAY, currentIndex);
    }

    function denormalizeDebt(
        uint256 normalizedDebt,
        uint256 currentIndex
    ) internal pure returns (uint256) {
        if (currentIndex == 0) revert InvalidIndex();
        return normalizedDebt.mulRayUp(currentIndex);
    }

    function applyBorrow(
        NovaTypes.VaultAccount memory account,
        uint256 amount,
        uint256 currentIndex
    ) internal pure returns (NovaTypes.VaultAccount memory next, uint256 previousDebt) {
        previousDebt = currentDebt(account, currentIndex);
        next = account;
        next.normalizedDebt = previousDebt + amount;
        next.debtIndex = currentIndex;
    }

    function applyRepay(
        NovaTypes.VaultAccount memory account,
        uint256 amount,
        uint256 currentIndex
    ) internal pure returns (NovaTypes.VaultAccount memory next, uint256 paid, uint256 remaining) {
        uint256 debt = currentDebt(account, currentIndex);
        paid = NovaMath.min(amount, debt);
        remaining = debt - paid;
        next = account;
        next.normalizedDebt = remaining;
        next.debtIndex = currentIndex;
    }

    function utilization(
        uint256 debt,
        uint256 cash
    ) internal pure returns (uint256) {
        uint256 assets = debt + cash;
        if (assets == 0) return 0;
        return debt.divWadDown(assets);
    }

    function liquidationGap(
        uint256 thresholdValue,
        uint256 debt
    ) internal pure returns (uint256 gap) {
        return debt > thresholdValue ? debt - thresholdValue : 0;
    }

    function remainingCapacity(
        uint256 borrowCapacity,
        uint256 debt
    ) internal pure returns (uint256 capacity) {
        return borrowCapacity > debt ? borrowCapacity - debt : 0;
    }

    function debtShare(
        uint256 accountDebt,
        uint256 totalDebt
    ) internal pure returns (uint256 shareWad) {
        if (totalDebt == 0) return 0;
        return accountDebt.divWadDown(totalDebt);
    }

    function proRata(
        uint256 amount,
        uint256 accountDebt,
        uint256 totalDebt
    ) internal pure returns (uint256) {
        if (totalDebt == 0) return 0;
        return amount.mulDivDown(accountDebt, totalDebt);
    }
}
