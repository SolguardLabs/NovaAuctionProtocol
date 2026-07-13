// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IERC20 } from "../interfaces/IERC20.sol";
import { INovaConfigurator } from "../interfaces/INovaConfigurator.sol";
import { INovaPriceOracle } from "../interfaces/INovaPriceOracle.sol";
import { INovaVault } from "../interfaces/INovaVault.sol";
import { NovaMath } from "../libraries/NovaMath.sol";
import { NovaTypes } from "../libraries/NovaTypes.sol";
import { SafeTransferLib } from "../libraries/SafeTransferLib.sol";
import { ReentrancyGuard } from "../security/ReentrancyGuard.sol";
import { NovaStable } from "../tokens/NovaStable.sol";

contract NovaVault is INovaVault, ReentrancyGuard {
    using NovaMath for uint256;
    using SafeTransferLib for address;

    error DepositsPaused();
    error BorrowsPaused();
    error LiquidationsPaused();
    error InvalidCollateral();
    error InvalidAmount();
    error InsufficientCollateral();
    error InsufficientHealth(uint256 healthFactor);
    error DebtTooSmall();
    error DebtTooLarge();
    error NotLiquidationEngine();
    error NoDebt();

    INovaConfigurator public immutable configurator;

    mapping(address => mapping(address => NovaTypes.VaultAccount)) private _accounts;
    mapping(address => NovaTypes.MarketTotals) private _totals;

    event CollateralDeposited(
        address indexed collateralToken,
        address indexed payer,
        address indexed account,
        uint256 amount
    );
    event CollateralWithdrawn(
        address indexed collateralToken,
        address indexed account,
        address indexed recipient,
        uint256 amount
    );
    event DebtBorrowed(
        address indexed collateralToken,
        address indexed account,
        address indexed recipient,
        uint256 amount
    );
    event DebtRepaid(
        address indexed collateralToken,
        address indexed payer,
        address indexed account,
        uint256 amount
    );
    event CollateralSeized(
        address indexed collateralToken,
        address indexed borrower,
        address indexed recipient,
        uint256 amount
    );

    constructor(
        INovaConfigurator configurator_
    ) {
        configurator = configurator_;
    }

    function depositCollateral(
        address collateralToken,
        uint256 amount,
        address account
    ) external nonReentrant {
        NovaTypes.PauseState memory pauseState = configurator.pauseState();
        if (pauseState.depositsPaused) revert DepositsPaused();
        if (account == address(0)) revert InvalidCollateral();
        if (amount == 0) revert InvalidAmount();
        NovaTypes.RiskConfig memory risk = _enabledRisk(collateralToken);

        if (risk.maxCollateral != 0) {
            uint256 nextCollateral = _accounts[collateralToken][account].collateralAmount + amount;
            if (nextCollateral > risk.maxCollateral) revert InsufficientCollateral();
        }

        collateralToken.safeTransferFrom(msg.sender, address(this), amount);
        NovaTypes.VaultAccount storage accountData = _accounts[collateralToken][account];
        accountData.collateralAmount += amount;
        accountData.lastUpdated = uint64(block.timestamp);
        accountData.entered = true;
        _totals[collateralToken].totalCollateral += amount;
        _totals[collateralToken].lastAccrued = uint64(block.timestamp);

        emit CollateralDeposited(collateralToken, msg.sender, account, amount);
    }

    function withdrawCollateral(
        address collateralToken,
        uint256 amount,
        address recipient
    ) external nonReentrant {
        if (amount == 0) revert InvalidAmount();
        if (recipient == address(0)) revert InvalidCollateral();
        _enabledRisk(collateralToken);

        NovaTypes.VaultAccount storage accountData = _accounts[collateralToken][msg.sender];
        if (accountData.collateralAmount < amount) revert InsufficientCollateral();
        accountData.collateralAmount -= amount;
        accountData.lastUpdated = uint64(block.timestamp);
        _totals[collateralToken].totalCollateral -= amount;

        uint256 health = healthFactor(collateralToken, msg.sender);
        if (health < NovaMath.WAD) revert InsufficientHealth(health);

        collateralToken.safeTransfer(recipient, amount);
        emit CollateralWithdrawn(collateralToken, msg.sender, recipient, amount);
    }

    function borrow(
        address collateralToken,
        uint256 amount,
        address recipient
    ) external nonReentrant {
        NovaTypes.PauseState memory pauseState = configurator.pauseState();
        if (pauseState.borrowsPaused) revert BorrowsPaused();
        if (amount == 0) revert InvalidAmount();
        if (recipient == address(0)) revert InvalidCollateral();

        NovaTypes.RiskConfig memory risk = _enabledRisk(collateralToken);
        NovaTypes.VaultAccount storage accountData = _accounts[collateralToken][msg.sender];
        if (accountData.collateralAmount == 0) revert InsufficientCollateral();

        uint256 nextDebt = accountData.normalizedDebt + amount;
        if (nextDebt < risk.minDebt) revert DebtTooSmall();
        if (risk.maxDebt != 0 && nextDebt > risk.maxDebt) revert DebtTooLarge();

        uint256 capacity = _borrowCapacity(collateralToken, msg.sender, risk);
        if (nextDebt > capacity) revert InsufficientCollateral();

        accountData.normalizedDebt = nextDebt;
        accountData.debtIndex = NovaMath.RAY;
        accountData.lastUpdated = uint64(block.timestamp);
        _totals[collateralToken].totalNormalizedDebt += amount;
        _totals[collateralToken].debtIndex = NovaMath.RAY;
        _totals[collateralToken].lastAccrued = uint64(block.timestamp);

        NovaStable(configurator.debtToken()).mint(recipient, amount);
        emit DebtBorrowed(collateralToken, msg.sender, recipient, amount);
    }

    function repay(
        address collateralToken,
        uint256 amount,
        address account
    ) external nonReentrant returns (uint256 paid) {
        if (amount == 0) revert InvalidAmount();
        _enabledRisk(collateralToken);
        NovaTypes.VaultAccount storage accountData = _accounts[collateralToken][account];
        uint256 debt = accountData.normalizedDebt;
        if (debt == 0) revert NoDebt();

        paid = NovaMath.min(amount, debt);
        address debtToken = configurator.debtToken();
        debtToken.safeTransferFrom(msg.sender, address(this), paid);
        NovaStable(debtToken).burn(address(this), paid);

        accountData.normalizedDebt = debt - paid;
        accountData.lastUpdated = uint64(block.timestamp);
        _totals[collateralToken].totalNormalizedDebt -= paid;
        _totals[collateralToken].lastAccrued = uint64(block.timestamp);

        emit DebtRepaid(collateralToken, msg.sender, account, paid);
    }

    function seizeCollateral(
        address borrower,
        address collateralToken,
        uint256 amount,
        address recipient
    ) external nonReentrant {
        NovaTypes.PauseState memory pauseState = configurator.pauseState();
        if (pauseState.liquidationsPaused) revert LiquidationsPaused();
        if (msg.sender != configurator.liquidationEngine()) revert NotLiquidationEngine();
        if (amount == 0) revert InvalidAmount();

        NovaTypes.VaultAccount storage accountData = _accounts[collateralToken][borrower];
        if (accountData.collateralAmount < amount) revert InsufficientCollateral();
        accountData.collateralAmount -= amount;
        accountData.lastUpdated = uint64(block.timestamp);
        _totals[collateralToken].totalCollateral -= amount;

        collateralToken.safeTransfer(recipient, amount);
        emit CollateralSeized(collateralToken, borrower, recipient, amount);
    }

    function debtOf(
        address collateralToken,
        address account
    ) public view returns (uint256) {
        return _accounts[collateralToken][account].normalizedDebt;
    }

    function collateralOf(
        address collateralToken,
        address account
    ) public view returns (uint256) {
        return _accounts[collateralToken][account].collateralAmount;
    }

    function healthFactor(
        address collateralToken,
        address account
    ) public view returns (uint256) {
        NovaTypes.RiskConfig memory risk = configurator.getRiskConfig(collateralToken);
        uint256 debt = debtOf(collateralToken, account);
        if (debt == 0) return type(uint256).max;
        uint256 collateralValue = _collateralValue(collateralToken, account);
        uint256 adjusted = collateralValue.bps(risk.liquidationThresholdBps);
        return NovaMath.healthFactor(adjusted, debt);
    }

    function borrowerView(
        address collateralToken,
        address account
    ) external view returns (NovaTypes.BorrowerView memory viewData) {
        NovaTypes.RiskConfig memory risk = configurator.getRiskConfig(collateralToken);
        uint256 collateralAmount = collateralOf(collateralToken, account);
        uint256 collateralValue = _collateralValue(collateralToken, account);
        uint256 debt = debtOf(collateralToken, account);
        uint256 borrowCapacity = collateralValue.bps(risk.loanToValueBps);
        uint256 liquidationThresholdValue = collateralValue.bps(risk.liquidationThresholdBps);
        uint256 health = NovaMath.healthFactor(liquidationThresholdValue, debt);

        viewData = NovaTypes.BorrowerView({
            borrower: account,
            collateralToken: collateralToken,
            debtToken: configurator.debtToken(),
            collateralAmount: collateralAmount,
            collateralValue: collateralValue,
            debtAmount: debt,
            borrowCapacity: borrowCapacity,
            liquidationThresholdValue: liquidationThresholdValue,
            healthFactor: health,
            liquidatable: debt != 0 && health < NovaMath.WAD
        });
    }

    function marketTotals(
        address collateralToken
    ) external view returns (NovaTypes.MarketTotals memory totals) {
        return _totals[collateralToken];
    }

    function getAccountData(
        address collateralToken,
        address account
    ) external view returns (NovaTypes.VaultAccount memory data) {
        return _accounts[collateralToken][account];
    }

    function _enabledRisk(
        address collateralToken
    ) private view returns (NovaTypes.RiskConfig memory risk) {
        risk = configurator.getRiskConfig(collateralToken);
        if (!risk.enabled) revert InvalidCollateral();
    }

    function _borrowCapacity(
        address collateralToken,
        address account,
        NovaTypes.RiskConfig memory risk
    ) private view returns (uint256) {
        return _collateralValue(collateralToken, account).bps(risk.loanToValueBps);
    }

    function _collateralValue(
        address collateralToken,
        address account
    ) private view returns (uint256) {
        address oracle = configurator.oracle();
        return INovaPriceOracle(oracle)
            .valueOf(collateralToken, _accounts[collateralToken][account].collateralAmount);
    }
}
