// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "permit2/src/interfaces/IPermit2.sol";

import "./libraries/SignatureVerifier.sol";
import "./interfaces/IGoemonCore.sol";

contract GoemonCore is IGoemonCore, Ownable {
    using SafeERC20 for IERC20;

    IERC20 private immutable _token;
    IPermit2 public immutable permit2;

    struct User {
        uint256 balance;
        uint256 principal;
        uint256 yield;
        uint256 lockedUntilMaturity;
    }

    mapping(address => User) private users;

    constructor(
        address tokenAddress,
        address permit2Address
    ) Ownable(msg.sender) {
        require(tokenAddress != address(0), "Invalid token address");
        _token = IERC20(tokenAddress);
        permit2 = IPermit2(permit2Address);
    }

    // Permit2-based deposit using signatures
    function permitDeposit(
        address token,
        uint160 amount,
        uint256 deadline,
        uint48 nonce,
        bytes calldata signature
    ) external {
        IAllowanceTransfer.PermitDetails memory details = IAllowanceTransfer
            .PermitDetails({
                token: token,
                amount: amount,
                expiration: uint48(deadline),
                nonce: nonce
            });

        IAllowanceTransfer.PermitSingle memory permitSingle = IAllowanceTransfer
            .PermitSingle({
                details: details,
                spender: address(this),
                sigDeadline: deadline
            });

        permit2.permit(msg.sender, permitSingle, signature);

        // Transfer the tokens from the user to this contract
        IERC20(token).transferFrom(msg.sender, address(this), amount);

        // Update the user's balance
        users[msg.sender].balance += amount;

        emit Deposit(msg.sender, amount);
    }

    // Deposit function
    // function deposit(uint256 amount) external override {
    //     require(amount > 0, "Amount must be greater than zero");
    //     require(
    //         _token.transferFrom(msg.sender, address(this), amount),
    //         "Token transfer failed"
    //     );

    //     users[msg.sender].balance += amount;
    //     emit Deposit(msg.sender, amount);
    // }

    // Withdraw function
    function withdraw(uint256 amount) external override {
        User storage user = users[msg.sender];
        require(user.balance >= amount, "Insufficient balance");

        user.balance -= amount;
        require(_token.transfer(msg.sender, amount), "Token transfer failed");

        emit Withdraw(msg.sender, amount);
    }

    // Submit trade intent
    function submitTradeIntentWithSignature(
        uint256 amount,
        string calldata intentType,
        bytes memory signature
    ) external {
        require(
            SignatureVerifier.verifySignature(
                msg.sender,
                abi.encodePacked(amount, intentType),
                signature
            ),
            "Invalid signature"
        );

        emit TradeIntentSubmitted(
            msg.sender,
            amount,
            intentType,
            keccak256(signature)
        );
    }

    // Lock funds until maturity
    function lockFundsUntilMaturity(
        uint256 amount,
        uint256 maturityDate
    ) external override {
        User storage user = users[msg.sender];
        require(user.balance >= amount, "Insufficient balance");

        user.balance -= amount;
        user.lockedUntilMaturity = maturityDate;
        user.principal += amount;

        emit LockFunds(msg.sender, amount, maturityDate);
    }

    // View function for user balance
    function getUserBalance() external view override returns (uint256) {
        return users[msg.sender].balance;
    }

    // View function for locked funds
    function getLockedFunds() external view override returns (uint256) {
        return users[msg.sender].lockedUntilMaturity;
    }

    // View function for user yield
    function getUserYield() external view override returns (uint256) {
        return users[msg.sender].yield;
    }
}
