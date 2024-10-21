// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "permit2/src/interfaces/IPermit2.sol";

import "./interfaces/ITradeExecutor2.sol";
import "./interfaces/ICore.sol";

/**
 * @title GoemonCore
 * @dev This contract manages trade intents and executions using Permit2 for gasless approvals.
 * It interacts with a TradeExecutor contract to handle the actual trade execution logic.
 */
contract Core is ICore, Ownable {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;
    IPermit2 public immutable permit2;
    ITradeExecutor2 public tradeExecutor;
    address public treasury;

    mapping(address => Trade[]) private userTrades;

    /**
     * @dev Constructor to initialize the contract with necessary addresses.
     * @param tokenAddress The address of the ERC20 token used for trading.
     * @param permit2Address The address of the Permit2 contract for gasless approvals.
     * @param tradeExecutorAddress The address of the TradeExecutor contract.
     * @param treasuryAddress The address where funds will be stored.
     */
    constructor(
        address tokenAddress,
        address permit2Address,
        address tradeExecutorAddress,
        address treasuryAddress
    ) Ownable(msg.sender) {
        require(tokenAddress != address(0), "Invalid token address");
        require(treasuryAddress != address(0), "Invalid treasury address");
        token = IERC20(tokenAddress);
        permit2 = IPermit2(permit2Address);
        tradeExecutor = ITradeExecutor2(tradeExecutorAddress);
        treasury = treasuryAddress;
    }

    /**
     * @dev Allows users to submit a trade intent using Permit2 for gasless approval.
     * User flow:
     * 1. User signs a Permit2 message off-chain.
     * 2. User or a relayer calls this function with the signed message.
     * 3. Tokens are transferred to the treasury.
     * 4. Trade intent is recorded and passed to the TradeExecutor.
     * @param amount The amount of tokens to trade.
     * @param intentType The type of trade intent (e.g., "BUY" or "SELL").
     * @param deadline The deadline for the Permit2 signature.
     * @param nonce The nonce for the Permit2 signature.
     * @param signature The Permit2 signature for token approval.
     */
    function submitTradeIntent(
        uint256 amount,
        string calldata intentType,
        uint256 deadline,
        uint48 nonce,
        bytes calldata signature
    ) external {
        IAllowanceTransfer.PermitSingle memory permitSingle = IAllowanceTransfer
            .PermitSingle({
                details: IAllowanceTransfer.PermitDetails({
                    token: address(token),
                    amount: uint160(amount),
                    expiration: uint48(deadline),
                    nonce: nonce
                }),
                spender: address(this),
                sigDeadline: deadline
            });

        permit2.permit(msg.sender, permitSingle, signature);
        permit2.transferFrom(
            msg.sender,
            treasury,
            uint160(amount),
            address(token)
        );

        uint256 tradeNonce = tradeExecutor.initiateTrade(
            msg.sender,
            amount,
            intentType
        );

        userTrades[msg.sender].push(
            Trade({
                amount: amount,
                timestamp: block.timestamp,
                intentType: intentType,
                isSettled: false
            })
        );

        emit TradeIntentSubmitted(msg.sender, amount, intentType, tradeNonce);
    }

    /**
     * @dev Allows users to submit a trade intent using standard ERC20 approvals.
     * User flow:
     * 1. User approves this contract to spend their tokens.
     * 2. User calls this function.
     * 3. Tokens are transferred to the treasury.
     * 4. Trade intent is recorded and passed to the TradeExecutor.
     * @param amount The amount of tokens to trade.
     * @param intentType The type of trade intent (e.g., "BUY" or "SELL").
     */
    function manualTradeIntent(
        uint256 amount,
        string calldata intentType
    ) external {
        require(
            token.transferFrom(msg.sender, treasury, amount),
            "Transfer failed"
        );

        uint256 tradeNonce = tradeExecutor.initiateTrade(
            msg.sender,
            amount,
            intentType
        );

        userTrades[msg.sender].push(
            Trade({
                amount: amount,
                timestamp: block.timestamp,
                intentType: intentType,
                isSettled: false
            })
        );

        emit TradeIntentSubmitted(msg.sender, amount, intentType, tradeNonce);
    }

    /**
     * @dev Allows the contract owner to settle a trade.
     * This function should be called after the actual trade execution has occurred off-chain.
     * User flow:
     * 1. Off-chain system executes the trade.
     * 2. Contract owner calls this function to mark the trade as settled.
     * 3. TradeExecutor is notified of the settlement.
     * @param user The address of the user whose trade is being settled.
     * @param tradeIndex The index of the trade in the user's trade array.
     */
    function settleTrade(address user, uint256 tradeIndex) external onlyOwner {
        require(tradeIndex < userTrades[user].length, "Invalid trade index");
        require(
            !userTrades[user][tradeIndex].isSettled,
            "Trade already settled"
        );

        userTrades[user][tradeIndex].isSettled = true;
        tradeExecutor.settleTrade(user, tradeIndex);

        emit TradeSettled(user, tradeIndex);
    }

    /**
     * @dev Allows anyone to view the trade history of a specific user.
     * @param user The address of the user whose trades are being queried.
     * @return An array of Trade structs representing the user's trade history.
     */
    function getUserTrades(
        address user
    ) external view returns (Trade[] memory) {
        return userTrades[user];
    }

    /**
     * @dev Allows the contract owner to update the TradeExecutor address.
     * This might be necessary for upgrades or maintenance.
     * @param newTradeExecutor The address of the new TradeExecutor contract.
     */
    function setTradeExecutor(address newTradeExecutor) external onlyOwner {
        require(newTradeExecutor != address(0), "Invalid address");
        tradeExecutor = ITradeExecutor2(newTradeExecutor);
        emit TradeExecutorUpdated(newTradeExecutor);
    }

    /**
     * @dev Allows the contract owner to update the treasury address.
     * This might be necessary for security or operational reasons.
     * @param newTreasury The address of the new treasury.
     */
    function setTreasury(address newTreasury) external onlyOwner {
        require(newTreasury != address(0), "Invalid address");
        treasury = newTreasury;
        emit TreasuryUpdated(newTreasury);
    }
}
