require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
require("hardhat-gas-reporter");
require("solidity-coverage");
require("./tasks/deploy");

module.exports = {
  solidity: {
    version: "0.8.13",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    rinkeby: {
      url: "https://rinkeby.infura.io/v3/2c0efa3339aa4ad89371e8d48b00882f",
      accounts: [
        "d944cde96a33381122313819f2fd33e46c8a1c33b7006a18f9f7ed2542778e92",
      ],
    },
    arbitrumrinkeby: {
      url: "https://speedy-nodes-nyc.moralis.io/31275c685e69634319ac19cc/arbitrum/testnet",
      accounts: [
        "d944cde96a33381122313819f2fd33e46c8a1c33b7006a18f9f7ed2542778e92",
      ],
    },
  },
  etherscan: {
    apiKey: {
      rinkeby: "99E6GR5JSACE74DM9F1FD5QGDY27S1V8JW",
      arbitrumTestnet: "4UZ8YKDDJP1UZ69DKEM7HGI9DITIF83ZAZ",
    },
  },
};
