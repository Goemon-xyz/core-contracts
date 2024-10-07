// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/UserManager.sol";
import "../src/IntentsEngine.sol";
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
    MockToken public token;
    IPermit2 public permit2;
    address public user1;
    address public user2;
    uint256 public user1PrivateKey;
    uint256 public user2PrivateKey;

    function setUp() public {
        token = new MockToken();
        permit2 = IPermit2(address(0x000000000022D473030F116dDEE9F6B43aC78BA3));

        // Deploy UserManager
        UserManager userManagerImpl = new UserManager();
        bytes memory userManagerInitData = abi.encodeWithSelector(
            UserManager.initialize.selector,
            address(token),
            address(permit2)
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

        // Set up connections between contracts
        userManager.setIntentsEngine(address(intentsEngine));

        user1PrivateKey = 0xA11CE;
        user2PrivateKey = 0xB0B;
        user1 = vm.addr(user1PrivateKey);
        user2 = vm.addr(user2PrivateKey);

        // Ensure the test contract has enough tokens
        token.transfer(address(this), 1_000_000 * 10 ** 18);

        token.transfer(user1, 100_000 * 10 ** 18);
        token.transfer(user2, 100_000 * 10 ** 18);

        // Deposit tokens for users
        depositTokens(user1, user1PrivateKey, 10_000 * 10 ** 18);
        depositTokens(user2, user2PrivateKey, 10_000 * 10 ** 18);
    }

    function depositTokens(
        address user,
        uint256 privateKey,
        uint256 amount
    ) internal {
        uint256 deadline = block.timestamp + 1 hours;
        uint48 nonce = 0;

        IAllowanceTransfer.PermitDetails memory details = IAllowanceTransfer
            .PermitDetails({
                token: address(token),
                amount: uint160(amount),
                expiration: uint48(deadline),
                nonce: nonce
            });

        IAllowanceTransfer.PermitSingle memory permitSingle = IAllowanceTransfer
            .PermitSingle({
                details: details,
                spender: address(userManager),
                sigDeadline: deadline
            });

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                permit2.DOMAIN_SEPARATOR(),
                PermitHash.hash(permitSingle)
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.startPrank(user);
        token.approve(address(permit2), type(uint256).max);
        userManager.permitDeposit(uint160(amount), deadline, nonce, signature);
        vm.stopPrank();
    }

    function testSubmitIntent() public {
        uint256 intentAmount = 500 * 10 ** 18;

        vm.prank(user1);
        intentsEngine.submitIntent(intentAmount, "BUY");

        (uint256 availableBalance, uint256 lockedBalance) = userManager
            .getUserBalance(user1);
        assertEq(availableBalance, 9500 * 10 ** 18);
        assertEq(lockedBalance, 500 * 10 ** 18);

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
        intentsEngine.submitIntent(intentAmount, "BUY");
    }

    function testSetMaxIntentsPerUser() public {
        uint256 newMax = 5;

        vm.prank(intentsEngine.owner());
        intentsEngine.setMaxIntentsPerUser(newMax);

        vm.startPrank(user1);
        for (uint256 i = 0; i < newMax; i++) {
            intentsEngine.submitIntent(1 * 10 ** 18, "BUY");
        }

        // This should revert
        vm.expectRevert("Max intents limit reached");
        intentsEngine.submitIntent(1 * 10 ** 18, "BUY");

        vm.stopPrank();
    }

    function testGetUserIntents() public {
        vm.startPrank(user1);
        intentsEngine.submitIntent(100 * 10 ** 18, "BUY");
        intentsEngine.submitIntent(200 * 10 ** 18, "SELL");
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
        intentsEngine.submitIntent(100 * 10 ** 18, "BUY");

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
        intentsEngine.submitIntent(100 * 10 ** 18, "BUY");

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
        intentsEngine.submitIntent(100 * 10 ** 18, "BUY");

        vm.prank(intentsEngine.owner());
        intentsEngine.unpause();

        vm.prank(user1);
        intentsEngine.submitIntent(100 * 10 ** 18, "BUY");
    }
}
