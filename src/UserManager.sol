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
    uint256 public fee; // Fee in wei
    uint256 public collectedFees; // Total collected fees
    uint256 public minimumWithdrawAmount; // Minimum amount for withdrawal
    bool public useFeesForWithdrawals; // Flag to allow using fees for withdrawals

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

    /// @notice Set the fee for withdrawals
    /// @param _fee The fee amount in wei
    function setFee(uint256 _fee) external onlyOwner {
        fee = _fee;
    }

    /// @notice Set the minimum withdrawal amount
    /// @param _minimumWithdrawAmount The minimum amount for withdrawal
    function setMinimumWithdrawAmount(uint256 _minimumWithdrawAmount) external onlyOwner {
        minimumWithdrawAmount = _minimumWithdrawAmount;
    }

    /// @notice Enable or disable using collected fees for withdrawals
    /// @param _useFees Boolean to enable or disable using fees for withdrawals
    function setUseFeesForWithdrawals(bool _useFees) external onlyOwner {
        useFeesForWithdrawals = _useFees;
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
        );
    }

    /// @notice Fill an order for a user
    /// @param user The address of the user
    /// @param orderAmount The amount of the order
    function fillOrder(address user, uint256 orderAmount) external {
        // Emit the OrderFilled event
        emit OrderFilled(user, orderAmount);
    }

    /// @notice Close an order for a user
    /// @param user The address of the user
    /// @param orderAmount The amount of the order
    function closeOrder(address user, uint256 orderAmount) external {
        // Emit the OrderClosed event
        emit OrderClosed(user, orderAmount);
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

    /// @notice Withdraw funds to a single user
    /// @param user The address of the user
    /// @param amount The amount to withdraw
    function withdraw(address user, uint256 amount) external onlyOwner nonReentrant whenNotPaused {
        if (amount < minimumWithdrawAmount) revert InvalidAmount();
        uint256 amountAfterFee = amount - fee;
        uint256 availableBalance = useFeesForWithdrawals ? address(this).balance : address(this).balance - collectedFees;
        if (availableBalance < amountAfterFee) revert InsufficientBalance();
        (bool success, ) = user.call{value: amountAfterFee}("");
        if (!success) revert WithdrawFailed();
        collectedFees += fee;
        emit Withdraw(user, amountAfterFee);
    }

    /// @notice Batch withdraw funds to multiple users
    /// @param users The addresses of the users
    /// @param amounts The amounts to withdraw to each user
    /// @param totalAmount The total amount to withdraw
    function batchWithdraw(address[] calldata users, uint256[] calldata amounts, uint256 totalAmount) external onlyOwner nonReentrant whenNotPaused {
        if (users.length != amounts.length) revert AmountMismatch();
        uint256 availableBalance = useFeesForWithdrawals ? address(this).balance : address(this).balance - collectedFees;
        if (availableBalance < totalAmount) revert InsufficientBalance();

        uint256 feePerUser = fee; // Cache fee in memory to save gas
        for (uint256 i = 0; i < users.length; i++) {
            if (amounts[i] < minimumWithdrawAmount) revert InvalidAmount();
            uint256 amountAfterFee = amounts[i] - feePerUser;
            (bool success, ) = users[i].call{value: amountAfterFee}("");
            if (!success) revert WithdrawFailed();
            collectedFees += feePerUser;
        }

        emit BatchWithdraw(users, amounts);
    }

    /// @notice Collect accumulated fees
    function collectFees() external onlyOwner {
        uint256 feesToCollect = collectedFees;
        collectedFees = 0;
        (bool success, ) = msg.sender.call{value: feesToCollect}("");
        if (!success) revert FeeCollectionFailed();
    }

    /// @notice Set the powerTrade account address
    /// @param _powerTrade The address of the powerTrade account
    function setPowerTrade(address _powerTrade) external onlyOwner {
        if (_powerTrade == address(0)) revert InvalidAddress();
        powerTrade = _powerTrade;
    }

    /// @notice Get the contract's token balance minus collected fees
    /// @return The token balance of the contract minus collected fees
    function getBalance() external view returns (uint256) {
        return address(this).balance - collectedFees;
    }

    /// @notice Get the total collected fees
    /// @return The total collected fees in the contract
    function getCollectedFees() external view returns (uint256) {
        return collectedFees;
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