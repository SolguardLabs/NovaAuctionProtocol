// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { INovaAuctionHouse } from "../interfaces/INovaAuctionHouse.sol";
import { INovaConfigurator } from "../interfaces/INovaConfigurator.sol";
import { INovaTreasury } from "../interfaces/INovaTreasury.sol";
import { INovaVault } from "../interfaces/INovaVault.sol";
import { AuctionPricing } from "../libraries/AuctionPricing.sol";
import { NovaTypes } from "../libraries/NovaTypes.sol";

contract NovaAuctionLens {
    INovaConfigurator public immutable configurator;
    INovaAuctionHouse public immutable auctionHouse;

    constructor(
        INovaConfigurator configurator_,
        INovaAuctionHouse auctionHouse_
    ) {
        configurator = configurator_;
        auctionHouse = auctionHouse_;
    }

    function auctionView(
        uint256 auctionId
    ) external view returns (NovaTypes.AuctionView memory viewData) {
        NovaTypes.Auction memory auction = auctionHouse.getAuction(auctionId);
        NovaTypes.AuctionConfig memory config = configurator.getAuctionConfig();
        uint256 trueFloor = AuctionPricing.floorDebt(auction, config, block.timestamp);
        uint256 requiredNext = AuctionPricing.requiredNextBid(auction, config, block.timestamp);

        viewData = NovaTypes.AuctionView({
            id: auction.id,
            borrower: auction.borrower,
            collateralToken: auction.collateralToken,
            debtToken: auction.debtToken,
            collateralAmount: auction.collateralAmount,
            debtTarget: auction.debtTarget,
            winningBid: auction.winningBid,
            winner: auction.winner,
            cachedFloorDebt: auction.cachedFloorDebt,
            trueFloorDebt: trueFloor,
            requiredNextBid: requiredNext,
            startTime: auction.startTime,
            endTime: auction.endTime,
            lastBidTime: auction.lastBidTime,
            extensionCount: auction.extensionCount,
            status: auction.status
        });
    }

    function borrowerView(
        address collateralToken,
        address borrower
    ) external view returns (NovaTypes.BorrowerView memory viewData) {
        return INovaVault(configurator.vault()).borrowerView(collateralToken, borrower);
    }

    function settlementPreview(
        uint256 auctionId
    ) external view returns (NovaTypes.SettlementPreview memory preview) {
        NovaTypes.Auction memory auction = auctionHouse.getAuction(auctionId);
        NovaTypes.AuctionConfig memory config = configurator.getAuctionConfig();
        uint256 trueFloor = AuctionPricing.floorDebt(auction, config, block.timestamp);
        uint256 surplus =
            auction.winningBid > auction.debtTarget ? auction.winningBid - auction.debtTarget : 0;
        uint256 shortfall =
            auction.winningBid < auction.debtTarget ? auction.debtTarget - auction.winningBid : 0;

        preview = NovaTypes.SettlementPreview({
            auctionId: auctionId,
            winner: auction.winner,
            winningBid: auction.winningBid,
            debtTarget: auction.debtTarget,
            surplus: surplus,
            shortfall: shortfall,
            cachedFloorDebt: auction.cachedFloorDebt,
            trueFloorDebt: trueFloor,
            canSettle: auction.status == NovaTypes.AuctionStatus.Active
                && block.timestamp >= auction.endTime && auction.winner != address(0)
        });
    }

    function treasurySnapshot(
        address debtToken
    ) external view returns (NovaTypes.TreasurySnapshot memory snapshot) {
        return INovaTreasury(configurator.treasury()).getSnapshot(debtToken);
    }

    function batchAuctions(
        uint256 startId,
        uint256 count
    ) external view returns (NovaTypes.AuctionView[] memory views) {
        views = new NovaTypes.AuctionView[](count);
        NovaTypes.AuctionConfig memory config = configurator.getAuctionConfig();
        for (uint256 i = 0; i < count; i++) {
            NovaTypes.Auction memory auction = auctionHouse.getAuction(startId + i);
            if (auction.id == 0) continue;
            uint256 trueFloor = AuctionPricing.floorDebt(auction, config, block.timestamp);
            views[i] = NovaTypes.AuctionView({
                id: auction.id,
                borrower: auction.borrower,
                collateralToken: auction.collateralToken,
                debtToken: auction.debtToken,
                collateralAmount: auction.collateralAmount,
                debtTarget: auction.debtTarget,
                winningBid: auction.winningBid,
                winner: auction.winner,
                cachedFloorDebt: auction.cachedFloorDebt,
                trueFloorDebt: trueFloor,
                requiredNextBid: AuctionPricing.requiredNextBid(auction, config, block.timestamp),
                startTime: auction.startTime,
                endTime: auction.endTime,
                lastBidTime: auction.lastBidTime,
                extensionCount: auction.extensionCount,
                status: auction.status
            });
        }
    }
}
