// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "../src/UserManager.sol";
import "../src/TradeExecutor.sol";
import "../src/TreasuryManager.sol";
import "../src/IntentsEngine.sol";

contract DeployAllContracts is Script {
    // Declare addresses for tokens and dependencies
    address tokenAddress = 0x81778d52EBd0CC38BC84B8Ec15051ade2EEAc814; // Replace with actual token address
    address permit2Address = 0xFb890A782737F5Fc06bCF868306905501c5C3A80; // Replace with actual Permit2 address
    address treasuryAddress = 0x4665badb4b4734AfADFa28125432062d9e859089; // Replace with actual treasury address
    uint256 thresholdAmount = 100000000; // Threshold set to 100 USDC

    function run() external {
        // Start broadcasting the transactionQ
        vm.startBroadcast();

        //TO DO - MODIFY USER MANAGER INITIALIZATION ADDRESSES CORRECTLY
        // 1. Deploy UserManager contract
        UserManager userManager = new UserManager();
        userManager.initialize(tokenAddress, permit2Address, thresholdAmount);
        console2.log("UserManager deployed to:", address(userManager));

        // 2. Deploy IntentsEngine contract (depends on UserManager)
        IntentsEngine intentsEngine = new IntentsEngine();
        intentsEngine.initialize(address(userManager));
        console2.log("IntentsEngine deployed to:", address(intentsEngine));

        // 3. Deploy TradeExecutor contract (depends on UserManager and IntentsEngine)
        TradeExecutor tradeExecutor = new TradeExecutor();
        tradeExecutor.initialize(
            address(userManager),
            address(intentsEngine),
            treasuryAddress,
            tokenAddress
        );
        console2.log("TradeExecutor deployed to:", address(tradeExecutor));

        // 4. Deploy TreasuryManager contract
        TreasuryManager treasuryManager = new TreasuryManager();
        treasuryManager.initialize(treasuryAddress);
        console2.log("TreasuryManager deployed to:", address(treasuryManager));

        // Set necessary contract dependencies
        // Set IntentsEngine dependencies
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