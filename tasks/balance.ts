import {task, types} from 'hardhat/config';

task('balance', 'Balance of wallet')
    .addOptionalParam(
        'address',
        'The `Token` contract address',
        '0xf3C8D517ba8462911Cc2b8cfedc5dDeC50DFCBd6',
        types.string,
    )
    .addOptionalParam(
        'wallet',
        'Index of wallet to check',
        0,
        types.int,
    )
    .setAction(async ({address, wallet}, {ethers}) => {
        const busdAddress = '0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56'
        const marketAddress = '0xe21534C9751F17b6B245576DB9CEb7f4eaE91396'
        const deadAddress = '0x000000000000000000000000000000000000dEaD'

        const factory = await ethers.getContractFactory('Token');
        const signers = await ethers.getSigners();
        const contract = factory.attach(address);
        const busd = (await ethers.getContractFactory('Token')).attach(busdAddress)

        console.log(`>   Wallet: ${signers[wallet].address}`)
        const tx = await contract.balanceOf(signers[wallet].address)
        console.log(`>   Balance: ${tx.toString()}`)

        const txm = await busd.balanceOf(marketAddress)
        console.log(`>   MarketWallet: ${txm.toString()}`)

        const txb = await contract.balanceOf(deadAddress)
        console.log(`>   Burned: ${txb.toString()}`)
    });