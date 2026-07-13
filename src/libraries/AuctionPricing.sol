// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { NovaMath } from "./NovaMath.sol";
import { NovaTypes } from "./NovaTypes.sol";

library AuctionPricing {
    using NovaMath for uint256;

    error InvalidAuctionWindow();
    error InvalidFloorRange();

    function startFloor(
        uint256 debtTarget,
        NovaTypes.AuctionConfig memory config
    ) internal pure returns (uint256) {
        return debtTarget.bps(config.startFloorBps);
    }

    function reserveFloor(
        uint256 debtTarget,
        NovaTypes.AuctionConfig memory config
    ) internal pure returns (uint256) {
        return debtTarget.bps(config.reserveFloorBps);
    }

    function floorDebt(
        NovaTypes.Auction memory auction,
        NovaTypes.AuctionConfig memory config,
        uint256 timestamp
    ) internal pure returns (uint256) {
        if (auction.endTime <= auction.startTime) revert InvalidAuctionWindow();
        if (auction.startFloorDebt < auction.reserveFloorDebt) revert InvalidFloorRange();

        uint256 span = uint256(auction.endTime) - uint256(auction.startTime);
        uint256 elapsed = timestamp <= auction.startTime ? 0 : timestamp - auction.startTime;
        if (elapsed > span) elapsed = span;

        uint256 decayRange = auction.startFloorDebt - auction.reserveFloorDebt;
        uint256 decay = decayRange.mulDivDown(elapsed, span);
        uint256 decayedFloor = auction.startFloorDebt - decay;

        uint256 extensionPremium =
            auction.debtTarget.bps(uint256(config.extensionPremiumBps) * auction.extensionCount);
        uint256 floorWithPremium = decayedFloor + extensionPremium;
        uint256 hardCap = auction.debtTarget + extensionPremium;

        if (floorWithPremium > hardCap) return hardCap;
        if (floorWithPremium < auction.reserveFloorDebt) return auction.reserveFloorDebt;
        return floorWithPremium;
    }

    function requiredNextBid(
        NovaTypes.Auction memory auction,
        NovaTypes.AuctionConfig memory config,
        uint256 timestamp
    ) internal pure returns (uint256) {
        uint256 floor = floorDebt(auction, config, timestamp);
        uint256 increment = auction.winningBid.bps(config.minIncrementBps);
        uint256 outbid = auction.winningBid == 0 ? 0 : auction.winningBid + increment;
        return NovaMath.max(floor, outbid);
    }

    function requiredNextBidFromCachedFloor(
        NovaTypes.Auction memory auction,
        NovaTypes.AuctionConfig memory config
    ) internal pure returns (uint256) {
        uint256 increment = auction.winningBid.bps(config.minIncrementBps);
        uint256 outbid = auction.winningBid == 0 ? 0 : auction.winningBid + increment;
        return NovaMath.max(auction.cachedFloorDebt, outbid);
    }

    function wouldExtend(
        NovaTypes.Auction memory auction,
        NovaTypes.AuctionConfig memory config,
        uint256 timestamp
    ) internal pure returns (bool) {
        if (auction.extensionCount >= config.maxExtensions) return false;
        if (timestamp >= auction.endTime) return false;
        return uint256(auction.endTime) - timestamp <= config.extensionWindow;
    }

    function surplus(
        uint256 winningBid,
        uint256 debtTarget
    ) internal pure returns (uint256) {
        return winningBid > debtTarget ? winningBid - debtTarget : 0;
    }

    function shortfall(
        uint256 winningBid,
        uint256 debtTarget
    ) internal pure returns (uint256) {
        return winningBid < debtTarget ? debtTarget - winningBid : 0;
    }
}
