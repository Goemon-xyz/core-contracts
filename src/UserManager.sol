// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; // Import the ERC20 interface
import "./interfaces/IUserManager.sol";
import "./interfaces/IIntentsEngine.sol";
import "./interfaces/ITradeExecutor.sol";

contract UserManager is
    IUserManager,
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    IIntentsEngine public intentsEngine;
    ITradeExecutor public tradeExecutor;
    IERC20 public token; // Declare the token interface
    int256 public netPnl; // Track net synthetic balance changes

    mapping(address => User) private users;

    /// @notice Initialize the UserManager contract
    /// @param _token The address of the ERC20 token contract
    function initialize(address _token) external initializer {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        __Pausable_init();

        if (_token == address(0)) revert InvalidToken();
        token = IERC20(_token); // Set the token address
    }

    /// @notice Set the IntentsEngine contract address
    /// @param _intentsEngine The address of the IntentsEngine contract
    function setIntentsEngine(address _intentsEngine) external onlyOwner {
        if (_intentsEngine == address(0)) revert InvalidToken();
        intentsEngine = IIntentsEngine(_intentsEngine);
    }

    /// @notice Set the TradeExecutor contract address
    /// @param _tradeExecutor The address of the TradeExecutor contract
    function setTradeExecutor(address _tradeExecutor) external onlyOwner {
        if (_tradeExecutor == address(0)) revert InvalidToken();
        tradeExecutor = ITradeExecutor(_tradeExecutor);
    }

    /// @notice Update the net PnL
    /// @param pnlChange The change in PnL to apply
    function updateNetPnl(int256 pnlChange) external {
        if (msg.sender != address(tradeExecutor)) revert Unauthorized();
        netPnl += pnlChange;
    }

    /// @notice Pause the contract
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpause the contract
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Deposit synthetic balance
    /// @param amount The amount to deposit
    function deposit(uint256 amount) external nonReentrant whenNotPaused {
        // Check the real token balance of the sender
        uint256 senderBalance = token.balanceOf(msg.sender);
        if (senderBalance < amount) revert InsufficientBalance();

        users[msg.sender].syntheticBalance += amount;
        emit Deposit(msg.sender, amount);
    }

    /// @notice Withdraw synthetic balance
    /// @param amount The amount to withdraw
    function withdraw(uint256 amount) external nonReentrant whenNotPaused {
        User storage user = users[msg.sender];

        if (user.syntheticBalance < amount) revert InsufficientBalance();

        unchecked {
            user.syntheticBalance -= amount;
        }

        emit Withdraw(msg.sender, amount);
    }

    /// @notice Get the balance of a user
    /// @param user The address of the user
    /// @return syntheticBalance The synthetic balance
    /// @return lockedBalance The locked balance
    function getUserBalance(
        address user
    ) external view returns (uint256 syntheticBalance, uint256 lockedBalance) {
        User storage userData = users[user];
        return (userData.syntheticBalance, userData.lockedBalance);
    }

    /// @notice Lock a user's synthetic balance for intents
    /// @param user The address of the user
    /// @param amount The amount to lock
    function lockUserBalance(address user, uint256 amount) external {
        if (msg.sender != address(intentsEngine)) revert Unauthorized();

        User storage userData = users[user];

        if (userData.syntheticBalance < amount) revert InsufficientBalance();

        unchecked {
            userData.syntheticBalance -= amount;
            userData.lockedBalance += amount;
        }
    }

    /// @notice Unlock a user's previously locked balance
    /// @param user The address of the user
    /// @param amount The amount to unlock
    function unlockUserBalance(address user, uint256 amount) external {
        if (msg.sender != address(tradeExecutor)) revert Unauthorized();

        User storage userData = users[user];

        if (userData.lockedBalance < amount) revert InsufficientBalance();

        unchecked {
            userData.lockedBalance -= amount;
            userData.syntheticBalance += amount;
        }
    }

    /// @notice Adjust a user's synthetic balance based on pnl
    /// @param user The address of the user
    /// @param amount The pnl amount to adjust (can be positive or negative)
    function adjustUserBalance(address user, int256 amount) external {
        if (msg.sender != address(tradeExecutor)) revert Unauthorized();

        User storage userData = users[user];

        if (amount > 0) {
            userData.syntheticBalance += uint256(amount);
        } else {
            uint256 absAmount = uint256(-amount);
            if (userData.syntheticBalance < absAmount) revert InsufficientBalance();
            userData.syntheticBalance -= absAmount;
        }

        emit BalanceAdjusted(user, amount);
    }

    /// @notice Withdraw excess synthetic funds as fees
    /// @param amount The amount of funds to withdraw
    /// @param recipient The address to receive the withdrawn funds
    function withdrawExcessFunds(uint256 amount, address recipient) external onlyOwner nonReentrant whenNotPaused {
        if (netPnl < int256(amount)) {
            revert InsufficientExcessFunds();
        }
        if (recipient == address(0)) {
            revert InvalidAddress();
        }
        // transfer the requested amount to the recipient
        netPnl -= int256(amount);

        emit ExcessFundsWithdrawn(recipient, amount);
    }

    /// @notice View the current net pnl
    /// @return The current net synthetic balance changes
    function viewNetPnl() external view returns (int256) {
        return netPnl;
    }
}