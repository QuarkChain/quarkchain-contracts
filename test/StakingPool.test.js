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

async function forceSend(target, value) {
  const selfDestruct = await SelfDestruct.new({ value });
  await selfDestruct.forceSend(target);
}

contract('StakingPool', async (accounts) => {
  let pool;
  const miner = accounts[9];
  // 50% fee rate.
  const feeRateBp = 5000;
  const maxStakers = 16;

  beforeEach(async () => {
    pool = await StakingPool.new(miner, feeRateBp, maxStakers);
  });

  it('should deploy correctly', async () => {
    assert.notEqual(pool.address, `0x${'0'.repeat(40)}`);
  });

  it('should handle adding stakes properly', async () => {
    await pool.sendTransaction(txGen(accounts[0], toWei(42)));
    const minerReward = await pool.minerReward();
    assert.equal(minerReward, 0);
    const dividend = await pool.getDividend();
    assert.equal(dividend, 0);
    let stakerNumber = await pool.totalStakerSize();
    assert.equal(stakerNumber, 1);
    const staker = await pool.stakers(0);
    assert.equal(staker, accounts[0]);
    const stakerInfo = await pool.stakerInfo(accounts[0]);
    assert.equal(stakerInfo[0], toWei(42));
    assert.equal(stakerInfo[1], 0);
    let totalStakes = await pool.totalStakes();
    assert.equal(totalStakes, toWei(42));

    await pool.sendTransaction(txGen(accounts[1], toWei(100)));
    stakerNumber = await pool.totalStakerSize();
    assert.equal(stakerNumber, 2);
    totalStakes = await pool.totalStakes();
    assert.equal(totalStakes, toWei(142));
  });

  it('should handle withdrawing stakes properly', async () => {
    await pool.sendTransaction(txGen(accounts[0], toWei(42)));
    await pool.withdrawStakes(toWei(40));
    let totalStakes = await pool.totalStakes();
    assert.equal(totalStakes, toWei(2));
    let poolBalance = await web3.eth.getBalance(pool.address);
    assert.equal(poolBalance, toWei(2));
    // Failure.
    await pool.withdrawStakes(toWei(3))
      .should.be.rejectedWith(revertError);
    // Withdraw all.
    await pool.withdrawStakes(toWei(2));
    const stakerNumber = await pool.totalStakerSize();
    assert.equal(stakerNumber, 0);
    totalStakes = await pool.totalStakes();
    assert.equal(totalStakes, 0);
    poolBalance = await web3.eth.getBalance(pool.address);
    assert.equal(poolBalance, 0);
  });

  it('should calculate dividends correctly', async () => {
    await pool.sendTransaction(txGen(accounts[0], toWei(42)));
    await forceSend(pool.address, toWei(8));
    let poolBalance = await web3.eth.getBalance(pool.address);
    assert.equal(poolBalance, toWei(50));
    // State has not been updated.
    let minerReward = await pool.minerReward();
    assert.equal(minerReward, 0);
    const stakerInfo = await pool.stakerInfo(accounts[0]);
    let stakes = stakerInfo[0];
    assert.equal(stakes, toWei(42));
    // But dividend should reflect the change.
    const dividend = await pool.getDividend();
    assert.equal(dividend, toWei(8));
    // Or stakers can calculate their stakes with dividends.
    stakes = await pool.calculateStakesWithDividend(accounts[0]);
    assert.equal(stakes, toWei(42 + (8 / 2)));
    // Update internal state.
    await pool.calculatePayout();
    minerReward = await pool.minerReward();
    // 50% of coinbase rewards goes to miner.
    assert.equal(minerReward, toWei(4));
    // Stakers can withdraw.
    await pool.withdrawStakes(toWei(47)).should.be.rejectedWith(revertError);
    await pool.withdrawStakes(toWei(46));
    // Pool balance should update.
    poolBalance = await web3.eth.getBalance(pool.address);
    assert.equal(poolBalance, toWei(4));
    // Miner can withdraw as well.
    await pool.withdrawMinerReward({ from: miner });
    poolBalance = await web3.eth.getBalance(pool.address);
    assert.equal(poolBalance, 0);
  });
});
