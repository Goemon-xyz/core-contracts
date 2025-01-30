// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.26;

// import "forge-std/Test.sol";
// import "../src/GoemonCore.sol";
// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import "permit2/src/interfaces/IPermit2.sol";
// import "permit2/src/libraries/PermitHash.sol";
// import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
// import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

// contract MockToken is ERC20 {
//     constructor() ERC20("Mock Token", "MTK") {
//         _mint(msg.sender, 1_000_000 * 10 ** 18);
//     }
// }

// contract GoemonCoreTest is Test {
//     GoemonCore public goemonCore;
//     MockToken public token;
//     IPermit2 public permit2;
//     address public treasury;
//     address public user1;
//     address public user2;
//     uint256 public user1PrivateKey;
//     uint256 public user2PrivateKey;

//     function setUp() public {
//         token = new MockToken();
//         treasury = address(0xe3A9A99347e771735eaDf4DF7f6fF0D4f2Edb61B);
//         permit2 = IPermit2(address(0x000000000022D473030F116dDEE9F6B43aC78BA3));

//         // Deploy the implementation contract
//         GoemonCore implementationContract = new GoemonCore();

//         // Prepare the initialization data
//         bytes memory initData = abi.encodeWithSelector(
//             GoemonCore.initialize.selector,
//             address(token),
//             address(permit2),
//             treasury
//         );

//         // Deploy the proxy contract
//         ERC1967Proxy proxy = new ERC1967Proxy(
//             address(implementationContract),
//             initData
//         );

//         // Cast the proxy to GoemonCore
//         goemonCore = GoemonCore(address(proxy));

//         user1PrivateKey = 0xA11CE;
//         user2PrivateKey = 0xB0B;
//         user1 = vm.addr(user1PrivateKey);
//         user2 = vm.addr(user2PrivateKey);

//         // Ensure the test contract has enough tokens
//         token.transfer(address(this), 1_000_000 * 10 ** 18);

//         token.transfer(user1, 100_000 * 10 ** 18);
//         token.transfer(user2, 100_000 * 10 ** 18);
//     }

//     function testPermitDeposit() public {
//         uint256 amount = 1000 * 10 ** 18;
//         uint256 deadline = block.timestamp + 1 hours;
//         uint48 nonce = 0;

//         IAllowanceTransfer.PermitDetails memory details = IAllowanceTransfer
//             .PermitDetails({
//                 token: address(token),
//                 amount: uint160(amount),
//                 expiration: uint48(deadline),
//                 nonce: nonce
//             });

//         IAllowanceTransfer.PermitSingle memory permitSingle = IAllowanceTransfer
//             .PermitSingle({
//                 details: details,
//                 spender: address(goemonCore),
//                 sigDeadline: deadline
//             });

//         bytes32 digest = keccak256(
//             abi.encodePacked(
//                 "\x19\x01",
//                 permit2.DOMAIN_SEPARATOR(),
//                 PermitHash.hash(permitSingle)
//             )
//         );

//         (uint8 v, bytes32 r, bytes32 s) = vm.sign(user1PrivateKey, digest);
//         bytes memory signature = abi.encodePacked(r, s, v);

//         vm.startPrank(user1);
//         token.approve(address(permit2), type(uint256).max);
//         goemonCore.permitDeposit(uint160(amount), deadline, nonce, signature);
//         vm.stopPrank();

//         (uint256 balance, ) = goemonCore.getUserBalance(user1);
//         assertEq(balance, amount);
//     }

//     function testWithdraw() public {
//         testPermitDeposit();
//         uint256 withdrawAmount = 500 * 10 ** 18;

//         vm.prank(user1);
//         goemonCore.withdraw(withdrawAmount);

//         (uint256 balance, ) = goemonCore.getUserBalance(user1);
//         assertEq(balance, 500 * 10 ** 18);
//     }

//     function testSubmitIntent() public {
//         testPermitDeposit();
//         uint256 intentAmount = 500 * 10 ** 18;

//         vm.prank(user1);
//         goemonCore.submitIntent(intentAmount, "BUY");

//         (uint256 availableBalance, uint256 lockedBalance) = goemonCore
//             .getUserBalance(user1);
//         assertEq(availableBalance, 500 * 10 ** 18);
//         assertEq(lockedBalance, 500 * 10 ** 18);

//         GoemonCore.Intent[] memory intents = goemonCore.getUserIntents(user1);
//         assertEq(intents.length, 1);
//         assertEq(intents[0].amount, intentAmount);
//         assertEq(intents[0].intentType, "BUY");
//         assertEq(intents[0].isExecuted, false);
//     }

//     function testSettleIntent() public {
//         testSubmitIntent();

//         vm.prank(goemonCore.owner());
//         goemonCore.settleIntent(user1, 0, 50 * 10 ** 18);

//         (uint256 availableBalance, uint256 lockedBalance) = goemonCore
//             .getUserBalance(user1);
//         assertEq(availableBalance, 1050 * 10 ** 18);
//         assertEq(lockedBalance, 0);

//         GoemonCore.Intent[] memory intents = goemonCore.getUserIntents(user1);
//         assertEq(intents[0].isExecuted, true);
//     }

//     function testBatchSettleIntents() public {
//         testSubmitIntent();

//         // Submit another intent for user2
//         uint256 amount = 1000 * 10 ** 18;
//         uint256 deadline = block.timestamp + 1 hours;
//         uint48 nonce = 0;

//         IAllowanceTransfer.PermitDetails memory details = IAllowanceTransfer
//             .PermitDetails({
//                 token: address(token),
//                 amount: uint160(amount),
//                 expiration: uint48(deadline),
//                 nonce: nonce
//             });

//         IAllowanceTransfer.PermitSingle memory permitSingle = IAllowanceTransfer
//             .PermitSingle({
//                 details: details,
//                 spender: address(goemonCore),
//                 sigDeadline: deadline
//             });

//         bytes32 digest = keccak256(
//             abi.encodePacked(
//                 "\x19\x01",
//                 permit2.DOMAIN_SEPARATOR(),
//                 PermitHash.hash(permitSingle)
//             )
//         );

//         (uint8 v, bytes32 r, bytes32 s) = vm.sign(user2PrivateKey, digest);
//         bytes memory signature = abi.encodePacked(r, s, v);

//         vm.startPrank(user2);
//         token.approve(address(permit2), type(uint256).max);
//         goemonCore.permitDeposit(uint160(amount), deadline, nonce, signature);
//         goemonCore.submitIntent(500 * 10 ** 18, "SELL");
//         vm.stopPrank();

//         // Transfer tokens to the treasury and approve the contract to spend
//         uint256 treasuryAmount = 1000 * 10 ** 18;
//         vm.prank(address(this));
//         token.transfer(treasury, treasuryAmount);

//         vm.prank(treasury);
//         token.approve(address(goemonCore), treasuryAmount);

//         address[] memory users = new address[](2);
//         users[0] = user1;
//         users[1] = user2;

//         uint256[] memory intentIndices = new uint256[](2);
//         intentIndices[0] = 0;
//         intentIndices[1] = 0;

//         int256[] memory pnls = new int256[](2);
//         pnls[0] = 50 * 10 ** 18;
//         pnls[1] = -25 * 10 ** 18;

//         vm.prank(goemonCore.owner());
//         goemonCore.batchSettleIntents(users, intentIndices, pnls);

//         (uint256 user1Balance, uint256 user1LockedBalance) = goemonCore
//             .getUserBalance(user1);
//         (uint256 user2Balance, uint256 user2LockedBalance) = goemonCore
//             .getUserBalance(user2);

//         assertEq(user1Balance, 1050 * 10 ** 18);
//         assertEq(user1LockedBalance, 0);
//         assertEq(user2Balance, 975 * 10 ** 18);
//         assertEq(user2LockedBalance, 0);

//         GoemonCore.Intent[] memory user1Intents = goemonCore.getUserIntents(
//             user1
//         );
//         GoemonCore.Intent[] memory user2Intents = goemonCore.getUserIntents(
//             user2
//         );

//         assertEq(user1Intents[0].isExecuted, true);
//         assertEq(user2Intents[0].isExecuted, true);
//     }

//     function testSetTreasury() public {
//         address newTreasury = address(0x123);

//         vm.prank(goemonCore.owner());
//         goemonCore.setTreasury(newTreasury);

//         assertEq(goemonCore.treasury(), newTreasury);
//     }

//     function testFailWithdrawInsufficientBalance() public {
//         testPermitDeposit();

//         vm.prank(user1);
//         goemonCore.withdraw(2000 * 10 ** 18);
//     }

//     function testFailSubmitIntentInsufficientBalance() public {
//         testPermitDeposit();

//         vm.prank(user1);
//         goemonCore.submitIntent(2000 * 10 ** 18, "BUY");
//     }

//     function testFailSettleIntentNonOwner() public {
//         testSubmitIntent();

//         vm.prank(user2);
//         goemonCore.settleIntent(user1, 0, 50 * 10 ** 18);
//     }

//     function testFailBatchSettleIntentsNonOwner() public {
//         testSubmitIntent();

//         address[] memory users = new address[](1);
//         users[0] = user1;

//         uint256[] memory intentIndices = new uint256[](1);
//         intentIndices[0] = 0;

//         int256[] memory pnls = new int256[](1);
//         pnls[0] = 50 * 10 ** 18;

//         vm.prank(user2);
//         goemonCore.batchSettleIntents(users, intentIndices, pnls);
//     }

//     function testFailSetTreasuryNonOwner() public {
//         vm.prank(user1);
//         goemonCore.setTreasury(address(0x123));
//     }

//     function testSetMaxIntentsPerUser() public {
//         uint256 newMax = 5;

//         vm.prank(goemonCore.owner());
//         goemonCore.setMaxIntentsPerUser(newMax);

//         // Deposit some tokens first
//         uint256 depositAmount = 100 * 10 ** 18;
//         uint256 deadline = block.timestamp + 1 hours;
//         uint48 nonce = 0;

//         IAllowanceTransfer.PermitDetails memory details = IAllowanceTransfer
//             .PermitDetails({
//                 token: address(token),
//                 amount: uint160(depositAmount),
//                 expiration: uint48(deadline),
//                 nonce: nonce
//             });

//         IAllowanceTransfer.PermitSingle memory permitSingle = IAllowanceTransfer
//             .PermitSingle({
//                 details: details,
//                 spender: address(goemonCore),
//                 sigDeadline: deadline
//             });

//         bytes32 digest = keccak256(
//             abi.encodePacked(
//                 "\x19\x01",
//                 permit2.DOMAIN_SEPARATOR(),
//                 PermitHash.hash(permitSingle)
//             )
//         );

//         (uint8 v, bytes32 r, bytes32 s) = vm.sign(user1PrivateKey, digest);
//         bytes memory signature = abi.encodePacked(r, s, v);

//         vm.startPrank(user1);
//         token.approve(address(permit2), type(uint256).max);
//         goemonCore.permitDeposit(
//             uint160(depositAmount),
//             deadline,
//             nonce,
//             signature
//         );

//         // Now submit intents
//         for (uint256 i = 0; i < newMax; i++) {
//             goemonCore.submitIntent(1, "BUY");
//         }

//         // This should revert
//         vm.expectRevert("Max intents limit reached");
//         goemonCore.submitIntent(1, "BUY");

//         vm.stopPrank();
//     }

//     function testPauseUnpause() public {
//         vm.prank(goemonCore.owner());
//         goemonCore.pause();

//         vm.expectRevert();
//         goemonCore.permitDeposit(1, block.timestamp + 1 hours, 0, "");

//         vm.prank(goemonCore.owner());
//         goemonCore.unpause();

//         // Now it should work (it might revert for other reasons, but not because it's paused)
//         vm.expectRevert();
//         goemonCore.permitDeposit(1, block.timestamp + 1 hours, 0, "");
//     }

//     function testInitializer() public {
//         vm.expectRevert();
//         goemonCore.initialize(address(token), address(permit2), treasury);
//     }
// }
