// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { INovaAuctionHouse } from "../interfaces/INovaAuctionHouse.sol";
import { INovaConfigurator } from "../interfaces/INovaConfigurator.sol";
import { AuctionPricing } from "../libraries/AuctionPricing.sol";
import { NovaMath } from "../libraries/NovaMath.sol";
import { NovaTypes } from "../libraries/NovaTypes.sol";

contract NovaAuctionAnalytics {
    using NovaMath for uint256;

    uint256 internal constant STRESS_HAIRCUT_BPS = 1500;

    error AuctionNotFound(uint256 auctionId);

    struct AuctionAggregate {
        uint256 scanned;
        uint256 activeCount;
        uint256 settledCount;
        uint256 cancelledCount;
        uint256 totalDebtTarget;
        uint256 totalWinningBid;
        uint256 totalCollateral;
        uint256 totalDebtRecovered;
        uint256 totalShortfall;
        uint256 totalSurplus;
    }

    struct ExtensionReport {
        uint256 scanned;
        uint256 auctionsExtended;
        uint256 totalExtensions;
        uint256 largestExtensionCount;
        uint256 earliestActiveEndTime;
    }

    struct RecoveryProfile {
        uint256 auctionId;
        uint256 debtTarget;
        uint256 winningBid;
        uint256 nominalRecovery;
        uint256 shortfall;
        uint256 surplus;
        uint256 stressHaircutBps;
        uint256 stressedRecovery;
        uint256 stressedShortfall;
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
            data.totalDebtRecovered += NovaMath.min(auction.winningBid, auction.debtTarget);
            data.totalShortfall += AuctionPricing.shortfall(auction.winningBid, auction.debtTarget);
            data.totalSurplus += AuctionPricing.surplus(auction.winningBid, auction.debtTarget);
        }
    }

    function extensionReport(
        uint256 startId,
        uint256 count
    ) external view returns (ExtensionReport memory report) {
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
            if (
                auction.status == NovaTypes.AuctionStatus.Active
                    && (report.earliestActiveEndTime == 0
                        || auction.endTime < report.earliestActiveEndTime)
            ) {
                report.earliestActiveEndTime = auction.endTime;
            }
        }
    }

    function recoveryProfile(
        uint256 auctionId
    ) external view returns (RecoveryProfile memory profile) {
        NovaTypes.Auction memory auction = auctionHouse.getAuction(auctionId);
        if (auction.id == 0) revert AuctionNotFound(auctionId);
        uint256 recovered = NovaMath.min(auction.winningBid, auction.debtTarget);
        uint256 stressed = recovered.mulDivDown(NovaMath.BPS - STRESS_HAIRCUT_BPS, NovaMath.BPS);
        profile = RecoveryProfile({
            auctionId: auctionId,
            debtTarget: auction.debtTarget,
            winningBid: auction.winningBid,
            nominalRecovery: recovered,
            shortfall: AuctionPricing.shortfall(auction.winningBid, auction.debtTarget),
            surplus: AuctionPricing.surplus(auction.winningBid, auction.debtTarget),
            stressHaircutBps: STRESS_HAIRCUT_BPS,
            stressedRecovery: stressed,
            stressedShortfall: auction.debtTarget - stressed
        });
    }

    function weightedRecoveryBps(
        uint256 startId,
        uint256 count
    ) external view returns (uint256) {
        uint256 totalDebt;
        uint256 totalRecovery;
        for (uint256 i = 0; i < count; i++) {
            NovaTypes.Auction memory auction = auctionHouse.getAuction(startId + i);
            if (auction.id == 0) continue;
            totalDebt += auction.debtTarget;
            totalRecovery += NovaMath.min(auction.winningBid, auction.debtTarget);
        }
        if (totalDebt == 0) return 0;
        return totalRecovery.mulDivDown(NovaMath.BPS, totalDebt);
    }
}
