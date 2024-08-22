# Goldsand staking contract

Goldsand is a project by [InshAllah Network](https://inshallah.network), aiming to enable access to staking for 2B+ users in MENA & SEA (primarily Muslim). Goldsand is a halal, shar'ia-compliant staking service that allows users to earn yield by staking their ETH with our specialized validators. Our validators filter out non-compliant transactions, ensuring that the yield earned through our staking service is halal.

Goldsand is built as a set of contracts. The main Goldsand contract:

1. serves as an access point for users to use the Goldsand protocol
2. orchestrates the launch of Goldsand validators 
3. collects staking rewards 
4. processes user withdrawal requests

## Local development

The repository is based on the Forge development framework for Ethereum. More information about forge is available here: [https://book.getfoundry.sh](https://book.getfoundry.sh).

### Build contract locally

```bash
$ forge build
```

### Run unit tests

```bash
$ forge test
```

## Security Audit

The Goldsand contract has been authored and reviewed by experienced solidity engineers. A security audit was conducted by Spearbit Labs Cantina (the same auditors of Coinbase, Uniswap, and others) in August. The audit report will soon be made available in the repository.

## License

The smart contract code in this repository is licensed under GPL-3.0, excluding a small number of files licensed under CC0-1.0. Each file's license is available at the top of the file and clearly marked. Please see the included [`LICENSE`](./LICENSE) file for more information.

## Responsible disclosure of vulnerabilities

Security is taken seriously at InshAllah Network and we value the community's efforts in identifying potential vulnerabilities. If you come across any security issues or vulnerabilities within our smart contracts, we ask that you disclose them responsibly. Please reach out directly to our security team at [security@inshallah.network](mailto:security@inshallah.network). Your diligence in safeguarding our platform is greatly appreciated, and we are committed to addressing any reported issues promptly and transparently.

<p>&copy; 2024 InshAllah Network</p>
