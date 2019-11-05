pragma solidity >0.4.99 <0.6.0;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";


contract StakingPool {

    using SafeMath for uint256;

    struct StakerInfo {
        uint128 stakes;
        uint128 arrPos;
    }

    uint256 constant MAX_BP = 10000;

    mapping (address => StakerInfo) public stakerInfo;
    address[] public stakers;
    uint256 public totalStakes;
    address payable public miner;
    // Miner reward rate in basis point
    uint256 public feeRateBp;
    uint256 public minerReward;
    uint128 public maxStakers;

    constructor(address payable _miner, uint256 _feeRateBp, uint128 _maxStakers) public {
        require(_feeRateBp <= MAX_BP, "Fee rate should be in basis point.");
        miner = _miner;
        feeRateBp = _feeRateBp;
        maxStakers = _maxStakers;
    }

    function totalStakerSize() public view returns (uint256) {
        return stakers.length;
    }

    // Add stakes
    function () external payable {
        calculatePayout();
        StakerInfo storage info = stakerInfo[msg.sender];
        // New staker
        if (info.stakes == 0) {
            require(stakers.length < maxStakers, "Too many stakers.");
            info.arrPos = uint128(stakers.length);
            stakers.push(msg.sender);
        }

        info.stakes += uint128(msg.value);
        totalStakes = totalStakes.add(msg.value);
        require(totalStakes >= msg.value, "Addition overflow.");
    }

    function withdrawStakes(uint128 amount) public {
        require(amount > 0, "Invalid withdrawal.");
        calculatePayout();
        StakerInfo storage info = stakerInfo[msg.sender];
        require(stakers[info.arrPos] == msg.sender, "Staker should match.");
        require(info.stakes >= amount, "Should have enough stakes to withdraw.");
        info.stakes -= amount;
        totalStakes -= amount;

        msg.sender.transfer(amount);

        if (info.stakes == 0) {
            stakerInfo[stakers[stakers.length - 1]].arrPos = info.arrPos;
            stakers[info.arrPos] = stakers[stakers.length - 1];
            stakers.length--;
            delete stakerInfo[msg.sender];
        }
    }

    function withdrawMinerReward() public {
        require(msg.sender == miner, "Only miner can withdraw his/her rewards.");
        calculatePayout();
        uint256 toWithdraw = minerReward;
        minerReward = 0;
        msg.sender.transfer(toWithdraw);
    }

    function updateMiner(address payable _miner) public {
        require(msg.sender == miner, "Only miner can update the address.");
        calculatePayout();
        miner = _miner;
    }

    function calculateStakesWithDividend(address staker) public view returns (uint256) {
        uint256 dividend = getDividend(address(this).balance);
        uint256 stakerPayout = dividend.mul(MAX_BP - feeRateBp).div(MAX_BP);
        StakerInfo storage info = stakerInfo[staker];
        uint256 toPay = stakerPayout.mul(info.stakes).div(totalStakes);
        return info.stakes + toPay;
    }

    function estimateMinerReward() public view returns (uint256) {
        uint256 dividend = getDividend(address(this).balance);
        return minerReward + dividend.mul(feeRateBp).div(MAX_BP);
    }

    function calculatePayout() private {
        // When adding stakes, need to exclude the current message
        uint256 balance = address(this).balance - msg.value;
        uint256 dividend = getDividend(balance);
        if (dividend == 0) {
            return;
        }
        uint256 stakerPayout = dividend.mul(MAX_BP - feeRateBp).div(MAX_BP);
        uint256 totalPaid = 0;
        for (uint128 i = 0; i < stakers.length; i++) {
            StakerInfo storage info = stakerInfo[stakers[i]];
            uint256 toPay = stakerPayout.mul(info.stakes).div(totalStakes);
            totalPaid = totalPaid.add(toPay);
            info.stakes += uint128(toPay);
        }

        totalStakes = totalStakes.add(totalPaid);
        minerReward = minerReward.add(dividend - totalPaid);

        require(balance >= totalStakes, "Balance should be more than stakes.");
    }

    function getDividend(uint256 balance) private view returns (uint256) {
        require(balance >= totalStakes + minerReward, "Should have enough balance.");
        return balance - totalStakes - minerReward;
    }
}
