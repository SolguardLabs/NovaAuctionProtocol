// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { NovaAuctionHouse } from "../src/core/NovaAuctionHouse.sol";
import { NovaLiquidationEngine } from "../src/core/NovaLiquidationEngine.sol";
import { NovaVault } from "../src/core/NovaVault.sol";
import { NovaConfigurator } from "../src/governance/NovaConfigurator.sol";
import { NovaAuctionLens } from "../src/lens/NovaAuctionLens.sol";
import { NovaPriceOracle } from "../src/oracle/NovaPriceOracle.sol";
import { NovaStable } from "../src/tokens/NovaStable.sol";
import { NovaTreasury } from "../src/treasury/NovaTreasury.sol";
import { Script } from "forge-std/Script.sol";

contract DeployNova is Script {
    function run() external {
        address deployer = vm.envOr("DEPLOYER", msg.sender);

        vm.startBroadcast();
        NovaConfigurator configurator = new NovaConfigurator(deployer);
        NovaPriceOracle oracle = new NovaPriceOracle(deployer);
        NovaStable stable = new NovaStable(deployer);
        NovaTreasury treasury = new NovaTreasury(configurator);
        NovaVault vault = new NovaVault(configurator);
        NovaAuctionHouse auctionHouse = new NovaAuctionHouse(configurator);
        NovaLiquidationEngine liquidationEngine = new NovaLiquidationEngine(configurator);
        new NovaAuctionLens(configurator, auctionHouse);

        configurator.configureAddresses(
            address(stable),
            address(treasury),
            address(oracle),
            address(auctionHouse),
            address(vault),
            address(liquidationEngine)
        );
        configurator.setRole(configurator.AUCTIONEER_ROLE(), address(liquidationEngine), true);
        stable.setMinter(address(vault), true);
        vm.stopBroadcast();
    }
}
