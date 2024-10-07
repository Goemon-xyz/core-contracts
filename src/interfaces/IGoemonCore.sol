// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IGoemonCore {
    struct Intent {
        uint256 amount;
        string intentType;
        uint256 timestamp;
        bool isExecuted;
    }

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event IntentSubmitted(
        address indexed user,
        uint256 amount,
        string intentType
    );
    event IntentSettled(address indexed user, uint256 intentIndex, int256 pnl);
    event TreasuryUpdated(address newTreasury);

    function permitDeposit(
        uint160 amount,
        uint256 deadline,
        uint48 nonce,
        bytes calldata signature
    ) external;

    function withdraw(uint256 amount) external;

    function submitIntent(uint256 amount, string calldata intentType) external;

    function settleIntent(
        address user,
        uint256 intentIndex,
        int256 pnl
    ) external;

    function batchSettleIntents(
        address[] calldata users,
        uint256[] calldata intentIndices,
        int256[] calldata pnls
    ) external;

    function getUserBalance(
        address user
    ) external view returns (uint256 availableBalance, uint256 lockedBalance);

    function getUserIntents(
        address user
    ) external view returns (Intent[] memory);

    function setTreasury(address newTreasury) external;
}
