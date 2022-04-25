import { BigNumber } from 'ethers';
import { ethers } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

// deploy contract function
async function deployContract(contractName: string, ...callData: any): Promise<any> {
  const factory = await ethers.getContractFactory(contractName);
  const contract = await factory.deploy(...callData);
  await contract.deployed();
  return contract;
}

// deploy contract function
async function tryDeploy(contractName: string, ...callData: any): Promise<any> {
  const factory = await ethers.getContractFactory(contractName);
  return factory.deploy(...callData);
}

// transfer eth to contract
async function transferETH(contract: any, amount: BigNumber, singer: SignerWithAddress): Promise<any> {
  const tx = await singer.sendTransaction({
    to: contract.address,
    value: amount,
  });
  await tx.wait();
  return tx;
}

export { deployContract, tryDeploy, transferETH };
