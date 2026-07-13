// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { NovaTypes } from "../libraries/NovaTypes.sol";

interface INovaTreasury {
    function recordAuctionSettlement(
        uint256 auctionId,
        address borrower,
        address debtToken,
        uint256 winningBid,
        uint256 debtTarget
    ) external;
    function recordAuctionCancellation(
        uint256 auctionId,
        address borrower,
        address debtToken
    ) external;
    function withdrawSurplus(
        address debtToken,
        address account,
        address recipient
    ) external returns (uint256 amount);
    function surplusCredit(
        address debtToken,
        address account
    ) external view returns (uint256);
    function getSnapshot(
        address debtToken
    ) external view returns (NovaTypes.TreasurySnapshot memory snapshot);
}
