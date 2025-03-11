// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/UserManager.sol";

contract DeployUserManager is Script {
    
    address public constant USDC_ADDRESS = 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d; // Arbitrum Sepolia USDC
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