require("@nomiclabs/hardhat-waffle");

const mnemonic = require('./mnemonic.json')

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
//  链网址：qitmeer.io
//  浏览器：evm.meerscan.io
//  rpc开放节点：RPC https://rpc.evm.meerscan.io
//  - swap网址：www.candyswap.network
//  - 链logo，
//  swaplogo
// 813
module.exports = {
  // defaultNetwork: "localhost",
  networks: {
  //   hardhat: {
  
  //  },
    qitmeer:{
      url: "https://explorer.qitmeer.io/rpc",
      accounts:
        {
          mnemonic: "tooth manage income garlic electric hobby say pitch object quick discover assist",
          path:"m/44'/60'/0'/0",
          initialIndex: 0,
          count:100,
        }
    },
    qitTest: {
      // url: "https://testnet.qng.meerscan.io/api/eth-rpc",
      // url: "https://rpc.evm.meerscan.io",
      url: "https://explorer.qitmeer.io/rpc",
      accounts:
        {
          mnemonic: mnemonic.meerTest,
          path:"m/44'/60'/0'/0",
          initialIndex: 0,
          count: 100,
        }
    },
    main: {
      // url: "https://testnet.qng.meerscan.io/api/eth-rpc",
      // url: "https://rpc.evm.meerscan.io",
      url: "https://rpc.evm.meerscan.io",
      accounts:
        {
          mnemonic: mnemonic.meerTest,
          path:"m/44'/60'/0'/0",
          initialIndex: 0,
          count: 100,
        }
    },
    dev: {
      url: "http://localhost:8545",
      accounts:
        {
          mnemonic: mnemonic.meerTest,
          path:"m/44'/60'/0'/0",
          initialIndex: 0,
          count: 100,
        }
    },
    hardhat: {
      throwOnTransactionFailures: true,
      throwOnCallFailures: true,
      allowUnlimitedContractSize: true,
      blockGasLimit: 0x1fffffffffffff,
      forking: {
        url: "https://rpc.evm.meerscan.io", // 全节点
        blockNumber: 795  
      },
      mining: {
        auto: true,
        interval: 3000
      },
      accounts: {
        mnemonic: process.env.MNEMONIC,
        count: 10
      }
    }
  },
  solidity: {
    version: "0.8.15",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      },
    }
  },


  mocha: {
    timeout: 10000000000000,
    gas: 2000000,
   
  }
};
