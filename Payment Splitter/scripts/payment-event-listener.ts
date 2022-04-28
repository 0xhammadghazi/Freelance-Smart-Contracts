import { ethers } from 'hardhat';
import hre from 'hardhat';

async function main() {
  // get signer wallet
  const signer = (await ethers.getSigners())[0];

  //get contract instance from address
  const PaymentSplitter = await ethers.getContractAt(
    'PaymentSplitter',
    process.env.PAYMENT_SPLITTER_ADDRESS ?? '',
    signer
  );

  console.log('listening to events on ' + PaymentSplitter.address + ' on network ' + hre.network.name);
  // listen on Received event
  PaymentSplitter.on('Received', (from: string, amount: string) => {
    console.log(`Received ${amount} from ${from}`);

    const tx = PaymentSplitter.withdraw();

    tx.then((tx) => {
      console.log('Withdraw tx:', tx.hash);
    });
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
