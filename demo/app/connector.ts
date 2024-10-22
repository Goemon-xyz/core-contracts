import { initializeConnector, Web3ReactHooks } from '@web3-react/core'
import { MetaMask } from '@web3-react/metamask'
import { Network } from '@web3-react/network'
import { Connector } from '@web3-react/types';

export const [metaMask, metaMaskHooks] = initializeConnector<MetaMask>((actions) => new MetaMask({ actions }))

export const [network, networkHooks] = initializeConnector<Network>((actions) => new Network({
    actions,
    urlMap: {
        1: 'http://localhost:8545', // Anvil
        31337: 'http://localhost:8545', // Anvil
    }
}))

export const connectors: [Connector, Web3ReactHooks][] = [
    [metaMask, metaMaskHooks],
    [network, networkHooks],
]