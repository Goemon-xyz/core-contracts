// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ITradeExecutor2.sol";

contract TradeExecutor2 is ITradeExecutor2, Ownable {
    uint256 public nextNonce;
    address public goemonCore;

    mapping(uint256 => Trade) public trades;

    constructor() Ownable(msg.sender) {
        nextNonce = 0;
    }

    function setGoemonCore(address _goemonCore) external onlyOwner {
        require(_goemonCore != address(0), "Invalid GoemonCore address");
        goemonCore = _goemonCore;
    }

    modifier onlyGoemonCore() {
        require(msg.sender == goemonCore, "Only GoemonCore can call this function");
        _;
    }

    function initiateTrade(
        address user,
        uint256 amount,
        string calldata intentType
    )
        external
        override
        onlyGoemonCore
        returns (uint256)
    {
        uint256 nonce = nextNonce++;
        trades[nonce] =
            Trade({ user: user, amount: amount, intentType: intentType, timestamp: block.timestamp, isSettled: false });

        emit TradeInitiated(user, nonce, amount, intentType);
        return nonce;
    }

    function settleTrade(address user, uint256 nonce) external override onlyGoemonCore {
        require(!trades[nonce].isSettled, "Trade already settled");
        require(trades[nonce].user == user, "Invalid user for trade");

        trades[nonce].isSettled = true;

        emit TradeSettled(user, nonce);
    }

    function getTrade(uint256 nonce) external view returns (Trade memory) {
        return trades[nonce];
    }
}
