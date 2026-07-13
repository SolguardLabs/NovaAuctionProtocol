// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { NovaTypes } from "../libraries/NovaTypes.sol";

interface INovaAuctionHouse {
    function startAuction(
        address borrower,
        address collateralToken,
        address debtToken,
        uint256 collateralAmount,
        uint256 debtTarget
    ) external returns (uint256 auctionId);
    function bid(
        uint256 auctionId,
        uint256 amount,
        address bidder
    ) external returns (NovaTypes.BidReceipt memory receipt);
    function settle(
        uint256 auctionId
    ) external returns (NovaTypes.CollateralClaim memory claim);
    function cancel(
        uint256 auctionId,
        string calldata reason
    ) external;
    function claimCollateral(
        uint256 auctionId,
        address recipient
    ) external returns (uint256 amount);
    function withdrawBidCredit(
        address debtToken,
        address recipient
    ) external returns (uint256 amount);
    function getAuction(
        uint256 auctionId
    ) external view returns (NovaTypes.Auction memory auction);
    function getClaim(
        uint256 auctionId
    ) external view returns (NovaTypes.CollateralClaim memory claim);
    function requiredBid(
        uint256 auctionId
    ) external view returns (uint256);
    function trueRequiredBid(
        uint256 auctionId
    ) external view returns (uint256);
    function trueFloorDebt(
        uint256 auctionId
    ) external view returns (uint256);
    function auctionCount() external view returns (uint256);
}
