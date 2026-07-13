// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface INovaKeeperRewards {
    function notifyAuctionStarted(
        uint256 auctionId,
        address keeper,
        uint256 debtTarget
    ) external;
    function notifyAuctionSettled(
        uint256 auctionId,
        address keeper,
        uint256 winningBid
    ) external;
    function claimReward(
        address token,
        address recipient
    ) external returns (uint256 amount);
    function rewardCredit(
        address token,
        address keeper
    ) external view returns (uint256);
}
