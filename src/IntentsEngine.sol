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

    function initialize(address _userManager) public initializer {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        __Pausable_init();

        require(_userManager != address(0), "Invalid UserManager address");
        userManager = IUserManager(_userManager);
        maxIntentsPerUser = 10; // Default value, can be changed later
    }

    function setTradeExecutor(address _tradeExecutor) external onlyOwner {
        require(_tradeExecutor != address(0), "Invalid TradeExecutor address");
        tradeExecutor = _tradeExecutor;
    }

    function submitIntent(
        uint256 amount,
        string calldata intentType
    ) external nonReentrant whenNotPaused {
        require(
            userIntents[msg.sender].length < maxIntentsPerUser,
            "Max intents limit reached"
        );

        userManager.lockUserBalance(msg.sender, amount);

        userIntents[msg.sender].push(
            Intent({
                amount: amount,
                intentType: intentType,
                timestamp: block.timestamp,
                isExecuted: false
            })
        );

        emit IntentSubmitted(msg.sender, amount, intentType);
    }

    function getUserIntents(
        address user
    ) external view returns (Intent[] memory) {
        return userIntents[user];
    }

    function setMaxIntentsPerUser(uint256 newMax) external onlyOwner {
        maxIntentsPerUser = newMax;
    }

    function markIntentAsExecuted(address user, uint256 intentIndex) external {
        require(
            msg.sender == address(userManager) || msg.sender == tradeExecutor,
            "Only UserManager or TradeExecutor can mark intents as executed"
        );
        require(intentIndex < userIntents[user].length, "Invalid intent index");
        require(
            !userIntents[user][intentIndex].isExecuted,
            "Intent already executed"
        );

        userIntents[user][intentIndex].isExecuted = true;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
