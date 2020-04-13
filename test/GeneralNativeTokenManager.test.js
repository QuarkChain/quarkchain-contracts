/* eslint no-unused-vars: 0 */
const assert = require('assert');

const GeneralNativeTokenManager = artifacts.require('./GeneralNativeTokenManager');
require('chai').use(require('chai-as-promised')).should();

const revertError = 'VM Exception while processing transaction: revert';
const toWei = i => web3.utils.toWei(String(i));

contract('GeneralNativeTokenManager', async (accounts) => {
  let manager;

  beforeEach(async () => {
    // Use account 3 as the caller for debugging purposes.
    manager = await GeneralNativeTokenManager.new(accounts[0], accounts[3]);
    manager.setMinGasReserve(toWei(2), toWei(2), { from: accounts[0] });
  });

  it('should deploy correctly', async () => {
    assert.notEqual(manager.address, `0x${'0'.repeat(40)}`);
  });

  it('should handle gas reserve and withdraw correctly', async () => {
    // Add more QKC fail if invalid tokenId.
    await manager.depositGasReserve(123, { from: accounts[0], value: toWei(2) })
      .should.be.rejectedWith(revertError);
    // Non-existed token can not be proposed exchange rate.
    await manager.proposeNewExchangeRate(123, 1, 1, { from: accounts[0], value: toWei(2) })
      .should.be.rejectedWith(revertError);
    // The supervisor turn off the token registration switch.
    await manager.requireTokenRegistration(false);
    // First time adding reserve should succeed.
    await manager.proposeNewExchangeRate(123, 1, 1, { from: accounts[0], value: toWei(2) });
    // Check the ratio is correct.
    let gasRatio = (await manager.gasReserves(123));
    assert.equal(gasRatio[2], 1);
    assert.equal(gasRatio[3], 1);
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
    gasRatio = (await manager.gasReserves(123));
    assert.equal(gasRatio[2], 2);
    assert.equal(gasRatio[3], 1);
    // Can propose higher rate.
    await manager.proposeNewExchangeRate(123, 3, 1, { from: accounts[1], value: toWei(0) });
    gasRatio = (await manager.gasReserves(123));
    assert.equal(gasRatio[2], 3);
    assert.equal(gasRatio[3], 1);

    // Test refund percentage.
    // Only admin can set refund percentage.
    await manager.setRefundPercentage(123, 66, { from: accounts[0] })
      .should.be.rejectedWith(revertError);
    // Success.
    await manager.setRefundPercentage(123, 66, { from: accounts[1] });
    // Refund rate should be in the range between 10% and 100%.
    await manager.setRefundPercentage(123, 101, { from: accounts[1] })
      .should.be.rejectedWith(revertError);
    const refundPercentage = (await manager.gasReserves(123))[1];
    assert.equal(refundPercentage, 66);

    // New proposal fails if zero numerator or denominator.
    await manager.proposeNewExchangeRate(123, 0, 1, { from: accounts[0], value: toWei(10) })
      .should.be.rejectedWith(revertError);
    await manager.proposeNewExchangeRate(123, 1, 0, { from: accounts[0], value: toWei(10) })
      .should.be.rejectedWith(revertError);
    // Requires ratio * 21000 <= minGasReserve.
    await manager.proposeNewExchangeRate(123, toWei(1), 1, { from: accounts[0], value: toWei(10) })
      .should.be.rejectedWith(revertError);

    // Test converting native tokens to QKC as gas.
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
    assert.equal(calculateGasPriceReturn[0], 50);
    assert.equal(calculateGasPriceReturn[1], 1);

    // Success if enough gas reserve.
    await manager.payAsGas(123, toWei(1), 2, { from: accounts[3] });
    // Check the gas reserve toWei(2) - toWei(1) * 2 * (1 / 2) = toWei(1).
    assert.equal(await manager.gasReserveBalance(123, accounts[4]), toWei(1));
    // payAsGas fails if gas reserve not enough.
    await manager.payAsGas(123, toWei(2), 2, { from: accounts[3] })
      .should.be.rejectedWith(revertError);
  });

  it('should replace gas reserve that is lower than maintain', async () => {
    // The supervisor turn off the token registration switch.
    await manager.requireTokenRegistration(false);
    // First time adding reserve should succeed.
    await manager.setMinGasReserve(toWei(5), toWei(10));
    // Doesn't satisfy init condition.
    await manager.proposeNewExchangeRate(123, 1, 1, { from: accounts[0], value: toWei(5) })
      .should.be.rejectedWith(revertError);
    await manager.proposeNewExchangeRate(123, 1, 1, { from: accounts[0], value: toWei(15) });
    // Cannot propose another exchange rate unless the rate is greater
    // or GAS reserved is smaller than maintain.
    await manager.proposeNewExchangeRate(123, 1, 2, { from: accounts[1], value: toWei(10) })
      .should.be.rejectedWith(revertError);

    await manager.payAsGas(123, toWei(7), 1, { from: accounts[3] });
    assert.equal(await manager.gasReserveBalance(123, accounts[0]), toWei(8));

    await manager.payAsGas(123, toWei(4), 1, { from: accounts[3] });
    assert.equal(await manager.gasReserveBalance(123, accounts[0]), toWei(4));

    await manager.payAsGas(123, toWei(5), 1, { from: accounts[3] })
      .should.be.rejectedWith(revertError);

    // We could propose another exchange rate.
    await manager.proposeNewExchangeRate(123, 1, 2, { from: accounts[1], value: toWei(10) });
  });

  it('should freeze contract correctly', async () => {
    await manager.requireTokenRegistration(false);
    // First time adding reserve should succeed.
    await manager.proposeNewExchangeRate(123, 1, 1, { from: accounts[0], value: toWei(5) });
    // Withdraw fail if is the liquidity provider.
    await manager.withdrawGasReserve(123, { from: accounts[0] })
      .should.be.rejectedWith(revertError);
    // Paying as gas should succeed.
    const caller = accounts[3];
    await manager.payAsGas(123, toWei(1), 1, { from: caller });
    assert.equal(await manager.gasReserveBalance(123, accounts[0]), toWei(5 - 1));

    // Now supervisor freezes the contract.
    await manager.setFrozen(true);
    // Higher rate proposal should still fail.
    await manager.proposeNewExchangeRate(123, 2, 1, { from: accounts[0], value: toWei(5) })
      .should.be.rejectedWith(revertError);
    // Paying gas also fails.
    await manager.payAsGas(123, toWei(1), 1, { from: caller })
      .should.be.rejectedWith(revertError);
    // Liquidity provider can withdraw.
    await manager.withdrawGasReserve(123, { from: accounts[0] });
  });

  it('should verify rate numbers correctly', async () => {
    // The supervisor turn off the token registration switch.
    await manager.requireTokenRegistration(false);
    // Should fail as the rate is too big.
    // Note that this test is added to guard against uint128 overflow, where if the numerator
    // in contract is not casted to uint256 then proposing will pass, which is incorrect.
    await manager.proposeNewExchangeRate(123, '170141183460469231731687303715884105728', 1, { from: accounts[0], value: toWei(2) })
      .should.be.rejectedWith(revertError);
  });
});

