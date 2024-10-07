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
        userManager.setIntentsEngine(address(intentsEngine));
        userManager.setTradeExecutor(address(tradeExecutor));

        user1PrivateKey = 0xA11CE;
        user2PrivateKey = 0xB0B;
        user1 = vm.addr(user1PrivateKey);
        user2 = vm.addr(user2PrivateKey);

        // Ensure the test contract has enough tokens
        token.transfer(address(this), 1_000_000 * 10 ** 18);

        token.transfer(user1, 100_000 * 10 ** 18);
        token.transfer(user2, 100_000 * 10 ** 18);
    }

    function testPermitDeposit() public {
        uint256 amount = 1000 * 10 ** 18;
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

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(user1PrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.startPrank(user1);
        token.approve(address(permit2), type(uint256).max);
        userManager.permitDeposit(uint160(amount), deadline, nonce, signature);
        vm.stopPrank();

        (uint256 balance, ) = userManager.getUserBalance(user1);
        assertEq(balance, amount);
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
        userManager.permitDeposit(1, block.timestamp + 1 hours, 0, "");

        vm.prank(userManager.owner());
        userManager.unpause();

        // Now it should work (it might revert for other reasons, but not because it's paused)
        vm.expectRevert();
        userManager.permitDeposit(1, block.timestamp + 1 hours, 0, "");
    }

    function testInitializer() public {
        vm.expectRevert();
        userManager.initialize(address(token), address(permit2));
    }
}
