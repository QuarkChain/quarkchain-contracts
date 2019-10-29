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
  let supervisor;

  beforeEach(async () => {
    supervisor = accounts[0];
    manager = await NativeTokenManager.new(supervisor, true);
  });

  it('should deploy correctly', async () => {
    assert.notEqual(manager.address, `0x${'0'.repeat(40)}`);
  });

  it('should handle new token bid sucessfully', async () => {
    await manager.newTokenAuctionSetter(1000, 50, 10000, { from: accounts[0] });
    console.log('sss', supervisor);

    // Start a new token auction.
    await manager.newTokenAuctionStart();

    // One bidder place a bid.
    manager.bidNewToken(990, 900, { from: accounts[1], value: 800 });
    console.log('sssd', accounts[1]);
  });
});
