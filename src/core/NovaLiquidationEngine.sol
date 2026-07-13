// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { INovaAuctionHouse } from "../interfaces/INovaAuctionHouse.sol";
import { INovaConfigurator } from "../interfaces/INovaConfigurator.sol";
import { INovaPriceOracle } from "../interfaces/INovaPriceOracle.sol";
import { INovaVault } from "../interfaces/INovaVault.sol";
import { NovaMath } from "../libraries/NovaMath.sol";
import { NovaTypes } from "../libraries/NovaTypes.sol";
import { SafeTransferLib } from "../libraries/SafeTransferLib.sol";
import { ReentrancyGuard } from "../security/ReentrancyGuard.sol";

contract NovaLiquidationEngine is ReentrancyGuard {
    using NovaMath for uint256;
    using SafeTransferLib for address;

    error LiquidationsPaused();
    error NotKeeper();
    error NotLiquidatable();
    error InvalidAmount();
    error InvalidQuote();

    INovaConfigurator public immutable configurator;

    event LiquidationAuctionOpened(
        uint256 indexed auctionId,
        address indexed borrower,
        address indexed collateralToken,
        uint256 debtToCover,
        uint256 collateralSeized
    );

    constructor(
        INovaConfigurator configurator_
    ) {
        configurator = configurator_;
    }

    function startLiquidationAuction(
        address borrower,
        address collateralToken,
        uint256 requestedDebtToCover
    ) external nonReentrant returns (uint256 auctionId) {
        NovaTypes.PauseState memory pauseState = configurator.pauseState();
        if (pauseState.liquidationsPaused) revert LiquidationsPaused();
        if (!configurator.hasRole(configurator.KEEPER_ROLE(), msg.sender)) revert NotKeeper();

        NovaTypes.LiquidationQuote memory quote =
            previewLiquidation(borrower, collateralToken, requestedDebtToCover);
        if (!quote.liquidatable) revert NotLiquidatable();
        if (quote.debtToCover == 0 || quote.collateralToSeize == 0) revert InvalidQuote();

        INovaVault(configurator.vault())
            .seizeCollateral(borrower, collateralToken, quote.collateralToSeize, address(this));

        collateralToken.safeApprove(configurator.auctionHouse(), 0);
        collateralToken.safeApprove(configurator.auctionHouse(), quote.collateralToSeize);
        auctionId = INovaAuctionHouse(configurator.auctionHouse())
            .startAuction(
                borrower,
                collateralToken,
                configurator.debtToken(),
                quote.collateralToSeize,
                quote.debtToCover
            );

        emit LiquidationAuctionOpened(
            auctionId, borrower, collateralToken, quote.debtToCover, quote.collateralToSeize
        );
    }

    function previewLiquidation(
        address borrower,
        address collateralToken,
        uint256 requestedDebtToCover
    ) public view returns (NovaTypes.LiquidationQuote memory quote) {
        INovaVault vault = INovaVault(configurator.vault());
        uint256 health = vault.healthFactor(collateralToken, borrower);
        uint256 debt = vault.debtOf(collateralToken, borrower);
        uint256 collateral = vault.collateralOf(collateralToken, borrower);
        NovaTypes.RiskConfig memory risk = configurator.getRiskConfig(collateralToken);

        if (debt == 0 || health >= NovaMath.WAD) {
            return NovaTypes.LiquidationQuote({
                borrower: borrower,
                collateralToken: collateralToken,
                debtToken: configurator.debtToken(),
                debtToCover: 0,
                collateralToSeize: 0,
                penaltyAmount: 0,
                protocolPenalty: 0,
                borrowerRefund: collateral,
                healthFactorBefore: health,
                liquidatable: false
            });
        }

        uint256 debtToCover =
            requestedDebtToCover == 0 ? debt : NovaMath.min(requestedDebtToCover, debt);
        uint256 penaltyAmount = debtToCover.bps(risk.liquidationPenaltyBps);
        uint256 protocolPenalty = penaltyAmount.bps(risk.protocolPenaltyShareBps);
        uint256 valueToSeize = debtToCover + penaltyAmount;
        uint256 collateralToSeize = INovaPriceOracle(configurator.oracle())
            .tokenAmountForValue(collateralToken, valueToSeize);
        collateralToSeize = NovaMath.min(collateralToSeize, collateral);

        quote = NovaTypes.LiquidationQuote({
            borrower: borrower,
            collateralToken: collateralToken,
            debtToken: configurator.debtToken(),
            debtToCover: debtToCover,
            collateralToSeize: collateralToSeize,
            penaltyAmount: penaltyAmount,
            protocolPenalty: protocolPenalty,
            borrowerRefund: collateral - collateralToSeize,
            healthFactorBefore: health,
            liquidatable: true
        });
    }
}
