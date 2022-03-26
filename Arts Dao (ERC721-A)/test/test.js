const { expect } = require("chai");
const { utils } = require("ethers");
const { waffle, ethers } = require("hardhat");
const provider = waffle.provider;

describe("Ethernal Gates", () => {
  let owner;
  let addrs;
  let ethernalGatesContract;
  let addr1;
  let proof = [
    "0x1fa96f804e8b8050da5c53c1146e30f3eb3e4496682ab86e827815fb426d907a",
    "0xa6443a8706e103fc2ac4771878df8f69a27345a5d77744d6f0043ac6add07bb5",
    "0x498dcb58a25d8f319da176e453c6dd1792b44dda8cc39cc749e3defdb857e244",
    "0x3a6c84dac8debee2601ffe8cbabaa86d22ec38d5dbcbf20d010745f1bba082f6",
    "0x54bb28698033a246f879aa49e4d5e3a381bb55b09ec7dacdb0ea7d26d5f36638",
    "0x8882bec35b509ab554718a0180fae41ca557f5d672c73b6471e063d1cff6ff61",
  ];
  let merkleRoot =
    "0x44a245a36bced89e7d644adb3c017d9e250a7f2f9daab8073edc749a611efdf1";

  const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

  beforeEach(async () => {
    [owner, addr1, ...addrs] = await provider.getWallets();

    const Contract = await ethers.getContractFactory("EthernalGates");
    ethernalGatesContract = await Contract.deploy("");
  });

  it("Should return current supply", async () => {
    expect(await ethernalGatesContract.currentSupply()).to.equal(2000);
  });

  it("Should set the right owner", async () => {
    expect(await ethernalGatesContract.owner()).to.equal(await owner.address);
  });

  it("Should mint an nft in public sale", async () => {
    await ethernalGatesContract.setSaleStatus(4);
    const egPrice = await ethernalGatesContract.publicPrice();
    const tokenId = await ethernalGatesContract.totalSupply();
    await expect(
      ethernalGatesContract.publicMint(1, {
        value: egPrice,
      })
    )
      .to.emit(ethernalGatesContract, "Transfer")
      .withArgs(ZERO_ADDRESS, owner.address, tokenId + 1);
  });

  it("should doesn't allow to exceed maximum supply of NFT", async () => {
    await ethernalGatesContract.setSaleStatus(4);
    const egPrice = await ethernalGatesContract.publicPrice();
    await expect(
      ethernalGatesContract.publicMint(2001, {
        value: egPrice,
      })
    ).to.be.revertedWith(
      "Transaction will exceed maximum supply of Ethernal Gates"
    );
  });

  it("Should doesn't allow to mint less than one nft", async () => {
    await ethernalGatesContract.setSaleStatus(4);
    const egPrice = await ethernalGatesContract.publicPrice();
    await expect(
      ethernalGatesContract.publicMint(0, {
        value: egPrice,
      })
    ).to.be.revertedWith("MintZeroQuantity()");
  });

  it("Should allow to reserve an NFT", async () => {
    const tokenId = await ethernalGatesContract.totalSupply();
    await expect(ethernalGatesContract.reserveEthernalGates(1))
      .to.emit(ethernalGatesContract, "Transfer")
      .withArgs(ZERO_ADDRESS, owner.address, tokenId + 1);
  });

  it("should doesn't allow to mint when public sale is closed", async () => {
    const egPrice = await ethernalGatesContract.publicPrice();
    await expect(
      ethernalGatesContract.publicMint(1, {
        value: egPrice,
      })
    ).to.be.revertedWith("Public sale is not started");
  });

  it("should doesn't allow to mint in public sale when sufficient ETH is not sent ", async () => {
    await ethernalGatesContract.setSaleStatus(4);
    await expect(
      ethernalGatesContract.publicMint(1, {
        value: 0,
      })
    ).to.be.revertedWith("Incorrect ether sent with this transaction");
  });

  it("should doesn't allow to increase supply by more than 6000", async () => {
    await expect(ethernalGatesContract.increaseSupply(4001)).to.be.revertedWith(
      "Cannot increase supply by more than 6000"
    );
  });

  it("should allow to increase supply", async () => {
    await ethernalGatesContract.increaseSupply(2000);
    expect(await ethernalGatesContract.currentSupply()).to.equal(4000);
  });

  it("should allow to airdrop", async () => {
    const tokenId = await ethernalGatesContract.totalSupply();
    await expect(ethernalGatesContract.airdrop([owner.address], 2))
      .to.emit(ethernalGatesContract, "Transfer")
      .withArgs(ZERO_ADDRESS, owner.address, tokenId + 1);
  });

  it("Should allow to mint an nft in general presale", async () => {
    await ethernalGatesContract.setSaleStatus(3);
    await ethernalGatesContract.setMerkleRoot(merkleRoot);
    const egPrice = await ethernalGatesContract.presalePrice();
    const tokenId = await ethernalGatesContract.totalSupply();
    await expect(
      ethernalGatesContract.presaleMint(proof, 3, 1, {
        value: egPrice,
      })
    )
      .to.emit(ethernalGatesContract, "Transfer")
      .withArgs(ZERO_ADDRESS, owner.address, tokenId + 1);
  });

  it("Should doesn't allow to mint an nft in  presale if merkle root is not set", async () => {
    await ethernalGatesContract.setSaleStatus(3);
    const egPrice = await ethernalGatesContract.presalePrice();
    await expect(
      ethernalGatesContract.presaleMint(proof, 3, 1, {
        value: egPrice,
      })
    ).to.be.revertedWith("No address is eligible for presale minting yet");
  });

  it("Should doesn't allow to mint an nft in presale if presale is off", async () => {
    await ethernalGatesContract.setMerkleRoot(merkleRoot);
    const egPrice = await ethernalGatesContract.presalePrice();
    await expect(
      ethernalGatesContract.presaleMint(proof, 3, 1, {
        value: egPrice,
      })
    ).to.be.revertedWith("Presale sale not started");
  });

  it("Should doesn't allow to mint an nft in presale if public sale is live", async () => {
    await ethernalGatesContract.setSaleStatus(4);
    await ethernalGatesContract.setMerkleRoot(merkleRoot);
    const egPrice = await ethernalGatesContract.presalePrice();
    await expect(
      ethernalGatesContract.presaleMint(proof, 3, 1, {
        value: egPrice,
      })
    ).to.be.revertedWith("Presale sale not started");
  });

  it("Should doesn't allow to mint an nft in presale if address is not whitelisted", async () => {
    await ethernalGatesContract.setSaleStatus(3);
    await ethernalGatesContract.setMerkleRoot(merkleRoot);
    const egPrice = await ethernalGatesContract.presalePrice();
    await expect(
      ethernalGatesContract.connect(addr1).presaleMint(proof, 3, 1, {
        value: egPrice,
      })
    ).to.be.revertedWith("Address not eligible for presale mint");
  });

  it("Should doesn't allow to mint an nft in presale if allowed count is not legit", async () => {
    await ethernalGatesContract.setSaleStatus(3);
    await ethernalGatesContract.setMerkleRoot(merkleRoot);
    const egPrice = await ethernalGatesContract.presalePrice();
    await expect(
      ethernalGatesContract.presaleMint(proof, 4, 3, {
        value: egPrice,
      })
    ).to.be.revertedWith("Address not eligible for presale mint");
  });

  it("Should doesn't allow to mint if mount count exceeds allowance", async () => {
    await ethernalGatesContract.setSaleStatus(3);
    await ethernalGatesContract.setMerkleRoot(merkleRoot);
    const egPrice = await ethernalGatesContract.presalePrice();
    await expect(
      ethernalGatesContract.presaleMint(proof, 3, 4, {
        value: egPrice,
      })
    ).to.be.revertedWith("Mint count exceeds allowed mint count");
  });

  it("Should doesn't allow to mint an nft in presale if transaction will exceed allowed count", async () => {
    await ethernalGatesContract.setSaleStatus(3);
    await ethernalGatesContract.setMerkleRoot(merkleRoot);
    let egPrice = await ethernalGatesContract.presalePrice();
    await ethernalGatesContract.presaleMint(proof, 3, 3, {
      value: utils.parseEther("1.47"),
    });
    await expect(
      ethernalGatesContract.presaleMint(proof, 3, 1, {
        value: egPrice,
      })
    ).to.be.revertedWith(
      "Transaction will exceed maximum NFTs allowed to mint in presale"
    );
  });
});
