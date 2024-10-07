// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract Treasury is Pausable {
    using SafeERC20 for IERC20;

    address public gnosisSafe;
    uint256 public constant WITHDRAWAL_DELAY = 1 days;
    uint256 public constant MAX_DAILY_WITHDRAWAL = 1000 * 10 ** 18; // Example: 1000 tokens

    struct WithdrawalRequest {
        address token;
        address recipient;
        uint256 amount;
        uint256 requestTime;
        bool executed;
    }

    mapping(bytes32 => WithdrawalRequest) public withdrawalRequests;
    mapping(address => uint256) public dailyWithdrawals;
    mapping(address => uint256) public lastWithdrawalDay;

    event WithdrawalProposed(
        bytes32 indexed requestId,
        address token,
        address recipient,
        uint256 amount
    );
    event WithdrawalExecuted(
        bytes32 indexed requestId,
        address token,
        address recipient,
        uint256 amount
    );

    modifier onlyGnosisSafe() {
        require(msg.sender == gnosisSafe, "Not authorized");
        _;
    }

    constructor(address _gnosisSafe) {
        require(_gnosisSafe != address(0), "Invalid Gnosis Safe address");
        gnosisSafe = _gnosisSafe;
    }

    function proposeWithdrawal(
        IERC20 token,
        address recipient,
        uint256 amount
    ) external onlyGnosisSafe whenNotPaused {
        require(recipient != address(0), "Invalid recipient");
        require(amount > 0, "Invalid amount");

        bytes32 requestId = keccak256(
            abi.encodePacked(address(token), recipient, amount, block.timestamp)
        );
        withdrawalRequests[requestId] = WithdrawalRequest({
            token: address(token),
            recipient: recipient,
            amount: amount,
            requestTime: block.timestamp,
            executed: false
        });

        emit WithdrawalProposed(requestId, address(token), recipient, amount);
    }

    function executeWithdrawal(
        bytes32 requestId
    ) external onlyGnosisSafe whenNotPaused {
        WithdrawalRequest storage request = withdrawalRequests[requestId];
        require(request.requestTime != 0, "Invalid request");
        require(!request.executed, "Already executed");
        require(
            block.timestamp >= request.requestTime + WITHDRAWAL_DELAY,
            "Withdrawal delay not met"
        );

        uint256 currentDay = block.timestamp / 1 days;
        if (currentDay > lastWithdrawalDay[request.token]) {
            dailyWithdrawals[request.token] = 0;
            lastWithdrawalDay[request.token] = currentDay;
        }

        require(
            dailyWithdrawals[request.token] + request.amount <=
                MAX_DAILY_WITHDRAWAL,
            "Daily limit exceeded"
        );

        request.executed = true;
        dailyWithdrawals[request.token] += request.amount;

        IERC20(request.token).safeTransfer(request.recipient, request.amount);

        emit WithdrawalExecuted(
            requestId,
            request.token,
            request.recipient,
            request.amount
        );
    }

    function pause() external onlyGnosisSafe {
        _pause();
    }

    function unpause() external onlyGnosisSafe {
        _unpause();
    }

    function updateGnosisSafe(address newGnosisSafe) external onlyGnosisSafe {
        require(newGnosisSafe != address(0), "Invalid Gnosis Safe address");
        gnosisSafe = newGnosisSafe;
    }

    receive() external payable {}
}
