/* eslint no-unused-vars: 0 */
const assert = require('assert');
const { promisify } = require('util');

const NativeTokenManager = artifacts.require('./NativeTokenManager');
require('chai').use(require('chai-as-promised')).should();

const revertError = 'VM Exception while processing transaction: revert';
const toHex = web3.utils.asciiToHex;
const toWei = i => web3.utils.toWei(String(i));
const web3SendAsync = promisify(web3.currentProvider.send);

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

contract('NativeTokenManager', async (accounts) => {
  let manager;

  beforeEach(async () => {
    manager = await NativeTokenManager.new(accounts[0], 0);
    manager.setMinReserve(toWei(2), { from: accounts[0] });
  });

  it('should deploy correctly', async () => {
    assert.notEqual(manager.address, `0x${'0'.repeat(40)}`);
  });

  it('should handle reserve and withdraw correctly', async () => {
    // Add more QKC fail if invalid tokenId.
    await manager.depositGasReserve(123, { from: accounts[0], value: toWei(2) })
      .should.be.rejectedWith(revertError);
    // First time adding reverve should succeed.
    await manager.proposeNewExchangeRate(123, 1, 1, { from: accounts[0], value: toWei(2) });
    // Check the ratio is correct.
    let gasRatio = await manager.getUtilityInfo(123);
    assert.equal(gasRatio[0], 1);
    assert.equal(gasRatio[1], 1);
    // Add more QKC success.
    await manager.depositGasReserve(123, { from: accounts[0], value: toWei(1) });
    // Check the total deposit.
    assert.equal(await web3.eth.getBalance(manager.address), toWei(3));

    // Withdraw fail if highest bidder.
    await manager.withdrawGasReserve(123, { from: accounts[0] })
      .should.be.rejectedWith(revertError);
    // New bid fail if lower ratio.
    await manager.proposeNewExchangeRate(123, 1, 2, { from: accounts[1], value: toWei(20) })
      .should.be.rejectedWith(revertError);
    // New bid fail if no enough QKC deposit.
    await manager.proposeNewExchangeRate(123, 2, 1, { from: accounts[1], value: toWei(1) })
      .should.be.rejectedWith(revertError);
    // Success.
    await manager.proposeNewExchangeRate(123, 2, 1, { from: accounts[1], value: toWei(20) });
    // Withdraw QKC success.
    await manager.withdrawGasReserve(123, { from: accounts[0] });
    // Check the total deposit.
    assert.equal(await web3.eth.getBalance(manager.address), toWei(20));
    // Check the new ratio.
    gasRatio = await manager.getUtilityInfo(123);
    assert.equal(gasRatio[0], 2);
    assert.equal(gasRatio[1], 1);
    // Highest bidder can bid higher ratio without adding QKC.
    await manager.proposeNewExchangeRate(123, 3, 1, { from: accounts[1], value: toWei(0) });
    // Check the new ratio.
    gasRatio = await manager.getUtilityInfo(123);
    assert.equal(gasRatio[0], 3);
    assert.equal(gasRatio[1], 1);

    // New bid fail if zero numerator or denominator.
    await manager.proposeNewExchangeRate(123, 0, 1, { from: accounts[0], value: toWei(10) })
      .should.be.rejectedWith(revertError);
    await manager.proposeNewExchangeRate(123, 1, 0, { from: accounts[0], value: toWei(10) })
      .should.be.rejectedWith(revertError);
    // ratio * 21000 <= minGasReserve
    await manager.proposeNewExchangeRate(123, toWei(1), 1, { from: accounts[0], value: toWei(10) })
      .should.be.rejectedWith(revertError);
  });
});
