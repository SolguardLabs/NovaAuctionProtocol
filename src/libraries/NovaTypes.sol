// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

library NovaTypes {
    enum AuctionStatus {
        None,
        Active,
        Settled,
        Cancelled
    }

    enum RiskMode {
        Isolated,
        CrossMargin,
        Frozen
    }

    enum DebtAction {
        None,
        Borrow,
        Repay,
        Liquidate
    }

    struct AuctionConfig {
        uint64 defaultDuration;
        uint64 extensionWindow;
        uint64 extensionDuration;
        uint16 minIncrementBps;
        uint16 startFloorBps;
        uint16 reserveFloorBps;
        uint16 extensionPremiumBps;
        uint8 maxExtensions;
        uint64 claimDelay;
    }

    struct RiskConfig {
        uint16 loanToValueBps;
        uint16 liquidationThresholdBps;
        uint16 liquidationPenaltyBps;
        uint16 protocolPenaltyShareBps;
        uint96 minDebt;
        uint96 maxDebt;
        uint96 maxCollateral;
        uint64 heartbeat;
        bool enabled;
    }

    struct Auction {
        uint256 id;
        address borrower;
        address collateralToken;
        address debtToken;
        uint256 collateralAmount;
        uint256 debtTarget;
        uint256 startFloorDebt;
        uint256 reserveFloorDebt;
        uint256 cachedFloorDebt;
        uint256 acceptedFloorDebt;
        uint256 winningBid;
        address winner;
        uint64 startTime;
        uint64 endTime;
        uint64 originalEndTime;
        uint64 lastBidTime;
        uint8 extensionCount;
        AuctionStatus status;
    }

    struct BidReceipt {
        uint256 auctionId;
        address bidder;
        uint256 amount;
        uint256 requiredAmount;
        uint256 floorDebt;
        uint256 previousBid;
        uint64 timestamp;
        bool extended;
    }

    struct CollateralClaim {
        uint256 auctionId;
        address claimant;
        address collateralToken;
        uint256 collateralAmount;
        uint64 availableAt;
        bool claimed;
    }

    struct PriceObservation {
        uint256 priceWad;
        uint64 updatedAt;
        uint64 heartbeat;
        uint8 decimals;
        bool active;
        string source;
    }

    struct VaultAccount {
        uint256 collateralAmount;
        uint256 normalizedDebt;
        uint256 debtIndex;
        uint64 lastUpdated;
        bool entered;
    }

    struct MarketTotals {
        uint256 totalCollateral;
        uint256 totalNormalizedDebt;
        uint256 debtIndex;
        uint64 lastAccrued;
    }

    struct LiquidationQuote {
        address borrower;
        address collateralToken;
        address debtToken;
        uint256 debtToCover;
        uint256 collateralToSeize;
        uint256 penaltyAmount;
        uint256 protocolPenalty;
        uint256 borrowerRefund;
        uint256 healthFactorBefore;
        bool liquidatable;
    }

    struct SettlementPreview {
        uint256 auctionId;
        address winner;
        uint256 winningBid;
        uint256 debtTarget;
        uint256 surplus;
        uint256 shortfall;
        uint256 cachedFloorDebt;
        uint256 trueFloorDebt;
        bool canSettle;
    }

    struct AuctionView {
        uint256 id;
        address borrower;
        address collateralToken;
        address debtToken;
        uint256 collateralAmount;
        uint256 debtTarget;
        uint256 winningBid;
        address winner;
        uint256 cachedFloorDebt;
        uint256 trueFloorDebt;
        uint256 requiredNextBid;
        uint64 startTime;
        uint64 endTime;
        uint64 lastBidTime;
        uint8 extensionCount;
        AuctionStatus status;
    }

    struct BorrowerView {
        address borrower;
        address collateralToken;
        address debtToken;
        uint256 collateralAmount;
        uint256 collateralValue;
        uint256 debtAmount;
        uint256 borrowCapacity;
        uint256 liquidationThresholdValue;
        uint256 healthFactor;
        bool liquidatable;
    }

    struct TreasurySnapshot {
        uint256 totalDebtCollected;
        uint256 totalSurplusCredited;
        uint256 totalShortfallBooked;
        uint256 settledAuctions;
        uint256 cancelledAuctions;
    }

    struct AccessUpdate {
        bytes32 role;
        address account;
        bool enabled;
        address operator;
    }

    struct PauseState {
        bool depositsPaused;
        bool borrowsPaused;
        bool liquidationsPaused;
        bool auctionsPaused;
        bool claimsPaused;
    }
}
