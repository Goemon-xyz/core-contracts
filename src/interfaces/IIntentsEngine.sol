// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IIntentsEngine {
    struct Intent {
        uint256 amount;
        string intentType;
        uint256 timestamp;
        bool isExecuted;
    }

    event IntentSubmitted(
        address indexed user,
        uint256 amount,
        string intentType
    );

    function submitIntent(uint256 amount, string calldata intentType) external;

    function getUserIntents(
        address user
    ) external view returns (Intent[] memory);

    function setMaxIntentsPerUser(uint256 newMax) external;

    function markIntentAsExecuted(address user, uint256 intentIndex) external;
}
