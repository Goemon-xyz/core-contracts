// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IUserManager {
    // Events
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event OrderFilled(address indexed user, uint256 orderAmount);
    event OrderClosed(address indexed user, uint256 orderAmount);
    event BatchWithdraw(address[] users, uint256[] amounts);

    // Custom Errors
    error InsufficientBalance();
    error InvalidAmount();
    error Unauthorized();
    error InvalidToken();
    error InvalidAddress();
    error PermitExpired();
    error AmountMismatch();
    error WithdrawFailed();
    error NoFeesToCollect();
    error FeeCollectionFailed();

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
     * @notice Close an order for a user
     * @param user The address of the user
     * @param orderAmount The amount of the order
     */
    function closeOrder(address user, uint256 orderAmount) external;

    /**
     * @notice Withdraw funds to a single user
     * @param user The address of the user
     * @param amount The amount to withdraw
     */
    function withdraw(address user, uint256 amount) external;

    /**
     * @notice Batch withdraw funds to multiple users
     * @param users The addresses of the users
     * @param amounts The amounts to withdraw to each user
     * @param totalAmount The total amount to withdraw
     */
    function batchWithdraw(address[] calldata users, uint256[] calldata amounts, uint256 totalAmount) external;

    /**
     * @notice Collect accumulated fees
     */
    function collectFees() external;

    /**
     * @notice Get the contract's token balance minus collected fees
     * @return The token balance of the contract minus collected fees
     */
    function getBalance() external view returns (uint256);

    /**
     * @notice Get the total collected fees
     * @return The total collected fees in the contract
     */
    function getCollectedFees() external view returns (uint256);

    /**
     * @notice Set the powerTrade account address
     * @param _powerTrade The address of the powerTrade account
     */
    function setPowerTrade(address _powerTrade) external;

    /**
     * @notice Pause the contract
     */
    function pause() external;

    /**
     * @notice Unpause the contract
     */
    function unpause() external;
}