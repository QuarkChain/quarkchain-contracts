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
    manager = await NativeTokenManager.new(0, 0, 0, 0);
  });

  it('should deploy correctly', async () => {
    assert.notEqual(manager.address, `0x${'0'.repeat(40)}`);
  });
});
