// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface ITradeExecutor {
    struct Trade {
        address user;
        uint256 amount;
        string intentType;
        uint256 timestamp;
        bool isSettled;
    }
    event TradeInitiated(
        address indexed user,
        uint256 indexed nonce,
        uint256 amount,
        string intentType
    );
    event TradeSettled(address indexed user, uint256 indexed nonce);

    function initiateTrade(
        address user,
        uint256 amount,
        string calldata intentType
    ) external returns (uint256);

    function settleTrade(address user, uint256 nonce) external;

    function getTrade(uint256 nonce) external view returns (Trade memory);
}
