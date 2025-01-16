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

    bytes transactionData = hex"c81f847a0000000000000000000000001ad0ae8e1dbe78c7313cb8234c3f753adb088a15000000000000000000000000b451a36c8b6b2eac77ad0737ba732818143a0e2500000000000000000000000000000000000000000000003530116290712a97a300000000000000000000000000000000000000000000001b22f93249b1e6b5db00000000000000000000000000000000000000000000003bb3576ea220fb901500000000000000000000000000000000000000000000003645f2649363cd6bb6000000000000000000000000000000000000000000000000000000000000001e00000000000000000000000000000000000000000000000000038d7ea4c6800000000000000000000000000000000000000000000000000000000000000001400000000000000000000000000000000000000000000000000000000000000b20000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000000000000000000000000000000000003984bb400000000000000000000000004c9edd5852cd905f086c759e8383e09bff1e68b30000000000000000000000001e8b6ac39f8a33f46a6eb2d1acd1047b99180ad100000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000010000000000000000000000006131b5fae19ea4f9d964eac0408e4408b66337b5000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000884e21fd0e90000000000000000000000000000000000000000000000000000000000000020000000000000000000000000f081470f5c6fbccf48cc4e5b82dd926409dcdd67000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000003c000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000300000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000000000000000000000004c9edd5852cd905f086c759e8383e09bff1e68b3000000000000000000000000888888888889758f76e7103c6cbf23abbf58f946000000000000000000000000000000000000000000000000000000007fffffff00000000000000000000000000000000000000000000000000000000000002a000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000040d90ce49100000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000010000000000000000000000000002950460e2b9529d0e00284a5fa2d7bdf3fa4d72000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000000000000000000000004c9edd5852cd905f086c759e8383e09bff1e68b300000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003984bb40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000020000000000000000000036e077aab29cd000000000000003455a99f863e9e738c000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000000000000000000000004c9edd5852cd905f086c759e8383e09bff1e68b3000000000000000000000000000000000000000000000000000000000000016000000000000000000000000000000000000000000000000000000000000001a000000000000000000000000000000000000000000000000000000000000001e00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000888888888889758f76e7103c6cbf23abbf58f946000000000000000000000000000000000000000000000000000000003984bb4000000000000000000000000000000000000000000000003349b59736c27c8ff4000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002200000000000000000000000000000000000000000000000000000000000000001000000000000000000000000f081470f5c6fbccf48cc4e5b82dd926409dcdd670000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000003984bb4000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002307b22536f75726365223a2250656e646c65222c22416d6f756e74496e555344223a223936302e36323234333035383134373039222c22416d6f756e744f7574555344223a223936322e34303830333630313232353133222c22526566657272616c223a22222c22466c616773223a302c22416d6f756e744f7574223a22393635343033333331393936313039363635313634222c2254696d657374616d70223a313733363837303739382c22496e74656772697479496e666f223a7b224b65794944223a2231222c225369676e6174757265223a2263696f2b627562384d444b6e3074425262436f4e766458496d7943784a3237417a357752305370496643506569706a385037664571435149556278773251547436384a73526a775a666a7a425475324f356e7345637231686c674e322b4839436c54435a74486136327932394158664a6e426f782b5a62385658756f662b476a716739626135456b4a2b6f74634b74316d7a5058476c6f46363777655772634846664231704b593556566b387231476a6b42413045454476306e412b6442796874484b5730554375456d31464e49554b6d347656714e59682f63435a763145566557576f434358633544677a6a6a3559314264712b2b767a307a46584b544f7a78374e31697a6d5762577546616a4e4a4558625679693234656742484d464475385830763676336165322b43397657752f527874624c64392b3270487175376f33637636666d6e415878486f52486a522f41627263773d3d227d7d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
    address to = 0x888888888889758F76e7103c6CbF23ABbF58F946;

    bytes kyberTransactionData = hex"e21fd0e90000000000000000000000000000000000000000000000000000000000000020000000000000000000000000f081470f5c6fbccf48cc4e5b82dd926409dcdd67000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000003a000000000000000000000000000000000000000000000000000000000000005e000000000000000000000000000000000000000000000000000000000000002e0000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000000000000000000000004c9edd5852cd905f086c759e8383e09bff1e68b30000000000000000000000001ad0ae8e1dbe78c7313cb8234c3f753adb088a1500000000000000000000000000000000000000000000000000000000678736d300000000000000000000000000000000000000000000000000000000000002800000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000004063407a490000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000f081470f5c6fbccf48cc4e5b82dd926409dcdd67000000000000000000000000e6d7ebb9f1a9519dc06d557e03c522d53520e76a000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000000000000000000000004c9edd5852cd905f086c759e8383e09bff1e68b300000000000000000000000000000000000000000000000000000000000f42400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000e8c37481f600000000000000000ddfb068840e9dd3000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000000000000000000000004c9edd5852cd905f086c759e8383e09bff1e68b3000000000000000000000000000000000000000000000000000000000000016000000000000000000000000000000000000000000000000000000000000001a000000000000000000000000000000000000000000000000000000000000001e000000000000000000000000000000000000000000000000000000000000002000000000000000000000000001ad0ae8e1dbe78c7313cb8234c3f753adb088a1500000000000000000000000000000000000000000000000000000000000f42400000000000000000000000000000000000000000000000000ddc232d04f2f431000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002200000000000000000000000000000000000000000000000000000000000000001000000000000000000000000f081470f5c6fbccf48cc4e5b82dd926409dcdd67000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000f424000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002297b22536f75726365223a22222c22416d6f756e74496e555344223a22302e39393938353533333133383431393731222c22416d6f756e744f7574555344223a22302e39393830383735363335353130373132222c22526566657272616c223a22222c22466c616773223a302c22416d6f756e744f7574223a22393939373131363035323338313737323335222c2254696d657374616d70223a313733363931333434332c22496e74656772697479496e666f223a7b224b65794944223a2231222c225369676e6174757265223a2251716e78544f5835393377484952732b3347555234313066697a7250566f5a39594c782f4e7938742b73454d6464686f464a673243766e42486f67704a744648754c324e46306f70322f436956374e70384f414b4671364e7646654a644154717139537a7463394e7772687861376d45573736514476794c4d414e697772314375624e4f776b4d6e48676e5257442f356138486a7953747478576b6a306745562b31524d4d44572f467952767242344f304447433132796773394953304c6b7734764a7476567676776d366d6b3332382b5a702b7a4942453468566a32594b427050506a50342b44324b326567616c414e63544d4e63612b452b343475413567787a534655446f3778584a4452764c696a786978576739484c456b614371414369645a327a46324d67574a4f567753486c4a50423876537a4b364b6646437569484c4e6e61682b596c555969765751552f576b4634673d3d227d7d0000000000000000000000000000000000000000000000";
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
        vm.createSelectFork({ urlOrAlias: "mainnet" });
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
        deal(usdeAddress, address(this), 100_000 * 10 ** 6);
        deal(usdeAddress, user1, 100_000 * 10 ** 6);
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

    function testBuyPT() public {
        (uint256 netPtOut, , ) = router.swapExactTokenForPt(
        address(user1),
        address(wstMarket),
        0,
        defaultApprox,
        createTokenInputStruct(wstETHAddress, 1e18),
        emptyLimit
    );
    console.log("netPtOut: %s", netPtOut);
    }

    function testBuyUsdePT() public {
        (uint256 netPtOut, , ) = router.swapExactTokenForPt(
        address(user1),
        address(usdeMarket),
        0,
        defaultApprox,
        createTokenInputStruct(usdeAddress, 1e6),
        emptyLimit
    );
    console.log("netPtOut: %s", netPtOut);
    }

    function testDepositAndSwapUSDC() public {
        uint256 amount = 965 * 10 ** 6; // USDC amount to deposit and swap

        // Check initial USDC balance of user1
        uint256 initialBalance = usdc.balanceOf(user1);
        console.log("Initial USDC Balance:", initialBalance);

        vm.startPrank(user1);
        usdc.approve(address(userManager), amount);

        // Call the depositAndSwapUSDC function
        userManager.depositAndSwapUSDC(amount, address(to), transactionData);
        vm.stopPrank();

        // Check final USDC balance of user1
        uint256 finalBalance = usdc.balanceOf(user1);
        console.log("Final USDC Balance:", finalBalance);

        // Assert that the balance has decreased by the amount
        assertEq(finalBalance, initialBalance - amount, "USDC balance should decrease by the deposited amount");

        // Add additional assertions to verify the expected outcomes
        // For example, check the balance of PT tokens received
    }

    function testDepositAndSwapUSDCKyber() public {
        uint256 amount = 1 * 10 ** 6; // USDC amount to deposit and swap

        // Check initial USDC balance of user1
        uint256 initialUSDCBalance = usdc.balanceOf(user1);
        console.log("Initial USDC Balance:", initialUSDCBalance);

        // Check initial USDE balance of user1
        IERC20 usde = IERC20(usdeAddress);
        uint256 initialUSDEBalance = usde.balanceOf(0x1ad0ae8E1DBe78c7313cB8234C3F753adb088A15);
        console.log("Initial USDE Balance:", initialUSDEBalance);

        vm.startPrank(user1);
        usdc.approve(address(userManager), amount);

        // Call the depositAndSwapUSDC function
        userManager.depositAndSwapUSDC(amount, address(kyberRouter), kyberTransactionData);
        vm.stopPrank();

        // Check final USDC balance of user1
        uint256 finalUSDCBalance = usdc.balanceOf(user1);
        console.log("Final USDC Balance:", finalUSDCBalance);

        // Check final USDE balance of user1
        uint256 finalUSDEBalance = usde.balanceOf(0x1ad0ae8E1DBe78c7313cB8234C3F753adb088A15);
        console.log("Final USDE Balance:", finalUSDEBalance);

        // Assert that the USDC balance has decreased by the amount
        assertEq(finalUSDCBalance, initialUSDCBalance - amount, "USDC balance should decrease by the deposited amount");
        // Assert that the USDE balance has increased
        assertGt(finalUSDEBalance, initialUSDEBalance, "USDE balance should increase after swap");
    }

    function testPermitDepositWithTwoTransfers() public {
    uint256 amount = 1000 * 10 ** 6; // Total amount to deposit
    uint256 secondAmount = 200 * 10 ** 6; // Amount for the second transfer
    uint256 deadline = block.timestamp + 1 hours;
    uint256 nonce = 0;
    address secondRecipient = address(this);

    // Create permitTransferFrom data
    ISignatureTransfer.TokenPermissions[] memory permissions = new ISignatureTransfer.TokenPermissions[](2);
    permissions[0] = ISignatureTransfer.TokenPermissions({
        token: usdcAddress,
        amount: amount - secondAmount
    });
    permissions[1] = ISignatureTransfer.TokenPermissions({
        token: usdcAddress,
        amount: secondAmount
    });

    ISignatureTransfer.PermitBatchTransferFrom memory permit = ISignatureTransfer.PermitBatchTransferFrom({
        permitted: permissions,
        nonce: nonce,
        deadline: deadline
    });

    // Generate the permit data hash using the new function
    bytes32 digest = _getPermitBatchTypedDataHash(permit, address(userManager));
    console.logBytes32(digest);

    // Sign the permit data hash
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(user1PrivateKey, digest);
    bytes memory signature = abi.encodePacked(r, s, v);
    console.logBytes(signature);

    vm.startPrank(user1);
    usdc.approve(address(permit2), type(uint256).max);

    // Prepare transfer details
    ISignatureTransfer.SignatureTransferDetails[] memory transferDetails = new ISignatureTransfer.SignatureTransferDetails[](2);
    transferDetails[0] = ISignatureTransfer.SignatureTransferDetails({
        to: powerTrade,
        requestedAmount: amount - secondAmount
    });
    transferDetails[1] = ISignatureTransfer.SignatureTransferDetails({
        to: secondRecipient,
        requestedAmount: secondAmount
    });

    // Call the function
    try permit2.permitTransferFrom(
        permit,
        transferDetails,
        user1,
        signature
    ) {
        // Add assertions to verify the expected outcomes
        uint256 powerTradeBalance = usdc.balanceOf(powerTrade);
        uint256 secondRecipientBalance = usdc.balanceOf(secondRecipient);

        assertEq(powerTradeBalance, amount - secondAmount, "PowerTrade should receive the first amount");
        assertEq(secondRecipientBalance, secondAmount, "Second recipient should receive the second amount");
    } catch Error(string memory reason) {
        console.log("Revert reason:", reason);
    } catch (bytes memory lowLevelData) {
        console.logBytes(lowLevelData);
    }
    vm.stopPrank();
}

function testPermitDepositWithMultipleTransfers() public {
    uint256 amount = 1000 * 10 ** 6; // Total amount to deposit
    uint256 deadline = block.timestamp + 1 hours;
    uint256 nonce = 0;

    // Define recipients and amounts
    address[] memory recipients = new address[](2);
    uint256[] memory amounts = new uint256[](2);
    recipients[0] = address(0x123); // Example recipient 1
    recipients[1] = address(0x456); // Example recipient 2
    amounts[0] = 600 * 10 ** 6; // Amount for recipient 1
    amounts[1] = 400 * 10 ** 6; // Amount for recipient 2

    // Create token permissions array
    ISignatureTransfer.TokenPermissions[] memory permissions = new ISignatureTransfer.TokenPermissions[](2);
    permissions[0] = ISignatureTransfer.TokenPermissions({
        token: address(usdc),
        amount: amounts[0]
    });
    permissions[1] = ISignatureTransfer.TokenPermissions({
        token: address(usdc),
        amount: amounts[1]
    });

    // Create permit batch transfer data
    ISignatureTransfer.PermitBatchTransferFrom memory permit = ISignatureTransfer.PermitBatchTransferFrom({
        permitted: permissions,
        nonce: nonce,
        deadline: deadline
    });

    // Get domain separator from permit2 contract
    bytes32 domainSeparator = permit2.DOMAIN_SEPARATOR();

    // Generate signature using the template
    bytes memory signature = getPermitBatchTransferSignature(
        permit,
        user1PrivateKey,
        domainSeparator
    );

    // Log the generated signature
    // console.log("Generated Signature:", signature);

    // Create permitTransferFrom data
    bytes memory permitTransferFrom = abi.encode(address(usdc), amount);

    // Log the permitTransferFrom data
    // console.log("Permit Transfer From Data:", permitTransferFrom);

    // Log the expected address for permitDepositWithMultipleTransfers
    console.log("Expected address for permitDepositWithMultipleTransfers:", user1);

    // Log the address used in the signature
    console.log("Address used in signature:", user1);

    // Verify the private key and derived address
    address derivedUser1 = vm.addr(user1PrivateKey);
    console.log("Derived user1 address from private key:", derivedUser1);

    // Decode the signature
    (uint8 v, bytes32 r, bytes32 s) = splitSignature(signature);
    
    // Create a packed representation of the permissions
    bytes32[] memory tokenPermissions = new bytes32[](permissions.length);
    for (uint256 i = 0; i < permissions.length; i++) {
        tokenPermissions[i] = keccak256(abi.encode(permissions[i]));
    }
    
    bytes32 msgHash = keccak256(abi.encodePacked(
        "\x19\x01",
        permit2.DOMAIN_SEPARATOR(),
        keccak256(abi.encode(
            _PERMIT_BATCH_TRANSFER_FROM_TYPEHASH,
            keccak256(abi.encodePacked(tokenPermissions)), // Use the packed representation
            address(this),
            nonce,
            deadline
        ))
    ));
    
    // Log the message hash
    console.logBytes32(msgHash);

    // Recover the address from the signature
    address recoveredAddress = ecrecover(msgHash, v, r, s);
    console.log("Recovered address from signature:", recoveredAddress);
    
    // Call the permitDepositWithMultipleTransfers function
    vm.startPrank(user1);
    userManager.permitDepositWithMultipleTransfers(
        amount,
        deadline,
        nonce,
        permitTransferFrom,
        signature,
        recipients,
        amounts
    );

    vm.stopPrank();

    // Assertions
    assertEq(usdc.balanceOf(recipients[0]), amounts[0], "Recipient 1 should receive the correct amount");
    assertEq(usdc.balanceOf(recipients[1]), amounts[1], "Recipient 2 should receive the correct amount");
}

// Helper function to generate permit batch transfer signature
function getPermitBatchTransferSignature(
    ISignatureTransfer.PermitBatchTransferFrom memory permit,
    uint256 privateKey,
    bytes32 domainSeparator
) internal returns (bytes memory sig) {
    bytes32[] memory tokenPermissions = new bytes32[](permit.permitted.length);
    for (uint256 i = 0; i < permit.permitted.length; ++i) {
        tokenPermissions[i] = keccak256(abi.encode(_TOKEN_PERMISSIONS_TYPEHASH, permit.permitted[i]));
    }
    bytes32 msgHash = keccak256(
        abi.encodePacked(
            "\x19\x01",
            domainSeparator,
            keccak256(
                abi.encode(
                    _PERMIT_BATCH_TRANSFER_FROM_TYPEHASH,
                    keccak256(abi.encodePacked(tokenPermissions)),
                    address(this),
                    permit.nonce,
                    permit.deadline
                )
            )
        )
    );

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
    return bytes.concat(r, s, bytes1(v));
}

// Helper function to split the signature into v, r, and s
function splitSignature(bytes memory sig) internal pure returns (uint8 v, bytes32 r, bytes32 s) {
    require(sig.length == 65, "invalid signature length");
    assembly {
        r := mload(add(sig, 0x20))
        s := mload(add(sig, 0x40))
        v := byte(0, mload(add(sig, 0x60)))
    }
}
}