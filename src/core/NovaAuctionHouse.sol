// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { INovaAuctionHouse } from "../interfaces/INovaAuctionHouse.sol";
import { INovaConfigurator } from "../interfaces/INovaConfigurator.sol";
import { INovaTreasury } from "../interfaces/INovaTreasury.sol";
import { AuctionPricing } from "../libraries/AuctionPricing.sol";
import { NovaMath } from "../libraries/NovaMath.sol";
import { NovaTypes } from "../libraries/NovaTypes.sol";
import { SafeTransferLib } from "../libraries/SafeTransferLib.sol";
import { ReentrancyGuard } from "../security/ReentrancyGuard.sol";

contract NovaAuctionHouse is INovaAuctionHouse, ReentrancyGuard {
    using AuctionPricing for NovaTypes.Auction;
    using SafeTransferLib for address;

    error AuctionsPaused();
    error ClaimsPaused();
    error InvalidAuction();
    error InvalidBidder();
    error InvalidAmount();
    error AuctionNotActive();
    error AuctionStillOpen();
    error AuctionExpired();
    error BidTooLow(uint256 required, uint256 provided);
    error AlreadySettled();
    error NoWinningBid();
    error ClaimNotReady(uint256 availableAt);
    error NotClaimant();
    error AlreadyClaimed();
    error CancelForbidden();
    error TransferCreditMissing();

    INovaConfigurator public immutable configurator;

    uint256 public auctionCount;

    mapping(uint256 => NovaTypes.Auction) private _auctions;
    mapping(uint256 => NovaTypes.CollateralClaim) private _claims;
    mapping(address => mapping(address => uint256)) public bidCredit;

    event AuctionStarted(
        uint256 indexed auctionId,
        address indexed borrower,
        address indexed collateralToken,
        address debtToken,
        uint256 collateralAmount,
        uint256 debtTarget,
        uint64 startTime,
        uint64 endTime,
        uint256 startFloorDebt,
        uint256 reserveFloorDebt
    );
    event BidPlaced(
        uint256 indexed auctionId,
        address indexed bidder,
        uint256 amount,
        uint256 requiredAmount,
        uint256 cachedFloorDebt,
        uint256 previousBid
    );
    event AuctionExtended(
        uint256 indexed auctionId,
        uint64 previousEndTime,
        uint64 nextEndTime,
        uint8 extensionCount,
        uint256 floorDebt
    );
    event AuctionSettled(
        uint256 indexed auctionId,
        address indexed winner,
        uint256 winningBid,
        uint256 debtTarget,
        uint256 cachedFloorDebt,
        uint256 trueFloorDebt
    );
    event AuctionCancelled(uint256 indexed auctionId, address indexed borrower, string reason);
    event CollateralClaimed(
        uint256 indexed auctionId,
        address indexed claimant,
        address indexed recipient,
        uint256 amount
    );
    event BidCreditWithdrawn(
        address indexed debtToken, address indexed bidder, address indexed recipient, uint256 amount
    );

    constructor(
        INovaConfigurator configurator_
    ) {
        configurator = configurator_;
    }

    function startAuction(
        address borrower,
        address collateralToken,
        address debtToken,
        uint256 collateralAmount,
        uint256 debtTarget
    ) external nonReentrant returns (uint256 auctionId) {
        NovaTypes.PauseState memory pauseState = configurator.pauseState();
        if (pauseState.auctionsPaused) revert AuctionsPaused();
        configurator.requireRole(configurator.AUCTIONEER_ROLE(), msg.sender);
        if (borrower == address(0) || collateralToken == address(0) || debtToken == address(0)) {
            revert InvalidAuction();
        }
        if (collateralAmount == 0 || debtTarget == 0) revert InvalidAmount();

        NovaTypes.AuctionConfig memory config = configurator.getAuctionConfig();
        uint256 startFloorDebt = AuctionPricing.startFloor(debtTarget, config);
        uint256 reserveFloorDebt = AuctionPricing.reserveFloor(debtTarget, config);
        if (reserveFloorDebt > startFloorDebt) revert InvalidAuction();

        auctionId = ++auctionCount;
        uint64 start = uint64(block.timestamp);
        uint64 end = start + config.defaultDuration;
        _auctions[auctionId] = NovaTypes.Auction({
            id: auctionId,
            borrower: borrower,
            collateralToken: collateralToken,
            debtToken: debtToken,
            collateralAmount: collateralAmount,
            debtTarget: debtTarget,
            startFloorDebt: startFloorDebt,
            reserveFloorDebt: reserveFloorDebt,
            cachedFloorDebt: startFloorDebt,
            acceptedFloorDebt: 0,
            winningBid: 0,
            winner: address(0),
            startTime: start,
            endTime: end,
            originalEndTime: end,
            lastBidTime: 0,
            extensionCount: 0,
            status: NovaTypes.AuctionStatus.Active
        });

        collateralToken.safeTransferFrom(msg.sender, address(this), collateralAmount);
        emit AuctionStarted(
            auctionId,
            borrower,
            collateralToken,
            debtToken,
            collateralAmount,
            debtTarget,
            start,
            end,
            startFloorDebt,
            reserveFloorDebt
        );
    }

    function bid(
        uint256 auctionId,
        uint256 amount,
        address bidder
    ) external nonReentrant returns (NovaTypes.BidReceipt memory receipt) {
        NovaTypes.PauseState memory pauseState = configurator.pauseState();
        if (pauseState.auctionsPaused) revert AuctionsPaused();
        if (bidder == address(0)) revert InvalidBidder();
        if (amount == 0) revert InvalidAmount();

        NovaTypes.Auction storage auction = _activeAuction(auctionId);
        if (block.timestamp >= auction.endTime) revert AuctionExpired();

        NovaTypes.AuctionConfig memory config = configurator.getAuctionConfig();
        _refreshCachedFloorBeforeBid(auction, config);

        NovaTypes.Auction memory snapshot = auction;
        uint256 requiredAmount = AuctionPricing.requiredNextBidFromCachedFloor(snapshot, config);
        if (amount < requiredAmount) revert BidTooLow(requiredAmount, amount);

        auction.debtToken.safeTransferFrom(msg.sender, address(this), amount);

        uint256 previousBid = auction.winningBid;
        address previousWinner = auction.winner;
        if (previousWinner != address(0)) {
            bidCredit[auction.debtToken][previousWinner] += previousBid;
        }

        auction.winner = bidder;
        auction.winningBid = amount;
        auction.acceptedFloorDebt = auction.cachedFloorDebt;
        auction.lastBidTime = uint64(block.timestamp);

        bool extended = false;
        if (AuctionPricing.wouldExtend(snapshot, config, block.timestamp)) {
            uint64 previousEndTime = auction.endTime;
            auction.endTime = previousEndTime + config.extensionDuration;
            auction.extensionCount += 1;
            extended = true;

            emit AuctionExtended(
                auctionId,
                previousEndTime,
                auction.endTime,
                auction.extensionCount,
                auction.cachedFloorDebt
            );
        }

        receipt = NovaTypes.BidReceipt({
            auctionId: auctionId,
            bidder: bidder,
            amount: amount,
            requiredAmount: requiredAmount,
            floorDebt: auction.cachedFloorDebt,
            previousBid: previousBid,
            timestamp: uint64(block.timestamp),
            extended: extended
        });

        emit BidPlaced(
            auctionId, bidder, amount, requiredAmount, auction.cachedFloorDebt, previousBid
        );
    }

    function settle(
        uint256 auctionId
    ) external nonReentrant returns (NovaTypes.CollateralClaim memory claim) {
        NovaTypes.Auction storage auction = _activeAuction(auctionId);
        if (block.timestamp < auction.endTime) revert AuctionStillOpen();
        if (auction.winner == address(0)) revert NoWinningBid();

        NovaTypes.Auction memory snapshot = auction;
        uint256 trueFloor =
            AuctionPricing.floorDebt(snapshot, configurator.getAuctionConfig(), block.timestamp);

        auction.status = NovaTypes.AuctionStatus.Settled;
        auction.debtToken.safeTransfer(configurator.treasury(), auction.winningBid);
        INovaTreasury(configurator.treasury())
            .recordAuctionSettlement(
                auctionId,
                auction.borrower,
                auction.debtToken,
                auction.winningBid,
                auction.debtTarget
            );

        uint64 availableAt = uint64(block.timestamp) + configurator.getAuctionConfig().claimDelay;
        claim = NovaTypes.CollateralClaim({
            auctionId: auctionId,
            claimant: auction.winner,
            collateralToken: auction.collateralToken,
            collateralAmount: auction.collateralAmount,
            availableAt: availableAt,
            claimed: false
        });
        _claims[auctionId] = claim;

        emit AuctionSettled(
            auctionId,
            auction.winner,
            auction.winningBid,
            auction.debtTarget,
            auction.acceptedFloorDebt,
            trueFloor
        );
    }

    function cancel(
        uint256 auctionId,
        string calldata reason
    ) external nonReentrant {
        NovaTypes.Auction storage auction = _activeAuction(auctionId);
        bool isAuctioneer = configurator.hasRole(configurator.AUCTIONEER_ROLE(), msg.sender);
        bool isBorrowerWithoutBid = msg.sender == auction.borrower && auction.winner == address(0);
        if (!isAuctioneer && !isBorrowerWithoutBid) revert CancelForbidden();

        auction.status = NovaTypes.AuctionStatus.Cancelled;
        if (auction.winner != address(0)) {
            bidCredit[auction.debtToken][auction.winner] += auction.winningBid;
        }
        auction.collateralToken.safeTransfer(auction.borrower, auction.collateralAmount);
        INovaTreasury(configurator.treasury())
            .recordAuctionCancellation(auctionId, auction.borrower, auction.debtToken);
        emit AuctionCancelled(auctionId, auction.borrower, reason);
    }

    function claimCollateral(
        uint256 auctionId,
        address recipient
    ) external nonReentrant returns (uint256 amount) {
        NovaTypes.PauseState memory pauseState = configurator.pauseState();
        if (pauseState.claimsPaused) revert ClaimsPaused();
        NovaTypes.CollateralClaim storage claim = _claims[auctionId];
        if (claim.claimant == address(0)) revert InvalidAuction();
        if (msg.sender != claim.claimant) revert NotClaimant();
        if (claim.claimed) revert AlreadyClaimed();
        if (block.timestamp < claim.availableAt) revert ClaimNotReady(claim.availableAt);
        claim.claimed = true;
        amount = claim.collateralAmount;
        claim.collateralToken.safeTransfer(recipient, amount);
        emit CollateralClaimed(auctionId, msg.sender, recipient, amount);
    }

    function withdrawBidCredit(
        address debtToken,
        address recipient
    ) external nonReentrant returns (uint256 amount) {
        amount = bidCredit[debtToken][msg.sender];
        if (amount == 0) revert TransferCreditMissing();
        bidCredit[debtToken][msg.sender] = 0;
        debtToken.safeTransfer(recipient, amount);
        emit BidCreditWithdrawn(debtToken, msg.sender, recipient, amount);
    }

    function getAuction(
        uint256 auctionId
    ) external view returns (NovaTypes.Auction memory auction) {
        auction = _auctions[auctionId];
    }

    function getClaim(
        uint256 auctionId
    ) external view returns (NovaTypes.CollateralClaim memory claim) {
        claim = _claims[auctionId];
    }

    function requiredBid(
        uint256 auctionId
    ) external view returns (uint256) {
        NovaTypes.Auction memory auction = _existingAuction(auctionId);
        return
            AuctionPricing.requiredNextBidFromCachedFloor(auction, configurator.getAuctionConfig());
    }

    function trueRequiredBid(
        uint256 auctionId
    ) external view returns (uint256) {
        NovaTypes.Auction memory auction = _existingAuction(auctionId);
        return
            AuctionPricing.requiredNextBid(
                auction, configurator.getAuctionConfig(), block.timestamp
            );
    }

    function trueFloorDebt(
        uint256 auctionId
    ) external view returns (uint256) {
        NovaTypes.Auction memory auction = _existingAuction(auctionId);
        return AuctionPricing.floorDebt(auction, configurator.getAuctionConfig(), block.timestamp);
    }

    function settlementPreview(
        uint256 auctionId
    ) external view returns (NovaTypes.SettlementPreview memory preview) {
        NovaTypes.Auction memory auction = _existingAuction(auctionId);
        uint256 trueFloor =
            AuctionPricing.floorDebt(auction, configurator.getAuctionConfig(), block.timestamp);
        preview = NovaTypes.SettlementPreview({
            auctionId: auctionId,
            winner: auction.winner,
            winningBid: auction.winningBid,
            debtTarget: auction.debtTarget,
            surplus: AuctionPricing.surplus(auction.winningBid, auction.debtTarget),
            shortfall: AuctionPricing.shortfall(auction.winningBid, auction.debtTarget),
            cachedFloorDebt: auction.cachedFloorDebt,
            trueFloorDebt: trueFloor,
            canSettle: auction.status == NovaTypes.AuctionStatus.Active
                && block.timestamp >= auction.endTime && auction.winner != address(0)
        });
    }

    function _activeAuction(
        uint256 auctionId
    ) private view returns (NovaTypes.Auction storage auction) {
        auction = _auctions[auctionId];
        if (auction.id == 0) revert InvalidAuction();
        if (auction.status != NovaTypes.AuctionStatus.Active) revert AuctionNotActive();
    }

    function _existingAuction(
        uint256 auctionId
    ) private view returns (NovaTypes.Auction memory auction) {
        auction = _auctions[auctionId];
        if (auction.id == 0) revert InvalidAuction();
    }

    function _refreshCachedFloorBeforeBid(
        NovaTypes.Auction storage auction,
        NovaTypes.AuctionConfig memory config
    ) private {
        NovaTypes.Auction memory snapshot = auction;
        auction.cachedFloorDebt = AuctionPricing.floorDebt(snapshot, config, block.timestamp);
    }
}
