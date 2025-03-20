// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/UserManager.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract UpgradeUserManager is Script {

    address public constant EXISTING_PROXY_ADDRESS = 0x46a3A1c66DcaEFE42045d3D16D391689b9F68812; //testnet sepolia
    // address public constant EXISTING_PROXY_ADDRESS = 0xb7A73b686578a2994b65a57023784Be1304cEAd1; //mainnet ethereum
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy new implementation
        UserManager newImplementation = new UserManager();
        console2.log("New implementation deployed to:", address(newImplementation));

        // Get the proxy instance as UUPSUpgradeable
        UUPSUpgradeable proxy = UUPSUpgradeable(EXISTING_PROXY_ADDRESS);
        // Upgrade the proxy to new implementation
        // Using the correct method for UUPSUpgradeable
        proxy.upgradeToAndCall(address(newImplementation), "");
        console2.log("Proxy upgraded to new implementation");

        vm.stopBroadcast();
}
}