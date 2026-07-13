// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { NovaAuctionHouse } from "./core/NovaAuctionHouse.sol";
import { NovaLiquidationEngine } from "./core/NovaLiquidationEngine.sol";
import { NovaVault } from "./core/NovaVault.sol";
import { NovaConfigurator } from "./governance/NovaConfigurator.sol";
import { NovaAuctionLens } from "./lens/NovaAuctionLens.sol";
import { NovaPriceOracle } from "./oracle/NovaPriceOracle.sol";
import { NovaCollateralToken } from "./tokens/NovaCollateralToken.sol";
import { NovaStable } from "./tokens/NovaStable.sol";
import { NovaTreasury } from "./treasury/NovaTreasury.sol";

contract NovaAuctionProtocol {
    NovaConfigurator public immutable configurator;
    NovaPriceOracle public immutable oracle;
    NovaStable public immutable stable;
    NovaTreasury public immutable treasury;
    NovaVault public immutable vault;
    NovaAuctionHouse public immutable auctionHouse;
    NovaLiquidationEngine public immutable liquidationEngine;
    NovaAuctionLens public immutable lens;

    event ProtocolDeployed(
        address configurator,
        address oracle,
        address stable,
        address treasury,
        address vault,
        address auctionHouse,
        address liquidationEngine,
        address lens
    );

    constructor(
        address owner
    ) {
        configurator = new NovaConfigurator(owner);
        oracle = new NovaPriceOracle(owner);
        stable = new NovaStable(owner);
        treasury = new NovaTreasury(configurator);
        vault = new NovaVault(configurator);
        auctionHouse = new NovaAuctionHouse(configurator);
        liquidationEngine = new NovaLiquidationEngine(configurator);
        lens = new NovaAuctionLens(configurator, auctionHouse);

        emit ProtocolDeployed(
            address(configurator),
            address(oracle),
            address(stable),
            address(treasury),
            address(vault),
            address(auctionHouse),
            address(liquidationEngine),
            address(lens)
        );
    }

    function createCollateralToken(
        string memory name,
        string memory symbol,
        uint8 decimals,
        address owner
    ) external returns (NovaCollateralToken token) {
        token = new NovaCollateralToken(name, symbol, decimals, owner);
    }
}
