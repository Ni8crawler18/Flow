module TransceiverRegistry {
    use 0x1::Signer;
    use 0x1::Errors;
    use 0x1::Vector;
    use 0x1::Map;

    const MAX_TRANSCEIVERS: u8 = 64;

    struct TransceiverInfo has copy, drop, store {
        registered: bool,
        enabled: bool,
        index: u8,
    }

    struct EnabledTransceiverBitmap has copy, drop, store {
        bitmap: u64,
    }

    struct NumTransceivers has copy, drop, store {
        registered: u8,
        enabled: u8,
    }

    struct TransceiverRegistry has key {
        transceiver_infos: Map<address, TransceiverInfo>,
        enabled_transceivers: vector<address>,
        registered_transceivers: vector<address>,
        enabled_transceiver_bitmap: EnabledTransceiverBitmap,
        num_transceivers: NumTransceivers,
    }

    public fun initialize(owner: &signer) {
        let transceiver_registry = TransceiverRegistry {
            transceiver_infos: Map::empty<address, TransceiverInfo>(),
            enabled_transceivers: Vector::empty<address>(),
            registered_transceivers: Vector::empty<address>(),
            enabled_transceiver_bitmap: EnabledTransceiverBitmap { bitmap: 0 },
            num_transceivers: NumTransceivers { registered: 0, enabled: 0 },
        };
        move_to(owner, transceiver_registry);
    }

    public fun set_transceiver(
        registry: &mut TransceiverRegistry,
        transceiver: address
    ) acquires Errors::INVALID_ARGUMENT, Errors::LIMIT_EXCEEDED {
        if (transceiver == 0) {
            abort Errors::INVALID_ARGUMENT;
        }

        let mut transceiver_infos = &mut registry.transceiver_infos;
        let mut enabled_transceiver_bitmap = &mut registry.enabled_transceiver_bitmap;
        let mut enabled_transceivers = &mut registry.enabled_transceivers;
        let mut num_transceivers = &mut registry.num_transceivers;

        if (Map::contains_key(&transceiver_infos, transceiver)) {
            let mut info = Map::borrow_mut(&mut transceiver_infos, transceiver);
            if (info.enabled) {
                abort Errors::LIMIT_EXCEEDED;
            }
            info.enabled = true;
        } else {
            if (num_transceivers.registered >= MAX_TRANSCEIVERS) {
                abort Errors::LIMIT_EXCEEDED;
            }
            let index = num_transceivers.registered;
            let info = TransceiverInfo {
                registered: true,
                enabled: true,
                index,
            };
            Map::insert(&mut transceiver_infos, transceiver, info);
            Vector::push_back(&mut registry.registered_transceivers, transceiver);
            num_transceivers.registered += 1;
        }

        Vector::push_back(&mut enabled_transceivers, transceiver);
        num_transceivers.enabled += 1;
        let index = Map::borrow(&transceiver_infos, transceiver).index;
        enabled_transceiver_bitmap.bitmap |= 1 << index;

        check_transceivers_invariants(registry);
    }

    public fun remove_transceiver(
        registry: &mut TransceiverRegistry,
        transceiver: address
    ) acquires Errors::INVALID_ARGUMENT, Errors::PERMISSION_DENIED {
        if (transceiver == 0) {
            abort Errors::INVALID_ARGUMENT;
        }

        let mut transceiver_infos = &mut registry.transceiver_infos;
        let mut enabled_transceiver_bitmap = &mut registry.enabled_transceiver_bitmap;
        let mut enabled_transceivers = &mut registry.enabled_transceivers;
        let mut num_transceivers = &mut registry.num_transceivers;

        if (!Map::contains_key(&transceiver_infos, transceiver)) {
            abort Errors::PERMISSION_DENIED;
        }

        let mut info = Map::borrow_mut(&mut transceiver_infos, transceiver);
        if (!info.enabled) {
            abort Errors::PERMISSION_DENIED;
        }

        info.enabled = false;
        num_transceivers.enabled -= 1;
        let index = info.index;
        enabled_transceiver_bitmap.bitmap &= !(1 << index);

        let len = Vector::length(&enabled_transceivers);
        for (i in 0..len) {
            if (Vector::borrow(&enabled_transceivers, i) == transceiver) {
                Vector::swap_remove(&mut enabled_transceivers, i);
                break;
            }
        }

        check_transceivers_invariants(registry);
    }

    public fun get_transceivers(registry: &TransceiverRegistry): vector<address> {
        registry.enabled_transceivers
    }

    public fun get_transceiver_info(registry: &TransceiverRegistry): vector<TransceiverInfo> {
        let mut result = Vector::empty<TransceiverInfo>();
        let len = Vector::length(&registry.enabled_transceivers);
        for (i in 0..len) {
            let transceiver = Vector::borrow(&registry.enabled_transceivers, i);
            let info = Map::borrow(&registry.transceiver_infos, *transceiver);
            Vector::push_back(&mut result, *info);
        }
        result
    }

    fun check_transceivers_invariants(registry: &TransceiverRegistry) {
        let num_transceivers = &registry.num_transceivers;
        let enabled_transceivers = &registry.enabled_transceivers;
        let enabled_transceiver_bitmap = &registry.enabled_transceiver_bitmap.bitmap;

        assert(num_transceivers.enabled == Vector::length(&enabled_transceivers));

        for (i in 0..num_transceivers.enabled) {
            let transceiver = Vector::borrow(&enabled_transceivers, i);
            check_transceiver_invariants(registry, *transceiver);
        }

        for (i in 0..num_transceivers.enabled) {
            for (j in (i + 1)..num_transceivers.enabled) {
                assert(Vector::borrow(&enabled_transceivers, i) != Vector::borrow(&enabled_transceivers, j));
            }
        }

        assert(num_transceivers.registered <= MAX_TRANSCEIVERS);
    }

    fun check_transceiver_invariants(registry: &TransceiverRegistry, transceiver: address) {
        let transceiver_infos = &registry.transceiver_infos;
        let enabled_transceiver_bitmap = &registry.enabled_transceiver_bitmap.bitmap;
        let num_transceivers = &registry.num_transceivers;
        let enabled_transceivers = &registry.enabled_transceivers;

        let info = Map::borrow(&transceiver_infos, transceiver);

        assert(info.registered || (!info.enabled && info.index == 0));

        let transceiver_in_enabled_bitmap = (enabled_transceiver_bitmap & (1 << info.index)) != 0;
        let transceiver_enabled = info.enabled;

        let mut transceiver_in_enabled_transceivers = false;
        let len = Vector::length(&enabled_transceivers);
        for (i in 0..len) {
            if (Vector::borrow(&enabled_transceivers, i) == transceiver) {
                transceiver_in_enabled_transceivers = true;
                break;
            }
        }

        assert(transceiver_in_enabled_bitmap == transceiver_enabled);
        assert(transceiver_in_enabled_transceivers == transceiver_enabled);
        assert(info.index < num_transceivers.registered);
    }
}
