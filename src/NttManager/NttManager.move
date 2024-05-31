module NttManager {
    use 0x1::Signer;
    use 0x1::Event;
    use 0x1::Token;
    use 0x1::Account;
    use 0x1::Vector;
    use 0x1::Errors;
    use 0x1::Map;

    const LOCKING: u8 = 0;
    const BURNING: u8 = 1;

    struct NttManager has key {
        owner: address,
        token: Token.T,
        mode: u8,
        chain_id: u16,
        rate_limit_duration: u64,
        skip_rate_limiting: bool,
        peers: Map<u16, Peer>,
        outbound_limit: u64,
        inbound_limits: Map<u16, u64>,
        outbound_consumed: u64,
        inbound_consumed: Map<u16, u64>,
        outbound_queue: Map<u64, OutboundQueuedTransfer>,
        inbound_queue: Map<vector<u8>, InboundQueuedTransfer>,
    }

    struct Peer has copy, store {
        address: vector<u8>,
        token_decimals: u8,
    }

    struct OutboundQueuedTransfer has copy, store {
        sender: address,
        amount: u64,
        recipient_chain: u16,
        recipient: vector<u8>,
        refund_address: vector<u8>,
        timestamp: u64,
    }

    struct InboundQueuedTransfer has copy, store {
        recipient: address,
        amount: u64,
        timestamp: u64,
    }

    struct TransferEvent has copy, drop, store {
        from: address,
        to: vector<u8>,
        amount: u64,
        chain_id: u16,
    }

    public fun initialize(
        owner: &signer,
        token: Token.T,
        mode: u8,
        chain_id: u16,
        rate_limit_duration: u64,
        skip_rate_limiting: bool
    ) {
        let owner_address = Signer::address_of(owner);
        let ntt_manager = NttManager {
            owner: owner_address,
            token,
            mode,
            chain_id,
            rate_limit_duration,
            skip_rate_limiting,
            peers: Map::empty<u16, Peer>(),
            outbound_limit: 0,
            inbound_limits: Map::empty<u16, u64>(),
            outbound_consumed: 0,
            inbound_consumed: Map::empty<u16, u64>(),
            outbound_queue: Map::empty<u64, OutboundQueuedTransfer>(),
            inbound_queue: Map::empty<vector<u8>, InboundQueuedTransfer>(),
        };
        move_to(owner, ntt_manager);
    }

    public fun set_peer(
        manager: &mut NttManager,
        peer_chain_id: u16,
        peer_address: vector<u8>,
        decimals: u8,
        inbound_limit: u64
    ) {
        if (peer_chain_id == 0 || Vector::length(&peer_address) == 0 || decimals == 0) {
            abort Errors::INVALID_ARGUMENT;
        }
        let peer = Peer {
            address: peer_address,
            token_decimals: decimals,
        };
        Map::insert(&mut manager.peers, peer_chain_id, peer);
        Map::insert(&mut manager.inbound_limits, peer_chain_id, inbound_limit);
    }

    public fun set_outbound_limit(manager: &mut NttManager, limit: u64) {
        manager.outbound_limit = limit;
    }

    public fun set_inbound_limit(manager: &mut NttManager, chain_id: u16, limit: u64) {
        Map::insert(&mut manager.inbound_limits, chain_id, limit);
    }

    public fun transfer(
        manager: &mut NttManager,
        amount: u64,
        recipient_chain: u16,
        recipient: vector<u8>,
        refund_address: vector<u8>,
        should_queue: bool
    ) {
        if (amount == 0 || Vector::length(&recipient) == 0 || Vector::length(&refund_address) == 0) {
            abort Errors::INVALID_ARGUMENT;
        }

        let balance_before = Token::balance_of(&manager.token, &manager.owner);
        Token::transfer_from(&manager.token, &manager.owner, &manager.owner, amount);
        let balance_after = Token::balance_of(&manager.token, &manager.owner);
        let actual_amount = balance_after - balance_before;

        if (manager.mode == BURNING) {
            Token::burn(&manager.token, actual_amount);
        }

        let mut remaining_amount = actual_amount;
        let current_time = move_to(current_time());

        if (manager.skip_rate_limiting == false) {
            if (manager.outbound_consumed + actual_amount > manager.outbound_limit) {
                if (should_queue) {
                    let queue_entry = OutboundQueuedTransfer {
                        sender: manager.owner,
                        amount: actual_amount,
                        recipient_chain,
                        recipient,
                        refund_address,
                        timestamp: current_time,
                    };
                    Map::insert(&mut manager.outbound_queue, current_time, queue_entry);
                    return;
                } else {
                    abort Errors::LIMIT_EXCEEDED;
                }
            }
            manager.outbound_consumed += actual_amount;
        }

        Event::emit_event(&manager.owner, TransferEvent {
            from: manager.owner,
            to: recipient,
            amount: actual_amount,
            chain_id: recipient_chain,
        });

        let outbound_peer = Map::get(&manager.peers, recipient_chain);
        let inbound_limit = Map::get(&manager.inbound_limits, recipient_chain);
        if (manager.inbound_consumed + actual_amount > inbound_limit) {
            if (should_queue) {
                let inbound_queue_entry = InboundQueuedTransfer {
                    recipient: Account::address_of(),
                    amount: actual_amount,
                    timestamp: current_time,
                };
                Map::insert(&mut manager.inbound_queue, current_time, inbound_queue_entry);
                return;
            } else {
                abort Errors::LIMIT_EXCEEDED;
            }
        }

        manager.inbound_consumed += actual_amount;
        if (manager.mode == LOCKING) {
            Token::transfer(&manager.token, &manager.owner, &Account::address_of(), actual_amount);
        } else if (manager.mode == BURNING) {
            Token::mint(&manager.token, &Account::address_of(), actual_amount);
        }
    }

    public fun complete_inbound_queued_transfer(manager: &mut NttManager, digest: vector<u8>) {
        let queued_transfer = Map::get(&manager.inbound_queue, digest);
        if (queued_transfer.timestamp == 0) {
            abort Errors::NOT_FOUND;
        }

        let current_time = move_to(current_time());
        if (current_time - queued_transfer.timestamp < manager.rate_limit_duration) {
            abort Errors::LIMIT_EXCEEDED;
        }

        manager.inbound_consumed -= queued_transfer.amount;
        Map::remove(&mut manager.inbound_queue, digest);

        if (manager.mode == LOCKING) {
            Token::transfer(&manager.token, &manager.owner, &queued_transfer.recipient, queued_transfer.amount);
        } else if (manager.mode == BURNING) {
            Token::mint(&manager.token, &queued_transfer.recipient, queued_transfer.amount);
        }
    }

    public fun complete_outbound_queued_transfer(manager: &mut NttManager, sequence: u64) {
        let queued_transfer = Map::get(&manager.outbound_queue, sequence);
        if (queued_transfer.timestamp == 0) {
            abort Errors::NOT_FOUND;
        }

        let current_time = move_to(current_time());
        if (current_time - queued_transfer.timestamp < manager.rate_limit_duration) {
            abort Errors::LIMIT_EXCEEDED;
        }

        manager.outbound_consumed -= queued_transfer.amount;
        Map::remove(&mut manager.outbound_queue, sequence);

        if (manager.mode == LOCKING) {
            Token::transfer(&manager.token, &manager.owner, &queued_transfer.recipient, queued_transfer.amount);
        } else if (manager.mode == BURNING) {
            Token::mint(&manager.token, &queued_transfer.recipient, queued_transfer.amount);
        }
    }

    public fun cancel_outbound_queued_transfer(manager: &mut NttManager, sequence: u64) {
        let queued_transfer = Map::get(&manager.outbound_queue, sequence);
        if (queued_transfer.sender != manager.owner) {
            abort Errors::PERMISSION_DENIED;
        }

        Map::remove(&mut manager.outbound_queue, sequence);

        if (manager.mode == LOCKING) {
            Token::transfer(&manager.token, &manager.owner, &manager.owner, queued_transfer.amount);
        } else if (manager.mode == BURNING) {
            Token::mint(&manager.token, &manager.owner, queued_transfer.amount);
        }
    }

    public fun get_token_decimals(manager: &NttManager): u8 {
        Token::decimals(&manager.token)
    }
}
