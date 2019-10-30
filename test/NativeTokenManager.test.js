/* eslint no-unused-vars: 0 */
const assert = require('assert');
const { promisify } = require('util');

const NativeTokenManager = artifacts.require('./NativeTokenManager');
require('chai').use(require('chai-as-promised')).should();

const revertError = 'VM Exception while processing transaction: revert';
const toHex = web3.utils.asciiToHex;
const toWei = i => web3.utils.toWei(String(i));
const web3SendAsync = promisify(web3.currentProvider.send);
/* eslint-disable */
const sleep = (milliseconds) => {
  return new Promise(resolve => setTimeout(resolve, milliseconds));
};
/* eslint-disable */

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
  let supervisor;

  beforeEach(async () => {
    supervisor = accounts[0];
    manager = await NativeTokenManager.new(supervisor, true);
  });

  it('should deploy correctly', async () => {
    assert.notEqual(manager.address, `0x${'0'.repeat(40)}`);
  });

  it('should handle new token bid sucessfully', async () => {
    await manager.newTokenAuctionSetter(1000, 50, 3, { from: accounts[0] });

    // Start a new token auction.
    await manager.newTokenAuctionStart();
    // One bidder place a bid.
    await manager.bidNewToken(990, 1000, { from: accounts[1], value: 1001 });
    await sleep(3000);
    await manager.newTokenAuctionEnd();
    let nativeToken = await manager.nativeTokens(990);
    assert.equal(nativeToken.owner, accounts[1]);

    // Start a new token auction.
    await manager.newTokenAuctionStart();
    // Bidder 1 places a bid, should success.
    await manager.bidNewToken(991, 1100, { from: accounts[1], value: 1100 });
    // Bidder 2 places a bid with lower price, should fail.
    await manager.bidNewToken(992, 1050, { from: accounts[2], value: 1050 })
      .should.be.rejectedWith(revertError);
    // Bidder 2 place another valid bid.
    await manager.bidNewToken(992, 1200, { from: accounts[2], value: 1200 });
    await sleep(3000);
    // The auction ends, Bidder 2 wins.
    await manager.newTokenAuctionEnd();
    nativeToken = await manager.nativeTokens(992);
    assert.equal(nativeToken.owner, accounts[2]);
  });
});
