// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
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
    IERC20 public token;

    uint256 public constant MAX_BATCH_SIZE = 100;

    using SafeERC20 for IERC20;

    function initialize(
        address _userManager,
        address _intentsEngine,
        address _treasury,
        address _token
    ) public initializer {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        __Pausable_init();

        require(_userManager != address(0), "Invalid UserManager address");
        require(_intentsEngine != address(0), "Invalid IntentsEngine address");
        require(_treasury != address(0), "Invalid treasury address");
        require(_token != address(0), "Invalid token address");

        userManager = IUserManager(_userManager);
        intentsEngine = IIntentsEngine(_intentsEngine);
        treasury = _treasury;
        token = IERC20(_token);
    }

    function settleIntent(
        address user,
        uint256 intentIndex,
        int256 pnl,
        address powerTrade
    ) external onlyOwner nonReentrant whenNotPaused {
        _settleIntent(user, intentIndex, pnl, powerTrade);
    }

    function batchSettleIntents(
        address[] calldata allUsers,
        uint256[] calldata intentIndices,
        int256[] calldata pnls,
        address powerTrade
    ) external onlyOwner nonReentrant whenNotPaused {
        require(
            allUsers.length == intentIndices.length &&
                allUsers.length == pnls.length,
            "Array lengths mismatch"
        );
        require(allUsers.length <= MAX_BATCH_SIZE, "Batch size exceeds limit");

        for (uint256 i = 0; i < allUsers.length; i++) {
            _settleIntent(allUsers[i], intentIndices[i], pnls[i], powerTrade);
        }
    }

    function _settleIntent(
        address user,
        uint256 intentIndex,
        int256 pnl,
        address powerTrade
    ) internal {
        IIntentsEngine.Intent[] memory intents = intentsEngine.getUserIntents(user);
        require(intentIndex < intents.length, "Invalid intent index");
        require(!intents[intentIndex].isExecuted, "Intent already executed");

        uint256 lockedAmount = intents[intentIndex].amount;

        userManager.unlockUserBalance(user, lockedAmount);
        userManager.adjustUserBalance(user, pnl);

        if (lockedAmount > userManager.getThresholdAmount()) {
            int256 finalAmount = int256(lockedAmount) + pnl;
            require(finalAmount >= 0, "Final amount cannot be negative");

            if(finalAmount > 0) {
            uint256 allowance = token.allowance(powerTrade, address(this));
            require(allowance >= uint256(finalAmount), "Insufficient token allowance");
            token.safeTransferFrom(powerTrade, address(userManager), uint256(finalAmount));
        }
        }

        intentsEngine.markIntentAsExecuted(user, intentIndex);

        emit IntentSettled(user, intentIndex, pnl);
    }
}