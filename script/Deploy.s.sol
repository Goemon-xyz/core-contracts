// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.26;

// import "forge-std/Script.sol";
// import "../src/UserManager.sol";
// import "../src/TradeExecutor.sol";
// import "../src/TreasuryManager.sol";
// import "../src/IntentsEngine.sol";

// contract DeployAllContracts is Script {
//     // Declare addresses for tokens and dependencies
//     address tokenAddress = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // Replace with actual token address
//     address permit2Address = 0x000000000022D473030F116dDEE9F6B43aC78BA3; // Replace with actual Permit2 address
//     address treasuryAddress = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; // Replace with actual treasury address
//     uint256 thresholdAmount = 100000000; // Threshold set to 100 USDC

//     function run() external {
//         // Start broadcasting the transaction
//         vm.startBroadcast();

//         // 1. Deploy UserManager contract
//         UserManager userManager = new UserManager();
//         userManager.initialize(tokenAddress, permit2Address, thresholdAmount);
//         console2.log("UserManager deployed to:", address(userManager));

//         // 2. Deploy IntentsEngine contract (depends on UserManager)
//         IntentsEngine intentsEngine = new IntentsEngine();
//         intentsEngine.initialize(address(userManager));
//         console2.log("IntentsEngine deployed to:", address(intentsEngine));

//         // 3. Deploy TradeExecutor contract (depends on UserManager and IntentsEngine)
//         TradeExecutor tradeExecutor = new TradeExecutor();
//         tradeExecutor.initialize(
//             address(userManager),
//             address(intentsEngine),
//             treasuryAddress,
//             tokenAddress
//         );
//         console2.log("TradeExecutor deployed to:", address(tradeExecutor));

//         // 4. Deploy TreasuryManager contract
//         TreasuryManager treasuryManager = new TreasuryManager();
//         treasuryManager.initialize(treasuryAddress);
//         console2.log("TreasuryManager deployed to:", address(treasuryManager));

//         // Set necessary contract dependencies
//         // Set IntentsEngine dependencies
//         intentsEngine.setTradeExecutor(address(tradeExecutor));
//         console2.log("Set TradeExecutor in IntentsEngine");

//         // End broadcasting the transaction
//         vm.stopBroadcast();
//     }
// }