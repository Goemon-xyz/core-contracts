// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interfaces/ITreasuryManager.sol";

contract TreasuryManager is
    Initializable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ITreasuryManager
{
    address public treasury;

    function initialize(address _treasury) public initializer {
        __Ownable_init(msg.sender);
        __Pausable_init();

        require(_treasury != address(0), "Invalid treasury address");
        treasury = _treasury;
    }

    function setTreasury(address newTreasury) external onlyOwner {
        require(newTreasury != address(0), "Invalid treasury address");
        treasury = newTreasury;
        emit TreasuryUpdated(newTreasury);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
