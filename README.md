# GOEMON

GOEMON is an Intent-Based Options Liquidity Layer. We unify options liquidity from CEXs, DEXs, and MMs, providing seamless access to advanced strategies with just a few clicks. We leverage intents for frictionless cross-chain execution.

## License

This project is licensed under the Business Source License 1.1. See the [LICENSE](./LICENSE) file for details.

## Getting Started

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [Node.js](https://nodejs.org/) (for running scripts)

### Installation

1. Clone the repository:

   ```shell
   git clone https://github.com/Goemon-xyz/core-contracts.git
   cd core-contracts
   ```

2. Install dependencies:
   ```shell
   forge install
   ```

## Usage

### Build

```shell
forge build
```

### Test

```shell
forge test -vvv --fork-url <RPC_URL> --decode-internal
```

### Deploy

```shell
forge script script/DeployMainnet.s.sol:DeployUserManager --rpc-url <RPC-URL> --etherscan-api-key <ETHERSCAN-API-KEY> --broadcast --verify -vvvv
```

```shell
forge script script/DeployTestnet.s.sol:DeployUserManager --rpc-url <RPC-URL> --etherscan-api-key <ETHERSCAN-API-KEY> --broadcast --verify -vvvv
```

### Upgrade

```shell
forge script script/Upgrade.s.sol:UpgradeContract --rpc-url <RPC-URL> --etherscan-api-key <ETHERSCAN-API-KEY> --broadcast --verify -vvvv
```

## Deployed Contracts

### Mainnet

- Ethereum: [0x01D75243e0f7d3145E985acC1D4007968A45B08e](https://etherscan.io/address/0x01D75243e0f7d3145E985acC1D4007968A45B08e)
- Arbitrum: [0xb7a73b686578a2994b65a57023784be1304cead1](https://arbiscan.io/address/0xb7a73b686578a2994b65a57023784be1304cead1)
- Base: [0xa1ea1c86d5f0297ae24d87dfb4914c4bc82c8122](https://basescan.org/address/0xa1ea1c86d5f0297ae24d87dfb4914c4bc82c8122)

### Testnet

- Sepolia: [0x46a3a1c66dcaefe42045d3d16d391689b9f68812](https://sepolia.etherscan.io/address/0x46a3a1c66dcaefe42045d3d16d391689b9f68812)
- Arbitrum Sepolia: [0x93247c6c8af6bd15b2d829ee6e86599a91f74ef7](https://sepolia.arbiscan.io/address/0x93247c6c8af6bd15b2d829ee6e86599a91f74ef7)
- Base Sepolia: [0x9cA62a3326f74192b5974fC43f5ca472BA90460E](https://sepolia.basescan.org/address/0x9cA62a3326f74192b5974fC43f5ca472BA90460E)

## Foundry

This project uses Foundry, a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.

- [Foundry Book](https://book.getfoundry.sh/)
- [Foundry GitHub](https://github.com/foundry-rs/foundry)

## Contact

- Twitter: [@goemon_xyz](https://x.com/goemon_xyz)
- GitHub: [https://github.com/Goemon-xyz](https://github.com/Goemon-xyz)
