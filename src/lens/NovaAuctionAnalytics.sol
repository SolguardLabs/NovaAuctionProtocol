// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { INovaAuctionHouse } from "../interfaces/INovaAuctionHouse.sol";
import { INovaConfigurator } from "../interfaces/INovaConfigurator.sol";
import { AuctionPricing } from "../libraries/AuctionPricing.sol";
import { NovaMath } from "../libraries/NovaMath.sol";
import { NovaTypes } from "../libraries/NovaTypes.sol";

contract NovaAuctionAnalytics {
    using NovaMath for uint256;

    struct AuctionAggregate {
        uint256 scanned;
        uint256 activeCount;
        uint256 settledCount;
        uint256 cancelledCount;
        uint256 totalDebtTarget;
        uint256 totalWinningBid;
        uint256 totalCollateral;
        uint256 totalCachedFloor;
        uint256 totalTrueFloor;
        uint256 staleFloorCount;
    }

    struct ExtensionReport {
        uint256 scanned;
        uint256 auctionsExtended;
        uint256 totalExtensions;
        uint256 largestExtensionCount;
        uint256 largestFloorGap;
        uint256 largestFloorGapAuctionId;
    }

    INovaConfigurator public immutable configurator;
    INovaAuctionHouse public immutable auctionHouse;

    constructor(
        INovaConfigurator configurator_,
        INovaAuctionHouse auctionHouse_
    ) {
        configurator = configurator_;
        auctionHouse = auctionHouse_;
    }

    function aggregate(
        uint256 startId,
        uint256 count
    ) external view returns (AuctionAggregate memory data) {
        NovaTypes.AuctionConfig memory config = configurator.getAuctionConfig();
        for (uint256 i = 0; i < count; i++) {
            NovaTypes.Auction memory auction = auctionHouse.getAuction(startId + i);
            if (auction.id == 0) continue;
            data.scanned += 1;
            if (auction.status == NovaTypes.AuctionStatus.Active) data.activeCount += 1;
            if (auction.status == NovaTypes.AuctionStatus.Settled) data.settledCount += 1;
            if (auction.status == NovaTypes.AuctionStatus.Cancelled) data.cancelledCount += 1;
            data.totalDebtTarget += auction.debtTarget;
            data.totalWinningBid += auction.winningBid;
            data.totalCollateral += auction.collateralAmount;
            data.totalCachedFloor += auction.cachedFloorDebt;
            uint256 trueFloor = AuctionPricing.floorDebt(auction, config, block.timestamp);
            data.totalTrueFloor += trueFloor;
            if (trueFloor > auction.cachedFloorDebt) data.staleFloorCount += 1;
        }
    }

    function extensionReport(
        uint256 startId,
        uint256 count
    ) external view returns (ExtensionReport memory report) {
        NovaTypes.AuctionConfig memory config = configurator.getAuctionConfig();
        for (uint256 i = 0; i < count; i++) {
            NovaTypes.Auction memory auction = auctionHouse.getAuction(startId + i);
            if (auction.id == 0) continue;
            report.scanned += 1;
            if (auction.extensionCount != 0) {
                report.auctionsExtended += 1;
                report.totalExtensions += auction.extensionCount;
                if (auction.extensionCount > report.largestExtensionCount) {
                    report.largestExtensionCount = auction.extensionCount;
                }
            }
            uint256 trueFloor = AuctionPricing.floorDebt(auction, config, block.timestamp);
            uint256 gap =
                trueFloor > auction.cachedFloorDebt ? trueFloor - auction.cachedFloorDebt : 0;
            if (gap > report.largestFloorGap) {
                report.largestFloorGap = gap;
                report.largestFloorGapAuctionId = auction.id;
            }
        }
    }

    function staleFloorGap(
        uint256 auctionId
    ) external view returns (uint256 gap, uint256 cachedFloor, uint256 trueFloor) {
        NovaTypes.Auction memory auction = auctionHouse.getAuction(auctionId);
        cachedFloor = auction.cachedFloorDebt;
        trueFloor =
            AuctionPricing.floorDebt(auction, configurator.getAuctionConfig(), block.timestamp);
        gap = trueFloor > cachedFloor ? trueFloor - cachedFloor : 0;
    }

    function weightedAverageDiscount(
        uint256 startId,
        uint256 count
    ) external view returns (uint256 discountBps) {
        uint256 weightedGap;
        uint256 weightedBase;
        NovaTypes.AuctionConfig memory config = configurator.getAuctionConfig();
        for (uint256 i = 0; i < count; i++) {
            NovaTypes.Auction memory auction = auctionHouse.getAuction(startId + i);
            if (auction.id == 0 || auction.winningBid == 0) continue;
            uint256 trueFloor = AuctionPricing.floorDebt(auction, config, block.timestamp);
            if (trueFloor <= auction.winningBid) continue;
            weightedGap += trueFloor - auction.winningBid;
            weightedBase += trueFloor;
        }
        if (weightedBase == 0) return 0;
        discountBps = weightedGap.mulDivDown(NovaMath.BPS, weightedBase);
    }
}
