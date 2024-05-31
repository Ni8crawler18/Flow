### Flow - Standard NTT Implementation using Wormhole Attestionson the Sui Blockchain

## Overview

This document provides a guide for implementing and managing a Non-Fungible Token Transfer (NTT) system on the Sui blockchain using the Move programming language. The system enables secure, cross-chain token transfers leveraging a decentralized protocol for verifiable attestations. The implementation comprises smart contracts for minting, locking, and burning tokens, integrated with a decentralized network to facilitate seamless interoperability between different blockchain networks.

## Prerequisites

- Install the Sui CLI tools.
- Set up a Sui local network or connect to the Sui testnet/mainnet.

## Installation

To get started, clone the repository and navigate to the project directory:

```sh
git clone https://github.com/Ni8crawler18/Flow
cd src
```

## Build

Run the following command to compile the Move smart contracts:

```sh
sui move build
```

## Test

To run the full test-suite for the Move smart contracts, use the following command:

```sh
sui move test
```

The test-suite includes unit tests and integration tests to ensure the contracts behave as expected.

## Formatting

To format the Move source files, run this command from the root directory:

```sh
sui move format
```

## Contracts

### Transfer Lifecycle

A client initiates an NTT transfer by calling the `transfer` function. The client must specify the amount of the transfer, the recipient chain, and the recipient address on the recipient chain. Optionally, a flag can be set to specify whether the NttManager should queue rate-limited transfers or revert. Transfers are either "locked" or "burned" depending on the mode set in the initial configuration of the NttManager contract. Once the transfer is forwarded to the Transceiver, the NttManager emits the `TransferSent` event.

### Events

#### TransferSent

```move
event TransferSent {
    recipient: address,
    amount: u64,
    fee: u64,
    recipient_chain: u16,
    msg_sequence: u64,
}
```

#### OutboundTransferQueued

```move
event OutboundTransferQueued {
    queue_sequence: u64,
}
```

#### OutboundTransferRateLimited

```move
event OutboundTransferRateLimited {
    sender: address,
    amount: u64,
    current_capacity: u64,
}
```

#### InboundTransferQueued

```move
event InboundTransferQueued {
    digest: vector<u8>,
}
```

#### SendTransceiverMessage

```move
event SendTransceiverMessage {
    recipient_chain: u16,
    message: vector<u8>,
}
```

#### ReceivedRelayedMessage

```move
event ReceivedRelayedMessage {
    digest: vector<u8>,
    emitter_chain_id: u16,
    emitter_address: address,
}
```

#### ReceivedMessage

```move
event ReceivedMessage {
    digest: vector<u8>,
    emitter_chain_id: u16,
    emitter_address: address,
    sequence: u64,
}
```

#### MessageAlreadyExecuted

```move
event MessageAlreadyExecuted {
    source_ntt_manager: address,
    msg_hash: vector<u8>,
}
```

#### TransferRedeemed

```move
event TransferRedeemed {
    digest: vector<u8>,
}
```

## Usage

### Environment Setup

Set up the environment configuration for each blockchain network where the NttManager and Transceiver contracts will be deployed. Create an environment file for each target network (e.g., testnet or mainnet).

```sh
mkdir env/testnet
cp env/.env.sample env/testnet/sui.env
```

Configure each `.env` file with the appropriate RPC variables and other settings.

### Config Setup

Navigate to the configuration directory and copy the sample file:

```sh
cd cfg
cp NttConfig.json.sample NttConfig.json
```

Modify `NttConfig.json` to suit your configuration needs, including adding/removing networks and setting up contract addresses.

### Deployment

Deploy the NttManager and Transceiver contracts to each target network using the deployment script:

```sh
bash sh/deploy_ntt.sh -n NETWORK_TYPE -c CHAIN_NAME -k PRIVATE_KEY
# Argument examples
# -n testnet, mainnet
# -c sui
```

Save the deployed contract addresses in the `NttConfig.json` file.

### Configuration

After deploying the contracts, configure each target network using the configuration script:

```sh
bash sh/configure_ntt.sh -n NETWORK_TYPE -c CHAIN_NAME -k PRIVATE_KEY
# Argument examples
# -n testnet, mainnet
# -c sui
```

### Additional Notes

- Tokens powered by NTT in burn mode require the `burn` method. Ensure that the `burn` method is implemented in your token contract.
- The `mint` and `set_minter` methods found in the INttToken Interface are required for NTT tokens and must be present in the token contract implementation.

## Example

Here is an example of a simple token contract with minting and burning capabilities:

```move
module 0x1::ExampleToken {
    use 0x1::Signer;
    use 0x1::Vector;
    use 0x1::Table;

    struct Token has store {
        supply: u64,
        balances: Table::Table<address, u64>,
    }

    public fun mint(signer: &signer, to: address, amount: u64) {
        let token = borrow_global_mut<Token>(Signer::address_of(signer));
        let balance = Table::borrow_mut(&mut token.balances, &to);
        *balance = *balance + amount;
        token.supply = token.supply + amount;
    }

    public fun burn(signer: &signer, amount: u64) {
        let token = borrow_global_mut<Token>(Signer::address_of(signer));
        let sender = Signer::address_of(signer);
        let balance = Table::borrow_mut(&mut token.balances, &sender);
        assert!(*balance >= amount, 1);
        *balance = *balance - amount;
        token.supply = token.supply - amount;
    }
}
```

## Help

For more information and help with the Sui CLI tools, use the following commands:

```sh
sui --help
sui move --help
```

## Conclusion

This guide provides a comprehensive overview of setting up and managing a Non-Fungible Token Transfer system on the Sui blockchain using Move. Follow the steps carefully to ensure proper configuration and deployment of your contracts.
