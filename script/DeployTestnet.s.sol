// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "../src/UserManager.sol";

contract DeployUserManager is Script {
    // address public constant USDC_ADDRESS = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238; // Sepolia USDC
    address public constant USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // Ethereum USDC
    address public constant POWER_TRADE_ADDRESS = 0x3f9a360F544E8e13e1789A69511d439426f5f0af; // Replace with actual address
    address public constant PERMIT2_ADDRESS = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    uint256 public constant INITIAL_FEE = 1e3; // Example fee in wei (adjust as needed)

    function run() external {
        // Start broadcasting the transaction
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy UserManager contract
        UserManager userManager = new UserManager();
        userManager.initialize(USDC_ADDRESS, POWER_TRADE_ADDRESS, PERMIT2_ADDRESS);
        console2.log("UserManager deployed to:", address(userManager));

        // Set the initial fee
        userManager.setFee(INITIAL_FEE);
        console2.log("Initial fee set to:", INITIAL_FEE);

        // End broadcasting the transaction
        vm.stopBroadcast();
        
    }
}