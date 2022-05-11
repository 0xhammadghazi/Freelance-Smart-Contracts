// scripts/create-box.js
const { ethers } = require("hardhat");

async function main() {
  const DatabaseFactory = await ethers.getContractFactory("EthBridge");
  const DataBase = await DatabaseFactory.deploy();

  //   await DataBase.deployed();
  console.log("DataBase address:", DataBase.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
