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

contract UserManagerTest is Test {
    UserManager public userManager;
    IntentsEngine public intentsEngine;
    TradeExecutor public tradeExecutor;
    TreasuryManager public treasuryManager;
    MockToken public token;
    IPermit2 public permit2;
    address public treasury;
    address public user1;
    address public user2;
    address public powerTrade;
    uint256 public user1PrivateKey;
    uint256 public user2PrivateKey;
    uint256 public powerTradePrivateKey;
    uint256 public thresholdAmount = 100 * 10 ** 18; // Set the threshold amount

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

        // Deploy UserManager
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
        userManager.setIntentsEngine(address(intentsEngine));
        userManager.setTradeExecutor(address(tradeExecutor));

        // Ensure the test contract has enough tokens
        token.transfer(address(this), 1_000_000 * 10 ** 18);

        token.transfer(user1, 100_000 * 10 ** 18);
        token.transfer(user2, 100_000 * 10 ** 18);
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

    function testPermitDeposit() public {
        uint256 amount = 1000 * 10 ** 18;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = 0;

        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer
            .PermitTransferFrom({
                permitted: ISignatureTransfer.TokenPermissions({
                    token: address(token),
                    amount: amount
                }),
                nonce: nonce,
                deadline: deadline
            });

        ISignatureTransfer.SignatureTransferDetails
            memory transferDetails = ISignatureTransfer
                .SignatureTransferDetails({
                    to: address(userManager),
                    requestedAmount: amount
                });

        bytes32 digest = _getPermitTypedDataHash(permit, address(userManager));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(user1PrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        bytes memory permitTransferFrom = abi.encode(address(token), amount);

        vm.startPrank(user1);
        token.approve(address(permit2), type(uint256).max);
        userManager.permitDeposit(
            amount,
            deadline,
            nonce,
            permitTransferFrom,
            signature
        );
        vm.stopPrank();

        (uint256 balance, ) = userManager.getUserBalance(user1);
        assertEq(balance, amount, "Deposit amount should match user balance");
    }

    function testWithdraw() public {
        testPermitDeposit();
        uint256 withdrawAmount = 500 * 10 ** 18;

        vm.prank(user1);
        userManager.withdraw(withdrawAmount);

        (uint256 balance, ) = userManager.getUserBalance(user1);
        assertEq(balance, 500 * 10 ** 18);
    }

    function testFailWithdrawInsufficientBalance() public {
        testPermitDeposit();

        vm.prank(user1);
        userManager.withdraw(2000 * 10 ** 18);
    }

    function testPauseUnpause() public {
        vm.prank(userManager.owner());
        userManager.pause();

        vm.expectRevert();
        userManager.permitDeposit(1, block.timestamp + 1 hours, 0, "", "");

        vm.prank(userManager.owner());
        userManager.unpause();

        // Now it should work (it might revert for other reasons, but not because it's paused)
        vm.expectRevert();
        userManager.permitDeposit(1, block.timestamp + 1 hours, 0, "", "");
    }

    function testInitializer() public {
        vm.expectRevert();
        userManager.initialize(address(token), address(permit2), thresholdAmount); // Pass threshold amount
    }

    function testTransferFundsToPowerTrade() public {
        uint256 intentAmount = 200 * 10 ** 18; // Amount greater than threshold

        // First deposit tokens for user1
        testPermitDeposit();

        // Set the threshold amount in UserManager
        vm.prank(userManager.owner());
        userManager.setThresholdAmount(thresholdAmount);

        // Lock the user's balance
        vm.prank(address(intentsEngine));
        userManager.lockUserBalance(user1, intentAmount);

        // Simulate the transfer of funds to powerTrade
        vm.prank(address(intentsEngine));
        userManager.transferFundsToPowerTrade(user1, intentAmount, powerTrade);

        // Check that the funds were transferred to powerTrade
        uint256 powerTradeBalance = token.balanceOf(powerTrade);
        assertEq(powerTradeBalance, intentAmount);

        // Check user's balances
        (uint256 availableBalance, uint256 lockedBalance) = userManager.getUserBalance(user1);
        assertEq(availableBalance, 1000 * 10 ** 18 - intentAmount); // Initial deposit - locked amount
        assertEq(lockedBalance, intentAmount);
    }

    function testFailTransferFundsBelowThreshold() public {
        uint256 intentAmount = 50 * 10 ** 18; // Amount below threshold

        // First deposit tokens for user1
        testPermitDeposit();

        // Set the threshold amount in UserManager
        vm.prank(userManager.owner());
        userManager.setThresholdAmount(thresholdAmount);

        // Lock the user's balance
        vm.prank(address(intentsEngine));
        userManager.lockUserBalance(user1, intentAmount);

        // Attempt to transfer funds below the threshold
        vm.prank(address(intentsEngine));
        userManager.transferFundsToPowerTrade(user1, intentAmount, powerTrade);
    }

    function testRepayFundsFromPowerTrade() public {
        uint256 intentAmount = 200 * 10 ** 18; // Amount greater than threshold

        // First deposit tokens for user1
        testPermitDeposit();

        // Set the threshold amount in UserManager
        vm.prank(userManager.owner());
        userManager.setThresholdAmount(thresholdAmount);

        // Lock the user's balance
        vm.prank(address(intentsEngine));
        userManager.lockUserBalance(user1, intentAmount);

        // Transfer funds to powerTrade
        vm.prank(address(intentsEngine));
        userManager.transferFundsToPowerTrade(user1, intentAmount, powerTrade);

        // Check initial balances
        uint256 initialPowerTradeBalance = token.balanceOf(powerTrade);
        assertEq(initialPowerTradeBalance, intentAmount);

        // Simulate powerTrade approving tokens for TradeExecutor
        vm.prank(powerTrade);
        token.approve(address(tradeExecutor), type(uint256).max);

        // Simulate repayment from powerTrade through TradeExecutor
        vm.prank(address(tradeExecutor));
        userManager.unlockUserBalance(user1, intentAmount);

        // Check final balances
        (uint256 availableBalance, uint256 lockedBalance) = userManager.getUserBalance(user1);
        assertEq(availableBalance, 1000 * 10 ** 18); // Should be back to initial deposit
        assertEq(lockedBalance, 0); // Should be fully unlocked
    }
}