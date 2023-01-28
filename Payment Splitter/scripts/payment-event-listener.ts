import { ethers } from 'hardhat';
import hre from 'hardhat';
import { ETHWithdraw  } from './withdraw-helpers';

async function main() {
  // get signer wallet
  const signer = (await ethers.getSigners())[0];

  //get contract instance from address
  const PaymentSplitter = await ethers.getContractAt(
    'PaymentSplitter',
    process.env.PAYMENT_SPLITTER_ADDRESS ?? '',
    signer
  );

  console.log('> First check contract balance and withdraw if any.');
  await ETHWithdraw(PaymentSplitter);

  // listen on Received event
  console.log('> Listening to events on ' + PaymentSplitter.address + ' on network ' + hre.network.name + '...');
  PaymentSplitter.on('Received', async (from: string, amount: string) => {
    console.log(`Received ${ethers.utils.formatEther(amount)} ETH from ${from}`);
    await ETHWithdraw(PaymentSplitter);
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});