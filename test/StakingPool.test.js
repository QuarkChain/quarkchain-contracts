/* eslint no-unused-vars: 0 */
const assert = require('assert');
const { promisify } = require('util');

const StakingPool = artifacts.require('./StakingPool');
require('chai').use(require('chai-as-promised')).should();

const revertError = 'VM Exception while processing transaction: revert';
const toHex = web3.utils.asciiToHex;
const toWei = i => web3.utils.toWei(String(i));
const web3SendAsync = promisify(web3.currentProvider.send);
const gasPriceMax = 0;

function txGen(from, value) {
  return {
    from, value, gasPrice: gasPriceMax,
  };
}

// For EVM snapshot - revert workflow.
let snapshotId;

async function addDaysOnEVM(days) {
  const seconds = days * 3600 * 24;
  await web3SendAsync({
    jsonrpc: '2.0', method: 'evm_increaseTime', params: [seconds], id: 0,
  });
  await web3SendAsync({
    jsonrpc: '2.0', method: 'evm_mine', params: [], id: 0,
  });
}

function snapshotEVM() {
  return web3SendAsync({
    jsonrpc: '2.0', method: 'evm_snapshot', id: Date.now() + 1,
  }).then(({ result }) => { snapshotId = result; });
}

function revertEVM() {
  return web3SendAsync({
    jsonrpc: '2.0', method: 'evm_revert', params: [snapshotId], id: Date.now() + 1,
  });
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
    const minerFee = await pool.minerFee();
    assert.equal(minerFee.toNumber(), 0);
    const dividend = await pool.getDividend();
    assert.equal(dividend.toNumber(), 0);
    const staker = await pool.stakers(0);
    assert.equal(staker, accounts[0]);
    const stakerInfo = await pool.stakerInfo(accounts[0]);
    assert.equal(stakerInfo[0], toWei(42));
    assert.equal(stakerInfo[1].toNumber(), 0);
  });
});
