// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { INovaConfigurator } from "../interfaces/INovaConfigurator.sol";
import { INovaKeeperRewards } from "../interfaces/INovaKeeperRewards.sol";
import { NovaMath } from "../libraries/NovaMath.sol";
import { SafeTransferLib } from "../libraries/SafeTransferLib.sol";
import { ReentrancyGuard } from "../security/ReentrancyGuard.sol";

contract NovaKeeperRewards is INovaKeeperRewards, ReentrancyGuard {
    using NovaMath for uint256;
    using SafeTransferLib for address;

    error NotAuthorizedNotifier();
    error InvalidRewardConfig();
    error NoReward();
    error InsufficientBudget();

    struct RewardConfig {
        uint16 startRewardBps;
        uint16 settleRewardBps;
        uint96 minReward;
        uint96 maxReward;
        bool enabled;
    }

    INovaConfigurator public immutable configurator;
    RewardConfig public rewardConfig;

    mapping(address => mapping(address => uint256)) public rewardCredit;
    mapping(address => uint256) public rewardBudget;
    mapping(uint256 => bool) public startNotified;
    mapping(uint256 => bool) public settleNotified;

    event RewardConfigUpdated(RewardConfig config);
    event RewardBudgetDeposited(address indexed token, address indexed payer, uint256 amount);
    event AuctionStartRewarded(uint256 indexed auctionId, address indexed keeper, uint256 amount);
    event AuctionSettleRewarded(uint256 indexed auctionId, address indexed keeper, uint256 amount);
    event RewardClaimed(
        address indexed token, address indexed keeper, address indexed recipient, uint256 amount
    );

    constructor(
        INovaConfigurator configurator_
    ) {
        configurator = configurator_;
        rewardConfig = RewardConfig({
            startRewardBps: 10,
            settleRewardBps: 5,
            minReward: uint96(5e18),
            maxReward: uint96(100e18),
            enabled: true
        });
    }

    function setRewardConfig(
        RewardConfig calldata config
    ) external {
        configurator.requireRole(configurator.RISK_ROLE(), msg.sender);
        if (config.startRewardBps > 1000 || config.settleRewardBps > 1000) {
            revert InvalidRewardConfig();
        }
        if (config.maxReward != 0 && config.maxReward < config.minReward) {
            revert InvalidRewardConfig();
        }
        rewardConfig = config;
        emit RewardConfigUpdated(config);
    }

    function depositBudget(
        address token,
        uint256 amount
    ) external nonReentrant {
        if (amount == 0) revert NoReward();
        token.safeTransferFrom(msg.sender, address(this), amount);
        rewardBudget[token] += amount;
        emit RewardBudgetDeposited(token, msg.sender, amount);
    }

    function notifyAuctionStarted(
        uint256 auctionId,
        address keeper,
        uint256 debtTarget
    ) external {
        _requireNotifier();
        if (startNotified[auctionId]) return;
        startNotified[auctionId] = true;
        uint256 reward = _quoteReward(debtTarget, rewardConfig.startRewardBps);
        _creditReward(auctionId, keeper, reward, true);
    }

    function notifyAuctionSettled(
        uint256 auctionId,
        address keeper,
        uint256 winningBid
    ) external {
        _requireNotifier();
        if (settleNotified[auctionId]) return;
        settleNotified[auctionId] = true;
        uint256 reward = _quoteReward(winningBid, rewardConfig.settleRewardBps);
        _creditReward(auctionId, keeper, reward, false);
    }

    function claimReward(
        address token,
        address recipient
    ) external nonReentrant returns (uint256 amount) {
        amount = rewardCredit[token][msg.sender];
        if (amount == 0) revert NoReward();
        rewardCredit[token][msg.sender] = 0;
        token.safeTransfer(recipient, amount);
        emit RewardClaimed(token, msg.sender, recipient, amount);
    }

    function quoteStartReward(
        uint256 debtTarget
    ) external view returns (uint256) {
        return _quoteReward(debtTarget, rewardConfig.startRewardBps);
    }

    function quoteSettleReward(
        uint256 winningBid
    ) external view returns (uint256) {
        return _quoteReward(winningBid, rewardConfig.settleRewardBps);
    }

    function _requireNotifier() private view {
        bool allowed = msg.sender == configurator.auctionHouse()
            || msg.sender == configurator.liquidationEngine()
            || configurator.hasRole(configurator.KEEPER_ROLE(), msg.sender);
        if (!allowed) revert NotAuthorizedNotifier();
    }

    function _creditReward(
        uint256 auctionId,
        address keeper,
        uint256 amount,
        bool isStart
    ) private {
        if (!rewardConfig.enabled || keeper == address(0) || amount == 0) return;
        address token = configurator.debtToken();
        if (rewardBudget[token] < amount) revert InsufficientBudget();
        rewardBudget[token] -= amount;
        rewardCredit[token][keeper] += amount;
        if (isStart) {
            emit AuctionStartRewarded(auctionId, keeper, amount);
        } else {
            emit AuctionSettleRewarded(auctionId, keeper, amount);
        }
    }

    function _quoteReward(
        uint256 basisAmount,
        uint16 rewardBps
    ) private view returns (uint256) {
        if (!rewardConfig.enabled || basisAmount == 0 || rewardBps == 0) return 0;
        uint256 reward = basisAmount.bps(rewardBps);
        if (reward < rewardConfig.minReward) reward = rewardConfig.minReward;
        if (rewardConfig.maxReward != 0 && reward > rewardConfig.maxReward) {
            reward = rewardConfig.maxReward;
        }
        return reward;
    }
}
