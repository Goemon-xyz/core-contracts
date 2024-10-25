// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface ICore {
    struct Trade {
        uint256 amount;
        uint256 timestamp;
        string intentType;
        bool isSettled;
    }

    event TradeIntentSubmitted(address indexed user, uint256 amount, string intentType, uint256 nonce);
    event TradeSettled(address indexed user, uint256 indexed nonce);
    event TradeExecutorUpdated(address newTradeExecutor);
    event TreasuryUpdated(address newTreasury);

    function submitTradeIntent(
        uint256 amount,
        string calldata intentType,
        uint256 deadline,
        uint48 nonce,
        bytes calldata signature
    )
        external;

    function manualTradeIntent(uint256 amount, string calldata intentType) external;

    function settleTrade(address user, uint256 tradeIndex) external;

    function getUserTrades(address user) external view returns (Trade[] memory);

    function setTradeExecutor(address newTradeExecutor) external;

    function setTreasury(address newTreasury) external;
}
