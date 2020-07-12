/* eslint no-unused-vars: 0 */
const assert = require('assert');
const { promisify } = require('util');

const StakingPool = artifacts.require('./StakingPool');
const SelfDestruct = artifacts.require('./mocks/SelfDestruct');
require('chai').use(require('chai-as-promised')).should();

const revertError = 'VM Exception while processing transaction: revert';
const toWei = i => web3.utils.toWei(String(i));
const gasPriceMax = 0;

function txGen(from, value) {
  return {
    from, value, gasPrice: gasPriceMax,
  };
}

async function forceSend(target, value, from) {
  const selfDestruct = await SelfDestruct.new({ value, from });
  await selfDestruct.forceSend(target);
}

contract('StakingPool', async (accounts) => {
  let pool;
  const miner = accounts[9];
  const minerContactInfo = 'miner@stakingpool';
  const admin = accounts[8];
  const adminContactInfo = 'admin@stakingpool';
  const maintainer = accounts[7];
  const treasury = accounts[6];
  // 50% miner fee rate.
  const minerFeeRateBp = 5000;
  // None goes to maintainer.
  const poolMaintainerFeeRateBp = 0;
  const maxStakers = 16;
  const minStakes = toWei(1);

  beforeEach(async () => {
    pool = await StakingPool.new(
      miner,
      minerContactInfo,
      admin,
      adminContactInfo,
      maintainer,
      minStakes,
      minerFeeRateBp,
      poolMaintainerFeeRateBp,
      maxStakers,
    );
  });

  it('should deploy correctly', async () => {
    assert.notEqual(pool.address, `0x${'0'.repeat(40)}`);
  });

  it('should work with minStakes correctly', async () => {
    const min = await pool.minStakes();
    assert.equal(min, toWei(1));

    await pool.sendTransaction(txGen(accounts[0], toWei(0.1)))
      .should.be.rejectedWith(revertError);

    await pool.sendTransaction(txGen(accounts[0], toWei(1)));
    const stakerInfo = await pool.stakerInfo(accounts[0]);
    assert.equal(stakerInfo[0], toWei(1));

    await pool.withdrawStakes(toWei(0.1)).should.be.rejectedWith(revertError);
    await pool.withdrawStakes(toWei(1));
  });

  it('should handle adding stakes properly', async () => {
    await pool.sendTransaction(txGen(accounts[0], toWei(42)));
    const minerReward = await pool.minerReward();
    assert.equal(minerReward, 0);
    let poolSize = await pool.poolSize();
    assert.equal(poolSize, 1);
    const staker = await pool.stakers(0);
    assert.equal(staker, accounts[0]);
    const stakerInfo = await pool.stakerInfo(accounts[0]);
    assert.equal(stakerInfo[0], toWei(42));
    assert.equal(stakerInfo[1], 0);
    let totalStakes = await pool.totalStakes();
    assert.equal(totalStakes, toWei(42));
    let stakesWithDividends = await pool.calculateStakesWithDividend(accounts[0]);
    assert.equal(stakesWithDividends, toWei(42));
    // Random person should have zero stakes.
    stakesWithDividends = await pool.calculateStakesWithDividend(accounts[5]);
    assert.equal(stakesWithDividends, 0);

    await pool.sendTransaction(txGen(accounts[1], toWei(100)));
    poolSize = await pool.poolSize();
    assert.equal(poolSize, 2);
    totalStakes = await pool.totalStakes();
    assert.equal(totalStakes, toWei(142));
  });

  it('should handle withdrawing stakes properly', async () => {
    await pool.sendTransaction(txGen(accounts[0], toWei(42)));
    await pool.withdrawStakes(toWei(0)).should.be.rejectedWith(revertError);
    await pool.withdrawStakes(toWei(40));
    let totalStakes = await pool.totalStakes();
    assert.equal(totalStakes, toWei(2));
    let poolBalance = await web3.eth.getBalance(pool.address);
    assert.equal(poolBalance, toWei(2));
    let stakesWithDividends = await pool.calculateStakesWithDividend(accounts[0]);
    assert.equal(stakesWithDividends, toWei(2));
    // Failure.
    await pool.withdrawStakes(toWei(3))
      .should.be.rejectedWith(revertError);
    // Withdraw all.
    await pool.withdrawStakes(toWei(2));
    const poolSize = await pool.poolSize();
    assert.equal(poolSize, 0);
    totalStakes = await pool.totalStakes();
    assert.equal(totalStakes, 0);
    stakesWithDividends = await pool.calculateStakesWithDividend(accounts[0]);
    assert.equal(stakesWithDividends, 0);
    poolBalance = await web3.eth.getBalance(pool.address);
    assert.equal(poolBalance, 0);
  });

  it('should calculate dividends correctly', async () => {
    await pool.sendTransaction(txGen(accounts[0], toWei(42)));
    await forceSend(pool.address, toWei(8), treasury);
    let poolBalance = await web3.eth.getBalance(pool.address);
    assert.equal(poolBalance, toWei(50));
    // State has not been updated.
    let minerReward = await pool.minerReward();
    assert.equal(minerReward, 0);
    const stakerInfo = await pool.stakerInfo(accounts[0]);
    let stakes = stakerInfo[0];
    assert.equal(stakes, toWei(42));
    // Stakers can calculate their stakes with dividends.
    stakes = await pool.calculateStakesWithDividend(accounts[0]);
    assert.equal(stakes, toWei(42 + (8 / 2)));
    // Calculate amount of dividends and let the staker withdraw, which will update the state.
    const stakesWithDividends = await pool.calculateStakesWithDividend(accounts[0]);
    assert.equal(stakesWithDividends, toWei(46));
    await pool.withdrawStakes(toWei(46.1)).should.be.rejectedWith(revertError);
    await pool.withdrawStakes(toWei(46));
    // 50% of coinbase rewards goes to miner.
    minerReward = await pool.minerReward();
    assert.equal(minerReward, toWei(4));
    // Pool balance should update.
    poolBalance = await web3.eth.getBalance(pool.address);
    assert.equal(poolBalance, toWei(4));
    // Miner can withdraw as well.
    await pool.withdrawMinerReward({ from: miner });
    poolBalance = await web3.eth.getBalance(pool.address);
    assert.equal(poolBalance, 0);
    minerReward = await pool.minerReward();
    assert.equal(minerReward, 0);
  });

  it('should accept new stakers', async () => {
    await pool.sendTransaction(txGen(accounts[0], toWei(10)));
    await forceSend(pool.address, toWei(10), treasury);
    // Now the staker should have 15 QKC and the miner has 5.
    // A new staker comes in.
    const newStaker = accounts[2];
    await pool.sendTransaction(txGen(newStaker, toWei(20)));
    // Shouldn't affect the outcome: prev staker 15 QKC, miner 5 and new staker 20.
    // 1. Check prev staker.
    // Internal state not updated but should be able to withdraw stakes + dividends.
    let stakerInfo = await pool.stakerInfo(accounts[0]);
    let stakes = stakerInfo[0];
    assert.equal(stakes, toWei(15));
    stakes = await pool.calculateStakesWithDividend(accounts[0]);
    assert.equal(stakes, toWei(15));
    // 2. Check new staker.
    stakerInfo = await pool.stakerInfo(newStaker);
    stakes = stakerInfo[0];
    assert.equal(stakes, toWei(20));
    stakes = await pool.calculateStakesWithDividend(newStaker);
    assert.equal(stakes, toWei(20));
    // 3. Check miner.
    const minerBalanceBefore = await web3.eth.getBalance(miner);
    let minerReward = await pool.minerReward();
    assert.equal(minerReward, toWei(5));
    // But should be able to withdraw his/her rewards.
    await pool.withdrawMinerReward({ from: miner, gasPrice: 0 });
    const minerBalanceAfter = await web3.eth.getBalance(miner);
    const diff = (minerBalanceAfter / (10 ** 18)) - (minerBalanceBefore / (10 ** 18));
    assert.equal(diff, 5);
    // Prev staker should also be able to withdraw stakes + dividends.
    await pool.withdrawStakes(toWei(15));
    // After a new round of mining rewards, only the miner and the new staker should have dividends.
    await forceSend(pool.address, toWei(20), treasury);
    stakes = await pool.calculateStakesWithDividend(newStaker);
    assert.equal(stakes, toWei(20 + (20 / 2)));
    stakes = await pool.calculateStakesWithDividend(accounts[0]);
    assert.equal(stakes, 0);
    minerReward = await pool.minerReward();
    assert.equal(minerReward, toWei(0));
    minerReward = await pool.estimateMinerReward();
    assert.equal(minerReward, toWei(20 / 2));
  });

  it('should handle no staker case', async () => {
    await forceSend(pool.address, toWei(10), treasury);
    let minerReward = await pool.minerReward();
    assert.equal(minerReward, toWei(0));
    minerReward = await pool.estimateMinerReward();
    assert.equal(minerReward, toWei(10));
    // Now adding a new staker, while miner's fee shouldn't be affected.
    await pool.sendTransaction(txGen(accounts[0], toWei(10)));
    minerReward = await pool.minerReward();
    assert.equal(minerReward, toWei(10));
    minerReward = await pool.estimateMinerReward();
    assert.equal(minerReward, toWei(10));
    // Now, new rewards should be distributed evenly.
    await forceSend(pool.address, toWei(4), treasury);
    minerReward = await pool.estimateMinerReward();
    assert.equal(minerReward, toWei(10 + (4 / 2)));
    const stakes = await pool.calculateStakesWithDividend(accounts[0]);
    assert.equal(stakes, toWei(10 + (4 / 2)));
  });

  it('should allow admin to update fee rate', async () => {
    let minerFeeRate = await pool.minerFeeRateBp();
    assert.equal(minerFeeRate, 5000);
    // Fail if not admin.
    await pool.adjustMinerFeeRate(1000)
      .should.be.rejectedWith(revertError);
    // Fail if rate out of range.
    await pool.adjustMinerFeeRate(10001, { from: admin })
      .should.be.rejectedWith(revertError);
    // Succeed.
    await pool.adjustMinerFeeRate(1000, { from: admin });
    minerFeeRate = await pool.minerFeeRateBp();
    assert.equal(minerFeeRate, 1000);
  });

  it('should handle maintainer fee correctly', async () => {
    // Start a new pool where the pool takes 12.5% while the miner takes 50%.
    // eslint-disable-next-line max-len
    pool = await StakingPool.new(miner, minerContactInfo, admin, adminContactInfo, maintainer, minStakes, minerFeeRateBp, 1250, maxStakers);
    await pool.sendTransaction(txGen(accounts[0], toWei(1)));
    await forceSend(pool.address, toWei(8), treasury);
    // Stakes should be calculated correctly.
    const stakes = await pool.calculateStakesWithDividend(accounts[0]);
    assert.equal(stakes, toWei(1 + 3));
    // State has not been updated. Estimate should work.
    assert.equal((await pool.poolMaintainerFee()), 0);
    assert.equal((await pool.estimatePoolMaintainerFee()), toWei(1));
    assert.equal((await pool.minerReward()), 0);
    assert.equal((await pool.estimateMinerReward()), toWei(4));
    // Trigger a state update. Pool should have 4 while miner has 0.
    await pool.withdrawMinerReward({ from: miner, gasPrice: 0 });
    assert.equal((await pool.poolMaintainerFee()), toWei(1));
    assert.equal((await pool.minerReward()), 0);
    // Pool withdraws transfers the maintaining fee.
    await pool.transferMaintainerFee({ from: maintainer, gasPrice: 0 });
    assert.equal((await pool.poolMaintainerFee()), 0);
    const maintainerBalance = await web3.eth.getBalance(maintainer);
    assert.equal(maintainerBalance, toWei(100 + (8 / 8)));
  });

  it('should handle no staker case with pool maintainer', async () => {
    // Start a new pool where the pool takes 12.5% while the miner takes 50%.
    // eslint-disable-next-line max-len
    pool = await StakingPool.new(miner, minerContactInfo, admin, adminContactInfo, maintainer, minStakes, minerFeeRateBp, 1250, maxStakers);

    await forceSend(pool.address, toWei(10), treasury);
    // Miner should take 50/(50+12.5) * 10 = 8.
    assert.equal((await pool.minerReward()), toWei(0));
    assert.equal((await pool.estimateMinerReward()), toWei(8));
    // While maintainer should take 12.5/(50+12.5) * 10 = 2;
    assert.equal((await pool.poolMaintainerFee()), 0);
    assert.equal((await pool.estimatePoolMaintainerFee()), toWei(2));
  });

  it('should update miner and admin contact infomation correctly', async () => {
    assert.equal(((await pool.minerContactInfo())), minerContactInfo);
    assert.equal(((await pool.adminContactInfo())), adminContactInfo);

    // Fail if not miner
    await pool.updateMinerContactInfo('miner0@stakingpool')
      .should.be.rejectedWith(revertError);
    // Fail if not admin
    await pool.updateAdminContactInfo('admin0@stakingpool')
      .should.be.rejectedWith(revertError);
    // Succeed
    await pool.updateMinerContactInfo('miner0@stakingpool', { from: miner });
    assert.equal(((await pool.minerContactInfo())), 'miner0@stakingpool');
    await pool.updateAdminContactInfo('admin0@stakingpool', { from: admin });
    assert.equal(((await pool.adminContactInfo())), 'admin0@stakingpool');
  });

  it('should update admin and pool maintainer correctly', async () => {
    assert.equal(((await pool.admin())), admin);
    assert.equal(((await pool.poolMaintainer())), maintainer);

    // Fail if not admin
    await pool.updateAdmin(accounts[4])
      .should.be.rejectedWith(revertError);
    // Fail if not poolMaintainer
    await pool.updatePoolMaintainer(accounts[3])
      .should.be.rejectedWith(revertError);
    // Succeed
    await pool.updateAdmin(accounts[4], { from: admin });
    assert.equal(((await pool.admin())), accounts[4]);
    await pool.updatePoolMaintainer(accounts[3], { from: maintainer });
    assert.equal(((await pool.poolMaintainer())), accounts[3]);
  });
});
