// require("hardhat/config");

task("Eth-Bridge", "Deploy ethereum bridge").setAction(async () => {
  const ethNftContract = "0x4dcC498f86126a23cDB95c26DF11808fE2bfb98F";
  const ethBridgeFactory = await ethers.getContractFactory("EthBridge");
  const ethBridgeContract = await ethBridgeFactory.deploy(ethNftContract);
  console.log("Eth Bridge Address --> ", ethBridgeContract.address);

  // setTimeout(async () => {
  //   await hre.run("verify:verify", {
  //     address: ethBridgeContract.address,
  //     constructorArguments: [ethNftContract],
  //   });
  // }, 60000);
});

task("Arb-Bridge", "Deploy arbitrum bridge").setAction(async () => {
  const arbNftContract = "0xD92a3B0BcAF32ae70F28F3E9b380b50b0bD34E85";
  const arbBridgeFactory = await ethers.getContractFactory("ArbitrumBridge");
  const arbBridgeContract = await arbBridgeFactory.deploy(arbNftContract);
  console.log("Arb Bridge Address --> ", arbBridgeContract.address);
});
