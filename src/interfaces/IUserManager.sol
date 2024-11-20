// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IUserManager {
    // Events
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event BalanceAdjusted(address indexed user, int256 amount);

    // Custom Errors
    error InsufficientBalance();
    error InvalidAmount();
    error Unauthorized();
    error InvalidToken();
    error InvalidAddress();
    error PermitExpired();
    error AmountMismatch();
    error PermitTransferFailed();

    // Function Signatures

    /**
     * @notice Deposit synthetic balance using permit
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
     * @notice Update a user's balance based on pnl
     * @param user The address of the user
     * @param pnl The profit or loss to apply
     */
    function updateUserBalance(address user, int256 pnl) external;

    /**
     * @notice Withdraw synthetic balance
     * @param amount The amount to withdraw
     */
    function withdraw(uint256 amount) external;

    /**
     * @notice Get the balance of a user
     * @param user The address of the user
     * @return The user's balance
     */
    function getUserBalance(address user) external view returns (uint256);

    /**
     * @notice Pause the contract
     */
    function pause() external;

    /**
     * @notice Unpause the contract
     */
    function unpause() external;

    /**
     * @notice Batch update users' balances based on pnl
     * @param users The addresses of the users
     * @param pnls The profits or losses to apply
     */
    function batchUpdateUserBalance(address[] calldata users, int256[] calldata pnls) external;
}