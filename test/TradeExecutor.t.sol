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

    function setUp() public {
        token = new MockToken();
        treasury = address(0xe3A9A99347e771735eaDf4DF7f6fF0D4f2Edb61B);
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
            address(treasuryManager)
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

        // Submit intents for users
        submitIntent(user1, 500 * 10 ** 18, "BUY");
        submitIntent(user2, 500 * 10 ** 18, "SELL");
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
        userManager.permitDeposit(
            uint160(amount),
            deadline,
            nonce,
            signature,
            ""
        );
        vm.stopPrank();
    }

    function submitIntent(
        address user,
        uint256 amount,
        string memory intentType
    ) internal {
        vm.prank(user);
        intentsEngine.submitIntent(amount, intentType, bytes("test"));
    }

    function testSettleIntent() public {
        vm.prank(tradeExecutor.owner());
        tradeExecutor.settleIntent(user1, 0, 50 * 10 ** 18);

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
        tradeExecutor.batchSettleIntents(users, intentIndices, pnls);

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
        tradeExecutor.settleIntent(user1, 0, 50 * 10 ** 18);
    }

    function testFailBatchSettleIntentsNonOwner() public {
        address[] memory users = new address[](1);
        users[0] = user1;

        uint256[] memory intentIndices = new uint256[](1);
        intentIndices[0] = 0;

        int256[] memory pnls = new int256[](1);
        pnls[0] = 50 * 10 ** 18;

        vm.prank(user2);
        tradeExecutor.batchSettleIntents(users, intentIndices, pnls);
    }

    function testFailSettleIntentInvalidIndex() public {
        vm.prank(tradeExecutor.owner());
        tradeExecutor.settleIntent(user1, 1, 50 * 10 ** 18);
    }

    function testFailSettleExecutedIntent() public {
        vm.startPrank(tradeExecutor.owner());
        tradeExecutor.settleIntent(user1, 0, 50 * 10 ** 18);
        tradeExecutor.settleIntent(user1, 0, 50 * 10 ** 18);
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
        tradeExecutor.batchSettleIntents(users, intentIndices, pnls);
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
        tradeExecutor.batchSettleIntents(users, intentIndices, pnls);
    }
}
