// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "../src/UserManager.sol";
import "../src/TradeExecutor.sol";
import "../src/IntentsEngine.sol";

contract DeployAllContracts is Script {
    address public constant USDC_ADDRESS = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;

    function run() external {
        // Start broadcasting the transaction
        vm.startBroadcast();

        // 1. Deploy UserManager contract
        UserManager userManager = new UserManager();
        userManager.initialize(USDC_ADDRESS);
        console2.log("UserManager deployed to:", address(userManager));

        // 2. Deploy IntentsEngine contract (depends on UserManager)
        IntentsEngine intentsEngine = new IntentsEngine();
        intentsEngine.initialize(address(userManager));
        console2.log("IntentsEngine deployed to:", address(intentsEngine));

        // 3. Deploy TradeExecutor contract (depends on UserManager and IntentsEngine)
        TradeExecutor tradeExecutor = new TradeExecutor();
        tradeExecutor.initialize(
            address(userManager),
            address(intentsEngine)
        );
        console2.log("TradeExecutor deployed to:", address(tradeExecutor));

        // Set necessary contract dependencies
        intentsEngine.setTradeExecutor(address(tradeExecutor));
        console2.log("Set TradeExecutor in IntentsEngine");

        userManager.setIntentsEngine(address(intentsEngine));
        console2.log("Set IntentsEngine in UserManager");
        userManager.setTradeExecutor(address(tradeExecutor));
        console2.log("Set TradeExecutor in UserManager");

        // End broadcasting the transaction
        vm.stopBroadcast();
    }
}