import {task, types} from 'hardhat/config';

task('transfer', 'Transfer from wallet to wallet')
    .addOptionalParam(
        'address',
        'The `Token` contract address',
        '0xf3C8D517ba8462911Cc2b8cfedc5dDeC50DFCBd6',
        types.string,
    )
    .addOptionalParam(
        'from',
        'Wallet from which send tokens',
        0,
        types.int,
    )
    .addOptionalParam(
        'to',
        'Wallet which receive tokens',
        1,
        types.int,
    )
    .addOptionalParam(
        'amount',
        'Amount of tokens',
        '100000000000'
    )
    .setAction(async ({address, from, to, amount}, {ethers}) => {
        const factory = await ethers.getContractFactory('Token');
        const contract = factory.attach(address);
        const signers = await ethers.getSigners();

        const am = ethers.BigNumber.from(amount)
        const tx = await contract.connect(signers[from]).transfer(signers[to].address, am)
        const rc = await tx.wait()
        // console.log(`>   Receipt: ${JSON.stringify(rc)}`)
    });