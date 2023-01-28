import { ethers } from 'hardhat';
import { PaymentSplitter } from '../typechain';

const MAX_GAS_PRICE = process.env.MAX_GAS_PRICE ?? '60'; // defaults to 60 gwei
const MAX_PRIORITY = process.env.MAX_PRIORITY ?? '1.5'; // defaults to 1.5 gwei

const ETHWithdraw = async (PaymentSplitter: PaymentSplitter) => {
  //                ETH
  const contractBalance = await ethers.provider.getBalance(PaymentSplitter.address);

  if (contractBalance.gt(0)) {
    console.log('Withdrawing ETH ...');
    const tx1 = await PaymentSplitter.withdraw({
      maxFeePerGas: ethers.utils.parseUnits(MAX_GAS_PRICE, 'gwei'),
      maxPriorityFeePerGas: ethers.utils.parseUnits(MAX_PRIORITY, 'gwei'),
    });
    await tx1.wait();
    console.log('Withdraw ETH' + ethers.utils.formatEther(contractBalance) + ' ETH at tx:', tx1.hash);
  } else {
    console.log('No ETH balance to withdraw!');
  }
};

const WETHWithdraw = async (PaymentSplitter: PaymentSplitter) => {
  //               WETH
  // get WETH contract
  const WETH = await ethers.getContractAt('ERC20', process.env.WETH_ADDRESS ?? '');
  const WETHBalance = await WETH.balanceOf(PaymentSplitter.address);

  if (WETHBalance.gt(0)) {
    console.log('Withdrawing WETH...');
    const tx2 = await PaymentSplitter.withdrawERC20(WETH.address, {
      maxFeePerGas: ethers.utils.parseUnits(MAX_GAS_PRICE, 'gwei'),
      maxPriorityFeePerGas: ethers.utils.parseUnits(MAX_PRIORITY, 'gwei'),
    });
    await tx2.wait();
    console.log('Withdraw ' + ethers.utils.formatEther(WETHBalance) + ' WETH at tx:', tx2.hash);
  } else {
    console.log('No WETH balance to withdraw!');
  }
};

const fullWithdraw = async (PaymentSplitter: PaymentSplitter) => {
  await ETHWithdraw(PaymentSplitter);
  await WETHWithdraw(PaymentSplitter);
};

export { fullWithdraw, ETHWithdraw, WETHWithdraw };