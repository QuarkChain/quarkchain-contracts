# Staking Pool Contract User Guide

> **Note: StakingPool.sol hasn't been audited yet. Please be aware of the risk for using it. Our team does not undertake any responsibility.**

## Deploy Contract

1. Use your favorite Ethereum tooling like _solc_ and _remix_ to compile the StakingPool contract, copy the byteCode and abi.

    - Paste your smart contract code in Remix and compile the smart contract. Click on start to compile to compile your smart contract. **QuarkChain VM hasn't supported Istanbul, complier version should be <= 0.5.13**

    - Choose the contract name that we want to deploy from the left dropdown and click on the details tab. You will see the bytecode and ABI while you scroll down the details.
    - Copy the byteCode and ABI by clicking on the copy to clipboard.

    ![compile](https://github.com/skji/quarkchain-contracts/raw/master/assets/images/1.jpg)

2. Passing arguments to the constructor of smart contract.
	
    We need geth console(metamask injects web3 so that will also be fine) to get the complete byte code. Just go to your geth console and type following commands:

	```
    let abi = abi_provided_by_remix;
	let rowByteCode = "byte_code_provided_by_remix";
	let byteCodeWithParam = rowByteCode + web3.eth.abi.encodeParameters(['address','address','address','uint256','uint256','uint256'], [your_miner_address, your_admin_address, your_poolMaintainer_address, _minerFeeRateBp, poolMaintainerFeeRateBp, _maxStakers]).slice(2);
	```
	> Admin should be a staker address.
    
	> Max feeRateBp is 10000 which equal to 100%.

3. Deploy your contract on [QuarkChain Mainet Explorer](https://mainnet.quarkchain.io/contract).

    - Choose the right shard which you want to mine on Address area.
    - Paste ```byteCodeWithParam``` to Deploy tab and set gas limit >= 5000000 (make sure you have enough qkc on this shard), then click deploy button.

      ![deploy transaction](https://github.com/skji/quarkchain-contracts/raw/master/assets/images/2.jpg)

      ![submit transaction](https://github.com/skji/quarkchain-contracts/raw/master/assets/images/3.jpg) 

    - On the transaction status page you may find the contract address once the transaction is confirmed.
      
      ![find the transaction](https://github.com/skji/quarkchain-contracts/raw/master/assets/images/4.jpg)
      
      ![copy the address](https://github.com/skji/quarkchain-contracts/raw/master/assets/images/5.jpg)

## Stake QKC

- You can interact your contract with our [QuarkChain Mainet Explorer](https://mainnet.quarkchain.io/contract). **Make sure you have enough QKC for paying the gas fee on the right chain.**
  
  ![interact contract](https://github.com/skji/quarkchain-contracts/raw/master/assets/images/6.jpg)

- QKC holder can transfer their QKC to the contract address. **Please try the contract methods before staking for making sure the contract deployed right and working well**
  
  ![interact contract](https://github.com/skji/quarkchain-contracts/raw/master/assets/images/7.jpg)

## Mine QKC

- Paste the contract address to your mining settings instead of the regular wallet address. Start mining. **Miner address should be ETH like, so we need delete last eight digits of the contract address.**
  
  ![miner settings](https://github.com/skji/quarkchain-contracts/raw/master/assets/images/8.jpg)

- You can check the mining result on [QuarkChain Mainet Explorer](https://mainnet.quarkchain.io/contract)

  ![PoSW successful](https://github.com/skji/quarkchain-contracts/raw/master/assets/images/9.jpg)

## Withdraw Profits

Staker, Miner and PoolMaintainer can withdraw their profits by methods *withdrawStakers(amount)*, *withdrawMinerReward* and *transferMaintainerFee*

![withdraw](https://github.com/skji/quarkchain-contracts/raw/master/assets/images/10.jpg)
