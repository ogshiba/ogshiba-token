import {task} from 'hardhat/config';
import {Contract as EthersContract} from 'ethers';

type ContractName = 'Token';

interface Contract {
    args?: (string | number | (() => string | undefined))[];
    instance?: EthersContract;
    libraries?: () => Record<string, string>;
    waitForConfirmation?: boolean;
}

task('deploy', 'Deploy contracts')
    .setAction(async (args, {ethers}) => {
        const network = await ethers.provider.getNetwork();
        if (network.chainId !== 31337) {
            console.log(`Invalid chain id. Expected 31337. Got: ${network.chainId}`);
            return;
        }

        const contracts: Record<ContractName, Contract> = {
            Token: {},
        };

        for (const [name, contract] of Object.entries(contracts)) {
            const factory = await ethers.getContractFactory(name, {
                libraries: contract?.libraries?.(),
            });

            const deployedContract = await factory.deploy(
                ...(contract.args?.map(a => (typeof a === 'function' ? a() : a)) ?? []),
            );

            if (contract.waitForConfirmation) {
                await deployedContract.deployed();
            }

            contracts[name as ContractName].instance = deployedContract;

            console.log(`>   ${name} contract deployed to ${deployedContract.address}`);

            await deployedContract.setLiquifyThreshhold(0)
        }

        return contracts;
    });