pragma solidity >0.4.99 <0.6.0;


contract RootChainPoSWStaking {

    // 3 day locking period.
    uint public constant LOCK_DURATION = 24 * 3600 * 3;

    struct Stake {
        bool unlocked;
        uint256 withdrawableTimestamp;
        uint256 amount;
        address signer;
    }

    mapping (address => Stake) public stakes;

    function addStakes(Stake storage stake, uint256 amount) private {
        if (amount > 0) {
            uint256 newAmount = stake.amount + amount;
            require(newAmount > stake.amount, "addition overflow");
            stake.amount = newAmount;
        }
    }

    function setSigner(address signer) external payable {
        Stake storage stake = stakes[msg.sender];
        require(!stake.unlocked, "should only set signer in locked state");

        stake.signer = signer;
        addStakes(stake, msg.value);
    }

    function () external payable {
        Stake storage stake = stakes[msg.sender];
        require(!stake.unlocked, "should only add stakes in locked state");

        addStakes(stake, msg.value);

    }

    function lock() public payable {
        Stake storage stake = stakes[msg.sender];
        require(stake.unlocked, "should not lock already-locked accounts");

        stake.unlocked = false;
        addStakes(stake, msg.value);
    }

    function unlock() public {
        Stake storage stake = stakes[msg.sender];
        require(!stake.unlocked, "should not unlock already-unlocked accounts");
        require(stake.amount > 0, "should have existing stakes");

        stake.unlocked = true;
        stake.withdrawableTimestamp = now + LOCK_DURATION;
    }

    function withdraw(uint256 amount) public {
        Stake storage stake = stakes[msg.sender];
        require(stake.unlocked && now >= stake.withdrawableTimestamp);
        require(amount <= stake.amount);

        stake.amount -= amount;

        msg.sender.transfer(amount);
    }

    function withdrawAll() public {
        Stake memory stake = stakes[msg.sender];
        require(stake.amount > 0);
        withdraw(stake.amount);
    }

    // Used by root chain for determining stakes.
    function getLockedStakes(address staker) public view returns (uint256, address) {
        Stake memory stake = stakes[staker];
        if (stake.unlocked) {
            return (0, address(0));
        }

        address signer;
        if (stake.signer == address(0)) {
            signer = staker;
        } else {
            signer = stake.signer;
        }
        return (stake.amount, signer);
    }

}
