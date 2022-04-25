import { ethers } from 'hardhat';

// set values here:
const addr1 = '0x';
const addr2 = '0x';
const share1 = 70;
const share2 = 30;

async function main() {
  const PaymentSplitterFactory = await ethers.getContractFactory('PaymentSplitter');
  const PaymentSplitter = await PaymentSplitterFactory.deploy(addr1, addr2, share1, share2);

  await PaymentSplitter.deployed();

  console.log('PaymentSplitter deployed to:', PaymentSplitter.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
