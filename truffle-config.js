var HDWalletProvider = require('@truffle/hdwallet-provider');
require('dotenv').config();

module.exports = {
  plugins: [
        'truffle-plugin-verify'
    ],

  networks: {
      ganache: {
        host: "127.0.0.1",
        port: 7545,
        network_id: 5777 // Match any network id
      },

      sepolia: {
        provider: () => new HDWalletProvider(
          process.env.ACCOUNT_2,
          "wss://ethereum-sepolia.publicnode.com"
        ),
        timeoutBlocks: 2000,
        skipDryRun: true,
        network_id: 11155111
      },

      base: {
        provider: () => new HDWalletProvider(
          process.env.ACCOUNT_2,
          "https://sepolia.base.org"
        ),
        timeoutBlocks: 2000,
        skipDryRun: true,
        network_id: 84532
      },

      bsctestnet: {
        provider: () => new HDWalletProvider(
          process.env.ACCOUNT_1,
          // "https://bsc.getblock.io/testnet/?api_key=d46d64f0-35c0-48aa-98f1-38884c382bcc"
          "https://bsc-testnet.publicnode.com"
        ),
        // timeoutBlocks: 20000,
        // skipDryRun: true,
        gas: 30000000,
        gasPrice: 5000000000,
        network_id: 97
      },
  },

  // Set default mocha options here, use special reporters, etc.
  mocha: {
    // timeout: 100000
  },

  // Configure your compilers
  compilers: {
    solc: {
      version: "0.8.25",      // Fetch exact version from solc-bin (default: truffle's version)
      // docker: true,        // Use "0.5.1" you've installed locally with docker (default: false)
      // settings: {          // See the solidity docs for advice about optimization and evmVersion
      //  optimizer: {
      //    enabled: false,
      //    runs: 200
      //  },
      //  evmVersion: "byzantium"
      // }
    }
  },

};
