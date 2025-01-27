// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/UserManager.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "permit2/src/interfaces/IPermit2.sol";
import "@pendle/core-v2/contracts/interfaces/IPAllActionV3.sol";
import "@pendle/core-v2/contracts/interfaces/IPMarket.sol";
import "../src/StructGen.sol";
import "forge-std/console.sol";

contract UserManagerTest is Test, StructGen {
    UserManager public userManager;
    IERC20 public usdc;
    IPermit2 public permit2;
    address public user1;
    uint256 public user1PrivateKey;
    address public powerTrade;

    IPAllActionV3 public constant router = IPAllActionV3(0x888888888889758F76e7103c6CbF23ABbF58F946);
    IPMarket public constant wstMarket = IPMarket(0xD0354D4e7bCf345fB117cabe41aCaDb724eccCa2);
    IPMarket public constant usdeMarket = IPMarket(0xB451A36c8B6b2EAc77AD0737BA732818143A0E25);
    address public constant wstETHAddress = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address public constant usdeAddress = 0x4c9EDD5852cd905f086C759E8383e09bff1E68B3;
    address public constant usdcAddress = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant ptUsdeAddress = 0x8A47b431A7D947c6a3ED6E42d501803615a97EAa;

    bytes transactionData = hex"c81f847a0000000000000000000000001ad0ae8e1dbe78c7313cb8234c3f753adb088a15000000000000000000000000b451a36c8b6b2eac77ad0737ba732818143a0e25000000000000000000000000000000000000000000000035224e181345092d8300000000000000000000000000000000000000000000001b1bf3995832e555ea00000000000000000000000000000000000000000000003ba3e4b7c20992236a00000000000000000000000000000000000000000000003637e732b065caabd5000000000000000000000000000000000000000000000000000000000000001e00000000000000000000000000000000000000000000000000038d7ea4c6800000000000000000000000000000000000000000000000000000000000000001400000000000000000000000000000000000000000000000000000000000000b20000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000000000000000000000000000000000000000000000000000000039d106800000000000000000000000004c9edd5852cd905f086c759e8383e09bff1e68b30000000000000000000000001e8b6ac39f8a33f46a6eb2d1acd1047b99180ad100000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000010000000000000000000000006131b5fae19ea4f9d964eac0408e4408b66337b5000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000884e21fd0e900000000000000000000000000000000000000000000000000000000000000200000000000000000000000000f4a1d7fdf4890be35e71f3e0bbc4a0ec377eca3000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000003c000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000300000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000000000000000000000004c9edd5852cd905f086c759e8383e09bff1e68b3000000000000000000000000888888888889758f76e7103c6cbf23abbf58f946000000000000000000000000000000000000000000000000000000007fffffff00000000000000000000000000000000000000000000000000000000000002a000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000040d90ce49100000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000010000000000000000000000000002950460e2b9529d0e00284a5fa2d7bdf3fa4d72000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000000000000000000000004c9edd5852cd905f086c759e8383e09bff1e68b3000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000039d106800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200000000000000000000371b52952c74d00000000000000348dca8dcb5996ce87000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000000000000000000000004c9edd5852cd905f086c759e8383e09bff1e68b3000000000000000000000000000000000000000000000000000000000000016000000000000000000000000000000000000000000000000000000000000001a000000000000000000000000000000000000000000000000000000000000001e00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000888888888889758f76e7103c6cbf23abbf58f9460000000000000000000000000000000000000000000000000000000039d1068000000000000000000000000000000000000000000000003380b7248ef6846e3c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000022000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000f4a1d7fdf4890be35e71f3e0bbc4a0ec377eca300000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000039d1068000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002307b22536f75726365223a2250656e646c65222c22416d6f756e74496e555344223a223936392e37313831343834363039323531222c22416d6f756e744f7574555344223a223937302e30373236393436313631313833222c22526566657272616c223a22222c22466c616773223a302c22416d6f756e744f7574223a22393639343437383236343432303631303038353139222c2254696d657374616d70223a313733373837393038342c22496e74656772697479496e666f223a7b224b65794944223a2231222c225369676e6174757265223a22634f505065726737397a546359594c717174706571506747784c74596953334a5137455735554f7735772b6264512f4d506138662f474f2b2b74376f5963764664414c5972655a574c485272785a597436475a5745666a33376e662f5a32304657384568483564424e645862305a59514c55304e30526434754b61444a4e5137656c4757374a724f4f534354504f7247674d6b6565797454583549643354664f716851794e3743664a75414d5a39656c334241786848413971694d62654d2b5333686a684d3231774d4d6c6d7054766f6233646d73664344446a44626f393974526c59573935386c50557a644c346f543030673454394d626c7234566b6779525733334f2f4a45506f7159536e64634c724c71354f36597336746a2b6e73713336304576387054683279716d5038466e77512f78546d44396a49745654535647343239477243394372776268355053726841396a4f773d3d227d7d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
    address to = 0x888888888889758F76e7103c6CbF23ABbF58F946;

    bytes kyberTransactionData = hex"8af033fb0000000000000000000000000f4a1d7fdf4890be35e71f3e0bbc4a0ec377eca3000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000002800000000000000000000000000000000000000000000000000000000000000640000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000000000000000000000004c9edd5852cd905f086c759e8383e09bff1e68b30000000000000000000000000000000000000000000000000000000000000160000000000000000000000000000000000000000000000000000000000000018000000000000000000000000000000000000000000000000000000000000001a000000000000000000000000000000000000000000000000000000000000001c00000000000000000000000001ad0ae8e1dbe78c7313cb8234c3f753adb088a1500000000000000000000000000000000000000000000000000000000000f42400000000000000000000000000000000000000000000000000de3355501ea1879000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000001e00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003a0000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000120000000000000000000000000000000000000000000000000000000006794effb000000000000000000000000000000000000000000000000000000000000034000000000000000000000000000000000000000000000000000000000000000010000000000000000000000001e496fae4613b4e9c4f8fc31826812cdcbd03a90000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000f42400000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000001c00000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000040593611990000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000001000000000000000000000000001e496fae4613b4e9c4f8fc31826812cdcbd03a90000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000000000000000000000004c9edd5852cd905f086c759e8383e09bff1e68b30000000000000000000000000f4a1d7fdf4890be35e71f3e0bbc4a0ec377eca30000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000300000000000000000000000000000000000000000000000000000000000003e8000000000000000000000000000000000000000000000000000000000000003200000000000000000000000000000000000000000000000000000000000000200000000000000000000000e93a344a0000000000000000000de6c4605e2b29ab000000000000000000000000000000000000000000000000000000000000022a7b22536f75726365223a22222c22416d6f756e74496e555344223a22312e30303031343934333132323238313132222c22416d6f756e744f7574555344223a22312e30303233313934323433323133323635222c22526566657272616c223a22222c22466c616773223a302c22416d6f756e744f7574223a2231303031373033383835333132333035353739222c2254696d657374616d70223a313733373831323831312c22496e74656772697479496e666f223a7b224b65794944223a2231222c225369676e6174757265223a22564751322f573547776b76792f4a7445444e50622b77596534677a315058635a5a324d36552f776c512b5675774e70595530633076483056322b35473752324e745737505771465871384130465264445548494645323163427142744d4139446c7556423257445868714d62713273516b424e754a627145375239466f6d556b6f65702b6f65697479316e47554f733943696b464a785532624e617842704e55545a42375645394c4353512f6f2f434731452b53427478767976653134324878374868454c336c357463636d37337556724d55302b63772b564d694e4562704874437454332b48532b7863706e46645a50706f504546725244327a31786962547a7843394b734e665a636d353059526b47586e642f686c785a63354c47485547556b3151754138544d344930387a4d714a6c572f6e366b45525a6c6d734c76696153675064414c765061764d6d514d44432b4e4c44413d3d227d7d00000000000000000000000000000000000000000000";
    address kyberRouter = 0x6131B5fae19EA4f9D964eAc0408E4408b66337b5;

    IStandardizedYield public SY;
    IPPrincipalToken public PT;
    IPYieldToken public YT;

    // Type hashes for EIP-712
    bytes32 constant _TOKEN_PERMISSIONS_TYPEHASH = keccak256(
        "TokenPermissions(address token,uint256 amount)"
    );
    
    bytes32 constant _PERMIT_BATCH_TRANSFER_FROM_TYPEHASH = keccak256(
        "PermitBatchTransferFrom(TokenPermissions[] permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"
    );

    function setUp() public {
        vm.createSelectFork({ urlOrAlias: "https://virtual.mainnet.rpc.tenderly.co/2abc540d-2399-4b5b-b786-fb19395c328a" });
        (SY, PT, YT) = IPMarket(wstMarket).readTokens();
        // Use USDC mainnet address
        usdc = IERC20(usdcAddress);
        permit2 = IPermit2(address(0x000000000022D473030F116dDEE9F6B43aC78BA3));

        // Create account with private key
        user1PrivateKey = 0xA11CE;
        user1 = vm.addr(user1PrivateKey);
        powerTrade = vm.addr(0xC0FFEE);

        // Deploy UserManager
        userManager = new UserManager();
        userManager.initialize(address(usdc), powerTrade, address(permit2));

        // Simulate transferring wstETHAddress to user1
        deal(wstETHAddress, address(this), 1e19);
        deal(usdeAddress, address(this), 100000 * 10 ** 18);
        deal(usdeAddress, user1, 100000 * 10 ** 18);
        deal(usdcAddress, address(this), 1e10);
        deal(usdcAddress, user1, 1e10);

        IERC20(wstETHAddress).approve(address(router), type(uint256).max);
        IERC20(usdeAddress).approve(address(router), type(uint256).max);
        IERC20(SY).approve(address(router), type(uint256).max);
        IERC20(PT).approve(address(router), type(uint256).max);
        IERC20(YT).approve(address(router), type(uint256).max);
        IERC20(wstMarket).approve(address(router), type(uint256).max);
    }

    function _getPermitTypedDataHash(
        ISignatureTransfer.PermitTransferFrom memory permit,
        address spender
    )
        internal
        view
        returns (bytes32)
    {
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
            abi.encode(PERMIT_TRANSFER_FROM_TYPEHASH, tokenPermissionsHash, spender, permit.nonce, permit.deadline)
        );

        bytes32 DOMAIN_SEPARATOR = permit2.DOMAIN_SEPARATOR();

        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
    }

    function _getPermitBatchTypedDataHash(
        ISignatureTransfer.PermitBatchTransferFrom memory permit,
        address spender
    )
        internal
        view
        returns (bytes32)
    {
        bytes32 PERMIT_BATCH_TRANSFER_FROM_TYPEHASH = keccak256(
            "PermitBatchTransferFrom(TokenPermissions[] permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"
        );

        bytes32[] memory tokenPermissionsHashes = new bytes32[](permit.permitted.length);
        for (uint256 i = 0; i < permit.permitted.length; i++) {
            tokenPermissionsHashes[i] = keccak256(
                abi.encode(
                    keccak256("TokenPermissions(address token,uint256 amount)"),
                    permit.permitted[i].token,
                    permit.permitted[i].amount
                )
            );
        }

        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_BATCH_TRANSFER_FROM_TYPEHASH,
                keccak256(abi.encodePacked(tokenPermissionsHashes)),
                spender,
                permit.nonce,
                permit.deadline
            )
        );

        bytes32 DOMAIN_SEPARATOR = permit2.DOMAIN_SEPARATOR();

        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
    }

    function testPermitDeposit() public {
        uint256 amount = 1000 * 10 ** 6; // USDC has 6 decimals
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = 0;

        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({ token: address(usdc), amount: amount }),
            nonce: nonce,
            deadline: deadline
        });

        bytes32 digest = _getPermitTypedDataHash(permit, address(userManager));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(user1PrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Retrieve the address from the signature
        address recoveredAddress = ecrecover(digest, v, r, s);
        console.log("Expected user address for PermitDeposit:", user1);
        console.log("Recovered address from signature for PermitDeposit:", recoveredAddress);

        bytes memory permitTransferFrom = abi.encode(address(usdc), amount);

        vm.startPrank(user1);
        usdc.approve(address(permit2), type(uint256).max);
        userManager.permitDeposit(amount, deadline, nonce, permitTransferFrom, signature);
        vm.stopPrank();

        uint256 powerTradeBalance = usdc.balanceOf(powerTrade);
        assertEq(powerTradeBalance, amount, "PowerTrade balance should increase by deposit amount");
    }

    // function testBuyPT() public {
    //     (uint256 netPtOut, , ) = router.swapExactTokenForPt(
    //     address(user1),
    //     address(wstMarket),
    //     0,
    //     defaultApprox,
    //     createTokenInputStruct(wstETHAddress, 1e18),
    //     emptyLimit
    // );
    // console.log("netPtOut: %s", netPtOut);
    // }

    // function testBuyUsdePT() public {
    //     (uint256 netPtOut, , ) = router.swapExactTokenForPt(
    //     address(user1),
    //     address(usdeMarket),
    //     0,
    //     defaultApprox,
    //     createTokenInputStruct(usdeAddress, 1e6),
    //     emptyLimit
    // );
    // console.log("netPtOut: %s", netPtOut);
    // }

//     function testSwapExactTokenForPt() public {
//     uint256 amount = 100 * 10 ** 18; // Same amount as in testBuyUsdePT
//     uint256 minPtOut = 60 * 10 ** 18;

//     // Check initial USDE balance
//     uint256 initialUsdeBalance = IERC20(usdeAddress).balanceOf(address(user1));
//     console.log("Initial USDE Balance:", initialUsdeBalance);

//     vm.startPrank(user1);
    
//     // Approve USDC spending
//     usdc.approve(address(userManager), amount);
//     IERC20(usdeAddress).approve(address(userManager), type(uint256).max);
    
//     // Create TokenInput struct
//     TokenInput memory input = createTokenInputStruct(usdeAddress, amount);

//     // Call swapExactTokenForPt
//     uint256 netPtOut = userManager.swapExactTokenForPt(
//         address(usdeMarket), // Using the same market as testBuyUsdePT
//         minPtOut,
//         input,
//         ptUsdeAddress
//     );

//     vm.stopPrank();

//     // Log output for debugging
//     console.log("Net PT Output:", netPtOut);

//     // Assert PT tokens received
//     assertGt(netPtOut, minPtOut, "Should receive more than minimum PT tokens");

//     // Check final USDE balance
//     uint256 finalUsdeBalance = IERC20(usdeAddress).balanceOf(address(user1));
//     console.log("Final USDE Balance:", finalUsdeBalance);

//     uint256 ptTokenBalance = IERC20(ptUsdeAddress).balanceOf(address(user1));
//     console.log("User1 PT balance:", ptTokenBalance);

//     uint256 umPtTokenBalance = IERC20(ptUsdeAddress).balanceOf(address(userManager));
//     console.log("UM PT bala:", umPtTokenBalance);

//     // Assert USDE balance changes
//     assertGt(initialUsdeBalance, finalUsdeBalance, "USDE balance should decrease");
// }

    // function testDepositAndSwapUSDC() public {
    //     uint256 amount = 970 * 10 ** 6; // USDC amount to deposit and swap

    //     // Check initial PT USDE balance of user1
    //     uint256 initialBalance = IERC20(ptUsdeAddress).balanceOf(address(0x1ad0ae8E1DBe78c7313cB8234C3F753adb088A15));
    //     console.log("Initial PT USDE Balance:", initialBalance);

    //     vm.startPrank(user1);
    //     usdc.approve(address(userManager), amount);

    //     // Call the depositAndSwapUSDC function
    //     userManager.depositAndSwapUSDC(usdcAddress, amount, address(to), transactionData);
    //     vm.stopPrank();

    //     // Check final PT USDE balance of user1
    //     uint256 finalBalance = IERC20(ptUsdeAddress).balanceOf(address(0x1ad0ae8E1DBe78c7313cB8234C3F753adb088A15));
    //     console.log("Final PT USDE Balance:", finalBalance);

    //     // Assert that the PT USDE balance has increased
    //     assertGt(finalBalance, initialBalance, "PT USDE balance should increase after swap");
    // }

    //     function testDepositBatchAndSwap() public {
    //     uint256 totalAmount = 1170 * 10 ** 6; // Total USDC amount
    //     uint256 yieldAmount = 200 * 10 ** 6;  // Yield portion
    //     uint256 deadline = block.timestamp + 1 hours;
    //     uint256 nonce = 0;

    //     // Create permit batch data
    //     ISignatureTransfer.TokenPermissions[] memory permissions = new ISignatureTransfer.TokenPermissions[](1);
    //     permissions[0] = ISignatureTransfer.TokenPermissions({
    //         token: address(usdc),
    //         amount: totalAmount
    //     });

    //     ISignatureTransfer.PermitBatchTransferFrom memory permit = ISignatureTransfer.PermitBatchTransferFrom({
    //         permitted: permissions,
    //         nonce: nonce,
    //         deadline: deadline
    //     });

    //     // Generate and sign the permit
    //     bytes32 digest = _getPermitBatchTypedDataHash(permit, address(userManager));
    //     (uint8 v, bytes32 r, bytes32 s) = vm.sign(user1PrivateKey, digest);
    //     bytes memory signature = abi.encodePacked(r, s, v);

    //     // Check initial balances
    //     uint256 initialPtBalance = IERC20(ptUsdeAddress).balanceOf(address(user1));
    //     uint256 initialPowerTradeBalance = usdc.balanceOf(powerTrade);

    //     vm.startPrank(user1);
    //     usdc.approve(address(permit2), type(uint256).max);

    //     // Execute batch deposit and swap
    //     userManager.depositBatchAndSwap(
    //         totalAmount,
    //         yieldAmount,
    //         permit,
    //         signature,
    //         to,
    //         transactionData
    //     );
    //     vm.stopPrank();

    //     // Verify balances
    //     uint256 finalPtBalance = IERC20(ptUsdeAddress).balanceOf(address(user1));
    //     uint256 finalPowerTradeBalance = usdc.balanceOf(powerTrade);

    //     // Assert results
    //     assertGt(finalPtBalance, initialPtBalance, "PT USDE balance should increase");
    //     assertEq(
    //         finalPowerTradeBalance,
    //         initialPowerTradeBalance + yieldAmount,
    //         "PowerTrade should receive yield amount"
    //     );
    // }

    // function testDepositBatchSimple() public {
    //     uint256 totalAmount = 1000 * 10 ** 6; // Total USDC amount
    //     uint256 yieldAmount = 200 * 10 ** 6;  // Yield portion
    //     uint256 deadline = block.timestamp + 1 hours;
    //     uint256 nonce = 0;

    //     // Create permit batch data
    //     ISignatureTransfer.TokenPermissions[] memory permissions = new ISignatureTransfer.TokenPermissions[](1);
    //     permissions[0] = ISignatureTransfer.TokenPermissions({
    //         token: address(usdc),
    //         amount: totalAmount
    //     });

    //     ISignatureTransfer.PermitBatchTransferFrom memory permit = ISignatureTransfer.PermitBatchTransferFrom({
    //         permitted: permissions,
    //         nonce: nonce,
    //         deadline: deadline
    //     });

    //     // Generate and sign the permit
    //     bytes32 digest = _getPermitBatchTypedDataHash(permit, address(userManager));
    //     (uint8 v, bytes32 r, bytes32 s) = vm.sign(user1PrivateKey, digest);
    //     bytes memory signature = abi.encodePacked(r, s, v);

    //     // Check initial balances
    //     uint256 initialUserBalance = usdc.balanceOf(address(user1));
    //     uint256 initialPowerTradeBalance = usdc.balanceOf(powerTrade);

    //     vm.startPrank(user1);
    //     usdc.approve(address(permit2), type(uint256).max);

    //     // Execute simple batch deposit
    //     userManager.depositBatchSimple(
    //         totalAmount,
    //         yieldAmount,
    //         permit,
    //         signature
    //     );
    //     vm.stopPrank();

    //     // Verify balances
    //     uint256 finalUserBalance = usdc.balanceOf(address(user1));
    //     uint256 finalPowerTradeBalance = usdc.balanceOf(powerTrade);

    //     // Assert results
    //     assertEq(
    //         finalUserBalance,
    //         initialUserBalance - totalAmount,
    //         "User balance should decrease by total amount"
    //     );
    //     assertEq(
    //         finalPowerTradeBalance,
    //         initialPowerTradeBalance + yieldAmount,
    //         "PowerTrade should receive yield amount"
    //     );
    // }

    // function testDepositAndSwapUSDCKyber() public {
    //     uint256 amount = 1 * 10 ** 6; // USDC amount to deposit and swap

    //     // Check initial USDC balance of user1
    //     uint256 initialUSDCBalance = usdc.balanceOf(user1);
    //     console.log("Initial USDC Balance:", initialUSDCBalance);

    //     // Check initial USDE balance of user1
    //     IERC20 usde = IERC20(usdeAddress);
    //     uint256 initialUSDEBalance = usde.balanceOf(0x1ad0ae8E1DBe78c7313cB8234C3F753adb088A15);
    //     console.log("Initial USDE Balance:", initialUSDEBalance);

    //     vm.startPrank(user1);
    //     usdc.approve(address(userManager), amount);

    //     // Call the depositAndSwapUSDC function
    //     userManager.depositAndSwapUSDC(amount, address(kyberRouter), kyberTransactionData);
    //     vm.stopPrank();

    //     // Check final USDC balance of user1
    //     uint256 finalUSDCBalance = usdc.balanceOf(user1);
    //     console.log("Final USDC Balance:", finalUSDCBalance);

    //     // Check final USDE balance of user1
    //     uint256 finalUSDEBalance = usde.balanceOf(0x1ad0ae8E1DBe78c7313cB8234C3F753adb088A15);
    //     console.log("Final USDE Balance:", finalUSDEBalance);

    //     // Assert that the USDC balance has decreased by the amount
    //     assertEq(finalUSDCBalance, initialUSDCBalance - amount, "USDC balance should decrease by the deposited amount");
    //     // Assert that the USDE balance has increased
    //     assertGt(finalUSDEBalance, initialUSDEBalance, "USDE balance should increase after swap");
    // }

//     function testPermitDepositWithTwoTransfers() public {
//     uint256 amount = 1000 * 10 ** 6; // Total amount to deposit
//     uint256 secondAmount = 200 * 10 ** 6; // Amount for the second transfer
//     uint256 deadline = block.timestamp + 1 hours;
//     uint256 nonce = 0;
//     address secondRecipient = address(this);

//     // Create permitTransferFrom data
//     ISignatureTransfer.TokenPermissions[] memory permissions = new ISignatureTransfer.TokenPermissions[](2);
//     permissions[0] = ISignatureTransfer.TokenPermissions({
//         token: usdcAddress,
//         amount: amount - secondAmount
//     });
//     permissions[1] = ISignatureTransfer.TokenPermissions({
//         token: usdcAddress,
//         amount: secondAmount
//     });

//     ISignatureTransfer.PermitBatchTransferFrom memory permit = ISignatureTransfer.PermitBatchTransferFrom({
//         permitted: permissions,
//         nonce: nonce,
//         deadline: deadline
//     });

//     // Generate the permit data hash using the new function
//     bytes32 digest = _getPermitBatchTypedDataHash(permit, address(userManager));
//     console.logBytes32(digest);

//     // Sign the permit data hash
//     (uint8 v, bytes32 r, bytes32 s) = vm.sign(user1PrivateKey, digest);
//     bytes memory signature = abi.encodePacked(r, s, v);
//     console.logBytes(signature);

//     vm.startPrank(user1);
//     usdc.approve(address(permit2), type(uint256).max);

//     // Prepare transfer details
//     ISignatureTransfer.SignatureTransferDetails[] memory transferDetails = new ISignatureTransfer.SignatureTransferDetails[](2);
//     transferDetails[0] = ISignatureTransfer.SignatureTransferDetails({
//         to: powerTrade,
//         requestedAmount: amount - secondAmount
//     });
//     transferDetails[1] = ISignatureTransfer.SignatureTransferDetails({
//         to: secondRecipient,
//         requestedAmount: secondAmount
//     });

//     // Call the function
//     try permit2.permitTransferFrom(
//         permit,
//         transferDetails,
//         user1,
//         signature
//     ) {
//         // Add assertions to verify the expected outcomes
//         uint256 powerTradeBalance = usdc.balanceOf(powerTrade);
//         uint256 secondRecipientBalance = usdc.balanceOf(secondRecipient);

//         assertEq(powerTradeBalance, amount - secondAmount, "PowerTrade should receive the first amount");
//         assertEq(secondRecipientBalance, secondAmount, "Second recipient should receive the second amount");
//     } catch Error(string memory reason) {
//         console.log("Revert reason:", reason);
//     } catch (bytes memory lowLevelData) {
//         console.logBytes(lowLevelData);
//     }
//     vm.stopPrank();
// }

// // Helper function to generate permit batch transfer signature
// function getPermitBatchTransferSignature(
//     ISignatureTransfer.PermitBatchTransferFrom memory permit,
//     uint256 privateKey,
//     bytes32 domainSeparator
// ) internal returns (bytes memory sig) {
//     bytes32[] memory tokenPermissions = new bytes32[](permit.permitted.length);
//     for (uint256 i = 0; i < permit.permitted.length; ++i) {
//         tokenPermissions[i] = keccak256(abi.encode(_TOKEN_PERMISSIONS_TYPEHASH, permit.permitted[i]));
//     }
//     bytes32 msgHash = keccak256(
//         abi.encodePacked(
//             "\x19\x01",
//             domainSeparator,
//             keccak256(
//                 abi.encode(
//                     _PERMIT_BATCH_TRANSFER_FROM_TYPEHASH,
//                     keccak256(abi.encodePacked(tokenPermissions)),
//                     address(this),
//                     permit.nonce,
//                     permit.deadline
//                 )
//             )
//         )
//     );

//     (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
//     return bytes.concat(r, s, bytes1(v));
// }

// // Helper function to split the signature into v, r, and s
// function splitSignature(bytes memory sig) internal pure returns (uint8 v, bytes32 r, bytes32 s) {
//     require(sig.length == 65, "invalid signature length");
//     assembly {
//         r := mload(add(sig, 0x20))
//         s := mload(add(sig, 0x40))
//         v := byte(0, mload(add(sig, 0x60)))
//     }
// }

// function testBatchDepositAndSwapWithoutPermit() public {
//     uint256 tradeAmount = 1000 * 10 ** 6; // 1000 USDC
//     uint256 yieldAmount = 200 * 10 ** 6;  // 200 USDC
//     uint256 expectedOutput = 999617560449933076255; // Expected USDE output after swap
//     uint256 minPtOut = 900 * 10 ** 6; // Minimum PT tokens to receive

//     // Initial balances
//     uint256 initialUserUSDCBalance = usdc.balanceOf(user1);
//     uint256 initialPowerTradeBalance = usdc.balanceOf(powerTrade);

//     vm.startPrank(user1);
    
//     // Approve USDC spending
//     usdc.approve(address(userManager), tradeAmount + yieldAmount);

//     // Call batchDepositAndSwapWithoutPermit
//     uint256 netPtOut = userManager.batchDepositAndSwapWithoutPermit(
//         tradeAmount,
//         yieldAmount,
//         address(usdeMarket),
//         minPtOut,
//         address(kyberRouter),
//         kyberTransactionData,
//         expectedOutput
//     );

//     vm.stopPrank();

//     // Verify balances
//     uint256 finalUserUSDCBalance = usdc.balanceOf(user1);
//     uint256 finalPowerTradeBalance = usdc.balanceOf(powerTrade);

//     // Assert USDC transfers
//     assertEq(
//         finalUserUSDCBalance, 
//         initialUserUSDCBalance - (tradeAmount + yieldAmount), 
//         "User USDC balance should decrease by total amount"
//     );
//     assertEq(
//         finalPowerTradeBalance,
//         initialPowerTradeBalance + yieldAmount,
//         "PowerTrade should receive yield amount"
//     );

//     // Assert PT tokens received
//     assertGt(netPtOut, minPtOut, "Should receive more than minimum PT tokens");

//     // Optional: Check if USDE was received and swapped correctly
//     IERC20 usde = IERC20(usdeAddress);
//     uint256 usdeBalance = usde.balanceOf(address(userManager));
//     assertEq(usdeBalance, 0, "All USDE should be swapped to PT");
// }

// function testDirectTransaction() public {
//     uint256 amount = 970 * 10 ** 6; // USDC amount for swap
    
//     // Set block timestamp to a time when market is active
//     // This timestamp should be after market activation but before expiry
//     vm.warp(1737879084); // Use the timestamp from your transaction data
    
//     vm.startPrank(user1);
//     // Approve USDC spending directly to the router
//     usdc.approve(to, amount);
    
//     // Execute transaction directly
//     (bool success, ) = to.call(transactionData);
//     require(success, "Transaction failed");
    
//     vm.stopPrank();
// }

// function testDirectKyberTransaction() public {
//     uint256 amount = 1 * 10 ** 6; // USDC amount for swap
    
//     vm.startPrank(user1);
//     // Approve USDC spending directly to the Kyber router
//     usdc.approve(kyberRouter, amount);
    
//     // Execute Kyber transaction directly
//     (bool success, ) = kyberRouter.call(kyberTransactionData);
//     require(success, "Kyber transaction failed");
    
//     vm.stopPrank();
// }
}