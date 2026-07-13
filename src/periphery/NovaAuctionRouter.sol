// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IERC20 } from "../interfaces/IERC20.sol";
import { INovaAuctionHouse } from "../interfaces/INovaAuctionHouse.sol";
import { INovaAuctionRouter } from "../interfaces/INovaAuctionRouter.sol";
import { NovaTypes } from "../libraries/NovaTypes.sol";
import { SafeTransferLib } from "../libraries/SafeTransferLib.sol";
import { ReentrancyGuard } from "../security/ReentrancyGuard.sol";

contract NovaAuctionRouter is INovaAuctionRouter, ReentrancyGuard {
    using SafeTransferLib for address;

    error SlippageExceeded(uint256 requiredBid, uint256 maxRequiredBid);
    error NotWinner();
    error InvalidAuction();

    INovaAuctionHouse public immutable auctionHouse;

    mapping(uint256 => address) public routedWinner;
    mapping(address => mapping(address => uint256)) public routedBidCredit;

    event RoutedBid(
        uint256 indexed auctionId,
        address indexed bidder,
        uint256 amount,
        uint256 maxRequiredBid,
        uint256 observedRequiredBid
    );
    event RoutedSettleAndClaim(
        uint256 indexed auctionId, address indexed caller, address indexed recipient, uint256 amount
    );

    constructor(
        INovaAuctionHouse auctionHouse_
    ) {
        auctionHouse = auctionHouse_;
    }

    function bidWithMaxFloor(
        uint256 auctionId,
        uint256 amount,
        uint256 maxRequiredBid
    ) external nonReentrant returns (NovaTypes.BidReceipt memory receipt) {
        NovaTypes.Auction memory auction = auctionHouse.getAuction(auctionId);
        if (auction.id == 0) revert InvalidAuction();
        uint256 required = auctionHouse.requiredBid(auctionId);
        if (required > maxRequiredBid) revert SlippageExceeded(required, maxRequiredBid);

        address previousRoutedWinner = routedWinner[auctionId];
        uint256 previousRoutedBid = auction.winner == address(this)
            && previousRoutedWinner != address(0)
            ? auction.winningBid
            : 0;

        auction.debtToken.safeTransferFrom(msg.sender, address(this), amount);
        IERC20(auction.debtToken).approve(address(auctionHouse), 0);
        IERC20(auction.debtToken).approve(address(auctionHouse), amount);
        receipt = auctionHouse.bid(auctionId, amount, address(this));
        routedWinner[auctionId] = msg.sender;

        if (previousRoutedBid != 0) {
            uint256 pulled = auctionHouse.withdrawBidCredit(auction.debtToken, address(this));
            routedBidCredit[auction.debtToken][previousRoutedWinner] += pulled;
        }
        emit RoutedBid(auctionId, msg.sender, amount, maxRequiredBid, required);
    }

    function settleAndClaim(
        uint256 auctionId,
        address recipient
    ) external nonReentrant returns (uint256 amount) {
        NovaTypes.Auction memory auction = auctionHouse.getAuction(auctionId);
        if (auction.id == 0) revert InvalidAuction();
        if (auction.winner != address(this) || routedWinner[auctionId] != msg.sender) {
            revert NotWinner();
        }
        auctionHouse.settle(auctionId);
        amount = auctionHouse.claimCollateral(auctionId, recipient);
        emit RoutedSettleAndClaim(auctionId, msg.sender, recipient, amount);
    }

    function withdrawBidCredit(
        address debtToken,
        address recipient
    ) external nonReentrant returns (uint256 amount) {
        amount = routedBidCredit[debtToken][msg.sender];
        if (amount == 0) return 0;
        routedBidCredit[debtToken][msg.sender] = 0;
        debtToken.safeTransfer(recipient, amount);
    }
}
