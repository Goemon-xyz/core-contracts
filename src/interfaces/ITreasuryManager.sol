// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface ITreasuryManager {
    event TreasuryUpdated(address newTreasury);

    function setTreasury(address newTreasury) external;
}
