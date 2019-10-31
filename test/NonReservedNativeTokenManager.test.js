/* eslint no-unused-vars: 0 */
const assert = require('assert');
const { promisify } = require('util');

const NonReservedNativeTokenManager = artifacts.require('./NonReservedNativeTokenManager');
require('chai').use(require('chai-as-promised')).should();

const revertError = 'VM Exception while processing transaction: revert';
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

contract('NonReservedNativeTokenManager', async (accounts) => {
  let manager;
  let supervisor;

  beforeEach(async () => {
    supervisor = accounts[0];
    manager = await NonReservedNativeTokenManager.new(supervisor, true);
  });

  it('should deploy correctly', async () => {
    assert.notEqual(manager.address, `0x${'0'.repeat(40)}`);
  });

  it('should handle new token bid successfully', async () => {
    await manager.newTokenAuctionSetter(5, 2, 7 * 3600 * 24, { from: accounts[0] });

    // Start a new token auction.
    await manager.newTokenAuctionStart();
    // One bidder place a bid.
    await manager.bidNewToken(990, toWei(5), { from: accounts[1], value: toWei(5) });
    await addDaysOnEVM(6);
    await manager.newTokenAuctionEnd().should.be.rejectedWith(revertError);
    await addDaysOnEVM(7);
    await manager.newTokenAuctionEnd();
    let nativeToken = await manager.nativeTokens(990);
    assert.equal(nativeToken.owner, accounts[1]);

    // Start a new token auction.
    await manager.newTokenAuctionStart();
    // Bidder 1 places a bid, should success.
    await manager.bidNewToken(991, toWei(7), { from: accounts[1], value: toWei(7) });
    // Bidder 2 places a bid with lower price, should fail.
    await manager.bidNewToken(992, toWei(6), { from: accounts[2], value: toWei(6) })
      .should.be.rejectedWith(revertError);
    // Bidder 2 place another bid with not enough increment, should fail.
    await manager.bidNewToken(992, toWei(8), { from: accounts[2], value: toWei(9) })
      .should.be.rejectedWith(revertError);
    // Bidder 2 place yet another valid bid, should success.
    await manager.bidNewToken(992, toWei(9), { from: accounts[2], value: toWei(9) });
    await addDaysOnEVM(7);
    // The auction ends, Bidder 2 wins.
    await manager.newTokenAuctionEnd();
    nativeToken = await manager.nativeTokens(992);
    assert.equal(nativeToken.owner, accounts[2]);
  });
});
