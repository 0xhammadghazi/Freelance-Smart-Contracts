import { expect } from 'chai';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { ethers } from 'hardhat';
import { PaymentSplitter, WETHMock } from '../typechain';

import { deployContract, tryDeploy, transferETH } from './helpers';
import { BigNumber } from 'ethers';

describe('PaymentSplitter', () => {
  let splitter: PaymentSplitter;

  let owner: SignerWithAddress;
  let addr1: SignerWithAddress;
  let addr2: SignerWithAddress;
  let addr3: SignerWithAddress;
  let addr4: SignerWithAddress;
  let addr5: SignerWithAddress;
  let addrs: SignerWithAddress[];
  const share1: BigNumber = BigNumber.from(70);
  const share2: BigNumber = BigNumber.from(30);

  const ZERO_ADDRESS = ethers.constants.AddressZero;

  beforeEach(async () => {
    [owner, addr1, addr2, addr3, addr4, addr5, ...addrs] = await ethers.getSigners();
  });

  context('deploy', async () => {
    it('should deploy with correct params', async () => {
      expect(await tryDeploy('PaymentSplitter', addr1.address, addr2.address, share1, share2)).to.be.ok;
    });

    context('address', () => {
      it('should revert with zero address', async () => {
        await expect(tryDeploy('PaymentSplitter', ZERO_ADDRESS, addr2.address, share1, share2)).to.revertedWith(
          'WrongAddress'
        );

        await expect(tryDeploy('PaymentSplitter', addr1.address, ZERO_ADDRESS, share1, share2)).to.revertedWith(
          'WrongAddress'
        );

        await expect(tryDeploy('PaymentSplitter', ZERO_ADDRESS, ZERO_ADDRESS, share1, share2)).to.revertedWith(
          'WrongAddress'
        );
      });
    });

    context('shares', () => {
      it('should revert with zero share', async () => {
        await expect(tryDeploy('PaymentSplitter', addr1.address, addr2.address, 0, 100)).to.revertedWith('WrongShare');

        await expect(tryDeploy('PaymentSplitter', addr1.address, addr2.address, 100, 0)).to.revertedWith('WrongShare');

        await expect(tryDeploy('PaymentSplitter', addr1.address, addr2.address, 0, 0)).to.revertedWith('WrongShare');
      });

      it('should revert when shares sum are not 100', async () => {
        await expect(tryDeploy('PaymentSplitter', addr1.address, addr2.address, 10, 20)).to.revertedWith('WrongShare');
      });
    });
  });

  context('after deploy', async () => {
    beforeEach(async () => {
      // deploy contracts
      splitter = await deployContract('PaymentSplitter', addr1.address, addr2.address, share1, share2);
    });

    context('storage vars', async () => {
      it('should return correct address', async () => {
        expect((await splitter.addrs()).addr1).to.eq(addr1.address);
        expect((await splitter.addrs()).addr2).to.eq(addr2.address);
      });

      it('should return correct shares', async () => {
        expect(await splitter.share1()).to.eq(share1);
        expect(await splitter.share2()).to.eq(share2);
      });
    });

    context('recieve', async () => {
      it('should recieve eth', async () => {
        const amount = ethers.utils.parseEther('1');

        const tx = await transferETH(splitter, amount, owner);

        // expect to emit Received
        await expect(tx).to.emit(splitter, 'Received').withArgs(owner.address, amount);

        // get balance of contract
        const contractBalance = await ethers.provider.getBalance(splitter.address);

        expect(contractBalance).to.eq(amount);
      });
    });

    context('withdraw eth', async () => {
      it('should withdraw eth', async () => {
        const amount = ethers.utils.parseEther('1');

        const tx = await transferETH(splitter, amount, owner);

        // expect to emit Received
        await expect(tx).to.emit(splitter, 'Received').withArgs(owner.address, amount);

        // get balance of contract
        const contractBalanceBefore = await ethers.provider.getBalance(splitter.address);

        expect(contractBalanceBefore).to.eq(amount);

        // get balance before
        const addr1BalanceBefore = await addr1.getBalance();
        const addr2BalanceBefore = await addr2.getBalance();
        const addr1Share = amount.mul(share1).div(100);
        const addr2Share = amount.mul(share2).div(100);
        const addr1ExpectedBalance = addr1BalanceBefore.add(addr1Share);
        const addr2ExpectedBalance = addr2BalanceBefore.add(addr2Share);

        // withdraw eth
        const withdrawTx = await splitter.withdraw();
        await expect(withdrawTx).to.emit(splitter, 'Withdraw').withArgs(addr1.address, addr1Share);
        await expect(withdrawTx).to.emit(splitter, 'Withdraw').withArgs(addr2.address, addr2Share);

        const contractBalanceAfter = await ethers.provider.getBalance(splitter.address);
        expect(contractBalanceAfter).to.eq(ethers.constants.Zero);

        // expect balance of addr1 and addr2 is correct
        const addr1BalanceAfter = await addr1.getBalance();
        const addr2BalanceAfter = await addr2.getBalance();

        expect(addr1BalanceAfter).to.eq(addr1ExpectedBalance);
        expect(addr2BalanceAfter).to.eq(addr2ExpectedBalance);
      });

      it('should revert when no balance', async () => {
        await expect(splitter.withdraw()).to.revertedWith('NoBalance');
      });
    });

    context('whithdraw erc20', async () => {
      let weth: WETHMock;
      beforeEach(async () => {
        // deploy erc20
        weth = await deployContract('WETHMock');

        // mint weth to owner
        await weth.deposit({ value: ethers.utils.parseEther('2') });
      });
      it('should withdraw erc20', async () => {
        const amount = ethers.utils.parseEther('2');

        // send some weth
        await weth.transfer(splitter.address, amount);
        const contractBalanceBefore = await weth.balanceOf(splitter.address);
        expect(contractBalanceBefore).to.eq(amount);

        // get balance before
        const addr1Share = amount.mul(share1).div(100);
        const addr2Share = amount.mul(share2).div(100);
        const addr1BalanceBefore = await weth.balanceOf(addr1.address);
        const addr2BalanceBefore = await weth.balanceOf(addr2.address);
        const addr1ExpectedBalance = addr1BalanceBefore.add(addr1Share);
        const addr2ExpectedBalance = addr2BalanceBefore.add(addr2Share);

        // withdraw weth
        const withdrawTx = await splitter.withdrawERC20(weth.address);
        await expect(withdrawTx).to.emit(splitter, 'WithdrawERC20').withArgs(weth.address, addr1.address, addr1Share);
        await expect(withdrawTx).to.emit(splitter, 'WithdrawERC20').withArgs(weth.address, addr2.address, addr2Share);

        const contractBalanceAfter = await weth.balanceOf(splitter.address);
        expect(contractBalanceAfter).to.eq(ethers.constants.Zero);

        // expect balance of addr1 and addr2 is correct
        const addr1BalanceAfter = await weth.balanceOf(addr1.address);
        const addr2BalanceAfter = await weth.balanceOf(addr2.address);

        expect(addr1BalanceAfter).to.eq(addr1ExpectedBalance);
        expect(addr2BalanceAfter).to.eq(addr2ExpectedBalance);
      });

      it('should revert when no balance', async () => {
        await expect(splitter.withdrawERC20(weth.address)).to.revertedWith('NoBalance');
      });
    });

    context('change Addr', async () => {
      context('changeAddr1', async () => {
        it('should change addr1', async () => {
          await splitter.connect(addr1).changeAddr1(addr3.address);
          expect((await splitter.addrs()).addr1).to.eq(addr3.address);
        });

        it('should change multiple times', async () => {
          await splitter.connect(addr1).changeAddr1(addr3.address);
          expect((await splitter.addrs()).addr1).to.eq(addr3.address);

          // sanity check
          await expect(splitter.connect(addr1).changeAddr1(addr3.address)).to.revertedWith('NotValidSender');

          await splitter.connect(addr3).changeAddr1(addr4.address);
          expect((await splitter.addrs()).addr1).to.eq(addr4.address);

          // sanity check
          await expect(splitter.connect(addr3).changeAddr1(addr3.address)).to.revertedWith('NotValidSender');

          await splitter.connect(addr4).changeAddr1(addr5.address);
          expect((await splitter.addrs()).addr1).to.eq(addr5.address);
        });

        it('should revert if not sender', async () => {
          await expect(splitter.connect(addr2).changeAddr1(addr3.address)).to.revertedWith('NotValidSender');
          await expect(splitter.connect(addr4).changeAddr1(addr3.address)).to.revertedWith('NotValidSender');
        });

        it('should revert if not zero address', async () => {
          await expect(splitter.connect(addr1).changeAddr1(ZERO_ADDRESS)).to.revertedWith('WrongAddress');
        });
      });

      context('changeAddr2', async () => {
        it('should change addr2', async () => {
          await splitter.connect(addr2).changeAddr2(addr3.address);
          expect((await splitter.addrs()).addr2).to.eq(addr3.address);
        });

        it('should change multiple times', async () => {
          await splitter.connect(addr2).changeAddr2(addr3.address);
          expect((await splitter.addrs()).addr2).to.eq(addr3.address);

          // sanity check
          await expect(splitter.connect(addr2).changeAddr2(addr3.address)).to.revertedWith('NotValidSender');

          await splitter.connect(addr3).changeAddr2(addr4.address);
          expect((await splitter.addrs()).addr2).to.eq(addr4.address);

          // sanity check
          await expect(splitter.connect(addr3).changeAddr2(addr3.address)).to.revertedWith('NotValidSender');

          await splitter.connect(addr4).changeAddr2(addr5.address);
          expect((await splitter.addrs()).addr2).to.eq(addr5.address);
        });

        it('should revert if not sender', async () => {
          await expect(splitter.connect(addr1).changeAddr2(addr3.address)).to.revertedWith('NotValidSender');
          await expect(splitter.connect(addr4).changeAddr2(addr3.address)).to.revertedWith('NotValidSender');
        });

        it('should revert if not zero address', async () => {
          await expect(splitter.changeAddr2(ZERO_ADDRESS)).to.revertedWith('WrongAddress');
          await expect(splitter.connect(addr2).changeAddr2(ZERO_ADDRESS)).to.revertedWith('WrongAddress');
        });
      });
    });
  });
});
