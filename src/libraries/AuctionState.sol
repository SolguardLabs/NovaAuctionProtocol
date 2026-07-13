// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { NovaTypes } from "./NovaTypes.sol";

library AuctionState {
    error AuctionIsNotActive();
    error AuctionIsNotFinished();
    error AuctionHasNoWinner();
    error AuctionAlreadyFinalized();

    function isActive(
        NovaTypes.Auction memory auction
    ) internal pure returns (bool) {
        return auction.status == NovaTypes.AuctionStatus.Active;
    }

    function isSettled(
        NovaTypes.Auction memory auction
    ) internal pure returns (bool) {
        return auction.status == NovaTypes.AuctionStatus.Settled;
    }

    function isCancelled(
        NovaTypes.Auction memory auction
    ) internal pure returns (bool) {
        return auction.status == NovaTypes.AuctionStatus.Cancelled;
    }

    function isFinalized(
        NovaTypes.Auction memory auction
    ) internal pure returns (bool) {
        return isSettled(auction) || isCancelled(auction);
    }

    function hasWinner(
        NovaTypes.Auction memory auction
    ) internal pure returns (bool) {
        return auction.winner != address(0) && auction.winningBid != 0;
    }

    function hasStarted(
        NovaTypes.Auction memory auction,
        uint256 timestamp
    ) internal pure returns (bool) {
        return timestamp >= auction.startTime;
    }

    function hasEnded(
        NovaTypes.Auction memory auction,
        uint256 timestamp
    ) internal pure returns (bool) {
        return timestamp >= auction.endTime;
    }

    function isOpenForBids(
        NovaTypes.Auction memory auction,
        uint256 timestamp
    ) internal pure returns (bool) {
        return isActive(auction) && timestamp >= auction.startTime && timestamp < auction.endTime;
    }

    function canBeSettled(
        NovaTypes.Auction memory auction,
        uint256 timestamp
    ) internal pure returns (bool) {
        return isActive(auction) && hasWinner(auction) && timestamp >= auction.endTime;
    }

    function secondsRemaining(
        NovaTypes.Auction memory auction,
        uint256 timestamp
    ) internal pure returns (uint256) {
        if (timestamp >= auction.endTime) return 0;
        return auction.endTime - timestamp;
    }

    function secondsElapsed(
        NovaTypes.Auction memory auction,
        uint256 timestamp
    ) internal pure returns (uint256) {
        if (timestamp <= auction.startTime) return 0;
        return timestamp - auction.startTime;
    }

    function totalDuration(
        NovaTypes.Auction memory auction
    ) internal pure returns (uint256) {
        if (auction.endTime <= auction.startTime) return 0;
        return auction.endTime - auction.startTime;
    }

    function extensionSeconds(
        NovaTypes.Auction memory auction
    ) internal pure returns (uint256) {
        if (auction.endTime <= auction.originalEndTime) return 0;
        return auction.endTime - auction.originalEndTime;
    }

    function elapsedBps(
        NovaTypes.Auction memory auction,
        uint256 timestamp
    ) internal pure returns (uint256) {
        uint256 duration = totalDuration(auction);
        if (duration == 0) return 0;
        uint256 elapsed = secondsElapsed(auction, timestamp);
        if (elapsed > duration) elapsed = duration;
        return (elapsed * 10_000) / duration;
    }

    function bidCoverageBps(
        NovaTypes.Auction memory auction
    ) internal pure returns (uint256) {
        if (auction.debtTarget == 0) return 0;
        return (auction.winningBid * 10_000) / auction.debtTarget;
    }

    function floorCoverageBps(
        NovaTypes.Auction memory auction
    ) internal pure returns (uint256) {
        if (auction.debtTarget == 0) return 0;
        return (auction.cachedFloorDebt * 10_000) / auction.debtTarget;
    }

    function acceptedFloorGap(
        NovaTypes.Auction memory auction
    ) internal pure returns (uint256) {
        if (auction.winningBid >= auction.acceptedFloorDebt) return 0;
        return auction.acceptedFloorDebt - auction.winningBid;
    }

    function staleFloorGap(
        NovaTypes.Auction memory auction,
        uint256 trueFloorDebt
    ) internal pure returns (uint256) {
        if (trueFloorDebt <= auction.cachedFloorDebt) return 0;
        return trueFloorDebt - auction.cachedFloorDebt;
    }

    function requireActive(
        NovaTypes.Auction memory auction
    ) internal pure {
        if (!isActive(auction)) revert AuctionIsNotActive();
    }

    function requireFinished(
        NovaTypes.Auction memory auction,
        uint256 timestamp
    ) internal pure {
        if (!hasEnded(auction, timestamp)) revert AuctionIsNotFinished();
    }

    function requireWinner(
        NovaTypes.Auction memory auction
    ) internal pure {
        if (!hasWinner(auction)) revert AuctionHasNoWinner();
    }

    function requireNotFinalized(
        NovaTypes.Auction memory auction
    ) internal pure {
        if (isFinalized(auction)) revert AuctionAlreadyFinalized();
    }

    function statusLabel(
        NovaTypes.Auction memory auction
    ) internal pure returns (string memory) {
        if (auction.status == NovaTypes.AuctionStatus.Active) return "ACTIVE";
        if (auction.status == NovaTypes.AuctionStatus.Settled) return "SETTLED";
        if (auction.status == NovaTypes.AuctionStatus.Cancelled) return "CANCELLED";
        return "NONE";
    }
}
