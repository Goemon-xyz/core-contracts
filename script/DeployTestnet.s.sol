// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/UserManager.sol";

contract DeployUserManager is Script {
    // address public constant USDC_ADDRESS = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238; // Sepolia USDC
    address public constant USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // Ethereum USDC
    address public constant POWER_TRADE_ADDRESS = 0x3f9a360F544E8e13e1789A69511d439426f5f0af;
    address public constant PERMIT2_ADDRESS = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    // uint256 public constant INITIAL_FEE = 1e3;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy implementation contract
        UserManager implementation = new UserManager();
        console2.log("Implementation deployed to:", address(implementation));

        // Encode initialization data
        bytes memory initData = abi.encodeWithSelector(
            UserManager.initialize.selector,
            USDC_ADDRESS,
            POWER_TRADE_ADDRESS,
            PERMIT2_ADDRESS
        );

        // Deploy proxy contract
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        UserManager userManager = UserManager(address(proxy));
        console2.log("Proxy deployed to:", address(userManager));

        // Set initial fee through proxy
        // userManager.setFee(INITIAL_FEE);
        // console2.log("Initial fee set to:", INITIAL_FEE);

        vm.stopBroadcast();
    }
}