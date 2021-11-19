import chai from 'chai';
import {solidity} from 'ethereum-waffle';
import {Token} from "../../typechain";
import {ethers, network} from "hardhat";
import {SignerWithAddress} from "@nomiclabs/hardhat-ethers/signers";
import {balance, deployToken, transfer} from "../utils";

chai.use(solidity);
const {expect} = chai;

describe('Transfer and check balances', () => {

    if (!["hardhat", "localhost"].includes(network.name))
        return

    let token: Token;
    let deployer: SignerWithAddress;
    let snapshotId: number;

    before(async () => {
        [deployer] = await ethers.getSigners();
        token = await deployToken();
    });

    beforeEach(async () => {
        snapshotId = await ethers.provider.send('evm_snapshot', []);
    });

    afterEach(async () => {
        await ethers.provider.send('evm_revert', [snapshotId]);
    });

    it('should transfer between 2 wallets from 0 to 1', async () => {
        await transfer(token, 0, 1, ethers.BigNumber.from('100000000000'))
        const b = await balance(token, 1)
        expect(b.balance).to.eq('100000000000')
        expect(b.dead).to.eq('0')
    });

    it('should transfer between 2 wallets from 0 to 2 and burn some tokens', async () => {
        await transfer(token, 0, 1, ethers.BigNumber.from('100000000000'))
        await transfer(token, 1, 2, ethers.BigNumber.from('100000000000'))
        const b = await balance(token, 2)
        expect(b.balance).to.eq('90000000000')
        expect(b.dead).to.eq('1000000000')
    });

})
