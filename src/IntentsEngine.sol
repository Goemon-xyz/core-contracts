// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interfaces/IIntentsEngine.sol";
import "./interfaces/IUserManager.sol";

contract IntentsEngine is
    IIntentsEngine,
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    IUserManager public userManager;
    address public tradeExecutor;

    mapping(address => Intent[]) private userIntents;
    uint256 public maxIntentsPerUser;

    /// @notice Initialize the IntentsEngine contract
    /// @param _userManager The address of the UserManager contract
    function initialize(address _userManager) external initializer {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        __Pausable_init();

        if (_userManager == address(0)) revert InvalidAddress();
        userManager = IUserManager(_userManager);
        maxIntentsPerUser = 10; // Default value, can be changed later
    }

    /// @notice Set the TradeExecutor contract address
    /// @param _tradeExecutor The address of the TradeExecutor contract
    function setTradeExecutor(address _tradeExecutor) external onlyOwner {
        if (_tradeExecutor == address(0)) revert InvalidAddress();
        tradeExecutor = _tradeExecutor;
    }

    /// @notice Submit a new intent
    /// @param amount The amount involved in the intent
    /// @param intentType The type/category of the intent
    /// @param metadata Additional data related to the intent
    function submitIntent(
        uint256 amount,
        string calldata intentType,
        bytes calldata metadata
    ) external nonReentrant whenNotPaused {
        (uint256 syntheticBalance, ) = userManager.getUserBalance(msg.sender);
        
        if (syntheticBalance < amount) revert InsufficientBalance();

        if (userIntents[msg.sender].length >= maxIntentsPerUser) {
            revert MaxIntentsLimitReached();
        }

        userManager.lockUserBalance(msg.sender, amount);

        userIntents[msg.sender].push(
            Intent({
                amount: amount,
                intentType: intentType,
                timestamp: block.timestamp,
                isExecuted: false,
                metadata: metadata
            })
        );

        emit IntentSubmitted(msg.sender, amount, intentType, metadata);
    }

    /// @notice Retrieve all intents for a user
    /// @param user The address of the user
    /// @return An array of the user's intents
    function getUserIntents(
        address user
    ) external view returns (Intent[] memory) {
        return userIntents[user];
    }

    /// @notice Set the maximum number of intents allowed per user
    /// @param newMax The new maximum number of intents
    function setMaxIntentsPerUser(uint256 newMax) external onlyOwner {
        maxIntentsPerUser = newMax;
    }

    /// @notice Mark a specific intent as executed
    /// @param user The address of the user
    /// @param intentIndex The index of the intent in the user's intent array
    function markIntentAsExecuted(address user, uint256 intentIndex) external {
        if (msg.sender != address(userManager) && msg.sender != tradeExecutor) {
            revert Unauthorized();
        }

        Intent storage intent = userIntents[user][intentIndex];

        if (intentIndex >= userIntents[user].length || intent.isExecuted) {
            revert InvalidIntent();
        }

        intent.isExecuted = true;
    }

    /// @notice Pause the contract
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpause the contract
    function unpause() external onlyOwner {
        _unpause();
    }
}