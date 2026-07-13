// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { INovaConfigurator } from "../interfaces/INovaConfigurator.sol";
import { NovaTypes } from "../libraries/NovaTypes.sol";
import { Ownable2Step } from "../security/Ownable2Step.sol";

contract NovaConfigurator is INovaConfigurator, Ownable2Step {
    error InvalidAddress();
    error InvalidAuctionConfig();
    error InvalidRiskConfig();
    error MissingRole(bytes32 role, address account);

    bytes32 public constant AUCTIONEER_ROLE = keccak256("NOVA_AUCTIONEER_ROLE");
    bytes32 public constant KEEPER_ROLE = keccak256("NOVA_KEEPER_ROLE");
    bytes32 public constant LIQUIDATION_ROLE = keccak256("NOVA_LIQUIDATION_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("NOVA_PAUSER_ROLE");
    bytes32 public constant RISK_ROLE = keccak256("NOVA_RISK_ROLE");

    address public debtToken;
    address public treasury;
    address public oracle;
    address public auctionHouse;
    address public vault;
    address public liquidationEngine;

    NovaTypes.AuctionConfig private _auctionConfig;
    NovaTypes.PauseState private _pauseState;

    mapping(bytes32 => mapping(address => bool)) private _roles;
    mapping(address => NovaTypes.RiskConfig) private _riskConfigs;
    address[] private _collateralList;
    mapping(address => bool) private _listedCollateral;

    event AddressBookUpdated(
        address debtToken,
        address treasury,
        address oracle,
        address auctionHouse,
        address vault,
        address liquidationEngine
    );
    event RoleUpdated(bytes32 indexed role, address indexed account, bool enabled);
    event AuctionConfigUpdated(NovaTypes.AuctionConfig config);
    event RiskConfigUpdated(address indexed collateralToken, NovaTypes.RiskConfig config);
    event PauseStateUpdated(NovaTypes.PauseState state);

    constructor(
        address owner_
    ) Ownable2Step(owner_) {
        _auctionConfig = NovaTypes.AuctionConfig({
            defaultDuration: 6 hours,
            extensionWindow: 15 minutes,
            extensionDuration: 30 minutes,
            minIncrementBps: 500,
            startFloorBps: 10_000,
            reserveFloorBps: 8000,
            extensionPremiumBps: 1500,
            maxExtensions: 4,
            claimDelay: 0
        });
        _roles[AUCTIONEER_ROLE][owner_] = true;
        _roles[KEEPER_ROLE][owner_] = true;
        _roles[LIQUIDATION_ROLE][owner_] = true;
        _roles[PAUSER_ROLE][owner_] = true;
        _roles[RISK_ROLE][owner_] = true;
    }

    function configureAddresses(
        address debtToken_,
        address treasury_,
        address oracle_,
        address auctionHouse_,
        address vault_,
        address liquidationEngine_
    ) external onlyOwner {
        if (debtToken_ == address(0)) revert InvalidAddress();
        if (treasury_ == address(0)) revert InvalidAddress();
        if (oracle_ == address(0)) revert InvalidAddress();
        debtToken = debtToken_;
        treasury = treasury_;
        oracle = oracle_;
        auctionHouse = auctionHouse_;
        vault = vault_;
        liquidationEngine = liquidationEngine_;
        emit AddressBookUpdated(
            debtToken_, treasury_, oracle_, auctionHouse_, vault_, liquidationEngine_
        );
    }

    function setRole(
        bytes32 role,
        address account,
        bool enabled
    ) external onlyOwner {
        if (account == address(0)) revert InvalidAddress();
        _roles[role][account] = enabled;
        emit RoleUpdated(role, account, enabled);
    }

    function setAuctionConfig(
        NovaTypes.AuctionConfig calldata config
    ) external onlyOwner {
        _validateAuctionConfig(config);
        _auctionConfig = config;
        emit AuctionConfigUpdated(config);
    }

    function setRiskConfig(
        address collateralToken,
        NovaTypes.RiskConfig calldata config
    ) external onlyOwner {
        if (collateralToken == address(0)) revert InvalidAddress();
        _validateRiskConfig(config);
        if (!_listedCollateral[collateralToken]) {
            _listedCollateral[collateralToken] = true;
            _collateralList.push(collateralToken);
        }
        _riskConfigs[collateralToken] = config;
        emit RiskConfigUpdated(collateralToken, config);
    }

    function setPauseState(
        NovaTypes.PauseState calldata state
    ) external {
        requireRole(PAUSER_ROLE, msg.sender);
        _pauseState = state;
        emit PauseStateUpdated(state);
    }

    function hasRole(
        bytes32 role,
        address account
    ) public view returns (bool) {
        return account == owner || _roles[role][account];
    }

    function requireRole(
        bytes32 role,
        address account
    ) public view {
        if (!hasRole(role, account)) revert MissingRole(role, account);
    }

    function getAuctionConfig() external view returns (NovaTypes.AuctionConfig memory) {
        return _auctionConfig;
    }

    function getRiskConfig(
        address collateralToken
    ) external view returns (NovaTypes.RiskConfig memory) {
        return _riskConfigs[collateralToken];
    }

    function pauseState() external view returns (NovaTypes.PauseState memory) {
        return _pauseState;
    }

    function collateralCount() external view returns (uint256) {
        return _collateralList.length;
    }

    function collateralAt(
        uint256 index
    ) external view returns (address) {
        return _collateralList[index];
    }

    function isCollateralListed(
        address collateralToken
    ) external view returns (bool) {
        return _listedCollateral[collateralToken];
    }

    function _validateAuctionConfig(
        NovaTypes.AuctionConfig calldata config
    ) private pure {
        if (config.defaultDuration == 0) revert InvalidAuctionConfig();
        if (config.extensionWindow > config.defaultDuration) revert InvalidAuctionConfig();
        if (config.extensionDuration == 0) revert InvalidAuctionConfig();
        if (config.minIncrementBps == 0 || config.minIncrementBps > 5000) {
            revert InvalidAuctionConfig();
        }
        if (config.reserveFloorBps > config.startFloorBps) revert InvalidAuctionConfig();
        if (config.startFloorBps > 20_000) revert InvalidAuctionConfig();
        if (config.extensionPremiumBps > 10_000) revert InvalidAuctionConfig();
    }

    function _validateRiskConfig(
        NovaTypes.RiskConfig calldata config
    ) private pure {
        if (!config.enabled) return;
        if (config.loanToValueBps == 0) revert InvalidRiskConfig();
        if (config.liquidationThresholdBps < config.loanToValueBps) revert InvalidRiskConfig();
        if (config.liquidationThresholdBps > 10_000) revert InvalidRiskConfig();
        if (config.liquidationPenaltyBps > 5000) revert InvalidRiskConfig();
        if (config.protocolPenaltyShareBps > 10_000) revert InvalidRiskConfig();
        if (config.maxDebt != 0 && config.maxDebt < config.minDebt) revert InvalidRiskConfig();
    }
}
