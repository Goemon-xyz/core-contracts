// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IUserManager {
    struct User {
        uint256 balance;
        uint256 lockedBalance;
    }

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);

    function permitDeposit(
        uint256 amount,
        uint256 deadline,
        uint256 nonce,
        bytes calldata permitTransferFrom,
        bytes calldata signature
    ) external;

    function withdraw(uint256 amount) external;

    function getUserBalance(
        address user
    ) external view returns (uint256 availableBalance, uint256 lockedBalance);

    function lockUserBalance(address user, uint256 amount) external;

    function unlockUserBalance(address user, uint256 amount) external;

    function adjustUserBalance(address user, int256 amount) external;

    function transferFundsToPowerTrade(address user, uint256 amount, address powerTrade) external;

    function getThresholdAmount() external view returns (uint256);
}