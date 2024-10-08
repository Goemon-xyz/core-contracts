# Goemon Project

Goemon is an Intent Centric Options Liquidity Layer with composible strategies. We are the missing agglayer specifically for options that builders can tap onto.

## License

This project is licensed under the Business Source License 1.1. See the [LICENSE](./LICENSE) file for details.

## Getting Started

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [Node.js](https://nodejs.org/) (for running scripts)

### Installation

1. Clone the repository:
   ```shell
   git clone https://github.com/your-username/goemon.git
   cd goemon
   ```

2. Install dependencies:
   ```shell
   forge install
   ```

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test -vvv --fork-url https://rpc.ankr.com/eth --decode-internal  
```

### Deploy

```shell
$ forge script script/DeployGoemon.s.sol:DeployGoemonScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

## Development

[Add any specific instructions for developers working on this project]

## Documentation

For more detailed information about the project, please refer to our [documentation](link-to-your-docs).

## Contributing

Please read [CONTRIBUTING.md](link-to-contributing-guide) for details on our code of conduct and the process for submitting pull requests.

## Foundry

This project uses Foundry, a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.

For more information on using Foundry:

- [Foundry Book](https://book.getfoundry.sh/)
- [Foundry GitHub](https://github.com/foundry-rs/foundry)

## Contact

[Goemon] - [@goemon_xyz](https://x.com/goemon_xyz) 

Project Link: [https://github.com/orgs/Goemon-xyz](https://github.com/orgs/Goemon-xyz)
