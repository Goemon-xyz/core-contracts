// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/UserManager.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "permit2/src/interfaces/IPermit2.sol";

contract MockToken is ERC20 {
    constructor() ERC20("Mock Token", "MTK") {
        _mint(msg.sender, 1_000_000 * 10 ** 18);
    }
}

contract UserManagerTest is Test {
    UserManager public userManager;
    MockToken public token;
    IPermit2 public permit2;
    address public user1;
    uint256 public user1PrivateKey;
    address public powerTrade;

    function setUp() public {
        // Deploy MockToken
        token = new MockToken();
        permit2 = IPermit2(address(0x000000000022D473030F116dDEE9F6B43aC78BA3));

        // Create account with private key
        user1PrivateKey = 0xA11CE;
        user1 = vm.addr(user1PrivateKey);
        powerTrade = vm.addr(0xC0FFEE);

        // Deploy UserManager
        userManager = new UserManager();
        userManager.initialize(address(token), powerTrade, address(permit2));

        token.transfer(address(this), 1_000_000 * 10 ** 18);
        // Assign tokens to user1
        token.transfer(user1, 100_000 * 10 ** 18);
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

            uint256 userBalance = userManager.getUserBalance(user1);
            assertEq(userBalance, amount, "Deposit amount should match user balance");

            uint256 powerTradeBalance = token.balanceOf(powerTrade);
            assertEq(powerTradeBalance, amount, "PowerTrade balance should increase by deposit amount");
        }
} 