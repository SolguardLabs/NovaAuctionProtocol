// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { NovaAuctionHouse } from "../src/core/NovaAuctionHouse.sol";
import { NovaTypes } from "../src/libraries/NovaTypes.sol";
import { NovaTestBase } from "./helpers/NovaTestBase.sol";

contract NovaAuctionProtocolTest is NovaTestBase {
    function testStartAuctionLocksCollateralAndRecordsTerms() public {
        uint256 auctionId = _startAuction();
        NovaTypes.Auction memory auction = auctionHouse.getAuction(auctionId);

        assertEq(auction.id, auctionId);
        assertEq(auction.borrower, borrower);
        assertEq(auction.collateralToken, address(collateral));
        assertEq(auction.debtToken, address(stable));
        assertEq(auction.collateralAmount, AUCTION_COLLATERAL);
        assertEq(auction.debtTarget, DEBT_TARGET);
        assertEq(auction.startFloorDebt, DEBT_TARGET);
        assertEq(auction.reserveFloorDebt, 800e18);
        assertEq(auction.cachedFloorDebt, DEBT_TARGET);
        assertEq(uint256(auction.status), uint256(NovaTypes.AuctionStatus.Active));
        assertEq(collateral.balanceOf(address(auctionHouse)), AUCTION_COLLATERAL);
        assertEq(collateral.balanceOf(owner), 0);
    }

    function testBidTracksWinnerAndRefundsPreviousBidder() public {
        uint256 auctionId = _startAuction();

        _bid(alice, auctionId, 1000e18);
        _bid(bob, auctionId, 1100e18);

        NovaTypes.Auction memory auction = auctionHouse.getAuction(auctionId);
        assertEq(auction.winner, bob);
        assertEq(auction.winningBid, 1100e18);
        assertEq(auctionHouse.bidCredit(address(stable), alice), 1000e18);

        uint256 balanceBefore = stable.balanceOf(alice);
        vm.prank(alice);
        uint256 withdrawn = auctionHouse.withdrawBidCredit(address(stable), alice);
        assertEq(withdrawn, 1000e18);
        assertEq(stable.balanceOf(alice), balanceBefore + 1000e18);
        assertEq(auctionHouse.bidCredit(address(stable), alice), 0);
    }

    function testSettleMovesDebtToTreasuryAndCreatesClaim() public {
        uint256 auctionId = _startAuction();
        _bid(alice, auctionId, 1000e18);
        _warpAfterEnd(auctionId);

        NovaTypes.CollateralClaim memory claim = auctionHouse.settle(auctionId);
        NovaTypes.Auction memory auction = auctionHouse.getAuction(auctionId);

        assertEq(uint256(auction.status), uint256(NovaTypes.AuctionStatus.Settled));
        assertEq(stable.balanceOf(address(treasury)), 1000e18);
        assertEq(claim.auctionId, auctionId);
        assertEq(claim.claimant, alice);
        assertEq(claim.collateralAmount, AUCTION_COLLATERAL);

        NovaTypes.TreasurySnapshot memory snapshot = treasury.getSnapshot(address(stable));
        assertEq(snapshot.totalDebtCollected, 1000e18);
        assertEq(snapshot.settledAuctions, 1);
    }

    function testCancelAuctionReturnsCollateralWhenNoBid() public {
        uint256 auctionId = _startAuction();

        vm.prank(borrower);
        auctionHouse.cancel(auctionId, "borrower recovered position");

        NovaTypes.Auction memory auction = auctionHouse.getAuction(auctionId);
        assertEq(uint256(auction.status), uint256(NovaTypes.AuctionStatus.Cancelled));
        assertEq(collateral.balanceOf(borrower), AUCTION_COLLATERAL);
        assertEq(collateral.balanceOf(address(auctionHouse)), 0);

        NovaTypes.TreasurySnapshot memory snapshot = treasury.getSnapshot(address(stable));
        assertEq(snapshot.cancelledAuctions, 1);
    }

    function testClaimCollateralAfterSettlement() public {
        uint256 auctionId = _startAuction();
        _bid(alice, auctionId, 1000e18);
        _warpAfterEnd(auctionId);
        auctionHouse.settle(auctionId);

        vm.prank(alice);
        uint256 claimed = auctionHouse.claimCollateral(auctionId, recipient);

        assertEq(claimed, AUCTION_COLLATERAL);
        assertEq(collateral.balanceOf(recipient), AUCTION_COLLATERAL);
        assertEq(collateral.balanceOf(address(auctionHouse)), 0);

        NovaTypes.CollateralClaim memory claim = auctionHouse.getClaim(auctionId);
        assertTrue(claim.claimed);
    }

    function testCannotClaimCollateralBeforeSettlement() public {
        uint256 auctionId = _startAuction();
        _bid(alice, auctionId, 1000e18);

        vm.prank(alice);
        vm.expectRevert(NovaAuctionHouse.InvalidAuction.selector);
        auctionHouse.claimCollateral(auctionId, alice);
    }
}
