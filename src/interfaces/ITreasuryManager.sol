// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface ITreasuryManager {
    // Events
    event TreasuryUpdated(address newTreasury);

    // Custom Errors
    error Unauthorized();

    // Function Signatures
    function setTreasury(address newTreasury) external;
}
