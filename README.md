# QuarkChain Contracts

[![CircleCI](https://circleci.com/gh/QuarkChain/quarkchain-contracts/tree/master.svg?style=svg)](https://circleci.com/gh/QuarkChain/quarkchain-contracts/tree/master)

Some of the contracts will be part of consensus, some will be reference implementations for standardized interfaces, and so forth.

Try compile:

```
npx truffle compile
```

Linting:

```
npm run lint
```

Testing:

```
npm test
```

## Staking Pool Contracts User Guide

> **Note: StakingPool.sol hasn't been audited yet. Please be aware of the risk for using it. Our team does not undertake any responsibility.**

### Deploy the contract

- Use your favorite Ethereum tooling like _solc_ and _remix_ to compile the StakingPool contract, copy the byteCode and abi.

    - Paste your smart contract code in Remix and compile the smart contract. Click on start to compile to compile your smart contract. **QuarkChain VM hasn't supported Istanbul, complier version should <= 0.5.13**
    - Choose the contract name that we want to deploy from the left dropdown and click on the details tab. You will see the bytecode and ABI while you scroll down the details.
    - Copy the byteCode and ABI by clicking on the copy to clipboard.

    ![compile](./assets/images/1.jpg)

- Passing arguments to the constructor of smart contract.

We need geth console(metamask injects web3 so that will also be fine) to get the complete byte code. Just go to your geth console and type following commands:
```
let abi = abi_provided_by_remix;
/*
let abi = [
	{
		"inputs": [
			{
				"internalType": "address",
				"name": "_miner",
				"type": "address"
			},
			{
				"internalType": "address",
				"name": "_admin",
				"type": "address"
			},
			{
				"internalType": "address",
				"name": "_poolMaintainer",
				"type": "address"
			},
			{
				"internalType": "uint256",
				"name": "_minerFeeRateBp",
				"type": "uint256"
			},
			{
				"internalType": "uint256",
				"name": "_poolMaintainerFeeRateBp",
				"type": "uint256"
			},
			{
				"internalType": "uint256",
				"name": "_maxStakers",
				"type": "uint256"
			}
		],
		"payable": false,
		"stateMutability": "nonpayable",
		"type": "constructor"
	},
	{
		"payable": true,
		"stateMutability": "payable",
		"type": "fallback"
	},
	{
		"constant": false,
		"inputs": [
			{
				"internalType": "uint256",
				"name": "_minerFeeRateBp",
				"type": "uint256"
			}
		],
		"name": "adjustMinerFeeRate",
		"outputs": [],
		"payable": false,
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"constant": true,
		"inputs": [],
		"name": "admin",
		"outputs": [
			{
				"internalType": "address",
				"name": "",
				"type": "address"
			}
		],
		"payable": false,
		"stateMutability": "view",
		"type": "function"
	},
	{
		"constant": true,
		"inputs": [
			{
				"internalType": "address",
				"name": "staker",
				"type": "address"
			}
		],
		"name": "calculateStakesWithDividend",
		"outputs": [
			{
				"internalType": "uint256",
				"name": "",
				"type": "uint256"
			}
		],
		"payable": false,
		"stateMutability": "view",
		"type": "function"
	},
	{
		"constant": true,
		"inputs": [],
		"name": "estimateMinerReward",
		"outputs": [
			{
				"internalType": "uint256",
				"name": "",
				"type": "uint256"
			}
		],
		"payable": false,
		"stateMutability": "view",
		"type": "function"
	},
	{
		"constant": true,
		"inputs": [],
		"name": "estimatePoolMaintainerFee",
		"outputs": [
			{
				"internalType": "uint256",
				"name": "",
				"type": "uint256"
			}
		],
		"payable": false,
		"stateMutability": "view",
		"type": "function"
	},
	{
		"constant": true,
		"inputs": [],
		"name": "maxStakers",
		"outputs": [
			{
				"internalType": "uint256",
				"name": "",
				"type": "uint256"
			}
		],
		"payable": false,
		"stateMutability": "view",
		"type": "function"
	},
	{
		"constant": true,
		"inputs": [],
		"name": "miner",
		"outputs": [
			{
				"internalType": "address",
				"name": "",
				"type": "address"
			}
		],
		"payable": false,
		"stateMutability": "view",
		"type": "function"
	},
	{
		"constant": true,
		"inputs": [],
		"name": "minerFeeRateBp",
		"outputs": [
			{
				"internalType": "uint256",
				"name": "",
				"type": "uint256"
			}
		],
		"payable": false,
		"stateMutability": "view",
		"type": "function"
	},
	{
		"constant": true,
		"inputs": [],
		"name": "minerReward",
		"outputs": [
			{
				"internalType": "uint256",
				"name": "",
				"type": "uint256"
			}
		],
		"payable": false,
		"stateMutability": "view",
		"type": "function"
	},
	{
		"constant": true,
		"inputs": [],
		"name": "poolMaintainer",
		"outputs": [
			{
				"internalType": "address",
				"name": "",
				"type": "address"
			}
		],
		"payable": false,
		"stateMutability": "view",
		"type": "function"
	},
	{
		"constant": true,
		"inputs": [],
		"name": "poolMaintainerFee",
		"outputs": [
			{
				"internalType": "uint256",
				"name": "",
				"type": "uint256"
			}
		],
		"payable": false,
		"stateMutability": "view",
		"type": "function"
	},
	{
		"constant": true,
		"inputs": [],
		"name": "poolMaintainerFeeRateBp",
		"outputs": [
			{
				"internalType": "uint256",
				"name": "",
				"type": "uint256"
			}
		],
		"payable": false,
		"stateMutability": "view",
		"type": "function"
	},
	{
		"constant": true,
		"inputs": [],
		"name": "poolSize",
		"outputs": [
			{
				"internalType": "uint256",
				"name": "",
				"type": "uint256"
			}
		],
		"payable": false,
		"stateMutability": "view",
		"type": "function"
	},
	{
		"constant": true,
		"inputs": [
			{
				"internalType": "address",
				"name": "",
				"type": "address"
			}
		],
		"name": "stakerInfo",
		"outputs": [
			{
				"internalType": "uint256",
				"name": "stakes",
				"type": "uint256"
			},
			{
				"internalType": "uint256",
				"name": "arrPos",
				"type": "uint256"
			}
		],
		"payable": false,
		"stateMutability": "view",
		"type": "function"
	},
	{
		"constant": true,
		"inputs": [
			{
				"internalType": "uint256",
				"name": "",
				"type": "uint256"
			}
		],
		"name": "stakers",
		"outputs": [
			{
				"internalType": "address",
				"name": "",
				"type": "address"
			}
		],
		"payable": false,
		"stateMutability": "view",
		"type": "function"
	},
	{
		"constant": true,
		"inputs": [],
		"name": "totalStakes",
		"outputs": [
			{
				"internalType": "uint256",
				"name": "",
				"type": "uint256"
			}
		],
		"payable": false,
		"stateMutability": "view",
		"type": "function"
	},
	{
		"constant": false,
		"inputs": [],
		"name": "transferMaintainerFee",
		"outputs": [],
		"payable": false,
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"constant": false,
		"inputs": [
			{
				"internalType": "address payable",
				"name": "_miner",
				"type": "address"
			}
		],
		"name": "updateMiner",
		"outputs": [],
		"payable": false,
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"constant": false,
		"inputs": [],
		"name": "withdrawMinerReward",
		"outputs": [],
		"payable": false,
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"constant": false,
		"inputs": [
			{
				"internalType": "uint256",
				"name": "amount",
				"type": "uint256"
			}
		],
		"name": "withdrawStakes",
		"outputs": [],
		"payable": false,
		"stateMutability": "nonpayable",
		"type": "function"
	}
]
*/
let rowByteCode = "byte_code_provided_by_remix";
/*
let rowBytecode = "0x608060405234801561001057600080fd5b5060405162001cfe38038062001cfe833981810160405260c081101561003557600080fd5b810190808051906020019092919080519060200190929190805190602001909291908051906020019092919080519060200190929190805190602001909291905050506127108311156100d4576040517f08c379a000000000000000000000000000000000000000000000000000000000815260040180806020018281038252602281526020018062001cdc6022913960400191505060405180910390fd5b612710821115610130576040517f08c379a000000000000000000000000000000000000000000000000000000000815260040180806020018281038252602281526020018062001cdc6022913960400191505060405180910390fd5b612710828401111561018e576040517f08c379a000000000000000000000000000000000000000000000000000000000815260040180806020018281038252602281526020018062001cdc6022913960400191505060405180910390fd5b85600560006101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff16021790555084600260006101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff16021790555083600860006101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff160217905550826006819055508160098190555080600481905550505050505050611a60806200027c6000396000f3fe60806040526004361061011f5760003560e01c80635756ae11116100a0578063d4e24be011610064578063d4e24be014610649578063e037ad1e146106a0578063e35b28c2146106db578063f851a44014610706578063fd5e6dd11461075d5761011f565b80635756ae11146105385780635d05ec471461056357806367174b20146105c8578063bf9befb1146105f3578063cbed45eb1461061e5761011f565b8063410390ec116100e7578063410390ec146104105780634e745f1f1461044b5780634ec18db9146104b75780634f7ff503146104e2578063536e41411461050d5761011f565b8063017f6f751461030f578063186697291461033a5780632b16cad214610351578063349dc329146103a25780633cfb18fd146103f9575b6101276107d8565b60008060003373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff168152602001908152602001600020905060008160000154141561026757600454600180549050106101f2576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260118152602001807f546f6f206d616e79207374616b6572732e00000000000000000000000000000081525060200191505060405180910390fd5b600180549050816001018190555060013390806001815401808255809150509060018203906000526020600020016000909192909190916101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff160217905550505b34816000016000828254019250508190555061028e34600354610a0590919063ffffffff16565b60038190555034600354101561030c576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260128152602001807f4164646974696f6e206f766572666c6f772e000000000000000000000000000081525060200191505060405180910390fd5b50005b34801561031b57600080fd5b50610324610a8d565b6040518082815260200191505060405180910390f35b34801561034657600080fd5b5061034f610a93565b005b34801561035d57600080fd5b506103a06004803603602081101561037457600080fd5b81019080803573ffffffffffffffffffffffffffffffffffffffff169060200190929190505050610b9a565b005b3480156103ae57600080fd5b506103b7610c8c565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b34801561040557600080fd5b5061040e610cb2565b005b34801561041c57600080fd5b506104496004803603602081101561043357600080fd5b8101908080359060200190929190505050610dd6565b005b34801561045757600080fd5b5061049a6004803603602081101561046e57600080fd5b81019080803573ffffffffffffffffffffffffffffffffffffffff169060200190929190505050611163565b604051808381526020018281526020019250505060405180910390f35b3480156104c357600080fd5b506104cc611187565b6040518082815260200191505060405180910390f35b3480156104ee57600080fd5b506104f7611194565b6040518082815260200191505060405180910390f35b34801561051957600080fd5b5061052261119a565b6040518082815260200191505060405180910390f35b34801561054457600080fd5b5061054d61121c565b6040518082815260200191505060405180910390f35b34801561056f57600080fd5b506105b26004803603602081101561058657600080fd5b81019080803573ffffffffffffffffffffffffffffffffffffffff16906020019092919050505061129e565b6040518082815260200191505060405180910390f35b3480156105d457600080fd5b506105dd611396565b6040518082815260200191505060405180910390f35b3480156105ff57600080fd5b5061060861139c565b6040518082815260200191505060405180910390f35b34801561062a57600080fd5b506106336113a2565b6040518082815260200191505060405180910390f35b34801561065557600080fd5b5061065e6113a8565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b3480156106ac57600080fd5b506106d9600480360360208110156106c357600080fd5b81019080803590602001909291905050506113ce565b005b3480156106e757600080fd5b506106f0611540565b6040518082815260200191505060405180910390f35b34801561071257600080fd5b5061071b611546565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b34801561076957600080fd5b506107966004803603602081101561078057600080fd5b810190808035906020019092919050505061156c565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b6000343073ffffffffffffffffffffffffffffffffffffffff16310390506000610801826115a8565b90506000811415610813575050610a03565b6000600954600654019050600061084b61271061083d84612710038661165990919063ffffffff16565b6116df90919063ffffffff16565b9050600080905060008090505b6001805490508110156109435760008060006001848154811061087757fe5b9060005260206000200160009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1681526020019081526020016000209050600061090b6003546108fd84600001548861165990919063ffffffff16565b6116df90919063ffffffff16565b90506109208185610a0590919063ffffffff16565b935080826000016000828254019250508190555050508080600101915050610858565b5061095981600354610a0590919063ffffffff16565b6003819055506000610974828661172990919063ffffffff16565b9050600061099f856109916006548561165990919063ffffffff16565b6116df90919063ffffffff16565b905060006109b6828461172990919063ffffffff16565b90506109cd81600a54610a0590919063ffffffff16565b600a819055506109e882600754610a0590919063ffffffff16565b6007819055506003548810156109fa57fe5b50505050505050505b565b600080828401905083811015610a83576040517f08c379a000000000000000000000000000000000000000000000000000000000815260040180806020018281038252601b8152602001807f536166654d6174683a206164646974696f6e206f766572666c6f77000000000081525060200191505060405180910390fd5b8091505092915050565b600a5481565b600860009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff1614610b39576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260318152602001806119fb6031913960400191505060405180910390fd5b610b416107d8565b6000600a5490506000600a819055503373ffffffffffffffffffffffffffffffffffffffff166108fc829081150290604051600060405180830381858888f19350505050158015610b96573d6000803e3d6000fd5b5050565b600560009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff1614610c40576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260228152602001806119d96022913960400191505060405180910390fd5b610c486107d8565b80600560006101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff16021790555050565b600560009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b600560009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff1614610d75576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260208152602001807f4f6e6c79206d696e65722063616e20776974686472617720726577617264732e81525060200191505060405180910390fd5b610d7d6107d8565b6000600754905060006007819055503373ffffffffffffffffffffffffffffffffffffffff166108fc829081150290604051600060405180830381858888f19350505050158015610dd2573d6000803e3d6000fd5b5050565b60008111610e4c576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260138152602001807f496e76616c6964207769746864726177616c2e0000000000000000000000000081525060200191505060405180910390fd5b610e546107d8565b60008060003373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200190815260200160002090503373ffffffffffffffffffffffffffffffffffffffff166001826001015481548110610ebe57fe5b9060005260206000200160009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1614610f0657fe5b8181600001541015610f63576040517f08c379a000000000000000000000000000000000000000000000000000000000815260040180806020018281038252602681526020018061194b6026913960400191505060405180910390fd5b818160000160008282540392505081905550816003600082825403925050819055503373ffffffffffffffffffffffffffffffffffffffff166108fc839081150290604051600060405180830381858888f19350505050158015610fcb573d6000803e3d6000fd5b5060008160000154141561115f57806001015460008060018080805490500381548110610ff457fe5b9060005260206000200160009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff168152602001908152602001600020600101819055506001808080549050038154811061107357fe5b9060005260206000200160009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1660018260010154815481106110af57fe5b9060005260206000200160006101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff160217905550600180548091906001900361110c91906118f9565b506000803373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff168152602001908152602001600020600080820160009055600182016000905550505b5050565b60006020528060005260406000206000915090508060000154908060010154905082565b6000600180549050905090565b60045481565b6000806111ff6000600180549050116111b957600954600654016111bd565b6127105b6111f16006546111e33073ffffffffffffffffffffffffffffffffffffffff16316115a8565b61165990919063ffffffff16565b6116df90919063ffffffff16565b905061121681600754610a0590919063ffffffff16565b91505090565b60008061128160006001805490501161123b576009546006540161123f565b6127105b6112736009546112653073ffffffffffffffffffffffffffffffffffffffff16316115a8565b61165990919063ffffffff16565b6116df90919063ffffffff16565b905061129881600a54610a0590919063ffffffff16565b91505090565b60008060035414156112b35760009050611391565b60006112d53073ffffffffffffffffffffffffffffffffffffffff16316115a8565b90506000600954600654019050600061130f61271061130184612710038661165990919063ffffffff16565b6116df90919063ffffffff16565b905060008060008773ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1681526020019081526020016000209050600061138060035461137284600001548661165990919063ffffffff16565b6116df90919063ffffffff16565b905080826000015401955050505050505b919050565b60065481565b60035481565b60075481565b600860009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b600260009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff1614611474576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260258152602001806119716025913960400191505060405180910390fd5b6127108111156114cf576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260228152602001806119b76022913960400191505060405180910390fd5b6127106009548201111561152e576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260228152602001806119b76022913960400191505060405180910390fd5b6115366107d8565b8060068190555050565b60095481565b600260009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b6001818154811061157957fe5b906000526020600020016000915054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b6000806115d6600a546115c8600754600354610a0590919063ffffffff16565b610a0590919063ffffffff16565b90508083101561164e576040517f08c379a000000000000000000000000000000000000000000000000000000000815260040180806020018281038252601b8152602001807f53686f756c64206861766520656e6f7567682062616c616e63652e000000000081525060200191505060405180910390fd5b808303915050919050565b60008083141561166c57600090506116d9565b600082840290508284828161167d57fe5b04146116d4576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260218152602001806119966021913960400191505060405180910390fd5b809150505b92915050565b600061172183836040518060400160405280601a81526020017f536166654d6174683a206469766973696f6e206279207a65726f000000000000815250611773565b905092915050565b600061176b83836040518060400160405280601e81526020017f536166654d6174683a207375627472616374696f6e206f766572666c6f770000815250611839565b905092915050565b6000808311829061181f576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825283818151815260200191508051906020019080838360005b838110156117e45780820151818401526020810190506117c9565b50505050905090810190601f1680156118115780820380516001836020036101000a031916815260200191505b509250505060405180910390fd5b50600083858161182b57fe5b049050809150509392505050565b60008383111582906118e6576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825283818151815260200191508051906020019080838360005b838110156118ab578082015181840152602081019050611890565b50505050905090810190601f1680156118d85780820380516001836020036101000a031916815260200191505b509250505060405180910390fd5b5060008385039050809150509392505050565b8154818355818111156119205781836000526020600020918201910161191f9190611925565b5b505050565b61194791905b8082111561194357600081600090555060010161192b565b5090565b9056fe53686f756c64206861766520656e6f756768207374616b657320746f2077697468647261772e4f6e6c792061646d696e2063616e2061646a757374206d696e65722066656520726174652e536166654d6174683a206d756c7469706c69636174696f6e206f766572666c6f7746656520726174652073686f756c6420626520696e20626173697320706f696e742e4f6e6c79206d696e65722063616e207570646174652074686520616464726573732e4f6e6c7920706f6f6c206d61696e7461696e65722063616e2067657420746865206d61697461696e616e6365206665652ea265627a7a72315820124c43f90cdbeb141590e510c61155c03ff45ea8fd22d287f63f5e881fb58c3664736f6c634300050d003246656520726174652073686f756c6420626520696e20626173697320706f696e742e"
*/

let byteCodeWithParam = rowByteCode + web3.eth.abi.encodeParameters(['address','address','address','uint256','uint256','uint256'], [your_miner_address, your_admin_address, your_poolMaintainer_address, _minerFeeRateBp, poolMaintainerFeeRateBp, _maxStakers]).slice(2);
// Admin should be a staker address.
// Max feeRateBp is 10000 which equal to 100%.
/* 
let byteCodeWithParam = rowByteCode + web3.eth.abi.encodeParameters(['address','address','address','uint256','uint256','uint256'], ['0x004e546327870122a467262513465a199c6c1258','0x13A83b461d7c612f5C120979cEf16335806d6EAc','0x62d4971dB0133dAC13dF915Be1D11FB9d0909a8B', '5000', '1000', '10']).slice(2);

0x608060405234801561001057600080fd5b5060405162001cfe38038062001cfe833981810160405260c081101561003557600080fd5b810190808051906020019092919080519060200190929190805190602001909291908051906020019092919080519060200190929190805190602001909291905050506127108311156100d4576040517f08c379a000000000000000000000000000000000000000000000000000000000815260040180806020018281038252602281526020018062001cdc6022913960400191505060405180910390fd5b612710821115610130576040517f08c379a000000000000000000000000000000000000000000000000000000000815260040180806020018281038252602281526020018062001cdc6022913960400191505060405180910390fd5b612710828401111561018e576040517f08c379a000000000000000000000000000000000000000000000000000000000815260040180806020018281038252602281526020018062001cdc6022913960400191505060405180910390fd5b85600560006101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff16021790555084600260006101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff16021790555083600860006101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff160217905550826006819055508160098190555080600481905550505050505050611a60806200027c6000396000f3fe60806040526004361061011f5760003560e01c80635756ae11116100a0578063d4e24be011610064578063d4e24be014610649578063e037ad1e146106a0578063e35b28c2146106db578063f851a44014610706578063fd5e6dd11461075d5761011f565b80635756ae11146105385780635d05ec471461056357806367174b20146105c8578063bf9befb1146105f3578063cbed45eb1461061e5761011f565b8063410390ec116100e7578063410390ec146104105780634e745f1f1461044b5780634ec18db9146104b75780634f7ff503146104e2578063536e41411461050d5761011f565b8063017f6f751461030f578063186697291461033a5780632b16cad214610351578063349dc329146103a25780633cfb18fd146103f9575b6101276107d8565b60008060003373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff168152602001908152602001600020905060008160000154141561026757600454600180549050106101f2576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260118152602001807f546f6f206d616e79207374616b6572732e00000000000000000000000000000081525060200191505060405180910390fd5b600180549050816001018190555060013390806001815401808255809150509060018203906000526020600020016000909192909190916101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff160217905550505b34816000016000828254019250508190555061028e34600354610a0590919063ffffffff16565b60038190555034600354101561030c576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260128152602001807f4164646974696f6e206f766572666c6f772e000000000000000000000000000081525060200191505060405180910390fd5b50005b34801561031b57600080fd5b50610324610a8d565b6040518082815260200191505060405180910390f35b34801561034657600080fd5b5061034f610a93565b005b34801561035d57600080fd5b506103a06004803603602081101561037457600080fd5b81019080803573ffffffffffffffffffffffffffffffffffffffff169060200190929190505050610b9a565b005b3480156103ae57600080fd5b506103b7610c8c565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b34801561040557600080fd5b5061040e610cb2565b005b34801561041c57600080fd5b506104496004803603602081101561043357600080fd5b8101908080359060200190929190505050610dd6565b005b34801561045757600080fd5b5061049a6004803603602081101561046e57600080fd5b81019080803573ffffffffffffffffffffffffffffffffffffffff169060200190929190505050611163565b604051808381526020018281526020019250505060405180910390f35b3480156104c357600080fd5b506104cc611187565b6040518082815260200191505060405180910390f35b3480156104ee57600080fd5b506104f7611194565b6040518082815260200191505060405180910390f35b34801561051957600080fd5b5061052261119a565b6040518082815260200191505060405180910390f35b34801561054457600080fd5b5061054d61121c565b6040518082815260200191505060405180910390f35b34801561056f57600080fd5b506105b26004803603602081101561058657600080fd5b81019080803573ffffffffffffffffffffffffffffffffffffffff16906020019092919050505061129e565b6040518082815260200191505060405180910390f35b3480156105d457600080fd5b506105dd611396565b6040518082815260200191505060405180910390f35b3480156105ff57600080fd5b5061060861139c565b6040518082815260200191505060405180910390f35b34801561062a57600080fd5b506106336113a2565b6040518082815260200191505060405180910390f35b34801561065557600080fd5b5061065e6113a8565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b3480156106ac57600080fd5b506106d9600480360360208110156106c357600080fd5b81019080803590602001909291905050506113ce565b005b3480156106e757600080fd5b506106f0611540565b6040518082815260200191505060405180910390f35b34801561071257600080fd5b5061071b611546565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b34801561076957600080fd5b506107966004803603602081101561078057600080fd5b810190808035906020019092919050505061156c565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b6000343073ffffffffffffffffffffffffffffffffffffffff16310390506000610801826115a8565b90506000811415610813575050610a03565b6000600954600654019050600061084b61271061083d84612710038661165990919063ffffffff16565b6116df90919063ffffffff16565b9050600080905060008090505b6001805490508110156109435760008060006001848154811061087757fe5b9060005260206000200160009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1681526020019081526020016000209050600061090b6003546108fd84600001548861165990919063ffffffff16565b6116df90919063ffffffff16565b90506109208185610a0590919063ffffffff16565b935080826000016000828254019250508190555050508080600101915050610858565b5061095981600354610a0590919063ffffffff16565b6003819055506000610974828661172990919063ffffffff16565b9050600061099f856109916006548561165990919063ffffffff16565b6116df90919063ffffffff16565b905060006109b6828461172990919063ffffffff16565b90506109cd81600a54610a0590919063ffffffff16565b600a819055506109e882600754610a0590919063ffffffff16565b6007819055506003548810156109fa57fe5b50505050505050505b565b600080828401905083811015610a83576040517f08c379a000000000000000000000000000000000000000000000000000000000815260040180806020018281038252601b8152602001807f536166654d6174683a206164646974696f6e206f766572666c6f77000000000081525060200191505060405180910390fd5b8091505092915050565b600a5481565b600860009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff1614610b39576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260318152602001806119fb6031913960400191505060405180910390fd5b610b416107d8565b6000600a5490506000600a819055503373ffffffffffffffffffffffffffffffffffffffff166108fc829081150290604051600060405180830381858888f19350505050158015610b96573d6000803e3d6000fd5b5050565b600560009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff1614610c40576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260228152602001806119d96022913960400191505060405180910390fd5b610c486107d8565b80600560006101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff16021790555050565b600560009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b600560009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff1614610d75576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260208152602001807f4f6e6c79206d696e65722063616e20776974686472617720726577617264732e81525060200191505060405180910390fd5b610d7d6107d8565b6000600754905060006007819055503373ffffffffffffffffffffffffffffffffffffffff166108fc829081150290604051600060405180830381858888f19350505050158015610dd2573d6000803e3d6000fd5b5050565b60008111610e4c576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260138152602001807f496e76616c6964207769746864726177616c2e0000000000000000000000000081525060200191505060405180910390fd5b610e546107d8565b60008060003373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200190815260200160002090503373ffffffffffffffffffffffffffffffffffffffff166001826001015481548110610ebe57fe5b9060005260206000200160009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1614610f0657fe5b8181600001541015610f63576040517f08c379a000000000000000000000000000000000000000000000000000000000815260040180806020018281038252602681526020018061194b6026913960400191505060405180910390fd5b818160000160008282540392505081905550816003600082825403925050819055503373ffffffffffffffffffffffffffffffffffffffff166108fc839081150290604051600060405180830381858888f19350505050158015610fcb573d6000803e3d6000fd5b5060008160000154141561115f57806001015460008060018080805490500381548110610ff457fe5b9060005260206000200160009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff168152602001908152602001600020600101819055506001808080549050038154811061107357fe5b9060005260206000200160009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1660018260010154815481106110af57fe5b9060005260206000200160006101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff160217905550600180548091906001900361110c91906118f9565b506000803373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff168152602001908152602001600020600080820160009055600182016000905550505b5050565b60006020528060005260406000206000915090508060000154908060010154905082565b6000600180549050905090565b60045481565b6000806111ff6000600180549050116111b957600954600654016111bd565b6127105b6111f16006546111e33073ffffffffffffffffffffffffffffffffffffffff16316115a8565b61165990919063ffffffff16565b6116df90919063ffffffff16565b905061121681600754610a0590919063ffffffff16565b91505090565b60008061128160006001805490501161123b576009546006540161123f565b6127105b6112736009546112653073ffffffffffffffffffffffffffffffffffffffff16316115a8565b61165990919063ffffffff16565b6116df90919063ffffffff16565b905061129881600a54610a0590919063ffffffff16565b91505090565b60008060035414156112b35760009050611391565b60006112d53073ffffffffffffffffffffffffffffffffffffffff16316115a8565b90506000600954600654019050600061130f61271061130184612710038661165990919063ffffffff16565b6116df90919063ffffffff16565b905060008060008773ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1681526020019081526020016000209050600061138060035461137284600001548661165990919063ffffffff16565b6116df90919063ffffffff16565b905080826000015401955050505050505b919050565b60065481565b60035481565b60075481565b600860009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b600260009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff1614611474576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260258152602001806119716025913960400191505060405180910390fd5b6127108111156114cf576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260228152602001806119b76022913960400191505060405180910390fd5b6127106009548201111561152e576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260228152602001806119b76022913960400191505060405180910390fd5b6115366107d8565b8060068190555050565b60095481565b600260009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b6001818154811061157957fe5b906000526020600020016000915054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b6000806115d6600a546115c8600754600354610a0590919063ffffffff16565b610a0590919063ffffffff16565b90508083101561164e576040517f08c379a000000000000000000000000000000000000000000000000000000000815260040180806020018281038252601b8152602001807f53686f756c64206861766520656e6f7567682062616c616e63652e000000000081525060200191505060405180910390fd5b808303915050919050565b60008083141561166c57600090506116d9565b600082840290508284828161167d57fe5b04146116d4576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260218152602001806119966021913960400191505060405180910390fd5b809150505b92915050565b600061172183836040518060400160405280601a81526020017f536166654d6174683a206469766973696f6e206279207a65726f000000000000815250611773565b905092915050565b600061176b83836040518060400160405280601e81526020017f536166654d6174683a207375627472616374696f6e206f766572666c6f770000815250611839565b905092915050565b6000808311829061181f576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825283818151815260200191508051906020019080838360005b838110156117e45780820151818401526020810190506117c9565b50505050905090810190601f1680156118115780820380516001836020036101000a031916815260200191505b509250505060405180910390fd5b50600083858161182b57fe5b049050809150509392505050565b60008383111582906118e6576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825283818151815260200191508051906020019080838360005b838110156118ab578082015181840152602081019050611890565b50505050905090810190601f1680156118d85780820380516001836020036101000a031916815260200191505b509250505060405180910390fd5b5060008385039050809150509392505050565b8154818355818111156119205781836000526020600020918201910161191f9190611925565b5b505050565b61194791905b8082111561194357600081600090555060010161192b565b5090565b9056fe53686f756c64206861766520656e6f756768207374616b657320746f2077697468647261772e4f6e6c792061646d696e2063616e2061646a757374206d696e65722066656520726174652e536166654d6174683a206d756c7469706c69636174696f6e206f766572666c6f7746656520726174652073686f756c6420626520696e20626173697320706f696e742e4f6e6c79206d696e65722063616e207570646174652074686520616464726573732e4f6e6c7920706f6f6c206d61696e7461696e65722063616e2067657420746865206d61697461696e616e6365206665652ea265627a7a72315820124c43f90cdbeb141590e510c61155c03ff45ea8fd22d287f63f5e881fb58c3664736f6c634300050d003246656520726174652073686f756c6420626520696e20626173697320706f696e742e000000000000000000000000004e546327870122a467262513465a199c6c125800000000000000000000000013a83b461d7c612f5c120979cef16335806d6eac00000000000000000000000062d4971db0133dac13df915be1d11fb9d0909a8b000000000000000000000000000000000000000000000000000000000000138800000000000000000000000000000000000000000000000000000000000003e8000000000000000000000000000000000000000000000000000000000000000a
*/
```

- Deploy your contract on [QuarkChain Mainet Explorer](https://mainnet.quarkchain.io/contract).

    - Choose the right shard which you want to mine on Address area.
    - Paste ```byteCodeWithParam``` to Deploy tab and set gas limit >= 5000000(make sure you have enough qkc on this shard), then click deploy button.
      ![deploy transaction](./assets/images/2.jpg)
      ![submit transaction](./assets/images/3.jpg) 
    - On the transaction status page you may find the contract address once the transaction is confirmed.
      ![find the transaction](./assets/images/4.jpg)
      ![copy the address](./assets/images/5.jpg)

### Stake QKC

- You can interact your contract with our [QuarkChain Mainet Explorer](https://mainnet.quarkchain.io/contract). **Make sure you have enough QKC for paying the gas fee on the right chain.**
  ![interact contract](./assets/images/6.jpg)

- QKC holder can transfer their QKC to the contract address.
  ![interact contract](./assets/images/7.jpg)

### Mine QKC with the contract address

- Paste the contract address to your mining settings instead of the regular wallet address. Start mining. **Miner address should be ETH like, so we need delete last eight digits of the contract address.**
  ![miner settings](./assets/images/8.jpg)

- You can check the mining result on [QuarkChain Mainet Explorer]
  ![PoSW successful](./assets/images/9.jpg)

### Withdraw Profits

Staker, Miner and PoolMaintainer can withdraw their profits by methods ```withdrawStakers(amount), withdrawMinerReward, transferMaintainerFee```
![withdraw](./assets/images/10.jpg)
