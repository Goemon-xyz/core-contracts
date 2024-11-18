// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "permit2/src/interfaces/ISignatureTransfer.sol";
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
    ISignatureTransfer public permit2;
    IIntentsEngine public intentsEngine;
    ITradeExecutor public tradeExecutor;

    mapping(address => User) private users;

    int256 public contractBalanceDiff;

    /// @notice Initialize the UserManager contract
    /// @param tokenAddress The address of the real token (e.g., USDC)
    /// @param permit2Address The address of the Permit2 contract
    function initialize(
        address tokenAddress,
        address permit2Address
    ) external initializer {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        __Pausable_init();

        if (tokenAddress == address(0)) revert InvalidToken();
        if (permit2Address == address(0)) revert InvalidToken();

        token = IERC20(tokenAddress);
        permit2 = ISignatureTransfer(permit2Address);
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

    /// @notice Deposit tokens using Permit2 and convert to synthetic balance (pUSDC)
    /// @param amount The amount to deposit
    /// @param deadline The permit deadline
    /// @param nonce The permit nonce
    /// @param permitTransferFrom The permit transfer details
    /// @param signature The permit signature
    function permitDeposit(
        uint256 amount,
        uint256 deadline,
        uint256 nonce,
        bytes calldata permitTransferFrom,
        bytes calldata signature
    ) external nonReentrant whenNotPaused {
        if (block.timestamp > deadline) revert PermitExpired();

        (address permittedToken, uint256 permitAmount) = abi.decode(
            permitTransferFrom,
            (address, uint256)
        );

        if (permittedToken != address(token)) revert InvalidToken();
        if (permitAmount != amount) revert AmountMismatch();

        // Perform Permit2 transfer
        try
            permit2.permitTransferFrom(
                ISignatureTransfer.PermitTransferFrom({
                    permitted: ISignatureTransfer.TokenPermissions({
                        token: permittedToken,
                        amount: amount
                    }),
                    nonce: nonce,
                    deadline: deadline
                }),
                ISignatureTransfer.SignatureTransferDetails({
                    to: address(this),
                    requestedAmount: amount
                }),
                msg.sender,
                signature
            )
        {
            users[msg.sender].syntheticBalance += amount;
            contractBalanceDiff += int256(amount);
            emit Deposit(msg.sender, amount);
        } catch {
            revert PermitTransferFailed();
        }
    }

    /// @notice Withdraw real tokens by converting synthetic balance (pUSDC) back to USDC
    /// @param amount The amount to withdraw
    function withdraw(uint256 amount) external nonReentrant whenNotPaused {
        User storage user = users[msg.sender];

        if (user.syntheticBalance < amount) revert InsufficientBalance();

        unchecked {
            user.syntheticBalance -= amount;
            contractBalanceDiff -= int256(amount);
        }

        token.safeTransfer(msg.sender, amount);
        emit Withdraw(msg.sender, amount);
    }

    /// @notice Get the balance of a user
    /// @param user The address of the user
    /// @return syntheticBalance The synthetic balance (pUSDC)
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
            contractBalanceDiff -= amount;
        } else {
            uint256 absAmount = uint256(-amount);
            if (userData.syntheticBalance < absAmount) revert InsufficientBalance();
            userData.syntheticBalance -= absAmount;
            contractBalanceDiff += amount; // amount is negative
        }

        emit BalanceAdjusted(user, amount);
    }

    /// @notice Get the difference between real token and synthetic asset
    /// @return The difference as an int256
    function getContractBalanceDiff() external view returns (int256) {
        return contractBalanceDiff;
    }

    /// @notice Repay the contract's balance difference
    /// @param amount The amount to repay
    function repayContractBalance(uint256 amount) external nonReentrant whenNotPaused {
        if (contractBalanceDiff > 0) revert InvalidAmount();
        
        // Convert negative diff to positive for comparison
        uint256 negativeDiff = uint256(-contractBalanceDiff);
        if (amount > negativeDiff) revert InvalidAmount();

        token.safeTransferFrom(msg.sender, address(this), amount);
        contractBalanceDiff += int256(amount); // contractBalanceDiff is negative

        emit ContractBalanceRepaid(msg.sender, amount);
    }

    /// @notice Withdraw excess real tokens when contractBalanceDiff is positive
    /// @param amount The amount to withdraw
    function withdrawExcessBalance(uint256 amount) external onlyOwner nonReentrant whenNotPaused {
        if (contractBalanceDiff <= 0) revert InvalidAmount();
        if (uint256(contractBalanceDiff) < amount) revert InvalidAmount();

        contractBalanceDiff -= int256(amount);
        token.safeTransfer(owner(), amount);

        emit ExcessBalanceWithdrawn(amount);
    }
}