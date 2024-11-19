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

    uint256 public constant MAX_BATCH_SIZE = 100;

    // Custom Errors are now defined in the interface

    /// @notice Initialize the TradeExecutor contract
    /// @param _userManager The address of the UserManager contract
    /// @param _intentsEngine The address of the IntentsEngine contract
    function initialize(
        address _userManager,
        address _intentsEngine
    ) external initializer {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        __Pausable_init();

        if (_userManager == address(0) || _intentsEngine == address(0)) {
            revert InvalidAddress();
        }

        userManager = IUserManager(_userManager);
        intentsEngine = IIntentsEngine(_intentsEngine);
    }

    /// @notice Settle a single intent
    /// @param user The address of the user
    /// @param intentIndex The index of the intent
    /// @param pnl The profit or loss from the intent
    function settleIntent(
        address user,
        uint256 intentIndex,
        int256 pnl
    ) external onlyOwner nonReentrant whenNotPaused {
        _settleIntent(user, intentIndex, pnl);
    }

    /// @notice Batch settle multiple intents
    /// @param allUsers Array of user addresses
    /// @param intentIndices Array of intent indices corresponding to each user
    /// @param pnls Array of pnl values corresponding to each intent
    function batchSettleIntents(
        address[] calldata allUsers,
        uint256[] calldata intentIndices,
        int256[] calldata pnls
    ) external onlyOwner nonReentrant whenNotPaused {
        uint256 length = allUsers.length;

        if (length != intentIndices.length || length != pnls.length) {
            revert ArrayLengthMismatch();
        }

        if (length > MAX_BATCH_SIZE) {
            revert BatchSizeExceedsLimit();
        }

        for (uint256 i = 0; i < length; ) {
            _settleIntent(allUsers[i], intentIndices[i], pnls[i]);
            unchecked {
                i++;
            }
        }
    }

    /// @notice Internal function to settle a single intent
    /// @param user The address of the user
    /// @param intentIndex The index of the intent
    /// @param pnl The profit or loss from the intent
    function _settleIntent(
        address user,
        uint256 intentIndex,
        int256 pnl
    ) internal {
        IIntentsEngine.Intent[] memory intents = intentsEngine.getUserIntents(user);

        if (intentIndex >= intents.length || intents[intentIndex].isExecuted) {
            revert InvalidIntent();
        }

        uint256 lockedAmount = intents[intentIndex].amount;

        // Unlock the user's locked balance
        userManager.unlockUserBalance(user, lockedAmount);

        int256 finalAmount = int256(lockedAmount) + pnl;

        // Adjust the user's synthetic balance
        userManager.adjustUserBalance(user, finalAmount);

        // Update the net PnL in UserManager
        userManager.updateNetPnl(-pnl);

        // Mark the intent as executed
        intentsEngine.markIntentAsExecuted(user, intentIndex);

        emit IntentSettled(user, intentIndex, pnl);
    }
}