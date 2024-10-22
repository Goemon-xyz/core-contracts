// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "permit2/src/interfaces/IPermit2.sol";
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

    event PermitDataReceived(uint256 amount, uint256 deadline, uint256 nonce);
    event TokenValidated(address token, uint256 amount);
    event PermitExecutionStarted();
    event PermitExecutionCompleted();

    function permitDeposit(
        uint256 amount,
        uint256 deadline,
        uint256 nonce,
        bytes calldata permitTransferFrom,
        bytes calldata signature
    ) external nonReentrant whenNotPaused {
        emit PermitDataReceived(amount, deadline, nonce);
        require(block.timestamp <= deadline, "Permit expired");

        (address permittedToken, uint256 permitAmount) = abi.decode(
            permitTransferFrom,
            (address, uint256)
        );

        emit TokenValidated(permittedToken, permitAmount);
        require(permittedToken == address(token), "Invalid token");
        require(permitAmount == amount, "Amount mismatch");

        emit PermitExecutionStarted();
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
            users[msg.sender].balance += amount;
            emit PermitExecutionCompleted();
            emit Deposit(msg.sender, amount);
        } catch Error(string memory reason) {
            revert(
                string(abi.encodePacked("Permit2 transfer failed: ", reason))
            );
        } catch (bytes memory lowLevelData) {
            revert(
                string(
                    abi.encodePacked(
                        "Permit2 transfer failed: ",
                        _toHex(lowLevelData)
                    )
                )
            );
        }
    }

    function _toHex(bytes memory data) internal pure returns (string memory) {
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(2 + data.length * 2);
        str[0] = "0";
        str[1] = "x";
        for (uint i = 0; i < data.length; i++) {
            str[2 + i * 2] = alphabet[uint(uint8(data[i] >> 4))];
            str[3 + i * 2] = alphabet[uint(uint8(data[i] & 0x0f))];
        }
        return string(str);
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
