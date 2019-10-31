pragma solidity >0.4.99 <0.6.0;


contract StakingPool {

    struct StakerInfo {
        uint128 stakes;
        uint128 arrPos;
    }

    mapping (address => StakerInfo) public stakerInfo;
    address[] public stakers;
    uint256 public totalStakes;
    address payable public miner;
    uint256 public feeRateBp;
    uint256 public minerFee;
    uint128 public maxStakers;

    constructor(address payable _miner, uint256 _feeRateBp, uint128 _maxStakers) public {
        require(_feeRateBp <= 10000, "Fee rate should be in basis point.");
        miner = _miner;
        feeRateBp = _feeRateBp;
        maxStakers = _maxStakers;
    }

    function getDividend() public view returns (uint256) {
        return address(this).balance - totalStakes;
    }

    // Add stakes
    function () external payable {
        StakerInfo storage info = stakerInfo[msg.sender];
        // New staker
        if (info.stakes == 0) {
            require(stakers.length < maxStakers, "Too many stakers.");
            info.arrPos = uint128(stakers.length);
            stakers.push(msg.sender);
        }

        info.stakes += uint128(msg.value);
        totalStakes += msg.value;
        require(totalStakes >= msg.value, "Addition overflow.");
        calculatePayout();
    }

    function withdrawStakes(uint128 amount) public {
        StakerInfo storage info = stakerInfo[msg.sender];
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

        calculatePayout();
    }

    function withdrawMinerRewards() public {
        require(msg.sender == miner, "Only miner can withdraw his/her rewards.");
        calculatePayout();
        uint256 toWithdraw = minerFee;
        minerFee = 0;
        msg.sender.transfer(toWithdraw);
    }

    function updateMiner(address payable _miner) public {
        require(msg.sender == miner, "Only miner can update the address.");
        calculatePayout();
        miner = _miner;
    }

    function calculatePayout() private {
        uint256 dividend = getDividend();
        uint256 stakerPayout = dividend * (10000 - feeRateBp) / 10000;
        uint256 paid = 0;
        for (uint16 i = 0; i < stakers.length; i++) {
            StakerInfo storage info = stakerInfo[stakers[i]];
            uint256 toPay = info.stakes * stakerPayout / totalStakes;
            paid += toPay;
            info.stakes += uint128(toPay);
        }

        totalStakes += paid;
        require(totalStakes >= paid, "Addition overflow.");

        minerFee += dividend - paid;

        require(address(this).balance >= totalStakes, "Balance should be more than stakes.");
    }
}
