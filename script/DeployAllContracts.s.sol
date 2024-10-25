// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "../src/UserManager.sol";
import "../src/TradeExecutor.sol";
import "../src/TreasuryManager.sol";
import "../src/IntentsEngine.sol";

contract DeployAllContracts is Script {
    // Declare addresses for tokens and dependencies
    address tokenAddress = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238; // Replace with actual token address
    address permit2Address = 0x000000000022D473030F116dDEE9F6B43aC78BA3; // Replace with actual Permit2 address
    address treasuryAddress = 0x5E1Bd63682ddec4dFe7b99396f30166Eb537d152; // Replace with actual treasury address

    function run() external {
        // Start broadcasting the transaction
        vm.startBroadcast();

        // 1. Deploy UserManager contract
        UserManager userManager = new UserManager();
        userManager.initialize(tokenAddress, permit2Address);
        console2.log("UserManager deployed to:", address(userManager));

        // 2. Deploy IntentsEngine contract (depends on UserManager)
        IntentsEngine intentsEngine = new IntentsEngine();
        intentsEngine.initialize(address(userManager));
        console2.log("IntentsEngine deployed to:", address(intentsEngine));

        // 3. Deploy TradeExecutor contract (depends on UserManager and IntentsEngine)
        TradeExecutor tradeExecutor = new TradeExecutor();
        tradeExecutor.initialize(address(userManager), address(intentsEngine), treasuryAddress);
        console2.log("TradeExecutor deployed to:", address(tradeExecutor));

        // 4. Deploy TreasuryManager contract
        TreasuryManager treasuryManager = new TreasuryManager();
        treasuryManager.initialize(treasuryAddress);
        console2.log("TreasuryManager deployed to:", address(treasuryManager));

        // Set necessary contract dependencies
        // Set IntentsEngine dependencies
        intentsEngine.setTradeExecutor(address(tradeExecutor));
        console2.log("Set TradeExecutor in IntentsEngine");

        // Set IntentsEngine in UserManager after deploying IntentsEngine
        userManager.setIntentsEngine(address(intentsEngine));
        console2.log("Set IntentsEngine in UserManager");

        // Set TradeExecutor in UserManager after deploying TradeExecutor
        userManager.setTradeExecutor(address(tradeExecutor));
        console2.log("Set TradeExecutor in UserManager");

        // End broadcasting the transaction
        vm.stopBroadcast();
    }
}
