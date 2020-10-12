pragma solidity >0.4.99 <0.6.0;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";

/*
 * This contract implements an algorithm to dynamically calculate staker's interest in O(1).
 */
contract RootChainStakingPool {

    using SafeMath for uint256;

    struct StakerInfo {
        uint256 stakes;
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of QKC
        // entitled to a staker but is pending to be distributed is:
        //
        //   pending reward = (staker.stakes * accQKCPerShare) - staker.rewardDebt
        //
        // Whenever a staker deposits or withdraws stakes to the RootChainStakingPool. Here's what happens:
        //   1. The pool's `accQKCPerShare` gets updated.
        //   2. Staker's `amount` gets updated.
        //   3. Staker's `rewardDebt` gets updated.
    }

    uint256 constant MAX_BP = 10000;

    mapping (address => StakerInfo) public stakerInfo;
    address public admin;
    uint256 public minStakes;
    string  public adminContactInfo;
    uint256 public totalStakes;
    uint256 public accQKCPershare; // Accumulated QKCs per share, times 1e18. See below
    uint256 private size; // pool size.

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
        uint256 _minStakes,
        uint256 _minerFeeRateBp,
        uint256 _poolMaintainerFeeRateBp
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
        minStakes = _minStakes;
        minerFeeRateBp = _minerFeeRateBp;
        poolMaintainerFeeRateBp = _poolMaintainerFeeRateBp;
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
        return size;
    }

    // Add stakes
    function () external payable {
        updateStakingPool();
        StakerInfo storage info = stakerInfo[msg.sender];
        // New staker
        if (info.stakes == 0) {
            require(msg.value >= minStakes, "Invalid stakes.");
            size = size.add(1);
        }
        // Calculate pending interest over two operations.
        uint256 pending = info.stakes.mul(accQKCPershare).div(1e18).sub(info.rewardDebt);
        // Updated staker'stakes, which is current stakes + pending interest + new stakes.
        info.stakes = info.stakes.add(pending).add(msg.value);
        // Update staker's rewardDebt based on the new stakes.
        info.rewardDebt = info.stakes.mul(accQKCPershare).div(1e18);
        totalStakes = totalStakes.add(msg.value);
    }

    function withdrawStakes(uint256 amount) public {
        require(amount > 0, "Invalid withdrawal.");
        updateStakingPool();
        StakerInfo storage info = stakerInfo[msg.sender];
        uint256 pending = info.stakes.mul(accQKCPershare).div(1e18).sub(info.rewardDebt);
        // Updated staker'stakes, which is the current stakes + pending interest.
        info.stakes = info.stakes.add(pending);
        require(info.stakes >= amount, "Should have enough stakes to withdraw.");
        require(
            info.stakes.sub(amount) == 0 || info.stakes.sub(amount) >= minStakes,
            "Should satisfy minimum stakes."
        );
        info.stakes = info.stakes.sub(amount);
        info.rewardDebt = info.stakes.mul(accQKCPershare).div(1e18);
        totalStakes = totalStakes.sub(amount);

        msg.sender.transfer(amount);

        if (info.stakes == 0) {
            size = size.sub(1);
            delete stakerInfo[msg.sender];
        }
    }

    function withdrawMinerReward() public onlyMiner {
        updateStakingPool();
        uint256 toWithdraw = minerReward;
        minerReward = 0;
        msg.sender.transfer(toWithdraw);
    }

    function transferMaintainerFee() public onlyPoolMaintainer {
        updateStakingPool();
        uint256 toTransfer = poolMaintainerFee;
        poolMaintainerFee = 0;
        msg.sender.transfer(toTransfer);
    }

    function updateMiner(address payable _miner) public onlyMiner {
        updateStakingPool();
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
        updateStakingPool();
        poolMaintainer = _poolMaintainer;
    }

    function adjustMinerFeeRate(uint256 _minerFeeRateBp) public onlyAdmin {
        require(_minerFeeRateBp <= MAX_BP, "Fee rate should be in basis point.");
        require(
            _minerFeeRateBp + poolMaintainerFeeRateBp <= MAX_BP,
            "Fee rate should be in basis point."
        );
        updateStakingPool();
        minerFeeRateBp = _minerFeeRateBp;
    }

    function calculateStakesWithDividend(address staker) public view returns (uint256) {
        if (totalStakes == 0) {
            return 0;
        }
        uint256 dividend = getDividend(address(this).balance);
        uint256 feeRateBp = minerFeeRateBp + poolMaintainerFeeRateBp;
        uint256 stakerPayout = dividend.mul(MAX_BP - feeRateBp).div(MAX_BP);
        // Calculate the latest accQKCPershare, so that staker can know his/her stakes until now.
        uint256 tempAccQKCPershare = accQKCPershare.add(stakerPayout.mul(1e18).div(totalStakes));
        StakerInfo storage info = stakerInfo[staker];
        uint256 pending = info.stakes.mul(tempAccQKCPershare).div(1e18).sub(info.rewardDebt);
        return info.stakes.add(pending);
    }

    function estimateMinerReward() public view returns (uint256) {
        uint256 dividend = getDividend(address(this).balance).mul(minerFeeRateBp).div(
            size > 0 ? MAX_BP : minerFeeRateBp + poolMaintainerFeeRateBp);
        return minerReward.add(dividend);
    }

    function estimatePoolMaintainerFee() public view returns (uint256) {
        uint256 dividend = getDividend(address(this).balance).mul(poolMaintainerFeeRateBp).div(
            size > 0 ? MAX_BP : minerFeeRateBp + poolMaintainerFeeRateBp);
        return poolMaintainerFee.add(dividend);
    }

    function updateStakingPool() private {
        // When adding stakes, need to exclude the current message
        uint256 balance = address(this).balance.sub(msg.value);
        uint256 dividend = getDividend(balance);
        if (dividend == 0) {
            return;
        }
        uint256 feeRateBp = minerFeeRateBp + poolMaintainerFeeRateBp;
        uint256 stakerPayout = dividend.mul(MAX_BP - feeRateBp).div(MAX_BP);
        uint256 totalPaid = 0;

        // Explain the theory of accQKCPershare.
        // For a period of time, the interest of a single staker got is his/her percentage of the total interest,
        // which can be expressed as (periodInterest * staker.stakes) / totalStakes.
        // Extract periodInterest / totalStakes named as QKCPershare.
        // Extend it to overall, the total interest of a single staker got is the sum of the interest of each period.
        // which can be expressed as (sum of periodInterest * staker.stakes) / totalStakes,
        // also equal to sum of QKCPershare * staker.stakes.
        // Extract sum of QKCPershare named as accQKCPershare.
        if (totalStakes != 0) {
            accQKCPershare = accQKCPershare.add(stakerPayout.mul(1e18).div(totalStakes));
            // If the pool has staker, the periodInterest will be automatically added to totalStakes.
            totalPaid = stakerPayout;
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
