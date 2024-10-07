// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.26;

// import "forge-std/Test.sol";
// import "../src/Core.sol";
// import "../src/TradeExecutor.sol";
// import "../src/interfaces/ITradeExecutor.sol";
// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import "permit2/src/interfaces/IPermit2.sol";
// import "permit2/src/libraries/PermitHash.sol";

// contract MockToken is ERC20 {
//     constructor() ERC20("Mock Token", "MTK") {
//         _mint(msg.sender, 1_000_000 * 10 ** 18);
//     }
// }

// contract CoreTest is Test {
//     Core public core;
//     MockToken public token;
//     IPermit2 public permit2;
//     TradeExecutor public tradeExecutor;
//     address public treasury;

//     address public user1;
//     uint256 public user1PrivateKey;

//     function setUp() public {
//         token = new MockToken();
//         permit2 = IPermit2(address(0x000000000022D473030F116dDEE9F6B43aC78BA3)); // Mainnet Permit2 address
//         tradeExecutor = new TradeExecutor();
//         treasury = address(0x1);

//         core = new Core(
//             address(token),
//             address(permit2),
//             address(tradeExecutor),
//             treasury
//         );

//         // Set the correct GoemonCore address in TradeExecutor
//         tradeExecutor.setGoemonCore(address(core));

//         user1 = vm.addr(1);
//         user1PrivateKey = 1;

//         token.transfer(user1, 100_000 * 10 ** 18);
//     }

//     function testSubmitTradeIntent() public {
//         vm.startPrank(user1);

//         uint256 amount = 10 * 10 ** 18; // Assuming 18 decimals
//         uint256 deadline = block.timestamp + 1 hours;
//         uint48 nonce = 0;

//         // Prepare Permit2's data
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
//                 spender: address(core),
//                 sigDeadline: deadline
//             });

//         // Generate the correct hash using Permit2's hashing function
//         bytes32 digest = keccak256(
//             abi.encodePacked(
//                 "\x19\x01",
//                 permit2.DOMAIN_SEPARATOR(),
//                 PermitHash.hash(permitSingle)
//             )
//         );

//         // Sign the digest using the test private key
//         (uint8 v, bytes32 r, bytes32 s) = vm.sign(user1PrivateKey, digest);
//         bytes memory signature = abi.encodePacked(r, s, v);

//         // Approve token for Permit2
//         token.approve(address(permit2), type(uint256).max);

//         core.submitTradeIntent(amount, "BUY", deadline, nonce, signature);

//         vm.stopPrank();

//         Core.Trade[] memory trades = core.getUserTrades(user1);
//         assertEq(trades.length, 1);
//         assertEq(trades[0].amount, amount);
//         assertEq(trades[0].intentType, "BUY");
//         assertEq(trades[0].isSettled, false);
//     }

//     function testManualTradeIntent() public {
//         vm.startPrank(user1);

//         uint256 amount = 1000 * 10 ** 18;
//         token.approve(address(core), amount);

//         core.manualTradeIntent(amount, "SELL");

//         vm.stopPrank();

//         Core.Trade[] memory trades = core.getUserTrades(user1);
//         assertEq(trades.length, 1);
//         assertEq(trades[0].amount, amount);
//         assertEq(trades[0].intentType, "SELL");
//         assertEq(trades[0].isSettled, false);
//     }

//     function testSettleTrade() public {
//         // First, submit a trade intent
//         testManualTradeIntent();

//         vm.prank(core.owner());
//         core.settleTrade(user1, 0);

//         Core.Trade[] memory trades = core.getUserTrades(user1);
//         assertEq(trades[0].isSettled, true);
//     }

//     function testSetTradeExecutor() public {
//         address newTradeExecutor = address(0x2);

//         vm.prank(core.owner());
//         core.setTradeExecutor(newTradeExecutor);

//         assertEq(address(core.tradeExecutor()), newTradeExecutor);
//     }

//     function testSetTreasury() public {
//         address newTreasury = address(0x3);

//         vm.prank(core.owner());
//         core.setTreasury(newTreasury);

//         assertEq(core.treasury(), newTreasury);
//     }

//     function testFailSettleTradeNonOwner() public {
//         vm.prank(user1);
//         core.settleTrade(user1, 0);
//     }

//     function testFailSetTradeExecutorNonOwner() public {
//         vm.prank(user1);
//         core.setTradeExecutor(address(0x2));
//     }

//     function testFailSetTreasuryNonOwner() public {
//         vm.prank(user1);
//         core.setTreasury(address(0x3));
//     }
// }
