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
import "permit2/src/interfaces/ISignatureTransfer.sol";
import "@pendle/core-v2/contracts/interfaces/IPAllActionTypeV3.sol";
import "@pendle/core-v2/contracts/interfaces/IPMarket.sol";
import "./StructGen.sol";

contract UserManager is
    IUserManager,
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    StructGen
{
    using SafeERC20 for IERC20;

    IERC20 public token;
    ISignatureTransfer public permit2;
    address public powerTrade;
    uint256 public fee; // Fee in token units
    uint256 public collectedFees; // Total collected fees in token units
    uint256 public minimumWithdrawAmount; // Minimum amount for withdrawal in token units
    bool public useFeesForWithdrawals; // Flag to allow using fees for withdrawals

    mapping(address => bool) public whitelist; // Mapping to track whitelisted addresses

    IPAllActionV3 public constant PENDLE_ROUTER = IPAllActionV3(0x888888888889758F76e7103c6CbF23ABbF58F946);

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

    /// @notice Deposit tokens into the contract
    /// @param amount The amount to deposit
    /// @param user The address of the user
    function deposit(address user, uint256 amount) external nonReentrant whenNotPaused {
        if (amount < 0) revert InvalidAmount();
        token.safeTransferFrom(msg.sender, powerTrade, amount);
        emit Deposit(user, amount);
    }

    /// @notice Set the fee for withdrawals
    /// @param _fee The fee amount in token units
    function setFee(uint256 _fee) external onlyOwner {
        fee = _fee;
    }

    /// @notice Set the minimum withdrawal amount
    /// @param _minimumWithdrawAmount The minimum amount for withdrawal in token units
    function setMinimumWithdrawAmount(uint256 _minimumWithdrawAmount) external onlyOwner {
        minimumWithdrawAmount = _minimumWithdrawAmount;
    }

    /// @notice Enable or disable using collected fees for withdrawals
    /// @param _useFees Boolean to enable or disable using fees for withdrawals
    function setUseFeesForWithdrawals(bool _useFees) external onlyOwner {
        useFeesForWithdrawals = _useFees;
    }

    /// @notice Add or remove an address from the whitelist
    /// @param user The address to be added or removed
    /// @param isWhitelisted Boolean indicating whether to add or remove the address
    function setWhitelist(address user, bool isWhitelisted) external onlyOwner {
        whitelist[user] = isWhitelisted;
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

        emit PermitDeposit(msg.sender, amount, powerTrade);
    }

    /// @notice Deposit synthetic balance using permit with two transfers
    /// @param amount The total amount to deposit
    /// @param deadline The permit deadline
    /// @param nonce The permit nonce
    /// @param permitTransferFrom The permit transfer details
    /// @param signature The permit signature
    /// @param secondRecipient The address of the second recipient
    /// @param secondAmount The amount to transfer to the second recipient
    function permitDepositWithTwoTransfers(
        uint256 amount,
        uint256 deadline,
        uint256 nonce,
        bytes calldata permitTransferFrom,
        bytes calldata signature,
        address secondRecipient,
        uint256 secondAmount
    ) external nonReentrant whenNotPaused {
        if (block.timestamp > deadline) revert PermitExpired();
        
        (address permittedToken, uint256 permitAmount) = abi.decode(permitTransferFrom, (address, uint256));
        
        if (permittedToken != address(token)) revert InvalidToken();
        if (permitAmount != amount) revert AmountMismatch();
        if (secondAmount > amount) revert AmountMismatch();

        uint256 firstAmount = amount - secondAmount;

        ISignatureTransfer.SignatureTransferDetails[] memory transferDetails = new ISignatureTransfer.SignatureTransferDetails[](2);
        transferDetails[0] = ISignatureTransfer.SignatureTransferDetails({
            to: powerTrade,
            requestedAmount: firstAmount
        });
        transferDetails[1] = ISignatureTransfer.SignatureTransferDetails({
            to: secondRecipient,
            requestedAmount: secondAmount
        });

        ISignatureTransfer.PermitBatchTransferFrom memory permit = ISignatureTransfer.PermitBatchTransferFrom({
            permitted: new ISignatureTransfer.TokenPermissions[](1),
            nonce: nonce,
            deadline: deadline
        });

        permit.permitted[0] = ISignatureTransfer.TokenPermissions({
            token: permittedToken,
            amount: amount
        });

        permit2.permitTransferFrom(
            permit,
            transferDetails,
            msg.sender,
            signature
        );

        emit PermitDeposit(msg.sender, amount, powerTrade);
        emit PermitDeposit(msg.sender, secondAmount, secondRecipient);
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

    /// @notice Withdraw funds to a single user
    /// @param user The address of the user
    /// @param amount The amount to withdraw in token units
    function withdraw(address user, uint256 amount) external onlyOwner nonReentrant whenNotPaused {
        if (amount < minimumWithdrawAmount) revert InvalidAmount();
        uint256 feeToApply = whitelist[user] ? 0 : fee;
        uint256 amountAfterFee = amount - feeToApply;
        uint256 availableBalance = useFeesForWithdrawals ? token.balanceOf(address(this)) : token.balanceOf(address(this)) - collectedFees;
        if (availableBalance < amountAfterFee) revert InsufficientBalance();
        token.safeTransfer(user, amountAfterFee);
        if (!whitelist[user]) {
            collectedFees += feeToApply;
        }
        emit Withdraw(user, amountAfterFee);
    }

    /// @notice Batch withdraw funds to multiple users
    /// @param users The addresses of the users
    /// @param amounts The amounts to withdraw to each user in token units
    function batchWithdraw(
        address[] calldata users, 
        uint256[] calldata amounts
    ) external onlyOwner nonReentrant whenNotPaused {
        if (users.length != amounts.length) revert AmountMismatch();
        
        // Cache storage variables
        uint256 minWithdrawAmount = minimumWithdrawAmount;
        uint256 feeAmount = fee;
        uint256 totalAmount;
        uint256 totalFees;
        
        // Calculate amounts after fees and total amount needed
        uint256[] memory amountsAfterFee = new uint256[](amounts.length);
        for (uint256 i = 0; i < amounts.length; i++) {
            if (amounts[i] < minWithdrawAmount) revert InvalidAmount();
            
            uint256 feeToApply = whitelist[users[i]] ? 0 : feeAmount;
            amountsAfterFee[i] = amounts[i] - feeToApply;
            totalAmount += amounts[i];
            totalFees += feeToApply;
        }

        // Check available balance
        uint256 availableBalance = useFeesForWithdrawals ? 
            token.balanceOf(address(this)) : 
            token.balanceOf(address(this)) - collectedFees;
        if (availableBalance < totalAmount - totalFees) revert InsufficientBalance();

        // Perform transfers
        for (uint256 i = 0; i < users.length; i++) {
            token.safeTransfer(users[i], amountsAfterFee[i]);
        }

        collectedFees += totalFees;
        emit BatchWithdraw(users, amounts, amountsAfterFee);
    }

    /// @notice Collect accumulated fees
    function collectFees() external onlyOwner {
        uint256 feesToCollect = collectedFees;
        collectedFees = 0;
        token.safeTransfer(msg.sender, feesToCollect);
    }

    /// @notice Set the powerTrade account address
    /// @param _powerTrade The address of the powerTrade account
    function setPowerTrade(address _powerTrade) external onlyOwner {
        require(_powerTrade != address(0), "Invalid address");
        powerTrade = _powerTrade;
    }

    /// @notice Get the contract's token balance minus collected fees
    /// @return The token balance of the contract minus collected fees
    function getBalance() external view returns (uint256) {
        return useFeesForWithdrawals ? token.balanceOf(address(this)) : token.balanceOf(address(this)) - collectedFees;
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

    function swapExactTokenForPt(
        address market,
        uint256 minPtOut,
        TokenInput calldata input
    ) external nonReentrant whenNotPaused returns (uint256 netPtOut) {
        // Convert calldata to memory
        TokenInput memory inputMemory = createTokenInputStruct(input.tokenIn, input.netTokenIn);

        // Approve router to spend the input token if not already approved
        IERC20(inputMemory.tokenIn).approve(address(PENDLE_ROUTER), inputMemory.netTokenIn);
        
        // Execute the swap
        (netPtOut, , ) = PENDLE_ROUTER.swapExactTokenForPt(
            address(this),    // recipient
            market,          // market address
            minPtOut,       // minimum PT tokens to receive
            defaultApprox,  // slippage approximation
            inputMemory,    // input token details
            emptyLimit      // output limits
        );

        emit PtSwapped(msg.sender, inputMemory.netTokenIn, netPtOut);
    }

    function depositAndSwapUSDC(
        uint256 amount,
        address to,
        bytes calldata transactionData
    ) external nonReentrant whenNotPaused {
        require(amount > 0, "Amount must be greater than zero");
        address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

        // Transfer USDC from the sender to this contract
        IERC20(usdc).transferFrom(msg.sender, address(this), amount);

        // Check current allowance
        uint256 currentAllowance = IERC20(usdc).allowance(address(this), to);

        // Approve unlimited if current allowance is less than amount
        if (currentAllowance < amount) {
            IERC20(usdc).approve(to, type(uint256).max);
        }

        // Execute the transaction
        (bool success, ) = to.call(transactionData);
        require(success, "Transaction failed");
    }

    /// @notice Deposit synthetic balance using permit with multiple transfers
    /// @param amount The total amount to deposit
    /// @param deadline The permit deadline
    /// @param nonce The permit nonce
    /// @param permitTransferFrom The permit transfer details
    /// @param signature The permit signature
    /// @param recipients The addresses of the recipients
    /// @param amounts The amounts to transfer to each recipient
    function permitDepositWithMultipleTransfers(
        uint256 amount,
        uint256 deadline,
        uint256 nonce,
        bytes calldata permitTransferFrom,
        bytes calldata signature,
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external nonReentrant whenNotPaused {
        if (recipients.length != amounts.length) revert AmountMismatch();
        if (block.timestamp > deadline) revert PermitExpired();

        (address permittedToken, uint256 permitAmount) = abi.decode(permitTransferFrom, (address, uint256));
        if (permittedToken != address(token)) revert InvalidToken();
        if (permitAmount != amount) revert AmountMismatch();

        ISignatureTransfer.SignatureTransferDetails[] memory transferDetails = new ISignatureTransfer.SignatureTransferDetails[](recipients.length);
        ISignatureTransfer.TokenPermissions[] memory permissions = new ISignatureTransfer.TokenPermissions[](recipients.length);

        for (uint256 i = 0; i < recipients.length; i++) {
            transferDetails[i] = ISignatureTransfer.SignatureTransferDetails({
                to: recipients[i],
                requestedAmount: amounts[i]
            });
            permissions[i] = ISignatureTransfer.TokenPermissions({
                token: permittedToken,
                amount: amounts[i]
            });
        }

        ISignatureTransfer.PermitBatchTransferFrom memory permit = ISignatureTransfer.PermitBatchTransferFrom({
            permitted: permissions,
            nonce: nonce,
            deadline: deadline
        });

        // Proceed with the permit transfer
        permit2.permitTransferFrom(permit, transferDetails, msg.sender, signature);

        for (uint256 i = 0; i < recipients.length; i++) {
            emit PermitDeposit(msg.sender, amounts[i], recipients[i]);
        }
    }
}