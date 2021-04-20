pragma solidity >0.4.99 <0.6.0;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/utils/ReentrancyGuard.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";


contract StakeDrop is ReentrancyGuard, Ownable {

    using SafeMath for uint256;

    uint256 public limit;
    uint256 public start;
    uint256 public end;
    uint256 public open;

    uint256 public total;

    mapping(address => uint256) public staked;

    constructor(uint256 _limit, uint256 _start, uint256 _end, uint256 _open) public {
        require(_start < _end, "start >= end");
        require(_end < _open, "end >= open");

        limit = _limit;
        start = _start;
        end = _end;
        open = _open;
    }

    function adjustLimit(uint256 _newLimit) external onlyOwner {
        limit = _newLimit;
    }

    function updateTime(uint256 _start, uint256 _end, uint256 _open) external onlyOwner {
        require(_start < _end, "start >= end");
        require(_end < _open, "end >= open");

        start = _start;
        end = _end;
        open = _open;
    }

    // Add stakes
    function () external payable {
        require(block.timestamp >= start, "not start");
        require(block.timestamp <= end, "ended");

        total = total.add(msg.value);
        require(total <= limit, "exceed limit");

        staked[msg.sender] = staked[msg.sender].add(msg.value);
    }

    function withdraw() external nonReentrant {
        require (block.timestamp >= open, "not yet open");

        uint256 amount = staked[msg.sender];
        total = total.sub(amount);
        staked[msg.sender] = 0;

        msg.sender.transfer(amount);
    }
}
