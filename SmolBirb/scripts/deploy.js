// scripts/create-box.js
const { ethers } = require("hardhat");

async function main() {
  // const ethNftContract = "0xF45aF344e0a31ffC270B61CDF1DEDAF63107ba54";
  // const ethBridgeFactory = await ethers.getContractFactory("EthBridge");
  // const ethBridgeContract = await ethBridgeFactory.deploy(ethNftContract);
  // console.log("Eth Bridge Address --> ", ethBridgeContract.address);

  const arbNftContract = "0x801BF055CEF440210bC61B7C484C96538CBb754B";
  const arbBridgeFactory = await ethers.getContractFactory("SmolBirbArb");
  const arbBridgeContract = await arbBridgeFactory.deploy("");
  console.log("Arb Bridge Address --> ", arbBridgeContract.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
