// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IGoemonCore {
    // Events
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event TradeIntentSubmitted(
        address indexed user,
        uint256 amount,
        string intentType,
        bytes32 signature
    );
    event LockFunds(address indexed user, uint256 amount, uint256 maturityDate);

    // Functions
    function permitDeposit(
        address token,
        uint160 amount,
        uint256 deadline,
        uint48 nonce,
        bytes calldata signature
    ) external;

    // function deposit(uint256 amount) external;

    function withdraw(uint256 amount) external;

    function submitTradeIntentWithSignature(
        uint256 amount,
        string calldata intentType,
        bytes memory signature
    ) external;

    function lockFundsUntilMaturity(
        uint256 amount,
        uint256 maturityDate
    ) external;

    function getUserBalance() external view returns (uint256);

    function getLockedFunds() external view returns (uint256);

    function getUserYield() external view returns (uint256);
}
