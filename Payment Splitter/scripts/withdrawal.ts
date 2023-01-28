import { ethers } from 'hardhat';
import { fullWithdraw } from './withdraw-helpers';

async function main() {
  // get signer wallet
  const signer = (await ethers.getSigners())[0];

  //get contract instance from address
  const PaymentSplitter = await ethers.getContractAt(
    'PaymentSplitter',
    process.env.PAYMENT_SPLITTER_ADDRESS ?? '',
    signer
  );

  await fullWithdraw(PaymentSplitter);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});