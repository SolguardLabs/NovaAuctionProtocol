// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { NovaAuctionHouse } from "../../src/core/NovaAuctionHouse.sol";
import { NovaLiquidationEngine } from "../../src/core/NovaLiquidationEngine.sol";
import { NovaVault } from "../../src/core/NovaVault.sol";
import { NovaConfigurator } from "../../src/governance/NovaConfigurator.sol";
import { NovaAuctionLens } from "../../src/lens/NovaAuctionLens.sol";
import { NovaTypes } from "../../src/libraries/NovaTypes.sol";
import { NovaPriceOracle } from "../../src/oracle/NovaPriceOracle.sol";
import { NovaCollateralToken } from "../../src/tokens/NovaCollateralToken.sol";
import { NovaStable } from "../../src/tokens/NovaStable.sol";
import { NovaTreasury } from "../../src/treasury/NovaTreasury.sol";
import { Test } from "forge-std/Test.sol";

abstract contract NovaTestBase is Test {
    address internal owner = address(this);
    address internal borrower = address(0xB0B);
    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B2);
    address internal recipient = address(0xCAFE);

    NovaConfigurator internal configurator;
    NovaPriceOracle internal oracle;
    NovaStable internal stable;
    NovaTreasury internal treasury;
    NovaVault internal vault;
    NovaAuctionHouse internal auctionHouse;
    NovaLiquidationEngine internal liquidationEngine;
    NovaAuctionLens internal lens;
    NovaCollateralToken internal collateral;

    uint256 internal constant COLLATERAL_UNIT = 1e18;
    uint256 internal constant DEBT_UNIT = 1e18;
    uint256 internal constant AUCTION_COLLATERAL = 1000e18;
    uint256 internal constant DEBT_TARGET = 1000e18;

    function setUp() public virtual {
        vm.warp(1_700_000_000);

        configurator = new NovaConfigurator(owner);
        oracle = new NovaPriceOracle(owner);
        stable = new NovaStable(owner);
        treasury = new NovaTreasury(configurator);
        vault = new NovaVault(configurator);
        auctionHouse = new NovaAuctionHouse(configurator);
        liquidationEngine = new NovaLiquidationEngine(configurator);
        lens = new NovaAuctionLens(configurator, auctionHouse);
        collateral = new NovaCollateralToken("Nova Collateral ETH", "nETH", 18, owner);

        configurator.configureAddresses(
            address(stable),
            address(treasury),
            address(oracle),
            address(auctionHouse),
            address(vault),
            address(liquidationEngine)
        );
        configurator.setRole(configurator.AUCTIONEER_ROLE(), address(liquidationEngine), true);
        configurator.setRole(configurator.KEEPER_ROLE(), owner, true);
        stable.setMinter(owner, true);
        stable.setMinter(address(vault), true);

        oracle.setPrice(address(collateral), 2000e8, 8, 30 days, "nETH/USD");
        configurator.setRiskConfig(
            address(collateral),
            NovaTypes.RiskConfig({
                loanToValueBps: 7000,
                liquidationThresholdBps: 8000,
                liquidationPenaltyBps: 1000,
                protocolPenaltyShareBps: 1000,
                minDebt: uint96(1e18),
                maxDebt: uint96(1_000_000e18),
                maxCollateral: uint96(10_000e18),
                heartbeat: uint64(30 days),
                enabled: true
            })
        );
    }

    function _startAuction() internal returns (uint256 auctionId) {
        return _startAuction(AUCTION_COLLATERAL, DEBT_TARGET);
    }

    function _startAuction(
        uint256 collateralAmount,
        uint256 debtTarget
    ) internal returns (uint256 auctionId) {
        collateral.mint(owner, collateralAmount);
        collateral.approve(address(auctionHouse), collateralAmount);
        auctionId = auctionHouse.startAuction(
            borrower, address(collateral), address(stable), collateralAmount, debtTarget
        );
    }

    function _fundBidder(
        address bidder,
        uint256 amount
    ) internal {
        stable.mint(bidder, amount);
        vm.prank(bidder);
        stable.approve(address(auctionHouse), type(uint256).max);
    }

    function _bid(
        address bidder,
        uint256 auctionId,
        uint256 amount
    ) internal returns (NovaTypes.BidReceipt memory receipt) {
        _fundBidder(bidder, amount);
        vm.prank(bidder);
        receipt = auctionHouse.bid(auctionId, amount, bidder);
    }

    function _auction(
        uint256 auctionId
    ) internal view returns (NovaTypes.Auction memory) {
        return auctionHouse.getAuction(auctionId);
    }

    function _warpToNearClose(
        uint256 auctionId
    ) internal {
        NovaTypes.Auction memory auction = _auction(auctionId);
        vm.warp(auction.endTime - 60);
    }

    function _warpAfterEnd(
        uint256 auctionId
    ) internal {
        NovaTypes.Auction memory auction = _auction(auctionId);
        vm.warp(auction.endTime + 1);
    }
}
