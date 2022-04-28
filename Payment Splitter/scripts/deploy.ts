import { ethers } from 'hardhat';
import hre from 'hardhat';

var prompt = require('prompt-sync')();

async function main() {
  const singer = (await ethers.getSigners())[0];

  let addr1: string;
  let addr2: string;
  let share1: number;
  let share2: number;

  console.log('\nDeploying to ' + hre.network.name + ' network with ' + singer.address + ' as the signer ...');

  addr1 = await prompt('Enter the first address: ');
  if (!ethers.utils.getAddress(addr1)) {
    console.log('Invalid address: ' + addr1);
    process.exit(1);
  }
  addr2 = await prompt('Enter the second address: ');
  if (!ethers.utils.getAddress(addr2)) {
    console.log('Invalid address: ' + addr2);
    process.exit(1);
  }
  share1 = Number(await prompt('Enter the first share: '));
  share2 = Number(await prompt('Enter the second share: '));

  // abort if share are not 100% valid
  if (share1 + share2 !== 100) {
    console.log('Invalid shares! shares must add up to 100%');
    process.exit(1);
  }

  // get confirm
  console.log('-----------------------------------------------');
  console.log('Your Inputs are: ');
  console.log('First address: ' + addr1 + ' with share of ' + share1 + '%');
  console.log('Second address: ' + addr2 + ' with share of ' + share2 + '%');
  const confirm = await prompt('Are you sure you want to deploy? (y/n) ');
  if (confirm !== 'y') {
    console.log('Aborting');
    process.exit(0);
  }

  console.log('Deploying...');
  const PaymentSplitterFactory = await ethers.getContractFactory('PaymentSplitter', singer);
  const PaymentSplitter = await PaymentSplitterFactory.connect(singer).deploy(addr1, addr2, share1, share2);

  await PaymentSplitter.deployed();

  console.log(
    'PaymentSplitter deployed to ' + hre.network.name + ' network' + ' with address ' + PaymentSplitter.address
  );
  // run verify

  console.log('run this command to verify contract: ');
  console.log(
    'npx hardhat verify --network ' +
      hre.network.name +
      ' --contract contracts/PaymentSplitter.sol:PaymentSplitter ' +
      PaymentSplitter.address +
      ' ' +
      addr1 +
      ' ' +
      addr2 +
      ' ' +
      share1 +
      ' ' +
      share2
  );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
