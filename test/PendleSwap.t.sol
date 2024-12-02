// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import "pendle-finance/pendle-core/contracts/interfaces/IPendleRouter.sol";
// import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
// import "forge-std/Test.sol";

// contract PendleSwapTest is Test {
//     IPendleRouter pendleRouter;
//     address marketAddress = 0x281fe15fd3e08a282f52d5cf09a4d13c3709e66d;
//     address tokenIn = 0x75faf114eafb1bdbe2f0316df893fd58ce46aa4d; // USDC token address
//     address receiverAddr = 0x5365598ba13e9f40AB2181dCB843Fa7875dA08a4; // Replace with actual receiver address
//     uint256 amount = 4970; // Amount to swap (USDC)
//     uint256 slippage = 200; // Slippage in bps (0.02%)

//     function setUp() public {
//         // Simulate a forked mainnet environment
//         vm.createFork("https://arb1.arbitrum.io/rpc");
//         vm.selectFork(vm.activeFork());
        
//         // Initialize Pendle Router
//         pendleRouter = IPendleRouter(0x...); // Replace with actual router address on Arbitrum
//     }

//     function testPendleSwap() public {
//         // Approve the router to spend the token
//         IERC20(tokenIn).approve(address(pendleRouter), amount);

//         // Execute the swap
//         uint256 amountOut = pendleRouter.swap(
//             marketAddress,
//             tokenIn,
//             amount,
//             receiverAddr,
//             slippage
//         );

//         // Assert the output
//         assert(amountOut > 0);
//     }
// }
