// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/TreasuryManager.sol";
import "../src/interfaces/ITreasuryManager.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract TreasuryManagerTest is Test {
    TreasuryManager public treasuryManager;
    address public treasury;
    address public newTreasury;
    address public owner;
    address public user;

    function setUp() public {
        treasury = address(0x1);
        newTreasury = address(0x2);
        owner = address(this);
        user = address(0x3);

        // Deploy TreasuryManager
        TreasuryManager treasuryManagerImpl = new TreasuryManager();
        bytes memory treasuryManagerInitData = abi.encodeWithSelector(TreasuryManager.initialize.selector, treasury);
        ERC1967Proxy treasuryManagerProxy = new ERC1967Proxy(address(treasuryManagerImpl), treasuryManagerInitData);
        treasuryManager = TreasuryManager(address(treasuryManagerProxy));
    }

    function testInitialize() public view {
        assertEq(treasuryManager.treasury(), treasury);
        assertEq(treasuryManager.owner(), owner);
        assertFalse(treasuryManager.paused());
    }

    function testSetTreasury() public {
        vm.prank(owner);
        treasuryManager.setTreasury(newTreasury);
        assertEq(treasuryManager.treasury(), newTreasury);
    }

    function testFailSetTreasuryNonOwner() public {
        vm.prank(user);
        treasuryManager.setTreasury(newTreasury);
    }

    function testFailSetTreasuryZeroAddress() public {
        vm.prank(owner);
        treasuryManager.setTreasury(address(0));
    }

    function testPause() public {
        vm.prank(owner);
        treasuryManager.pause();
        assertTrue(treasuryManager.paused());
    }

    function testUnpause() public {
        vm.startPrank(owner);
        treasuryManager.pause();
        treasuryManager.unpause();
        vm.stopPrank();
        assertFalse(treasuryManager.paused());
    }

    function testFailPauseNonOwner() public {
        vm.prank(user);
        treasuryManager.pause();
    }

    function testFailUnpauseNonOwner() public {
        vm.prank(owner);
        treasuryManager.pause();

        vm.prank(user);
        treasuryManager.unpause();
    }

    function testFailSetTreasuryWhenPaused() public {
        vm.prank(owner);
        treasuryManager.pause();

        vm.prank(owner);
        treasuryManager.setTreasury(newTreasury);
    }

    function testEmitEventOnSetTreasury() public {
        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit ITreasuryManager.TreasuryUpdated(newTreasury);
        treasuryManager.setTreasury(newTreasury);
    }
}
