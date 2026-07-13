// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { INovaConfigurator } from "../interfaces/INovaConfigurator.sol";
import { INovaPriceOracle } from "../interfaces/INovaPriceOracle.sol";
import { INovaRiskEngine } from "../interfaces/INovaRiskEngine.sol";
import { INovaVault } from "../interfaces/INovaVault.sol";
import { NovaMath } from "../libraries/NovaMath.sol";
import { NovaTypes } from "../libraries/NovaTypes.sol";

contract NovaRiskEngine is INovaRiskEngine {
    using NovaMath for uint256;

    INovaConfigurator public immutable configurator;

    constructor(
        INovaConfigurator configurator_
    ) {
        configurator = configurator_;
    }

    function canBorrow(
        address collateralToken,
        address account,
        uint256 additionalDebt
    ) external view returns (bool allowed, uint256 capacity, uint256 nextDebt) {
        NovaTypes.RiskConfig memory risk = configurator.getRiskConfig(collateralToken);
        NovaTypes.BorrowerView memory viewData =
            INovaVault(configurator.vault()).borrowerView(collateralToken, account);
        capacity = viewData.borrowCapacity;
        nextDebt = viewData.debtAmount + additionalDebt;
        bool insideMinimum = nextDebt == 0 || nextDebt >= risk.minDebt;
        bool insideMaximum = risk.maxDebt == 0 || nextDebt <= risk.maxDebt;
        allowed = risk.enabled && insideMinimum && insideMaximum && nextDebt <= capacity;
    }

    function canWithdraw(
        address collateralToken,
        address account,
        uint256 collateralAmount
    ) external view returns (bool allowed, uint256 healthAfter) {
        INovaVault vault = INovaVault(configurator.vault());
        uint256 currentCollateral = vault.collateralOf(collateralToken, account);
        if (collateralAmount > currentCollateral) return (false, 0);

        NovaTypes.RiskConfig memory risk = configurator.getRiskConfig(collateralToken);
        uint256 remainingCollateral = currentCollateral - collateralAmount;
        uint256 remainingValue =
            INovaPriceOracle(configurator.oracle()).valueOf(collateralToken, remainingCollateral);
        uint256 adjusted = remainingValue.bps(risk.liquidationThresholdBps);
        uint256 debt = vault.debtOf(collateralToken, account);
        healthAfter = NovaMath.healthFactor(adjusted, debt);
        allowed = debt == 0 || healthAfter >= NovaMath.WAD;
    }

    function liquidationQuote(
        address borrower,
        address collateralToken,
        uint256 requestedDebtToCover
    ) external view returns (NovaTypes.LiquidationQuote memory quote) {
        INovaVault vault = INovaVault(configurator.vault());
        NovaTypes.RiskConfig memory risk = configurator.getRiskConfig(collateralToken);
        uint256 health = vault.healthFactor(collateralToken, borrower);
        uint256 debt = vault.debtOf(collateralToken, borrower);
        uint256 collateral = vault.collateralOf(collateralToken, borrower);
        if (!risk.enabled || debt == 0 || health >= NovaMath.WAD) {
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
        if (collateralToSeize > collateral) collateralToSeize = collateral;

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

    function borrowerView(
        address collateralToken,
        address borrower
    ) external view returns (NovaTypes.BorrowerView memory viewData) {
        return INovaVault(configurator.vault()).borrowerView(collateralToken, borrower);
    }

    function liquidationBuffer(
        address collateralToken,
        address borrower
    ) external view returns (uint256 bufferValue) {
        NovaTypes.BorrowerView memory viewData =
            INovaVault(configurator.vault()).borrowerView(collateralToken, borrower);
        if (viewData.liquidationThresholdValue <= viewData.debtAmount) return 0;
        return viewData.liquidationThresholdValue - viewData.debtAmount;
    }
}
