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
    }

    struct AttestationInfo {
        executed: bool,
        attested_transceivers: u64,
    }

    const LOCKING: u8 = 0;
    const BURNING: u8 = 1;

    const NO_ENABLED_TRANSCEIVERS: u64 = 0;
    const ZERO_THRESHOLD: u64 = 1;
    const THRESHOLD_TOO_HIGH: u64 = 2;
    const TRANSCEIVER_ALREADY_ATTESTED: u64 = 3;
    const MESSAGE_NOT_APPROVED: u64 = 4;
    const PEER_NOT_REGISTERED: u64 = 5;

    public fun new(token: address, chain_id: u16, signer: &signer): NttManager {
        NttManager {
            mode: LOCKING,
            token,
            chain_id,
            threshold: 1,
            transceivers: Vector::empty(),
            attestations: Vector::empty(),
            sequence: 0,
        }
    }

    public fun get_mode(ntt_manager: &NttManager): u8 {
        ntt_manager.mode
    }

    public fun get_threshold(ntt_manager: &NttManager): u8 {
        ntt_manager.threshold
    }

    public fun transceiver_attested_to_message(ntt_manager: &NttManager, digest: vector<u8>, index: u8): bool {
        let attestation_info = Vector::borrow(&ntt_manager.attestations, index);
        (attestation_info.attested_transceivers & (1 << index)) != 0
    }

    public fun message_attestations(ntt_manager: &NttManager, digest: vector<u8>): u8 {
        let attestation_info = Vector::borrow(&ntt_manager.attestations, digest);
        attestation_info.attested_transceivers.leading_zeros()
    }

    public fun token(ntt_manager: &NttManager): address {
        ntt_manager.token
    }

    public fun chain_id(ntt_manager: &NttManager): u16 {
        ntt_manager.chain_id
    }

    public fun next_message_sequence(ntt_manager: &NttManager): u64 {
        ntt_manager.sequence
    }

    public entry fun set_threshold(ntt_manager: &mut NttManager, threshold: u8) acquires NttManager {
        assert!(threshold != 0, Errors::invalid_argument(ZERO_THRESHOLD));
        assert!(threshold <= Vector::length(&ntt_manager.transceivers), Errors::invalid_argument(THRESHOLD_TOO_HIGH));
        ntt_manager.threshold = threshold;
        emit ThresholdChanged(ntt_manager.threshold, threshold);
    }

    public entry fun set_transceiver(ntt_manager: &mut NttManager, transceiver: address) acquires NttManager {
        Vector::push_back(&mut ntt_manager.transceivers, transceiver);
        emit TransceiverAdded(transceiver, Vector::length(&ntt_manager.transceivers), ntt_manager.threshold);
    }

    public entry fun remove_transceiver(ntt_manager: &mut NttManager, transceiver: address) acquires NttManager {
        let index = Vector::remove(&mut ntt_manager.transceivers, &transceiver);
        emit TransceiverRemoved(transceiver, ntt_manager.threshold);
    }

    public fun is_message_approved(ntt_manager: &NttManager, digest: vector<u8>): bool {
        let attestation_info = Vector::borrow(&ntt_manager.attestations, digest);
        let attested_transceivers = attestation_info.attested_transceivers;
        let threshold = ntt_manager.threshold;
        let attested_count = attested_transceivers.leading_zeros();
        attested_count >= threshold
    }

    public fun is_message_executed(ntt_manager: &NttManager, digest: vector<u8>): bool {
        let attestation_info = Vector::borrow(&ntt_manager.attestations, digest);
        attestation_info.executed
    }

    public entry fun quote_delivery_price(ntt_manager: &NttManager, recipient_chain: u16, transceiver_instructions: vector<u8>): (vector<u256>, u256) {
        // Implement quoting logic
        let prices = Vector::empty();
        let total_price = 0;
        (prices, total_price)
    }

    // Additional functions for attesting, executing messages, and other functionality would be implemented here
}