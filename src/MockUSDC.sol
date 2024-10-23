// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUSDC is ERC20 {
    // Constructor to initialize the token with a name, symbol, and initial supply
    constructor() ERC20("USD Coin", "USDC") {
        // Mint initial supply of 1,000,000 USDC to the deployer's address
        // USDC uses 6 decimals, so we multiply by 10^6 to match USDC's precision
        _mint(msg.sender, 1000000 * 10**6);
    }

    // Override decimals to set 6 decimal places (USDC has 6 decimals)
    function decimals() public view virtual override returns (uint8) {
        return 6;
    }

    // Function to mint more USDC for testing purposes
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
