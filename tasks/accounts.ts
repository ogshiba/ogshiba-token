import {task} from 'hardhat/config';

task('accounts', 'Prints the list of accounts', async (_, {ethers}) => {
    const accounts = await ethers.getSigners();

    for (let [index, account] of accounts.entries()) {
        console.log(`>   Wallet ${index}: ${account.address}`);
    }
});