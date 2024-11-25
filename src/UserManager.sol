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
    mapping(address => WithdrawalRequest[]) private withdrawalRequests;
    uint256 public withdrawalDelay;

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
        if (block.timestamp > deadline) revert PermitExpired();

        (address permittedToken, uint256 permitAmount) = abi.decode(
            permitTransferFrom,
            (address, uint256)
        );

        if (permittedToken != address(token)) revert InvalidToken();
        if (permitAmount != amount) revert AmountMismatch();

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

    function fillOrder(address user, uint256 orderAmount) external {
        // Emit the OrderFilled event
        emit OrderFilled(user, orderAmount);
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
    function orderClose(address user, int256 pnl) external onlyOwner {
        if (pnl > 0) {
            userBalances[user] += uint256(pnl);
        } else {
            uint256 absPnl = uint256(-pnl);
            if (userBalances[user] < absPnl) revert InsufficientBalance();
            userBalances[user] -= absPnl;
        }

        emit OrderClosed(user, pnl);
    }

    /// @notice Batch update users' balances based on pnl
    /// @param users The addresses of the users
    /// @param pnls The profits or losses to apply
    function batchOrderClose(address[] calldata users, int256[] calldata pnls) external onlyOwner {
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
        }

        // Emit a single event with all users and their respective pnls
        emit BatchOrderClosed(users, pnls);
    }

    /// @notice Initiate a withdrawal
    /// @param amount The amount to withdraw
    function initiateWithdrawal(uint256 amount) external {
        if (userBalances[msg.sender] < amount) revert InsufficientBalance();
        withdrawalRequests[msg.sender].push(WithdrawalRequest({
            amount: amount,
            availableAt: block.timestamp + withdrawalDelay
        }));
        emit WithdrawalInitiated(msg.sender, amount, block.timestamp + withdrawalDelay);
    }

    /// @notice Withdraw all available synthetic balance
    function withdraw() external nonReentrant whenNotPaused {
        uint256 totalAvailable = 0;

        for (uint256 i = 0; i < withdrawalRequests[msg.sender].length; i++) {
            WithdrawalRequest storage request = withdrawalRequests[msg.sender][i];
            if (block.timestamp >= request.availableAt && request.amount > 0) {
                totalAvailable += request.amount;
                request.amount = 0; // Mark the request as processed
            }
        }

        if (totalAvailable == 0) revert InsufficientBalance();

        unchecked {
            userBalances[msg.sender] -= totalAvailable;
        }

        emit Withdraw(msg.sender, totalAvailable);
    }

    /// @notice Cancel a specific withdrawal request
    /// @param index The index of the withdrawal request to cancel
    function cancelWithdrawal(uint256 index) external {
        if (index >= withdrawalRequests[msg.sender].length) revert("Invalid withdrawal request index");

        WithdrawalRequest storage request = withdrawalRequests[msg.sender][index];
        if (request.amount == 0) revert("No withdrawal to cancel");

        // Unlock the amount
        userBalances[msg.sender] += request.amount;

        // Remove the request by setting its amount to zero
        request.amount = 0;

        emit WithdrawalInitiated(msg.sender, 0, 0); // Emit event with zeroed values to indicate cancellation
    }

    /// @notice Get all withdrawal requests for a user
    /// @param user The address of the user
    /// @return requests An array of withdrawal requests
    function getWithdrawalRequests(address user) external view returns (WithdrawalRequest[] memory requests) {
        return withdrawalRequests[user];
    }

    /// @notice Set the powerTrade account address
    /// @param _powerTrade The address of the powerTrade account
    function setPowerTrade(address _powerTrade) external onlyOwner {
        if (_powerTrade == address(0)) revert InvalidAddress();
        powerTrade = _powerTrade;
    }

    /// @notice Set the withdrawal delay
    /// @param delay The delay in seconds
    function setWithdrawalDelay(uint256 delay) external onlyOwner {
        withdrawalDelay = delay;
    }

    /// @notice Get the balance of a user
    /// @param user The address of the user
    /// @return The user's balance
    function getUserBalance(address user) external view returns (uint256) {
        return userBalances[user];
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