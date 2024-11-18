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
    event ContractBalanceRepaid(address indexed repayer, uint256 amount);
    event ExcessBalanceWithdrawn(uint256 amount);

    // Custom Errors
    error InsufficientBalance();
    error InvalidAmount();
    error Unauthorized();
    error AmountMismatch();
    error PermitExpired();
    error InvalidToken();
    error PermitTransferFailed();

    // Function Signatures

    /**
     * @notice Deposit tokens using Permit2 and convert to synthetic balance (pUSDC)
     * @param amount The amount to deposit
     * @param deadline The permit deadline
     * @param nonce The permit nonce
     * @param permitTransferFrom The permit transfer details
     * @param signature The permit signature
     */
    function permitDeposit(
        uint256 amount,
        uint256 deadline,
        uint256 nonce,
        bytes calldata permitTransferFrom,
        bytes calldata signature
    ) external;

    /**
     * @notice Withdraw real tokens by converting synthetic balance (pUSDC) back to USDC
     * @param amount The amount to withdraw
     */
    function withdraw(uint256 amount) external;

    /**
     * @notice Get the balance of a user
     * @param user The address of the user
     * @return syntheticBalance The synthetic balance (pUSDC)
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
     * @notice Get the difference between real token and synthetic asset
     * @return The difference as an int256
     */
    function getContractBalanceDiff() external view returns (int256);

    /**
     * @notice Repay the contract's balance difference
     * @param amount The amount to repay
     */
    function repayContractBalance(uint256 amount) external;

    /**
     * @notice Withdraw excess real tokens when contractBalanceDiff is positive
     * @param amount The amount to withdraw
     */
    function withdrawExcessBalance(uint256 amount) external;
}