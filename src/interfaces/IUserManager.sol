// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@pendle/core-v2/contracts/interfaces/IPAllActionTypeV3.sol"; // Import for TokenInput and TokenOutput
import "permit2/src/interfaces/ISignatureTransfer.sol"; // Ensure this import is present

interface IUserManager {
    // Events
    event Deposit(address indexed from, uint256 indexed amount);
    event Withdraw(address indexed user, uint256 amount);
    event OrderFilled(address indexed user, uint256 orderAmount);
    event OrderClosed(address indexed user, uint256 orderAmount);
    event BatchWithdraw(
        address[] users, 
        uint256[] amounts,
        uint256[] amountsAfterFee
    );
    event PermitDeposit(address indexed user, uint256 amount, address to);
    event PendlePermitBatchDeposit(
        address indexed user,
        uint256 totalAmount,
        uint256 yieldAmount,
        address indexed to
    );

    // Custom Errors
    error InsufficientBalance();
    error InvalidAmount();
    error Unauthorized();
    error InvalidToken();
    error InvalidAddress();
    error PermitExpired();
    error AmountMismatch();
    error NoFeesToCollect();
    error FeeCollectionFailed();

    // Function Signatures
    function deposit(address user, uint256 amount) external;
    function permitDeposit(
        uint256 amount,
        uint256 deadline,
        uint256 nonce,
        bytes calldata permitTransferFrom,
        bytes calldata signature
    ) external;
    function withdraw(address user, uint256 amount) external;
    function batchWithdraw(address[] calldata users, uint256[] calldata amounts) external;
    function collectFees() external;
    function setPowerTrade(address _powerTrade) external;
    function setFee(uint256 _fee) external;
    function setMinimumWithdrawAmount(uint256 _minimumWithdrawAmount) external;
    function setUseFeesForWithdrawals(bool _useFees) external;
    function setWhitelist(address user, bool isWhitelisted) external;
    function pause() external;
    function unpause() external;
    function getBalance() external view returns (uint256);
    function getCollectedFees() external view returns (uint256);
    function permitDepositBatchAndSwap(
        uint256 totalAmount,
        uint256 yieldAmount,
        ISignatureTransfer.PermitBatchTransferFrom calldata _permit,
        bytes calldata _signature,
        address to,
        bytes calldata transactionData
    ) external;
}