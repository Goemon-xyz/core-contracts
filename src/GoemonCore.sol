// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "permit2/src/interfaces/IPermit2.sol";
import "./interfaces/IGoemonCore.sol";

contract GoemonCore is
    IGoemonCore,
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    using SafeERC20 for IERC20;

    IERC20 public token;
    IPermit2 public permit2;
    address public treasury;

    struct User {
        uint256 balance;
        uint256 lockedBalance;
    }

    mapping(address => User) private users;
    mapping(address => Intent[]) private userIntents;

    uint256 public constant MAX_BATCH_SIZE = 100;
    uint256 public maxIntentsPerUser;

    function initialize(
        address tokenAddress,
        address permit2Address,
        address treasuryAddress
    ) public initializer {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        __Pausable_init();

        require(tokenAddress != address(0), "Invalid token address");
        require(permit2Address != address(0), "Invalid Permit2 address");
        require(treasuryAddress != address(0), "Invalid treasury address");
        token = IERC20(tokenAddress);
        permit2 = IPermit2(permit2Address);
        treasury = treasuryAddress;
        maxIntentsPerUser = 10; // Default value, can be changed later
    }

    function permitDeposit(
        uint160 amount,
        uint256 deadline,
        uint48 nonce,
        bytes calldata signature
    ) external nonReentrant whenNotPaused {
        IAllowanceTransfer.PermitSingle memory permitSingle = IAllowanceTransfer
            .PermitSingle({
                details: IAllowanceTransfer.PermitDetails({
                    token: address(token),
                    amount: amount,
                    expiration: uint48(deadline),
                    nonce: nonce
                }),
                spender: address(this),
                sigDeadline: deadline
            });

        permit2.permit(msg.sender, permitSingle, signature);
        permit2.transferFrom(msg.sender, address(this), amount, address(token));

        users[msg.sender].balance += amount;
        emit Deposit(msg.sender, amount);
    }

    function withdraw(uint256 amount) external nonReentrant whenNotPaused {
        require(users[msg.sender].balance >= amount, "Insufficient balance");
        users[msg.sender].balance -= amount;
        token.safeTransfer(msg.sender, amount);
        emit Withdraw(msg.sender, amount);
    }

    function submitIntent(
        uint256 amount,
        string calldata intentType
    ) external nonReentrant whenNotPaused {
        require(
            userIntents[msg.sender].length < maxIntentsPerUser,
            "Max intents limit reached"
        );
        User storage user = users[msg.sender];
        require(
            user.balance >= amount,
            "Insufficient balance for intent submission"
        );

        user.balance -= amount;
        user.lockedBalance += amount;

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

        uint256 totalProfit = 0;
        uint256 totalLoss = 0;

        for (uint256 i = 0; i < allUsers.length; i++) {
            (uint256 profit, uint256 loss) = _settleIntent(
                allUsers[i],
                intentIndices[i],
                pnls[i]
            );
            totalProfit += profit;
            totalLoss += loss;
        }

        if (totalProfit > 0) {
            token.safeTransferFrom(treasury, address(this), totalProfit);
        }
        if (totalLoss > 0) {
            token.safeTransfer(treasury, totalLoss);
        }
    }

    function _settleIntent(
        address user,
        uint256 intentIndex,
        int256 pnl
    ) internal returns (uint256 profit, uint256 loss) {
        require(intentIndex < userIntents[user].length, "Invalid intent index");
        Intent storage intent = userIntents[user][intentIndex];
        require(!intent.isExecuted, "Intent already executed");

        User storage trader = users[user];
        require(
            trader.lockedBalance >= intent.amount,
            "Insufficient locked balance"
        );

        trader.lockedBalance -= intent.amount;

        if (pnl > 0) {
            profit = uint256(pnl);
            trader.balance += intent.amount + profit;
        } else if (pnl < 0) {
            loss = uint256(-pnl);
            require(intent.amount >= loss, "Loss exceeds intent amount");
            trader.balance += intent.amount - loss;
        } else {
            trader.balance += intent.amount;
        }

        intent.isExecuted = true;

        emit IntentSettled(user, intentIndex, pnl);
    }

    function getUserBalance(
        address user
    ) external view returns (uint256 availableBalance, uint256 lockedBalance) {
        User storage userData = users[user];
        return (userData.balance, userData.lockedBalance);
    }

    function getUserIntents(
        address user
    ) external view returns (Intent[] memory) {
        return userIntents[user];
    }

    function setTreasury(address newTreasury) external onlyOwner {
        require(newTreasury != address(0), "Invalid treasury address");
        treasury = newTreasury;
        emit TreasuryUpdated(newTreasury);
    }

    function setMaxIntentsPerUser(uint256 newMax) external onlyOwner {
        maxIntentsPerUser = newMax;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
