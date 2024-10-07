// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface ITradeExecutor {
    event IntentSettled(address indexed user, uint256 intentIndex, int256 pnl);

    function settleIntent(
        address user,
        uint256 intentIndex,
        int256 pnl
    ) external;

    function batchSettleIntents(
        address[] calldata allUsers,
        uint256[] calldata intentIndices,
        int256[] calldata pnls
    ) external;
}
