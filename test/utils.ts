import {ethers} from 'hardhat';
import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers';
import {Token, Token__factory} from "../typechain";
import {BigNumber} from "ethers";

export type Attribute = {
    layer_type: string
    value: string
}

export type TestSigners = {
    deployer: SignerWithAddress;
    account0: SignerWithAddress;
    account1: SignerWithAddress;
    account2: SignerWithAddress;
};

export const getSigners = async (): Promise<TestSigners> => {
    const [deployer, account0, account1, account2] = await ethers.getSigners();
    return {
        deployer,
        account0,
        account1,
        account2,
    };
};

export const deployToken = async (deployer?: SignerWithAddress): Promise<Token> => {
    const factory = new Token__factory(deployer || (await getSigners()).deployer);

    return factory.deploy();
};

export const transfer = async (token: Token, from: number, to: number, amount: BigNumber) => {
    const signers = await ethers.getSigners();
    const tx = await token.connect(signers[from]).transfer(signers[to].address, amount)
    const rc = await tx.wait()
}

export const balance = async (token: Token, wallet: number) => {
    const deadAddress = '0x000000000000000000000000000000000000dEaD';
    const signers = await ethers.getSigners();

    const tx1 = await token.balanceOf(signers[wallet].address)
    const tx2 = await token.balanceOf(deadAddress)

    return {balance: tx1.toString(), dead: tx2.toString()}
}