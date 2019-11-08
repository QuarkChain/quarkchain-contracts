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

async function addMinutesOnEVM(minutes) {
  const seconds = minutes * 60;
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
    await manager.setAuctionParams(5, 5, 7 * 3600 * 24, { from: accounts[0] });

    // ----------------------- ROUND 0 -----------------------
    // One bidder place a bid.
    await manager.bidNewToken(19004000, toWei(5), 0, { from: accounts[1], value: toWei(5) });
    await addDaysOnEVM(6);
    await manager.endAuction().should.be.rejectedWith(revertError);
    await addDaysOnEVM(2);

    // Though end time comes, endAuction() hasn't been triggered.
    // So winner info of this auction hasn't been updated yet.
    let nativeToken = await manager.nativeTokens(19004000);
    assert.equal(nativeToken.owner, `0x${'0'.repeat(40)}`);

    // ----------------------- ROUND 1 -----------------------
    // Bidder 2 places a bid, should succeed.
    await manager.bidNewToken(19004002, toWei(20), 1, { from: accounts[2], value: toWei(20) });
    // The bid above triggers the end of last round of auction and
    // a new round of auction starts.
    nativeToken = await manager.nativeTokens(19004000);
    assert.equal(nativeToken.owner, accounts[1]);
    // Bidder 1 places a bid for token 19004000 again, should fail.
    await manager.bidNewToken(19004000, toWei(22), 1, { from: accounts[1], value: toWei(22) })
      .should.be.rejectedWith(revertError);
    // Bidder 1 outbids with different token id.
    await manager.bidNewToken(19004001, toWei(21), 1, { from: accounts[1], value: toWei(21) });

    // Bidder 2 places another bid with lower price, should fail.
    await manager.bidNewToken(19004002, toWei(20), 1, { from: accounts[2], value: toWei(20) })
      .should.be.rejectedWith(revertError);
    // Bidder 2 place another bid with not enough increment, should fail.
    await manager.bidNewToken(19004002, toWei(22), 1, { from: accounts[2], value: toWei(22) })
      .should.be.rejectedWith(revertError);
    // Bidder 2 places a bid for round 0, should fail (Round 0 has ended).
    await manager.bidNewToken(19004002, toWei(23), 0, { from: accounts[2], value: toWei(23) })
      .should.be.rejectedWith(revertError);
    // Bidder 2 places a bid for round 2, should fail (Round 2 hasn't started).
    await manager.bidNewToken(19004002, toWei(23), 2, { from: accounts[2], value: toWei(23) })
      .should.be.rejectedWith(revertError);
    // Bidder 1 tries to withdraw the deposit, should fail.
    await manager.withdraw({ from: accounts[1] }).should.be.rejectedWith(revertError);

    const {
      0: tokenId,
      1: highestBid,
      2: highestBidder,
      3: round,
      4: endTime,
    } = await manager.getAuctionState();
    assert.equal(tokenId, 19004001);
    assert.equal(highestBid, toWei(21));
    assert.equal(highestBidder, accounts[1]);
    assert.equal(round, 1);
    assert(Date.now() < 1000 * endTime.toNumber());

    // Bidder 2 place yet another valid bid with 5 more QKC as deposit, should succeed.
    await manager.bidNewToken(19004002, toWei(25), 1, { from: accounts[2], value: toWei(5) });
    // Bidder 1 tries to withdraw the deposit, should succeed.
    await manager.withdraw({ from: accounts[1] });
    // Try calling endAuction, should fail.
    await manager.endAuction().should.be.rejectedWith(revertError);

    await addDaysOnEVM(7);
    // The auction ends, Bidder 2 wins.
    await manager.endAuction();
    nativeToken = await manager.nativeTokens(19004002);
    assert.equal(nativeToken.owner, accounts[2]);
    // Bidder 2 tries to withdraw the deposit, should fail because the balance is 0.
    await manager.withdraw({ from: accounts[2] }).should.be.rejectedWith(revertError);

    // ----------------------- ROUND 2 -----------------------
    // Test for time extension when last-minute bid happens.
    await manager.bidNewToken(19004003, toWei(5), 2, { from: accounts[3], value: toWei(5) });
    await addMinutesOnEVM(10080 - 3); // 60 * 24 * 7 - 3
    await manager.bidNewToken(19004004, toWei(8), 2, { from: accounts[4], value: toWei(8) });
    await addMinutesOnEVM(5);
    await manager.endAuction().should.be.rejectedWith(revertError);
    await addMinutesOnEVM(3);
    await manager.endAuction();
    nativeToken = await manager.nativeTokens(19004003);
    assert.equal(nativeToken.owner, 0);
    nativeToken = await manager.nativeTokens(19004004);
    assert.equal(nativeToken.owner, accounts[4]);
  });
});
