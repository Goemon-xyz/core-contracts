// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/UserManager.sol";
import "../src/IntentsEngine.sol";
import "../src/TradeExecutor.sol";
import "../src/TreasuryManager.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "permit2/src/interfaces/IPermit2.sol";
import "permit2/src/libraries/PermitHash.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract MockToken is ERC20 {
    constructor() ERC20("Mock Token", "MTK") {
        _mint(msg.sender, 1_000_000 * 10 ** 18);
    }
}

contract TradeExecutorTest is Test {
    UserManager public userManager;
    IntentsEngine public intentsEngine;
    TradeExecutor public tradeExecutor;
    TreasuryManager public treasuryManager;
    MockToken public token;
    IPermit2 public permit2;
    address public treasury;
    address public user1;
    address public user2;
    uint256 public user1PrivateKey;
    uint256 public user2PrivateKey;
    uint256 public thresholdAmount = 100 * 10 ** 18; // Lower threshold for testing
    uint48 public nonce; // State variable for nonce
    address public powerTrade; // Add powerTrade address
    uint256 public powerTradePrivateKey;

    function setUp() public {
        token = new MockToken();
        treasury = address(0xe3A9A99347e771735eaDf4DF7f6fF0D4f2Edb61B);
        permit2 = IPermit2(address(0x000000000022D473030F116dDEE9F6B43aC78BA3));

        // Create accounts with private keys
        user1PrivateKey = 0xA11CE;
        user2PrivateKey = 0xB0B;
        powerTradePrivateKey = 0xC0C0A;
        user1 = vm.addr(user1PrivateKey);
        user2 = vm.addr(user2PrivateKey);
        powerTrade = vm.addr(powerTradePrivateKey);

        // Deploy UserManager with threshold
        UserManager userManagerImpl = new UserManager();
        bytes memory userManagerInitData = abi.encodeWithSelector(
            UserManager.initialize.selector,
            address(token),
            address(permit2),
            thresholdAmount // Pass the threshold amount here
        );
        ERC1967Proxy userManagerProxy = new ERC1967Proxy(
            address(userManagerImpl),
            userManagerInitData
        );    
        userManager = UserManager(address(userManagerProxy));

        // Deploy IntentsEngine
        IntentsEngine intentsEngineImpl = new IntentsEngine();
        bytes memory intentsEngineInitData = abi.encodeWithSelector(
            IntentsEngine.initialize.selector,
            address(userManager)
        );
        ERC1967Proxy intentsEngineProxy = new ERC1967Proxy(
            address(intentsEngineImpl),
            intentsEngineInitData
        );
        intentsEngine = IntentsEngine(address(intentsEngineProxy));

        // Deploy TreasuryManager
        TreasuryManager treasuryManagerImpl = new TreasuryManager();
        bytes memory treasuryManagerInitData = abi.encodeWithSelector(
            TreasuryManager.initialize.selector,
            treasury
        );
        ERC1967Proxy treasuryManagerProxy = new ERC1967Proxy(
            address(treasuryManagerImpl),
            treasuryManagerInitData
        );
        treasuryManager = TreasuryManager(address(treasuryManagerProxy));

        // Deploy TradeExecutor
        TradeExecutor tradeExecutorImpl = new TradeExecutor();
        bytes memory tradeExecutorInitData = abi.encodeWithSelector(
            TradeExecutor.initialize.selector,
            address(userManager),
            address(intentsEngine),
            address(treasuryManager),
            address(token)
        );
        ERC1967Proxy tradeExecutorProxy = new ERC1967Proxy(
            address(tradeExecutorImpl),
            tradeExecutorInitData
        );
        tradeExecutor = TradeExecutor(address(tradeExecutorProxy));

        // Set up connections between contracts
        vm.startPrank(userManager.owner());
        userManager.setIntentsEngine(address(intentsEngine));
        userManager.setTradeExecutor(address(tradeExecutor));
        vm.stopPrank();

        vm.prank(intentsEngine.owner());
        intentsEngine.setTradeExecutor(address(tradeExecutor));

        // Ensure the test contract has enough tokens
        token.transfer(address(this), 1_000_000 * 10 ** 18);

        token.transfer(user1, 100_000 * 10 ** 18);
        token.transfer(user2, 100_000 * 10 ** 18);

        // Deposit tokens for users
        depositTokens(user1, user1PrivateKey, 10_000 * 10 ** 18);
        depositTokens(user2, user2PrivateKey, 10_000 * 10 ** 18);
        depositTokens(powerTrade, powerTradePrivateKey, 1_000 * 10 ** 18);

        // Submit intents for users with powerTrade address
        submitIntentCall(user1, 50 * 10 ** 18, "BUY", bytes("test"),powerTrade);
        submitIntentCall(user2, 50 * 10 ** 18, "SELL", bytes("test"),powerTrade);
    }

    function _getPermitTypedDataHash(
        ISignatureTransfer.PermitTransferFrom memory permit,
        address spender
    ) internal view returns (bytes32) {
        bytes32 PERMIT_TRANSFER_FROM_TYPEHASH = keccak256(
            "PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"
        );

        bytes32 tokenPermissionsHash = keccak256(
            abi.encode(
                keccak256("TokenPermissions(address token,uint256 amount)"),
                permit.permitted.token,
                permit.permitted.amount
            )
        );

        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_TRANSFER_FROM_TYPEHASH,
                tokenPermissionsHash,
                spender,
                permit.nonce,
                permit.deadline
            )
        );

        bytes32 DOMAIN_SEPARATOR = permit2.DOMAIN_SEPARATOR();

        return
            keccak256(
                abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash)
            );
    }

    function depositTokens(
        address user,
        uint256 privateKey,
        uint256 amount
    ) internal {
        uint256 deadline = block.timestamp + 1 hours;

        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer
            .PermitTransferFrom({
                permitted: ISignatureTransfer.TokenPermissions({
                    token: address(token),
                    amount: amount
                }),
                nonce: nonce, // Use the current nonce
                deadline: deadline
            });

        ISignatureTransfer.SignatureTransferDetails
            memory transferDetails = ISignatureTransfer
                .SignatureTransferDetails({
                    to: address(userManager),
                    requestedAmount: amount
                });

        bytes32 digest = _getPermitTypedDataHash(permit, address(userManager));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        bytes memory permitTransferFrom = abi.encode(address(token), amount);

        vm.startPrank(user);
        token.approve(address(permit2), type(uint256).max);
        userManager.permitDeposit(
            amount,
            deadline,
            nonce,
            permitTransferFrom,
            signature
        );
        vm.stopPrank();

        nonce++; // Increment the nonce after each deposit
    }

    function submitIntentCall(
        address user,
        uint256 amount,
        string memory intentType,
        bytes memory metadata,
        address _powerTrade
    ) internal {
        vm.prank(user);
        intentsEngine.submitIntent(amount, intentType, metadata, _powerTrade);
    }

    function testSettleIntent() public {
        vm.prank(tradeExecutor.owner());
        tradeExecutor.settleIntent(user1, 0, 50 * 10 ** 18, powerTrade);

        (uint256 availableBalance, uint256 lockedBalance) = userManager
            .getUserBalance(user1);
        assertEq(availableBalance, 10050 * 10 ** 18);
        assertEq(lockedBalance, 0);

        IIntentsEngine.Intent[] memory intents = intentsEngine.getUserIntents(
            user1
        );
        assertEq(intents[0].isExecuted, true);
    }

    function testBatchSettleIntents() public {
        address[] memory users = new address[](2);
        users[0] = user1;
        users[1] = user2;

        uint256[] memory intentIndices = new uint256[](2);
        intentIndices[0] = 0;
        intentIndices[1] = 0;

        int256[] memory pnls = new int256[](2);
        pnls[0] = 50 * 10 ** 18;
        pnls[1] = -25 * 10 ** 18;

        vm.prank(tradeExecutor.owner());
        tradeExecutor.batchSettleIntents(users, intentIndices, pnls, powerTrade);

        (uint256 user1Balance, uint256 user1LockedBalance) = userManager
            .getUserBalance(user1);
        (uint256 user2Balance, uint256 user2LockedBalance) = userManager
            .getUserBalance(user2);

        assertEq(user1Balance, 10050 * 10 ** 18);
        assertEq(user1LockedBalance, 0);
        assertEq(user2Balance, 9975 * 10 ** 18);
        assertEq(user2LockedBalance, 0);

        IIntentsEngine.Intent[] memory user1Intents = intentsEngine
            .getUserIntents(user1);
        IIntentsEngine.Intent[] memory user2Intents = intentsEngine
            .getUserIntents(user2);

        assertEq(user1Intents[0].isExecuted, true);
        assertEq(user2Intents[0].isExecuted, true);
    }

    function testFailSettleIntentNonOwner() public {
        vm.prank(user2);
        tradeExecutor.settleIntent(user1, 0, 50 * 10 ** 18, powerTrade);
    }

    function testFailBatchSettleIntentsNonOwner() public {
        address[] memory users = new address[](1);
        users[0] = user1;

        uint256[] memory intentIndices = new uint256[](1);
        intentIndices[0] = 0;

        int256[] memory pnls = new int256[](1);
        pnls[0] = 50 * 10 ** 18;

        vm.prank(user2);
        tradeExecutor.batchSettleIntents(users, intentIndices, pnls, powerTrade);
    }

    function testFailSettleIntentInvalidIndex() public {
        vm.prank(tradeExecutor.owner());
        tradeExecutor.settleIntent(user1, 1, 50 * 10 ** 18, powerTrade);
    }

    function testFailSettleExecutedIntent() public {
        vm.startPrank(tradeExecutor.owner());
        tradeExecutor.settleIntent(user1, 0, 50 * 10 ** 18, powerTrade);
        tradeExecutor.settleIntent(user1, 0, 50 * 10 ** 18, powerTrade);
        vm.stopPrank();
    }

    function testFailBatchSettleIntentsMismatchedArrays() public {
        address[] memory users = new address[](2);
        users[0] = user1;
        users[1] = user2;

        uint256[] memory intentIndices = new uint256[](2);
        intentIndices[0] = 0;
        intentIndices[1] = 0;

        int256[] memory pnls = new int256[](1);
        pnls[0] = 50 * 10 ** 18;

        vm.prank(tradeExecutor.owner());
        tradeExecutor.batchSettleIntents(users, intentIndices, pnls, powerTrade);
    }

    function testFailBatchSettleIntentsExceedMaxBatchSize() public {
        address[] memory users = new address[](101);
        uint256[] memory intentIndices = new uint256[](101);
        int256[] memory pnls = new int256[](101);

        for (uint256 i = 0; i < 101; i++) {
            users[i] = address(uint160(i + 1));
            intentIndices[i] = 0;
            pnls[i] = 0;
        }

        vm.prank(tradeExecutor.owner());
        tradeExecutor.batchSettleIntents(users, intentIndices, pnls, powerTrade);
    }

    function testSettleIntentRepayFundsFromPowerTrade() public {
        uint256 intentAmount = 150 * 10 ** 18; // Amount greater than threshold (100)
        submitIntentCall(user1, intentAmount, "BUY", bytes("test"),powerTrade);

        // Check that the funds were transferred to powerTrade
        uint256 powerTradeInitialBalance = token.balanceOf(powerTrade);
        assertEq(powerTradeInitialBalance, intentAmount);

        // Simulate powerTrade approving TradeExecutor to spend tokens
        vm.prank(powerTrade);
        token.approve(address(tradeExecutor), type(uint256).max);

        // Settle the intent with a profit
        vm.prank(tradeExecutor.owner());
        tradeExecutor.settleIntent(user1, 1, 50 * 10 ** 18, powerTrade);

        // Check that the user's balance is updated correctly
        (uint256 availableBalance, uint256 lockedBalance) = userManager.getUserBalance(user1);
        assertEq(availableBalance, 9900 * 10 ** 18); // Initial - intentAmount + profit
        assertEq(lockedBalance, 0);

        // Check powerTrade's final balance
        uint256 powerTradeFinalBalance = token.balanceOf(powerTrade);
        assertEq(powerTradeFinalBalance, 0);
    }

    function testSettleIntentDoesNotRepayIfAmountIsBelowThreshold() public {
        uint256 intentAmount = 50 * 10 ** 18; // Amount below threshold (100)
        submitIntentCall(user1, intentAmount, "BUY", bytes("test"),powerTrade);

        // Check that no funds were transferred to powerTrade
        uint256 powerTradeBalance = token.balanceOf(powerTrade);
        assertEq(powerTradeBalance, 1000 * 10 ** 18);

        // Settle the intent with a profit
        vm.prank(tradeExecutor.owner());
        tradeExecutor.settleIntent(user1, 0, 50 * 10 ** 18, powerTrade);

        // Check that the user's balance is updated correctly
        (uint256 availableBalance, uint256 lockedBalance) = userManager.getUserBalance(user1);
        assertEq(availableBalance, 10050 * 10 ** 18); // Initial + profit
        assertEq(lockedBalance, 0);

        // Verify powerTrade balance hasn't changed
        assertEq(token.balanceOf(powerTrade), 0);
    }
}