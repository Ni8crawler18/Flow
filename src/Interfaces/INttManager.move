module NttManager {
    use 0x1::Signer;
    use 0x1::Vector;
    use 0x1::Errors;

    struct NttManager has key {
        mode: u8, // LOCKING = 0, BURNING = 1
        token: address,
        chain_id: u16,
        threshold: u8,
        transceivers: vector<address>,
        attestations: vector<AttestationInfo>,
        sequence: u64,
        peers: vector<NttManagerPeer>,
        outbound_limit: u64,
        inbound_limits: vector<(u16, u64)>, // (chain_id, limit)
    }

    struct AttestationInfo {
        executed: bool,
        attested_transceivers: u64,
    }

    struct NttManagerPeer {
        peer_address: vector<u8>,
        token_decimals: u8,
    }

    const LOCKING: u8 = 0;
    const BURNING: u8 = 1;

    const TRANSFER_AMOUNT_HAS_DUST: u64 = 0;
    const INVALID_MODE: u64 = 1;
    const INVALID_TARGET_CHAIN: u64 = 2;
    const ZERO_AMOUNT: u64 = 3;
    const INVALID_RECIPIENT: u64 = 4;
    const INVALID_REFUND_ADDRESS: u64 = 5;
    const BURN_AMOUNT_DIFFERENT_THAN_BALANCE_DIFF: u64 = 6;
    const UNEXPECTED_DEPLOYER: u64 = 7;
    const INVALID_PEER: u64 = 8;
    const INVALID_PEER_CHAIN_ID_ZERO: u64 = 9;
    const INVALID_PEER_ZERO_ADDRESS: u64 = 10;
    const INVALID_PEER_DECIMALS: u64 = 11;
    const STATICCALL_FAILED: u64 = 12;
    const CANCELLER_NOT_SENDER: u64 = 13;
    const UNEXPECTED_MSG_VALUE: u64 = 14;
    const INVALID_PEER_SAME_CHAIN_ID: u64 = 15;

    public fun new(token: address, chain_id: u16, signer: &signer): NttManager {
        NttManager {
            mode: LOCKING,
            token,
            chain_id,
            threshold: 1,
            transceivers: Vector::empty(),
            attestations: Vector::empty(),
            sequence: 0,
            peers: Vector::empty(),
            outbound_limit: 0,
            inbound_limits: Vector::empty(),
        }
    }

    public entry fun transfer(
        ntt_manager: &mut NttManager,
        amount: u64,
        recipient_chain: u16,
        recipient: vector<u8>,
        refund_address: vector<u8>,
        should_queue: bool,
        encoded_instructions: vector<u8>,
        signer: &signer
    ): u64 acquires NttManager {
        // Implement transfer logic
        0
    }

    public entry fun complete_outbound_queued_transfer(
        ntt_manager: &mut NttManager,
        queue_sequence: u64,
    ): u64 acquires NttManager {
        // Implement complete outbound queued transfer logic
        0
    }

    public entry fun cancel_outbound_queued_transfer(
        ntt_manager: &mut NttManager,
        queue_sequence: u64,
        signer: &signer
    ) acquires NttManager {
        // Implement cancel outbound queued transfer logic
    }

    public entry fun complete_inbound_queued_transfer(
        ntt_manager: &mut NttManager,
        digest: vector<u8>
    ) acquires NttManager {
        // Implement complete inbound queued transfer logic
    }

    public entry fun attestation_received(
        ntt_manager: &mut NttManager,
        source_chain_id: u16,
        source_ntt_manager_address: vector<u8>,
        payload: NttManagerMessage
    ) acquires NttManager {
        // Implement attestation received logic
    }

    public entry fun execute_msg(
        ntt_manager: &mut NttManager,
        source_chain_id: u16,
        source_ntt_manager_address: vector<u8>,
        message: NttManagerMessage
    ) acquires NttManager {
        // Implement execute message logic
    }

    public fun token_decimals(ntt_manager: &NttManager): u8 {
        // Return token decimals
        0
    }

    public fun get_peer(ntt_manager: &NttManager, chain_id: u16): NttManagerPeer {
        // Implement get peer logic
        NttManagerPeer { peer_address: x"", token_decimals: 0 }
    }

    public entry fun set_peer(
        ntt_manager: &mut NttManager,
        peer_chain_id: u16,
        peer_contract: vector<u8>,
        decimals: u8,
        inbound_limit: u64
    ) acquires NttManager {
        // Implement set peer logic
    }

    public entry fun set_outbound_limit(ntt_manager: &mut NttManager, limit: u64) acquires NttManager {
        ntt_manager.outbound_limit = limit;
    }

    public entry fun set_inbound_limit(
        ntt_manager: &mut NttManager,
        limit: u64,
        chain_id: u16
    ) acquires NttManager {
        // Implement set inbound limit logic
    }
}

struct NttManagerMessage {
    sequence: u64,
    msg_type: u8, // Transfer = 0, AttestedMessage = 1
    transfer: Option<TransferMessage>,
    attested_message: Option<AttestedMessage>,
}

struct TransferMessage {
    amount: u64,
    sender: vector<u8>,
    recipient: vector<u8>,
    refund_address: vector<u8>,
}

struct AttestedMessage {
    attestations: u64,
    digest: vector<u8>,
}