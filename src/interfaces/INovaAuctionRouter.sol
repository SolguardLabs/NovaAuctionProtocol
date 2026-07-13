// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { NovaTypes } from "../libraries/NovaTypes.sol";

interface INovaAuctionRouter {
    function bidWithMaxFloor(
        uint256 auctionId,
        uint256 amount,
        uint256 maxRequiredBid
    ) external returns (NovaTypes.BidReceipt memory receipt);
    function settleAndClaim(
        uint256 auctionId,
        address recipient
    ) external returns (uint256 amount);
    function withdrawBidCredit(
        address debtToken,
        address recipient
    ) external returns (uint256 amount);
}
