// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { NovaAuctionAnalytics } from "../src/lens/NovaAuctionAnalytics.sol";
import { NovaTestBase } from "./helpers/NovaTestBase.sol";

contract NovaAuctionAnalyticsTest is NovaTestBase {
    NovaAuctionAnalytics internal analytics;

    function setUp() public override {
        super.setUp();
        analytics = new NovaAuctionAnalytics(configurator, auctionHouse);
    }

    function testRecoveryProjectionTracksNominalAndStressAmounts() public {
        uint256 auctionId = _startAuction();
        _bid(alice, auctionId, 1000e18);

        NovaAuctionAnalytics.RecoveryProfile memory profile = analytics.recoveryProfile(auctionId);
        assertEq(profile.debtTarget, 1000e18);
        assertEq(profile.nominalRecovery, 1000e18);
        assertEq(profile.shortfall, 0);
        assertEq(profile.stressHaircutBps, 1500);
        assertEq(profile.stressedRecovery, 850e18);
        assertEq(profile.stressedShortfall, 150e18);
    }

    function testAggregateAndExtensionOperations() public {
        uint256 auctionId = _startAuction();
        _warpToNearClose(auctionId);
        _bid(alice, auctionId, 1000e18);

        NovaAuctionAnalytics.AuctionAggregate memory totals = analytics.aggregate(auctionId, 2);
        NovaAuctionAnalytics.ExtensionReport memory extension =
            analytics.extensionReport(auctionId, 2);

        assertEq(totals.scanned, 1);
        assertEq(totals.totalDebtTarget, 1000e18);
        assertEq(totals.totalDebtRecovered, 1000e18);
        assertEq(totals.totalShortfall, 0);
        assertEq(analytics.weightedRecoveryBps(auctionId, 2), 10_000);
        assertEq(extension.auctionsExtended, 1);
        assertEq(extension.totalExtensions, 1);
        assertGt(extension.earliestActiveEndTime, block.timestamp);
    }
}
