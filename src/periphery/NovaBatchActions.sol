// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { INovaAuctionHouse } from "../interfaces/INovaAuctionHouse.sol";
import { NovaTypes } from "../libraries/NovaTypes.sol";
import { ReentrancyGuard } from "../security/ReentrancyGuard.sol";

contract NovaBatchActions is ReentrancyGuard {
    error LengthMismatch();

    INovaAuctionHouse public immutable auctionHouse;

    event BatchSettled(address indexed caller, uint256 attempted, uint256 succeeded);
    event BatchCancelled(address indexed caller, uint256 attempted, uint256 succeeded);

    constructor(
        INovaAuctionHouse auctionHouse_
    ) {
        auctionHouse = auctionHouse_;
    }

    function batchSettle(
        uint256[] calldata auctionIds
    ) external nonReentrant returns (uint256 succeeded) {
        for (uint256 i = 0; i < auctionIds.length; i++) {
            try auctionHouse.settle(auctionIds[i]) returns (NovaTypes.CollateralClaim memory) {
                succeeded += 1;
            } catch { }
        }
        emit BatchSettled(msg.sender, auctionIds.length, succeeded);
    }

    function batchCancel(
        uint256[] calldata auctionIds,
        string[] calldata reasons
    ) external nonReentrant returns (uint256 succeeded) {
        if (auctionIds.length != reasons.length) revert LengthMismatch();
        for (uint256 i = 0; i < auctionIds.length; i++) {
            try auctionHouse.cancel(auctionIds[i], reasons[i]) {
                succeeded += 1;
            } catch { }
        }
        emit BatchCancelled(msg.sender, auctionIds.length, succeeded);
    }

    function previewRequiredBids(
        uint256[] calldata auctionIds
    ) external view returns (uint256[] memory cachedRequired, uint256[] memory trueRequired) {
        cachedRequired = new uint256[](auctionIds.length);
        trueRequired = new uint256[](auctionIds.length);
        for (uint256 i = 0; i < auctionIds.length; i++) {
            try auctionHouse.requiredBid(auctionIds[i]) returns (uint256 required) {
                cachedRequired[i] = required;
            } catch {
                cachedRequired[i] = 0;
            }
            try auctionHouse.trueRequiredBid(auctionIds[i]) returns (uint256 required) {
                trueRequired[i] = required;
            } catch {
                trueRequired[i] = 0;
            }
        }
    }

    function previewAuctions(
        uint256[] calldata auctionIds
    ) external view returns (NovaTypes.Auction[] memory auctions) {
        auctions = new NovaTypes.Auction[](auctionIds.length);
        for (uint256 i = 0; i < auctionIds.length; i++) {
            try auctionHouse.getAuction(auctionIds[i]) returns (NovaTypes.Auction memory auction) {
                auctions[i] = auction;
            } catch { }
        }
    }

    function firstSettleable(
        uint256[] calldata auctionIds
    ) external view returns (uint256 auctionId, bool found) {
        for (uint256 i = 0; i < auctionIds.length; i++) {
            NovaTypes.Auction memory auction = auctionHouse.getAuction(auctionIds[i]);
            if (
                auction.id != 0 && auction.status == NovaTypes.AuctionStatus.Active
                    && auction.winner != address(0) && block.timestamp >= auction.endTime
            ) {
                return (auction.id, true);
            }
        }
    }
}
