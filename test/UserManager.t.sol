// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.26;

// import "forge-std/Test.sol";
// import "../src/UserManager.sol";
// import "../src/IntentsEngine.sol";
// import "../src/TradeExecutor.sol";
// import "../src/TreasuryManager.sol";
// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import "permit2/src/interfaces/IPermit2.sol";
// import "permit2/src/libraries/PermitHash.sol";
// import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

// contract MockToken is ERC20 {
//     constructor() ERC20("Mock Token", "MTK") {
//         _mint(msg.sender, 1_000_000 * 10 ** 18);
//     }
// }

// contract UserManagerTest is Test {
//     UserManager public userManager;
//     IntentsEngine public intentsEngine;
//     TradeExecutor public tradeExecutor;
//     TreasuryManager public treasuryManager;
//     MockToken public token;
//     IPermit2 public permit2;
//     address public treasury;
//     address public user1;
//     address public user2;
//     address public powerTrade;
//     uint256 public user1PrivateKey;
//     uint256 public user2PrivateKey;
//     uint256 public powerTradePrivateKey;
//     uint256 public thresholdAmount = 100 * 10 ** 18; // Set the threshold amount

//     function setUp() public {
//         // Deploy MockToken
//         token = new MockToken();
//         treasury = address(0xe3A9A99347e771735eaDf4DF7f6fF0D4f2Edb61B);
//         permit2 = IPermit2(address(0x000000000022D473030F116dDEE9F6B43aC78BA3));

//         // Create accounts with private keys
//         user1PrivateKey = 0xA11CE;
//         user2PrivateKey = 0xB0B;
//         powerTradePrivateKey = 0xC0C0A;
//         user1 = vm.addr(user1PrivateKey);
//         user2 = vm.addr(user2PrivateKey);
//         powerTrade = vm.addr(powerTradePrivateKey);

//         // Deploy UserManager
//         UserManager userManagerImpl = new UserManager();
//         bytes memory userManagerInitData = abi.encodeWithSelector(
//             UserManager.initialize.selector,
//             address(token),
//             address(permit2)
//         );
//         ERC1967Proxy userManagerProxy = new ERC1967Proxy(
//             address(userManagerImpl),
//             userManagerInitData
//         );
//         userManager = UserManager(address(userManagerProxy));

//         // Deploy IntentsEngine with globalThreshold
//         IntentsEngine intentsEngineImpl = new IntentsEngine();
//         bytes memory intentsEngineInitData = abi.encodeWithSelector(
//             IntentsEngine.initialize.selector,
//             address(userManager),
//             thresholdAmount // Pass the globalThreshold parameter
//         );
//         ERC1967Proxy intentsEngineProxy = new ERC1967Proxy(
//             address(intentsEngineImpl),
//             intentsEngineInitData
//         );
//         intentsEngine = IntentsEngine(address(intentsEngineProxy));

//         // Deploy TreasuryManagerw
         
//         TreasuryManager treasuryManagerImpl = new TreasuryManager();
//         bytes memory treasuryManagerInitData = abi.encodeWithSelector(
//             TreasuryManager.initialize.selector,
//             treasury
//         );
//         ERC1967Proxy treasuryManagerProxy = new ERC1967Proxy(
//             address(treasuryManagerImpl),
//             treasuryManagerInitData
//         );
//         treasuryManager = TreasuryManager(address(treasuryManagerProxy));

//         // Deploy TradeExecutor
//         TradeExecutor tradeExecutorImpl = new TradeExecutor();
//         bytes memory tradeExecutorInitData = abi.encodeWithSelector(
//             TradeExecutor.initialize.selector,
//             address(userManager),
//             address(intentsEngine),
//             address(treasuryManager),
//             address(token)
//         );
//         ERC1967Proxy tradeExecutorProxy = new ERC1967Proxy(
//             address(tradeExecutorImpl),
//             tradeExecutorInitData
//         );
//         tradeExecutor = TradeExecutor(address(tradeExecutorProxy));

//         // Set up connections between contracts
//         userManager.setIntentsEngine(address(intentsEngine));
//         userManager.setTradeExecutor(address(tradeExecutor));

//         // Ensure the test contract has enough tokens
//         token.transfer(address(this), 1_000_000 * 10 ** 18);

//         // Assign tokens to users
//         token.transfer(user1, 100_000 * 10 ** 18);
//         token.transfer(user2, 100_000 * 10 ** 18);
//     }

//     function _getPermitTypedDataHash(
//         ISignatureTransfer.PermitTransferFrom memory permit,
//         address spender
//     ) internal view returns (bytes32) {
//         bytes32 PERMIT_TRANSFER_FROM_TYPEHASH = keccak256(
//             "PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"
//         );

//         bytes32 tokenPermissionsHash = keccak256(
//             abi.encode(
//                 keccak256("TokenPermissions(address token,uint256 amount)"),
//                 permit.permitted.token,
//                 permit.permitted.amount
//             )
//         );

//         bytes32 structHash = keccak256(
//             abi.encode(
//                 PERMIT_TRANSFER_FROM_TYPEHASH,
//                 tokenPermissionsHash,
//                 spender,
//                 permit.nonce,
//                 permit.deadline
//             )
//         );

//         bytes32 DOMAIN_SEPARATOR = permit2.DOMAIN_SEPARATOR();

//         return
//             keccak256(
//                 abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash)
//             );
//     }

//     function testPermitDeposit() public {
//         uint256 amount = 1000 * 10 ** 18;
//         uint256 deadline = block.timestamp + 1 hours;
//         uint256 nonce = 0;

//         ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer
//             .PermitTransferFrom({
//                 permitted: ISignatureTransfer.TokenPermissions({
//                     token: address(token),
//                     amount: amount
//                 }),
//                 nonce: nonce,
//                 deadline: deadline
//             });

//         ISignatureTransfer.SignatureTransferDetails
//             memory transferDetails = ISignatureTransfer
//                 .SignatureTransferDetails({
//                     to: address(userManager),
//                     requestedAmount: amount
//                 });

//         bytes32 digest = _getPermitTypedDataHash(permit, address(userManager));

//         (uint8 v, bytes32 r, bytes32 s) = vm.sign(user1PrivateKey, digest);
//         bytes memory signature = abi.encodePacked(r, s, v);

//         bytes memory permitTransferFrom = abi.encode(address(token), amount);

//         vm.startPrank(user1);
//         token.approve(address(permit2), type(uint256).max);
//         userManager.permitDeposit(
//             amount,
//             deadline,
//             nonce,
//             permitTransferFrom,
//             signature
//         );
//         vm.stopPrank();

//         (uint256 balance, ) = userManager.getUserBalance(user1);
//         assertEq(balance, amount, "Deposit amount should match user balance");
//     }

//     function testWithdraw() public {
//         testPermitDeposit();
//         uint256 withdrawAmount = 500 * 10 ** 18;

//         vm.prank(user1);
//         userManager.withdraw(withdrawAmount);

//         (uint256 balance, ) = userManager.getUserBalance(user1);
//         assertEq(balance, 500 * 10 ** 18, "Withdrawn amount should be deducted from balance");
//     }

//     function testFailWithdrawInsufficientBalance() public {
//         testPermitDeposit();

//         vm.prank(user1);
//         // Expecting InsufficientBalance custom error
//         vm.expectRevert(IUserManager.InsufficientBalance.selector);
//         userManager.withdraw(2000 * 10 ** 18); // Attempt to withdraw more than deposited
//     }

//     function testPauseUnpause() public {
//         vm.prank(userManager.owner());
//         userManager.pause();

//         // Expecting the permitDeposit to revert with Paused custom error if implemented
//         // Since Paused is a standard OpenZeppelin error, we can use the predefined selector
//         vm.expectRevert(bytes("Pausable: paused"));
//         vm.prank(user1);
//         userManager.permitDeposit(1, block.timestamp + 1 hours, 0, "", "");

//         vm.prank(userManager.owner());
//         userManager.unpause();

//         // Now it should work (it might revert for other reasons, but not because it's paused)
//         vm.prank(user1);
//         // Since we're depositing a minimal amount, ensure it doesn't revert due to pause
//         // Assuming other validations pass
//         vm.expectEmit(true, true, true, true);
//         emit IUserManager.Deposit(user1, 1);
//         userManager.permitDeposit(1, block.timestamp + 1 hours, 0, "", "");
//     }

//     function testInitializer() public {
//         // Attempt to re-initialize the contract, which should fail
//         vm.expectRevert("Initializable: contract is already initialized");
//         userManager.initialize(address(token), address(permit2));
//     }

//     function testLockUnlockUserBalance() public {
//         uint256 lockAmount = 200 * 10 ** 18;

//         // First deposit tokens for user1
//         testPermitDeposit();

//         // Lock the user's balance
//         vm.prank(address(intentsEngine));
//         userManager.lockUserBalance(user1, lockAmount);

//         // Check locked balance
//         (, uint256 lockedBalance) = userManager.getUserBalance(user1);
//         assertEq(lockedBalance, lockAmount, "Locked balance should match lock amount");

//         // Unlock the user's balance
//         vm.prank(address(tradeExecutor));
//         userManager.unlockUserBalance(user1, lockAmount);

//         // Check final balances
//         (uint256 availableBalance, uint256 finalLockedBalance) = userManager.getUserBalance(user1);
//         assertEq(availableBalance, 1000 * 10 ** 18, "Available balance should be back to initial deposit");
//         assertEq(finalLockedBalance, 0, "Locked balance should be fully unlocked");
//     }

//     function testAdjustUserBalance() public {
//         int256 adjustAmount = 100 * 10 ** 18;

//         // First deposit tokens for user1
//         testPermitDeposit();

//         // Adjust the user's balance positively
//         vm.prank(address(tradeExecutor));
//         userManager.adjustUserBalance(user1, adjustAmount);

//         // Check adjusted balance
//         (uint256 adjustedBalance, ) = userManager.getUserBalance(user1);
//         assertEq(adjustedBalance, 1100 * 10 ** 18, "Balance should be increased by adjust amount");

//         // Adjust the user's balance negatively
//         vm.prank(address(tradeExecutor));
//         userManager.adjustUserBalance(user1, -adjustAmount);

//         // Check final balance
//         (uint256 finalBalance, ) = userManager.getUserBalance(user1);
//         assertEq(finalBalance, 1000 * 10 ** 18, "Balance should be back to initial deposit");
//     }

//     function testWithdrawLockedBalance() public {
//         uint256 lockAmount = 200 * 10 ** 18;

//         // First deposit tokens for user1
//         testPermitDeposit();

//         // Lock the user's balance
//         vm.prank(address(intentsEngine));
//         userManager.lockUserBalance(user1, lockAmount);

//         // Withdraw locked balance
//         vm.prank(userManager.owner());
//         userManager.withdrawLockedBalance(lockAmount, treasury);

//         // Check treasury balance
//         uint256 treasuryBalance = token.balanceOf(treasury);
//         assertEq(treasuryBalance, lockAmount, "Treasury should receive the locked amount");
//     }

//     function testRepayLockedBalance() public {
//         uint256 repayAmount = 200 * 10 ** 18;

//         // First deposit tokens for user1
//         testPermitDeposit();

//         // Repay locked balance
//         vm.prank(userManager.owner());
//         userManager.repayLockedBalance(repayAmount, user1);

//         // Check total locked balance
//         uint256 totalLocked = userManager.totalLockedBalance();
//         assertEq(totalLocked, repayAmount, "Total locked balance should be increased by repay amount");
//     }
// }