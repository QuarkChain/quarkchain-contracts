/* eslint no-unused-vars: 0 */
const assert = require('assert');

const GeneralNativeTokenManager = artifacts.require('./GeneralNativeTokenManager');
require('chai').use(require('chai-as-promised')).should();

const revertError = 'VM Exception while processing transaction: revert';
const toWei = i => web3.utils.toWei(String(i));

contract('GeneralNativeTokenManager', async (accounts) => {
  let manager;

  beforeEach(async () => {
    manager = await GeneralNativeTokenManager.new(accounts[0]);
    manager.setMinGasReserve(toWei(2), toWei(2), { from: accounts[0] });
  });

  it('should deploy correctly', async () => {
    assert.notEqual(manager.address, `0x${'0'.repeat(40)}`);
  });

  it('should handle gas reserve and withdraw correctly', async () => {
    // Add more QKC fail if invalid tokenId.
    await manager.depositGasReserve(123, { from: accounts[0], value: toWei(2) })
      .should.be.rejectedWith(revertError);
    // First time adding reserve should succeed.
    await manager.proposeNewExchangeRate(123, 1, 1, { from: accounts[0], value: toWei(2) });
    // Check the ratio is correct.
    let gasRatio = (await manager.gasReserves(123))[2];
    assert.equal(gasRatio[0], 1);
    assert.equal(gasRatio[1], 1);
    // Add more QKC and check balance.
    await manager.depositGasReserve(123, { from: accounts[0], value: toWei(1) });
    assert.equal(await web3.eth.getBalance(manager.address), toWei(3));

    // Withdraw fail if is admin.
    await manager.withdrawGasReserve(123, { from: accounts[0] })
      .should.be.rejectedWith(revertError);
    // New proposal fails if ratio is lower.
    await manager.proposeNewExchangeRate(123, 1, 2, { from: accounts[1], value: toWei(20) })
      .should.be.rejectedWith(revertError);
    // New proposal fails if no enough QKC deposit.
    await manager.proposeNewExchangeRate(123, 2, 1, { from: accounts[1], value: toWei(1) })
      .should.be.rejectedWith(revertError);
    // Success.
    await manager.proposeNewExchangeRate(123, 2, 1, { from: accounts[1], value: toWei(22) });
    // Withdraw QKC should succeed.
    await manager.withdrawGasReserve(123, { from: accounts[0] });
    // Check the total deposit.
    assert.equal(await web3.eth.getBalance(manager.address), toWei(22));
    // Check the new ratio.
    gasRatio = (await manager.gasReserves(123))[2];
    assert.equal(gasRatio[0], 2);
    assert.equal(gasRatio[1], 1);
    // Can propose higher rate.
    await manager.proposeNewExchangeRate(123, 3, 1, { from: accounts[1], value: toWei(0) });
    gasRatio = (await manager.gasReserves(123))[2];
    assert.equal(gasRatio[0], 3);
    assert.equal(gasRatio[1], 1);

    // Test refund percentage.
    // Only admin can set refund percentage.
    await manager.setRefundPercentage(123, 66, { from: accounts[0] })
      .should.be.rejectedWith(revertError);
    // Success.
    await manager.setRefundPercentage(123, 66, { from: accounts[1] });
    // Refund rate should be > 0 && refund rate <= 100
    await manager.setRefundPercentage(123, 101, { from: accounts[1] })
      .should.be.rejectedWith(revertError);
    const refundPercentage = (await manager.gasReserves(123))[1];
    assert.equal(refundPercentage, 66);

    // New proposal fails if zero numerator or denominator.
    await manager.proposeNewExchangeRate(123, 0, 1, { from: accounts[0], value: toWei(10) })
      .should.be.rejectedWith(revertError);
    await manager.proposeNewExchangeRate(123, 1, 0, { from: accounts[0], value: toWei(10) })
      .should.be.rejectedWith(revertError);
    // Requires ratio * 21000 <= minGasReserve
    await manager.proposeNewExchangeRate(123, toWei(1), 1, { from: accounts[0], value: toWei(10) })
      .should.be.rejectedWith(revertError);

    // Test converting native tokens to QKC as gas.
    await manager.setCaller(accounts[3], { from: accounts[0] });
    await manager.payAsGas(123, toWei(7), 1, { from: accounts[3] });
    // Check the total deposit. toWei(22) - toWei(7) * 3 = toWei(1).
    assert.equal(await manager.gasReserveBalance(123, accounts[1]), toWei(1));
    // Check the native token amount.
    assert.equal(await manager.nativeTokenBalance(123, accounts[1]), toWei(7));

    // Anyone can propose success when balance < minimum to reserve.
    await manager.proposeNewExchangeRate(123, 1, 2, { from: accounts[4], value: toWei(2) });

    // Requires converted gas price > 0, ratio is 1 / 2.
    await manager.calculateGasPrice(123, 1, { from: accounts[3] })
      .should.be.rejectedWith(revertError);
    const calculateGasPriceReturn = (
      await manager.calculateGasPrice(123, 2, { from: accounts[3] }));
    // Defaulted refund percentage is 50.
    assert.equal(calculateGasPriceReturn[1], 50);
    assert.equal(calculateGasPriceReturn[2], 1);

    // Success if enough gas reserve.
    await manager.payAsGas(123, toWei(1), 2, { from: accounts[3] });
    // Check the gas reserve toWei(2) - toWei(1) * 2 * (1 / 2) = toWei(1).
    assert.equal(await manager.gasReserveBalance(123, accounts[4]), toWei(1));
    // payAsGas fails if gas reserve not enough.
    await manager.payAsGas(123, toWei(1), 2, { from: accounts[3] })
      .should.be.rejectedWith(revertError);
  });
});
