pragma solidity >0.4.99 <0.6.0;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/utils/ReentrancyGuard.sol";


contract StakeDrop is ReentrancyGuard {

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

        total = total.sub(staked[msg.sender]);
        msg.sender.transfer(staked[msg.sender]);
        staked[msg.sender] = 0;
    }
}