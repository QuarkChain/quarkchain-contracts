# Staking Pool Contract User Guide

> **DISCLAIMER: THIS IS A REFERENCE IMPLEMENTATION AND NOT AUDITED. USE IT AT YOUR OWN RISK. WE WILL NOT ACCEPT RESPONSIBILITY FOR COSTS YOU MAY INCUR AS A RESULT OF USING THIS CONTRACT.**

> **注意：StakingPool.sol为QuarkChain团队开源的合约，未经严格审核，社区可以免费试用，在部署和操作使用中出现的一切问题概不负责，均有用户自己承担。**

## Deploy Contract

1. Use your favorite Ethereum tooling like _solc_ and _remix_ to compile the StakingPool contract, copy the byteCode and abi.

    - Paste your smart contract code in Remix and compile the smart contract. Click on start to compile to compile your smart contract. **QuarkChain VM hasn't supported Istanbul, complier version should be <= 0.5.13**

    - Choose the contract name that we want to deploy from the left dropdown and click on the details tab. You will see the bytecode and ABI while you scroll down the details.

    - Copy ABI by clicking on the *ABI*.

    ![compile](https://github.com/skji/quarkchain-contracts/raw/master/assets/images/1.jpg)
    - Go to *Deploy* tab and deploy the contract on testnet.
    
    ![compile](https://github.com/skji/quarkchain-contracts/raw/master/assets/images/11.jpg)
    
	> Admin should be a trusted entity (preferrably on the staker side). He/she can adjust minerFeerateBp by using method *adjustMinerFeeRate* which could prevent miner doing evil. For example, miner doesn't stop mining when stakers want to withdraw their stakes.
    
	> Max feeRateBp is 10000 which equal to 100%.

    - Check the transaction on etherscan and copy *Input Data*.
    
    ![compile](https://github.com/skji/quarkchain-contracts/raw/master/assets/images/12.jpg)

3. Deploy your contract on [QuarkChain Mainet Explorer](https://mainnet.quarkchain.io/contract).

    - Choose the right shard which you want to mine on Address area.
    - Paste copied *Input Data* to Deploy tab and set gas limit >= 2000000 (make sure you have enough qkc on this shard), then click deploy button.

      ![deploy transaction](https://github.com/skji/quarkchain-contracts/raw/master/assets/images/2.jpg)

      ![submit transaction](https://github.com/skji/quarkchain-contracts/raw/master/assets/images/3.jpg) 

    - On the transaction status page you may find the contract address once the transaction is confirmed.
      
      ![find the transaction](https://github.com/skji/quarkchain-contracts/raw/master/assets/images/4.jpg)
      
      ![copy the address](https://github.com/skji/quarkchain-contracts/raw/master/assets/images/5.jpg)

## Stake QKC

- You can interact with your contract on our [QuarkChain Mainet Explorer](https://mainnet.quarkchain.io/contract). **Make sure you have enough QKC for paying the gas fee on the right chain.**
  
  ![interact contract](https://github.com/skji/quarkchain-contracts/raw/master/assets/images/6.jpg)

- QKC holder can transfer their QKC to the contract address. **Please try the contract methods before staking to make sure the contract is working as expected.**
  
  ![interact contract](https://github.com/skji/quarkchain-contracts/raw/master/assets/images/7.jpg)

## Mine QKC

> Here uses hiveos.farm with ethminer as an example. You may use your own tooling with similar procedures.

- Paste the contract address to your mining settings instead of the regular QKC wallet address. Start mining. **Miner address should be ETH like, so we need delete last eight digits of the contract address.**

  > You can only mine the the same chain as the contract deployed.
  
  ![miner settings](https://github.com/skji/quarkchain-contracts/raw/master/assets/images/8.jpg)
    
  > - [QKC GPU Miner](https://github.com/QuarkChain/ethminer)
  > - [QKC CPU Miner](https://github.com/QuarkChain/Qkchash_CPU_Miner)

- You can check the mining result on [QuarkChain Mainet Explorer](https://mainnet.quarkchain.io/contract)

  ![PoSW successful](https://github.com/skji/quarkchain-contracts/raw/master/assets/images/9.jpg)

## Withdraw Profits

Staker, Miner and PoolMaintainer can withdraw their profits by methods *withdrawStakers(amount)*, *withdrawMinerReward* and *transferMaintainerFee*.

![withdraw](https://github.com/skji/quarkchain-contracts/raw/master/assets/images/10.jpg)
