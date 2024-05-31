module WormholeTransceiverState {
    use 0x1::Event;

    struct RelayingInfoEvent has drop {
        relaying_type: u8,
        refund_address: vector<u8>,
        delivery_payment: u64,
    }

    struct SetWormholePeerEvent has drop {
        chain_id: u16,
        peer_contract: vector<u8>,
    }

    struct SetIsWormholeRelayingEnabledEvent has drop {
        chain_id: u16,
        is_relaying_enabled: bool,
    }

    struct SetIsSpecialRelayingEnabledEvent has drop {
        chain_id: u16,
        is_relaying_enabled: bool,
    }

    struct SetIsWormholeEvmChainEvent has drop {
        chain_id: u16,
        is_evm: bool,
    }

    const UNEXPECTED_ADDITIONAL_MESSAGES: u64 = 0;
    const INVALID_VAA: u64 = 1;
    const PEER_ALREADY_SET: u64 = 2;
    const INVALID_WORMHOLE_PEER_ZERO_ADDRESS: u64 = 3;
    const INVALID_WORMHOLE_CHAIN_ID_ZERO: u64 = 4;
    const CALLER_NOT_RELAYER: u64 = 5;

    public fun get_wormhole_peer(chain_id: u16): vector<u8> {
        // Implement logic to get Wormhole peer
        x""
    }

    public fun is_vaa_consumed(hash: vector<u8>): bool {
        // Implement logic to check if VAA is consumed
        false
    }

    public fun is_wormhole_relaying_enabled(chain_id: u16): bool {
        // Implement logic to check if Wormhole relaying is enabled
        false
    }

    public fun is_special_relaying_enabled(chain_id: u16): bool {
        // Implement logic to check if special relaying is enabled
        false
    }

    public fun is_wormhole_evm_chain(chain_id: u16): bool {
        // Implement logic to check if chain is EVM compatible
        false
    }

    public entry fun set_wormhole_peer(chain_id: u16, peer_contract: vector<u8>) acquires WormholeTransceiverState {
        // Implement logic to set Wormhole peer
    }

    public entry fun set_is_wormhole_evm_chain(chain_id: u16, is_evm: bool) acquires WormholeTransceiverState {
        // Implement logic to set if chain is EVM compatible
    }

    public entry fun set_is_wormhole_relaying_enabled(chain_id: u16, is_relaying_enabled: bool) acquires WormholeTransceiverState {
        // Implement logic to set if Wormhole relaying is enabled
    }

    public entry fun set_is_special_relaying_enabled(chain_id: u16, is_relaying_enabled: bool) acquires WormholeTransceiverState {
        // Implement logic to set if special relaying is enabled
    }
}