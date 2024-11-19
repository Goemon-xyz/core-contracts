// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IUserManager {
    struct User {
        uint256 syntheticBalance; // pUSDC balance
        uint256 lockedBalance;
    }

    // Events
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event BalanceAdjusted(address indexed user, int256 amount);
    event ExcessFundsWithdrawn(address indexed recipient, uint256 amount);

    // Custom Errors
    error InsufficientBalance();
    error InvalidAmount();
    error Unauthorized();
    error InvalidToken();
    error InsufficientExcessFunds();
    error InvalidAddress();

    // Function Signatures

    /**
     * @notice Deposit synthetic balance
     * @param amount The amount to deposit
     */
    function deposit(uint256 amount) external;

    /**
     * @notice Withdraw synthetic balance
     * @param amount The amount to withdraw
     */
    function withdraw(uint256 amount) external;

    /**
     * @notice Get the balance of a user
     * @param user The address of the user
     * @return syntheticBalance The synthetic balance
     * @return lockedBalance The locked balance
     */
    function getUserBalance(
        address user
    ) external view returns (uint256 syntheticBalance, uint256 lockedBalance);

    /**
     * @notice Lock a user's synthetic balance for intents
     * @param user The address of the user
     * @param amount The amount to lock
     */
    function lockUserBalance(address user, uint256 amount) external;

    /**
     * @notice Unlock a user's previously locked balance
     * @param user The address of the user
     * @param amount The amount to unlock
     */
    function unlockUserBalance(address user, uint256 amount) external;

    /**
     * @notice Adjust a user's synthetic balance based on pnl
     * @param user The address of the user
     * @param amount The pnl amount to adjust (can be positive or negative)
     */
    function adjustUserBalance(address user, int256 amount) external;

    /**
     * @notice Update the net trade funds
     * @param pnlChange The change in PnL to apply
     */
    function updateNetPnl(int256 pnlChange) external;

    /**
     * @notice Withdraw excess synthetic funds as fees
     * @param amount The amount of funds to withdraw
     * @param recipient The address to receive the withdrawn funds
     */
    function withdrawExcessFunds(uint256 amount, address recipient) external;

    /**
     * @notice View the current net pnl
     * @return The current net synthetic balance changes
     */
    function viewNetPnl() external view returns (int256);
}