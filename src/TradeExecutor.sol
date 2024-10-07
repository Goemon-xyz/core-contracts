// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interfaces/ITradeExecutor.sol";
import "./interfaces/IUserManager.sol";
import "./interfaces/IIntentsEngine.sol";

contract TradeExecutor is
    ITradeExecutor,
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    IUserManager public userManager;
    IIntentsEngine public intentsEngine;
    address public treasury;

    uint256 public constant MAX_BATCH_SIZE = 100;

    function initialize(
        address _userManager,
        address _intentsEngine,
        address _treasury
    ) public initializer {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        __Pausable_init();

        require(_userManager != address(0), "Invalid UserManager address");
        require(_intentsEngine != address(0), "Invalid IntentsEngine address");
        require(_treasury != address(0), "Invalid treasury address");

        userManager = IUserManager(_userManager);
        intentsEngine = IIntentsEngine(_intentsEngine);
        treasury = _treasury;
    }

    function settleIntent(
        address user,
        uint256 intentIndex,
        int256 pnl
    ) external onlyOwner nonReentrant whenNotPaused {
        _settleIntent(user, intentIndex, pnl);
    }

    function batchSettleIntents(
        address[] calldata allUsers,
        uint256[] calldata intentIndices,
        int256[] calldata pnls
    ) external onlyOwner nonReentrant whenNotPaused {
        require(
            allUsers.length == intentIndices.length &&
                allUsers.length == pnls.length,
            "Array lengths mismatch"
        );
        require(allUsers.length <= MAX_BATCH_SIZE, "Batch size exceeds limit");

        for (uint256 i = 0; i < allUsers.length; i++) {
            _settleIntent(allUsers[i], intentIndices[i], pnls[i]);
        }
    }

    function _settleIntent(
        address user,
        uint256 intentIndex,
        int256 pnl
    ) internal {
        IIntentsEngine.Intent[] memory intents = intentsEngine.getUserIntents(
            user
        );
        require(intentIndex < intents.length, "Invalid intent index");
        require(!intents[intentIndex].isExecuted, "Intent already executed");

        userManager.unlockUserBalance(user, intents[intentIndex].amount);
        userManager.adjustUserBalance(user, pnl);

        intentsEngine.markIntentAsExecuted(user, intentIndex);

        emit IntentSettled(user, intentIndex, pnl);
    }
}
