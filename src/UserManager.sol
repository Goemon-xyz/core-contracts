// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "permit2/src/interfaces/IPermit2.sol";
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
    using SafeERC20 for IERC20;

    IERC20 public token;
    IPermit2 public permit2;
    IIntentsEngine public intentsEngine;
    ITradeExecutor public tradeExecutor;

    mapping(address => User) private users;

    function initialize(
        address tokenAddress,
        address permit2Address
    ) public initializer {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        __Pausable_init();

        require(tokenAddress != address(0), "Invalid token address");
        require(permit2Address != address(0), "Invalid Permit2 address");
        token = IERC20(tokenAddress);
        permit2 = IPermit2(permit2Address);
    }

    function setIntentsEngine(address _intentsEngine) external onlyOwner {
        require(_intentsEngine != address(0), "Invalid IntentsEngine address");
        intentsEngine = IIntentsEngine(_intentsEngine);
    }

    function setTradeExecutor(address _tradeExecutor) external onlyOwner {
        require(_tradeExecutor != address(0), "Invalid TradeExecutor address");
        tradeExecutor = ITradeExecutor(_tradeExecutor);
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

    function getUserBalance(
        address user
    ) external view returns (uint256 availableBalance, uint256 lockedBalance) {
        User storage userData = users[user];
        return (userData.balance, userData.lockedBalance);
    }

    function lockUserBalance(address user, uint256 amount) external {
        require(
            msg.sender == address(intentsEngine),
            "Only IntentsEngine can lock balance"
        );
        require(users[user].balance >= amount, "Insufficient balance");
        users[user].balance -= amount;
        users[user].lockedBalance += amount;
    }

    function unlockUserBalance(address user, uint256 amount) external {
        require(
            msg.sender == address(tradeExecutor),
            "Only TradeExecutor can unlock balance"
        );
        require(
            users[user].lockedBalance >= amount,
            "Insufficient locked balance"
        );
        users[user].lockedBalance -= amount;
        users[user].balance += amount;
    }

    function adjustUserBalance(address user, int256 amount) external {
        require(
            msg.sender == address(tradeExecutor),
            "Only TradeExecutor can adjust balance"
        );
        if (amount > 0) {
            users[user].balance += uint256(amount);
        } else {
            require(
                users[user].balance >= uint256(-amount),
                "Insufficient balance"
            );
            users[user].balance -= uint256(-amount);
        }
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
