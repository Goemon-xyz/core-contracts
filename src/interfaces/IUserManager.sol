// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IUserManager {
    // Structs
    struct WithdrawalRequest {
        uint256 amount;
        uint256 availableAt;
    }

    // Events
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event BalanceAdjusted(address indexed user, int256 amount);
    event OrderFilled(address indexed user, uint256 orderAmount);
    event OrderClosed(address indexed user, int256 pnl);
    event BatchOrderClosed(address[] users, int256[] pnls);
    event WithdrawalInitiated(address indexed user, uint256 amount, uint256 availableAt);

    // Custom Errors
    error InsufficientBalance();
    error InvalidAmount();
    error Unauthorized();
    error InvalidToken();
    error InvalidAddress();
    error PermitExpired();
    error AmountMismatch();
    error PermitTransferFailed();
    error WithdrawalDelayNotPassed();
    error NoWithdrawalToCancel();
    error InvalidWithdrawalRequestIndex();

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
     * @notice Fill an order for a user
     * @param user The address of the user
     * @param orderAmount The amount of the order
     */
    function fillOrder(address user, uint256 orderAmount) external;

    /**
     * @notice Update a user's balance based on pnl
     * @param user The address of the user
     * @param pnl The profit or loss to apply
     */
    function orderClose(address user, int256 pnl) external;

    /**
     * @notice Batch update users' balances based on pnl
     * @param users The addresses of the users
     * @param pnls The profits or losses to apply
     */
    function batchOrderClose(address[] calldata users, int256[] calldata pnls) external;

    /**
     * @notice Withdraw all available synthetic balance
     */
    function withdraw() external;

    /**
     * @notice Initiate a withdrawal
     * @param amount The amount to withdraw
     */
    function initiateWithdrawal(uint256 amount) external;

    /**
     * @notice Cancel a specific withdrawal request
     * @param index The index of the withdrawal request to cancel
     */
    function cancelWithdrawal(uint256 index) external;

    /**
     * @notice Get all withdrawal requests for a user
     * @param user The address of the user
     * @return requests An array of withdrawal requests
     */
    function getWithdrawalRequests(address user) external view returns (WithdrawalRequest[] memory requests);

    /**
     * @notice Get the balance of a user
     * @param user The address of the user
     * @return The user's balance
     */
    function getUserBalance(address user) external view returns (uint256);

    /**
     * @notice Set the powerTrade account address
     * @param _powerTrade The address of the powerTrade account
     */
    function setPowerTrade(address _powerTrade) external;

    /**
     * @notice Set the withdrawal delay
     * @param delay The delay in seconds
     */
    function setWithdrawalDelay(uint256 delay) external;

    /**
     * @notice Pause the contract
     */
    function pause() external;

    /**
     * @notice Unpause the contract
     */
    function unpause() external;
}