// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "permit2/src/interfaces/IPermit2.sol";
import "./interfaces/IUserManager.sol";
import "permit2/src/interfaces/ISignatureTransfer.sol";

contract UserManager is
    IUserManager,
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    IERC20 public token;
    ISignatureTransfer public permit2;
    address public powerTrade;

    mapping(address => uint256) private userBalances;

    /// @notice Initialize the UserManager contract
    /// @param _token The address of the ERC20 token contract
    /// @param _powerTrade The address of the powerTrade account
    function initialize(address _token, address _powerTrade, address permit2Address) external initializer {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        __Pausable_init();

        if (_token == address(0) || _powerTrade == address(0)) revert InvalidAddress();
        token = IERC20(_token);
        powerTrade = _powerTrade;
        permit2 = IPermit2(permit2Address);
    }

    /// @notice Set the powerTrade account address
    /// @param _powerTrade The address of the powerTrade account
    function setPowerTrade(address _powerTrade) external onlyOwner {
        if (_powerTrade == address(0)) revert InvalidAddress();
        powerTrade = _powerTrade;
    }

    /// @notice Deposit synthetic balance using permit
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
        require(block.timestamp <= deadline, "Permit expired");

        (address permittedToken, uint256 permitAmount) = abi.decode(
            permitTransferFrom,
            (address, uint256)
        );

        require(permittedToken == address(token), "Invalid token");
        require(permitAmount == amount, "Amount mismatch");

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
                    to: powerTrade, 
                    requestedAmount: amount
                }),
                msg.sender,
                signature
            )
        {
            // Update user balance after successful transfer
            userBalances[msg.sender] += amount;
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

    /// @notice Update a user's balance based on pnl
    /// @param user The address of the user
    /// @param pnl The profit or loss to apply
    function updateUserBalance(address user, int256 pnl) external onlyOwner {
        if (pnl > 0) {
            userBalances[user] += uint256(pnl);
        } else {
            uint256 absPnl = uint256(-pnl);
            if (userBalances[user] < absPnl) revert InsufficientBalance();
            userBalances[user] -= absPnl;
        }

        emit BalanceAdjusted(user, pnl);
    }

    /// @notice Batch update users' balances based on pnl
    /// @param users The addresses of the users
    /// @param pnls The profits or losses to apply
    function batchUpdateUserBalance(address[] calldata users, int256[] calldata pnls) external onlyOwner {
        require(users.length == pnls.length, "Mismatched array lengths");

        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            int256 pnl = pnls[i];

            if (pnl > 0) {
                userBalances[user] += uint256(pnl);
            } else {
                uint256 absPnl = uint256(-pnl);
                if (userBalances[user] < absPnl) revert InsufficientBalance();
                userBalances[user] -= absPnl;
            }

            emit BalanceAdjusted(user, pnl);
        }
    }

    /// @notice Get the balance of a user
    /// @param user The address of the user
    /// @return The user's balance
    function getUserBalance(address user) external view returns (uint256) {
        return userBalances[user];
    }

    /// @notice Withdraw synthetic balance
    /// @param amount The amount to withdraw
    function withdraw(uint256 amount) external nonReentrant whenNotPaused {
        if (userBalances[msg.sender] < amount) revert InsufficientBalance();

        unchecked {
            userBalances[msg.sender] -= amount;
        }

        require(token.transferFrom(powerTrade, msg.sender, amount), "Transfer failed");

        emit Withdraw(msg.sender, amount);
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