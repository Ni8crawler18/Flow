// Governance module for the Diem blockchain

module Governance {
    use 0x1::Signer;
    use 0x1::Vector;
    use 0x1::Wormhole;

    // "GeneralPurposeGovernance" (left padded)
    const MODULE: vector<u8> = x"000000000000000047656E6572616C507572706F7365476F7665726E616E6365";

    /// Governance actions
    const UNDEFINED: u8 = 0;
    const EVM_CALL: u8 = 1;
    const SOLANA_CALL: u8 = 2;

    struct GeneralPurposeGovernanceMessage {
        action: u8,
        chain: u16,
        governance_contract: vector<u8>,
        governed_contract: vector<u8>,
        call_data: vector<u8>,
    }

    struct Governance has key {
        wormhole: Wormhole::Wormhole,
        consumed_governance_actions: vector<vector<u8>>,
    }

    public fun new(wormhole: &Wormhole::Wormhole, signer: &signer): Governance {
        Governance {
            wormhole: wormhole,
            consumed_governance_actions: Vector::empty(),
        }
    }

    public entry fun perform_governance(vaa: vector<u8>, governance: &mut Governance) acquires Governance {
        let verified = verify_governance_vaa(&vaa, &governance.wormhole);
        let message = parse_general_purpose_governance_message(verified.payload);

        assert!(message.action == EVM_CALL, Errors::invalid_action(message.action));
        assert!(message.chain == governance.wormhole.chain_id(), Errors::not_recipient_chain(message.chain));
        assert!(message.governance_contract == to_bytes(signer::address_of(signer)), Errors::not_recipient_contract(message.governance_contract));

        // Execute the call on the governed contract
        // ...

        replay_protect(verified.hash, &mut governance.consumed_governance_actions);
    }

    fun replay_protect(digest: vector<u8>, consumed_governance_actions: &mut vector<vector<u8>>) {
        assert!(!Vector::contains(consumed_governance_actions, &digest), Errors::governance_action_already_consumed(digest));
        Vector::push_back(consumed_governance_actions, digest);
    }

    fun verify_governance_vaa(vaa: &vector<u8>, wormhole: &Wormhole::Wormhole): Wormhole::VM {
        let (vm, valid, reason) = Wormhole::parse_and_verify_vm(wormhole, vaa);
        assert!(valid, reason);

        assert!(vm.emitter_chain_id == wormhole.governance_chain_id(), Errors::invalid_governance_chain_id(vm.emitter_chain_id));
        assert!(vm.emitter_address == wormhole.governance_contract(), Errors::invalid_governance_contract(vm.emitter_address));

        vm
    }

    public fun encode_general_purpose_governance_message(message: &GeneralPurposeGovernanceMessage): vector<u8> {
        let call_data_length = Vector::length(&message.call_data);
        assert!(call_data_length <= 0xFFFF, Errors::payload_too_long(call_data_length));

        let encoded = Vector::empty();
        Vector::append(&mut encoded, MODULE);
        Vector::push_back(&mut encoded, message.action);
        Vector::push_back(&mut encoded, (message.chain as u8));
        Vector::push_back(&mut encoded, (message.chain >> 8 as u8));
        Vector::append(&mut encoded, message.governance_contract);
        Vector::append(&mut encoded, message.governed_contract);
        Vector::push_back(&mut encoded, (call_data_length as u8));
        Vector::push_back(&mut encoded, (call_data_length >> 8 as u8));
        Vector::append(&mut encoded, message.call_data);

        encoded
    }

    public fun parse_general_purpose_governance_message(encoded: vector<u8>): GeneralPurposeGovernanceMessage {
        let offset = 0;

        let module = Vector::slice(&encoded, offset, offset + 32);
        offset = offset + 32;
        assert!(module == MODULE, Errors::invalid_module(module));

        let action = Vector::pop_back(&mut encoded);
        offset = offset + 1;

        let chain = (Vector::pop_back(&mut encoded) as u16) + ((Vector::pop_back(&mut encoded) as u16) << 8);
        offset = offset + 2;

        let governance_contract = Vector::slice(&encoded, offset, offset + 20);
        offset = offset + 20;

        let governed_contract = Vector::slice(&encoded, offset, offset + 20);
        offset = offset + 20;

        let call_data_length = (Vector::pop_back(&mut encoded) as u16) + ((Vector::pop_back(&mut encoded) as u16) << 8);
        offset = offset + 2;

        let call_data = Vector::slice(&encoded, offset, offset + call_data_length);

        GeneralPurposeGovernanceMessage {
            action,
            chain,
            governance_contract,
            governed_contract,
            call_data,
        }
    }
}