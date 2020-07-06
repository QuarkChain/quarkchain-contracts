pragma solidity >0.4.99 <0.6.0;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";


contract StakingPool {

    using SafeMath for uint256;

    struct StakerInfo {
        uint256 stakes;
        uint256 arrPos;
    }

    uint256 constant MAX_BP = 10000;

    mapping (address => StakerInfo) public stakerInfo;
    address[] public stakers;
    address public admin;
    string  public adminContactInfo;
    uint256 public totalStakes;
    uint256 public maxStakers;

    // Miner fee rate in basis point.
    address public miner;
    string  public minerContactInfo;
    uint256 public minerFeeRateBp;
    uint256 public minerReward;
    // Mining pool maintainer and corresponding fee structure.
    address public poolMaintainer;
    uint256 public poolMaintainerFeeRateBp;
    uint256 public poolMaintainerFee;

    constructor(
        address _miner,
        string  memory _minerContactInfo,
        address _admin,
        string  memory _adminContactInfo,
        address _poolMaintainer,
        uint256 _minerFeeRateBp,
        uint256 _poolMaintainerFeeRateBp,
        uint256 _maxStakers
    )
        public
    {
        require(_minerFeeRateBp <= MAX_BP, "Fee rate should be in basis point.");
        require(_poolMaintainerFeeRateBp <= MAX_BP, "Fee rate should be in basis point.");
        require(
            _minerFeeRateBp + _poolMaintainerFeeRateBp <= MAX_BP,
            "Fee rate should be in basis point."
        );
        miner = _miner;
        minerContactInfo = _minerContactInfo;
        admin = _admin;
        adminContactInfo = _adminContactInfo;
        poolMaintainer = _poolMaintainer;
        minerFeeRateBp = _minerFeeRateBp;
        poolMaintainerFeeRateBp = _poolMaintainerFeeRateBp;
        maxStakers = _maxStakers;
    }

    modifier onlyMiner() {
        require(msg.sender == miner, "Only miner can call this function.");
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function.");
        _;
    }

    modifier onlyPoolMaintainer() {
        require(msg.sender == poolMaintainer, "Only pool maintainer can call this function.");
        _;
    }

    function poolSize() public view returns (uint256) {
        return stakers.length;
    }

    // Add stakes
    function () external payable {
        calculatePayout();
        StakerInfo storage info = stakerInfo[msg.sender];
        // New staker
        if (info.stakes == 0) {
            require(stakers.length < maxStakers, "Too many stakers.");
            info.arrPos = stakers.length;
            stakers.push(msg.sender);
        }

        info.stakes = info.stakes.add(msg.value);
        totalStakes = totalStakes.add(msg.value);
    }

    function withdrawStakes(uint256 amount) public {
        require(amount > 0, "Invalid withdrawal.");
        calculatePayout();
        StakerInfo storage info = stakerInfo[msg.sender];
        assert(stakers[info.arrPos] == msg.sender);
        require(info.stakes >= amount, "Should have enough stakes to withdraw.");
        info.stakes = info.stakes.sub(amount);
        totalStakes = totalStakes.sub(amount);

        msg.sender.transfer(amount);

        if (info.stakes == 0) {
            stakerInfo[stakers[stakers.length.sub(1)]].arrPos = info.arrPos;
            stakers[info.arrPos] = stakers[stakers.length.sub(1)];
            stakers.length = stakers.length.sub(1);
            delete stakerInfo[msg.sender];
        }
    }

    function withdrawMinerReward() public onlyMiner {
        calculatePayout();
        uint256 toWithdraw = minerReward;
        minerReward = 0;
        msg.sender.transfer(toWithdraw);
    }

    function transferMaintainerFee() public onlyPoolMaintainer {
        calculatePayout();
        uint256 toTransfer = poolMaintainerFee;
        poolMaintainerFee = 0;
        msg.sender.transfer(toTransfer);
    }

    function updateMiner(address payable _miner) public onlyMiner {
        calculatePayout();
        miner = _miner;
    }

    function updateMinerContactInfo(string memory _minerContactInfo) public onlyMiner {
        minerContactInfo = _minerContactInfo;
    }

    function updateAdmin(address _admin) public onlyAdmin {
        admin = _admin;
    }

    function updateAdminContactInfo(string memory _adminContactInfo) public onlyAdmin {
        adminContactInfo = _adminContactInfo;
    }

    function updatePoolMaintainer(address payable _poolMaintainer) public onlyPoolMaintainer {
        calculatePayout();
        poolMaintainer = _poolMaintainer;
    }

    function adjustMinerFeeRate(uint256 _minerFeeRateBp) public onlyAdmin {
        require(_minerFeeRateBp <= MAX_BP, "Fee rate should be in basis point.");
        require(
            _minerFeeRateBp + poolMaintainerFeeRateBp <= MAX_BP,
            "Fee rate should be in basis point."
        );
        calculatePayout();
        minerFeeRateBp = _minerFeeRateBp;
    }

    function calculateStakesWithDividend(address staker) public view returns (uint256) {
        if (totalStakes == 0) {
            return 0;
        }
        uint256 dividend = getDividend(address(this).balance);
        uint256 feeRateBp = minerFeeRateBp + poolMaintainerFeeRateBp;
        uint256 stakerPayout = dividend.mul(MAX_BP - feeRateBp).div(MAX_BP);
        StakerInfo storage info = stakerInfo[staker];
        uint256 toPay = stakerPayout.mul(info.stakes).div(totalStakes);
        return info.stakes.add(toPay);
    }

    function estimateMinerReward() public view returns (uint256) {
        uint256 dividend = getDividend(address(this).balance).mul(minerFeeRateBp).div(
            stakers.length > 0 ? MAX_BP : minerFeeRateBp + poolMaintainerFeeRateBp);
        return minerReward.add(dividend);
    }

    function estimatePoolMaintainerFee() public view returns (uint256) {
        uint256 dividend = getDividend(address(this).balance).mul(poolMaintainerFeeRateBp).div(
            stakers.length > 0 ? MAX_BP : minerFeeRateBp + poolMaintainerFeeRateBp);
        return poolMaintainerFee.add(dividend);
    }

    function calculatePayout() private {
        // When adding stakes, need to exclude the current message
        uint256 balance = address(this).balance.sub(msg.value);
        uint256 dividend = getDividend(balance);
        if (dividend == 0) {
            return;
        }
        uint256 feeRateBp = minerFeeRateBp + poolMaintainerFeeRateBp;
        uint256 stakerPayout = dividend.mul(MAX_BP - feeRateBp).div(MAX_BP);
        uint256 totalPaid = 0;
        for (uint256 i = 0; i < stakers.length; i++) {
            StakerInfo storage info = stakerInfo[stakers[i]];
            uint256 toPay = stakerPayout.mul(info.stakes).div(totalStakes);
            totalPaid = totalPaid.add(toPay);
            info.stakes = info.stakes.add(toPay);
        }

        totalStakes = totalStakes.add(totalPaid);

        uint256 totalFee = dividend.sub(totalPaid);
        uint256 feeForMiner = totalFee.mul(minerFeeRateBp).div(feeRateBp);
        uint256 feeForMaintainer = totalFee.sub(feeForMiner);
        poolMaintainerFee = poolMaintainerFee.add(feeForMaintainer);
        minerReward = minerReward.add(feeForMiner);
        assert(balance >= totalStakes);
    }

    function getDividend(uint256 balance) private view returns (uint256) {
        uint256 recordedAmount = totalStakes.add(minerReward).add(poolMaintainerFee);
        require(balance >= recordedAmount, "Should have enough balance.");
        return balance.sub(recordedAmount);
    }
}
