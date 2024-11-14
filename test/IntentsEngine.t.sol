// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/UserManager.sol";
import "../src/IntentsEngine.sol";
import "../src/TradeExecutor.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "permit2/src/interfaces/IPermit2.sol";
import "permit2/src/libraries/PermitHash.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract MockToken is ERC20 {
    constructor() ERC20("Mock Token", "MTK") {
        _mint(msg.sender, 1_000_000 * 10 ** 18);
    }
}

contract IntentsEngineTest is Test {
    UserManager public userManager;
    IntentsEngine public intentsEngine;
    TradeExecutor public tradeExecutor;
    MockToken public token;
    IPermit2 public permit2;
    address public treasury;
    address public user1;
    address public user2;
    address public powerTrade;
    uint256 public user1PrivateKey;
    uint256 public user2PrivateKey;
    uint256 public powerTradePrivateKey;
    uint256 public thresholdAmount = 100 * 10 ** 18; // Lower threshold for testing
    uint48 public nonce; // State variable for nonce

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

        // Deploy TradeExecutor
        TradeExecutor tradeExecutorImpl = new TradeExecutor();
        bytes memory tradeExecutorInitData = abi.encodeWithSelector(
            TradeExecutor.initialize.selector,
            address(userManager),
            address(intentsEngine),
            treasury,
            token
        );
        ERC1967Proxy tradeExecutorProxy = new ERC1967Proxy(
            address(tradeExecutorImpl),
            tradeExecutorInitData
        );
        tradeExecutor = TradeExecutor(address(tradeExecutorProxy));

        // Set up connections between contracts
        userManager.setIntentsEngine(address(intentsEngine));
        userManager.setTradeExecutor(address(tradeExecutor));

        // Ensure the test contract has enough tokens
        token.transfer(address(this), 1_000_000 * 10 ** 18);

        token.transfer(user1, 100_000 * 10 ** 18);
        token.transfer(user2, 100_000 * 10 ** 18);

        // Deposit tokens for users
        depositTokens(user1, user1PrivateKey, 10_000 * 10 ** 18);
        depositTokens(user2, user2PrivateKey, 10_000 * 10 ** 18);
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

    function testSubmitIntent() public {
        uint256 intentAmount = 50 * 10 ** 18; // Below threshold

        vm.prank(user1);
        intentsEngine.submitIntent(intentAmount, "BUY", bytes("test"), powerTrade);

        (uint256 availableBalance, uint256 lockedBalance) = userManager
            .getUserBalance(user1);
        assertEq(availableBalance, 9950 * 10 ** 18);
        assertEq(lockedBalance, 50 * 10 ** 18);

        IIntentsEngine.Intent[] memory intents = intentsEngine.getUserIntents(
            user1
        );
        assertEq(intents.length, 1);
        assertEq(intents[0].amount, intentAmount);
        assertEq(intents[0].intentType, "BUY");
        assertEq(intents[0].isExecuted, false);
    }

    function testFailSubmitIntentInsufficientBalance() public {
        uint256 intentAmount = 20_000 * 10 ** 18;

        vm.prank(user1);
        intentsEngine.submitIntent(intentAmount, "BUY", bytes("test"), powerTrade);
    }

    function testSetMaxIntentsPerUser() public {
        uint256 newMax = 5;

        vm.prank(intentsEngine.owner());
        intentsEngine.setMaxIntentsPerUser(newMax);

        vm.startPrank(user1);
        for (uint256 i = 0; i < newMax; i++) {
            intentsEngine.submitIntent(1 * 10 ** 18, "BUY", bytes("test"), powerTrade);
        }

        // This should revert
        vm.expectRevert("Max intents limit reached");
        intentsEngine.submitIntent(1 * 10 ** 18, "BUY", bytes("test"), powerTrade);

        vm.stopPrank();
    }

    function testGetUserIntents() public {
        vm.startPrank(user1);
        intentsEngine.submitIntent(100 * 10 ** 18, "BUY", bytes("test"), powerTrade);
        intentsEngine.submitIntent(200 * 10 ** 18, "SELL", bytes("test"), powerTrade);
        vm.stopPrank();

        IIntentsEngine.Intent[] memory intents = intentsEngine.getUserIntents(
            user1
        );
        assertEq(intents.length, 2);
        assertEq(intents[0].amount, 100 * 10 ** 18);
        assertEq(intents[0].intentType, "BUY");
        assertEq(intents[1].amount, 200 * 10 ** 18);
        assertEq(intents[1].intentType, "SELL");
    }

    function testMarkIntentAsExecuted() public {
        vm.prank(user1);
        intentsEngine.submitIntent(100 * 10 ** 18, "BUY", bytes("test"), powerTrade);

        // Simulate TradeExecutor calling markIntentAsExecuted
        vm.prank(address(userManager));
        intentsEngine.markIntentAsExecuted(user1, 0);

        IIntentsEngine.Intent[] memory intents = intentsEngine.getUserIntents(
            user1
        );
        assertEq(intents[0].isExecuted, true);
    }

    function testFailMarkIntentAsExecutedUnauthorized() public {
        vm.prank(user1);
        intentsEngine.submitIntent(100 * 10 ** 18, "BUY", bytes("test"), powerTrade);

        // This should fail because the caller is not the UserManager
        vm.prank(user2);
        intentsEngine.markIntentAsExecuted(user1, 0);
    }

    function testPauseUnpause() public {
        vm.prank(intentsEngine.owner());
        intentsEngine.pause();

        vm.expectRevert(
            abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector)
        );
        vm.prank(user1);
        intentsEngine.submitIntent(100 * 10 ** 18, "BUY", bytes("test"), powerTrade);

        vm.prank(intentsEngine.owner());
        intentsEngine.unpause();

        vm.prank(user1);
        intentsEngine.submitIntent(100 * 10 ** 18, "BUY", bytes("test"), powerTrade);
    }

    function testSubmitIntentTransferFundsToPowerTrade() public {
        uint256 intentAmount = 150 * 10 ** 18; // Amount greater than threshold (100)

        vm.prank(user2);
        intentsEngine.submitIntent(intentAmount, "BUY", bytes("test"), powerTrade);

        // Check that the user's locked balance is updated
        (uint256 availableBalance, uint256 lockedBalance) = userManager.getUserBalance(user2);
        assertEq(availableBalance, 9850 * 10 ** 18); // 10,000 - 150
        assertEq(lockedBalance, 150 * 10 ** 18); // 150 locked

        // Check that the funds were transferred to the powerTrade
        uint256 powerTradeBalance = token.balanceOf(powerTrade);
        assertEq(powerTradeBalance, 150 * 10 ** 18); // 150 transferred
    }

    function testSubmitIntentDoesNotTransferFundsBelowThreshold() public {
        uint256 intentAmount = 50 * 10 ** 18; // Amount below threshold (100)

        vm.prank(user2);
        intentsEngine.submitIntent(intentAmount, "BUY", bytes("test"), address(0));

        // Check that the user's locked balance is updated
        (uint256 availableBalance, uint256 lockedBalance) = userManager.getUserBalance(user2);
        assertEq(availableBalance, 9950 * 10 ** 18); // 10,000 - 50
        assertEq(lockedBalance, 50 * 10 ** 18); // 50 locked

        // Check that no funds were transferred to the powerTrade
        uint256 powerTradeBalance = token.balanceOf(powerTrade);
        assertEq(powerTradeBalance, 0); // No transfer
    }
}