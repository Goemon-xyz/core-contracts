// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface ITradeExecutor {
    // Events
    event IntentSettled(address indexed user, uint256 intentIndex, int256 pnl);

    // Custom Errors
    error InvalidIntent();
    error FinalAmountNegative();
    error ArrayLengthMismatch();
    error BatchSizeExceedsLimit();
    error InvalidAddress();

    // Function Signatures

    /**
     * @notice Settle a single intent
     * @param user The address of the user
     * @param intentIndex The index of the intent
     * @param pnl The profit or loss from the intent
     */
    function settleIntent(
        address user,
        uint256 intentIndex,
        int256 pnl
    ) external;

    /**
     * @notice Batch settle multiple intents
     * @param allUsers Array of user addresses
     * @param intentIndices Array of intent indices corresponding to each user
     * @param pnls Array of pnl values corresponding to each intent
     */
    function batchSettleIntents(
        address[] calldata allUsers,
        uint256[] calldata intentIndices,
        int256[] calldata pnls
    ) external;
}
