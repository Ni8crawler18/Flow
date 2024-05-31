module WormholeTransceiver {
    use 0x1::Signer;
    use 0x1::Vector;
    use 0x1::Event;
    use wormhole::WormholeRelayerSDK;
    use wormhole::libraries::BytesParsing;
    use wormhole::interfaces::IWormhole;
    use wormhole::interfaces::IWormholeReceiver;
    use wormhole::interfaces::IWormholeTransceiver;
    use wormhole::interfaces::ISpecialRelayer;
    use wormhole::interfaces::INttManager;
    use transceiver::TransceiverHelpers;
    use transceiver::TransceiverStructs;
    use wormhole::state::WormholeTransceiverState;

    const WORMHOLE_TRANSCEIVER_VERSION: u8 = 1;

    struct WormholeTransceiver has copy, drop {
        ntt_manager: address,
        wormhole_core_bridge: address,
        wormhole_relayer_addr: address,
        special_relayer_addr: address,
        consistency_level: u8,
        gas_limit: u64,
    }

    public fun new(
        account: &signer,
        ntt_manager: address,
        wormhole_core_bridge: address,
        wormhole_relayer_addr: address,
        special_relayer_addr: address,
        consistency_level: u8,
        gas_limit: u64
    ): address {
        let transceiver = WormholeTransceiver {
            ntt_manager,
            wormhole_core_bridge,
            wormhole_relayer_addr,
            special_relayer_addr,
            consistency_level,
            gas_limit,
        };
        move_to(account, transceiver);
        signer::address_of(account)
    }

    public fun receive_message(transceiver: &mut WormholeTransceiver, encoded_message: vector<u8>) {
        let (source_chain_id, payload) = verify_message(transceiver, &encoded_message);

        let (parsed_transceiver_message, parsed_ntt_manager_message) = TransceiverStructs::parse_transceiver_and_ntt_manager_message(
            TransceiverHelpers::WH_TRANSCEIVER_PAYLOAD_PREFIX, &payload
        );

        deliver_to_ntt_manager(
            transceiver,
            source_chain_id,
            parsed_transceiver_message.source_ntt_manager_address,
            parsed_transceiver_message.recipient_ntt_manager_address,
            parsed_ntt_manager_message
        );
    }

    public fun receive_wormhole_messages(
        transceiver: &mut WormholeTransceiver,
        payload: vector<u8>,
        additional_messages: vector<vector<u8>>,
        source_address: vector<u8>,
        source_chain: u16,
        delivery_hash: vector<u8>
    ) {
        let wormhole_peer = get_wormhole_peer(transceiver, source_chain);
        assert!(wormhole_peer == source_address, 1);

        if is_vaa_consumed(transceiver, &delivery_hash) {
            abort 2;
        }
        set_vaa_consumed(transceiver, delivery_hash);

        assert!(Vector::length(&additional_messages) == 0, 3);

        Event::emit_event(transceiver, ReceivedRelayedMessage, delivery_hash, source_chain, source_address);

        let (parsed_transceiver_message, parsed_ntt_manager_message) = TransceiverStructs::parse_transceiver_and_ntt_manager_message(
            TransceiverHelpers::WH_TRANSCEIVER_PAYLOAD_PREFIX, &payload
        );

        deliver_to_ntt_manager(
            transceiver,
            source_chain,
            parsed_transceiver_message.source_ntt_manager_address,
            parsed_transceiver_message.recipient_ntt_manager_address,
            parsed_ntt_manager_message
        );
    }

    public fun parse_wormhole_transceiver_instruction(encoded: vector<u8>): WormholeTransceiverInstruction {
        let instruction = WormholeTransceiverInstruction { should_skip_relayer_send: false };
        if Vector::is_empty(&encoded) {
            return instruction;
        }

        let (should_skip_relayer_send, _) = BytesParsing::as_bool_unchecked(&encoded, 0);
        instruction.should_skip_relayer_send = should_skip_relayer_send;
        encoded.check_length(offset);
        instruction
    }

    public fun encode_wormhole_transceiver_instruction(instruction: WormholeTransceiverInstruction): vector<u8> {
        bcs::to_bytes(&instruction.should_skip_relayer_send)
    }

    public fun quote_delivery_price(
        transceiver: &WormholeTransceiver,
        target_chain: u16,
        instruction: TransceiverStructs::TransceiverInstruction
    ): u64 {
        let we_ins = parse_wormhole_transceiver_instruction(instruction.payload);
        if we_ins.should_skip_relayer_send {
            return wormhole::message_fee();
        }

        if check_invalid_relaying_config(transceiver, target_chain) {
            abort 4;
        }

        if should_relay_via_standard_relaying(transceiver, target_chain) {
            let (cost, _) = wormhole::relayer::quote_evm_delivery_price(target_chain, 0, transceiver.gas_limit);
            return cost;
        } else if is_special_relaying_enabled(transceiver, target_chain) {
            let cost = special_relayer::quote_delivery_price(get_ntt_manager_token(transceiver), target_chain, 0);
            return cost + wormhole::message_fee();
        } else {
            wormhole::message_fee()
        }
    }

    public fun send_message(
        transceiver: &mut WormholeTransceiver,
        recipient_chain: u16,
        delivery_payment: u64,
        caller: address,
        recipient_ntt_manager_address: vector<u8>,
        refund_address: vector<u8>,
        instruction: TransceiverStructs::TransceiverInstruction,
        ntt_manager_message: vector<u8>
    ) {
        let (transceiver_message, encoded_transceiver_payload) = TransceiverStructs::build_and_encode_transceiver_message(
            TransceiverHelpers::WH_TRANSCEIVER_PAYLOAD_PREFIX,
            TransceiverHelpers::to_wormhole_format(caller),
            recipient_ntt_manager_address,
            ntt_manager_message,
            vector::empty<u8>()
        );

        let we_ins = parse_wormhole_transceiver_instruction(instruction.payload);

        if !we_ins.should_skip_relayer_send && should_relay_via_standard_relaying(transceiver, recipient_chain) {
            wormhole_relayer::send_payload_to_evm(
                recipient_chain,
                from_wormhole_format(get_wormhole_peer(transceiver, recipient_chain)),
                encoded_transceiver_payload,
                0,
                transceiver.gas_limit,
                recipient_chain,
                from_wormhole_format(refund_address)
            );
            emit_event(transceiver, RelayingInfo, 1, refund_address, delivery_payment);
        } else if !we_ins.should_skip_relayer_send && is_special_relaying_enabled(transceiver, recipient_chain) {
            let wormhole_fee = wormhole::message_fee();
            let sequence = wormhole::publish_message(0, encoded_transceiver_payload, transceiver.consistency_level);
            special_relayer::request_delivery(
                get_ntt_manager_token(transceiver), recipient_chain, 0, sequence
            );
            emit_event(transceiver, RelayingInfo, 2, vector::empty<u8>(), delivery_payment);
        } else {
            wormhole::publish_message(0, encoded_transceiver_payload, transceiver.consistency_level);
            emit_event(transceiver, RelayingInfo, 3, vector::empty<u8>(), delivery_payment);
        }

        emit_event(transceiver, SendTransceiverMessage, recipient_chain, transceiver_message);
    }

    fun verify_message(transceiver: &WormholeTransceiver, encoded_message: &vector<u8>): (u16, vector<u8>) {
        let (vm, valid, reason) = wormhole::parse_and_verify_vm(encoded_message);
        assert!(valid, 5);

        if !verify_bridge_vm(transceiver, vm) {
            abort 6;
        }

        if is_vaa_consumed(transceiver, vm.hash) {
            abort 7;
        }
        set_vaa_consumed(transceiver, vm.hash);
        emit_event(transceiver, ReceivedMessage, vm.hash, vm.emitter_chain_id, vm.emitter_address, vm.sequence);

        (vm.emitter_chain_id, vm.payload)
    }

    fun verify_bridge_vm(transceiver: &WormholeTransceiver, vm: &IWormhole::VM): bool {
        check_fork(WormholeTransceiverState::wormhole_transceiver_evm_chain_id);
        get_wormhole_peer(transceiver, vm.emitter_chain_id) == vm.emitter_address
    }

    fun get_wormhole_peer(transceiver: &WormholeTransceiver, chain_id: u16): vector<u8> {
        // logic to get wormhole peer for the specified chain_id
    }

    fun is_vaa_consumed(transceiver: &WormholeTransceiver, vaa_hash: vector<u8>): bool {
        // logic to check if VAA has been consumed
    }

    fun set_vaa_consumed(transceiver: &mut WormholeTransceiver, vaa_hash: vector<u8>) {
        // logic to set VAA as consumed
    }

    fun emit_event<T>(transceiver: &WormholeTransceiver, event: Event, data: T) {
        // logic to emit events
    }

    fun check_invalid_relaying_config(transceiver: &WormholeTransceiver, target_chain: u16): bool {
        // logic to check invalid relaying configuration
    }

    fun should_relay_via_standard_relaying(transceiver: &WormholeTransceiver, target_chain: u16): bool {
        // logic to check if standard relaying should be used
    }

    fun is_special_relaying_enabled(transceiver: &WormholeTransceiver, target_chain: u16): bool {
        // logic to check if special relaying is enabled
    }

    fun get_ntt_manager_token(transceiver: &WormholeTransceiver): vector<u8> {
        // logic to get NTT manager token
    }

    fun deliver_to_ntt_manager(
        transceiver: &WormholeTransceiver,
        source_chain_id: u16,
        source_ntt_manager_address: vector<u8>,
        recipient_ntt_manager_address: vector<u8>,
        parsed_ntt_manager_message: TransceiverStructs::NttManagerMessage
    ) {
        // logic to deliver message to NTT manager
    }

    // Additional helper functions and structures as needed
}
