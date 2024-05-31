module RateLimiterEvents {
    use 0x1::Event;

    struct InboundTransferQueuedEvent has drop {
        digest: vector<u8>,
    }

    struct OutboundTransferQueuedEvent has drop {
        queue_sequence: u64,
    }

    struct OutboundTransferRateLimitedEvent has drop {
        sender: address,
        sequence: u64,
        amount: u64,
        current_capacity: u64,
    }

    public fun emit_inbound_transfer_queued_event(
        digest: vector<u8>,
        event_handle: &mut Event::EventHandle<InboundTransferQueuedEvent>,
    ) {
        Event::emit_event(
            event_handle,
            InboundTransferQueuedEvent {
                digest,
            },
        );
    }

    public fun emit_outbound_transfer_queued_event(
        queue_sequence: u64,
        event_handle: &mut Event::EventHandle<OutboundTransferQueuedEvent>,
    ) {
        Event::emit_event(
            event_handle,
            OutboundTransferQueuedEvent {
                queue_sequence,
            },
        );
    }

    public fun emit_outbound_transfer_rate_limited_event(
        sender: address,
        sequence: u64,
        amount: u64,
        current_capacity: u64,
        event_handle: &mut Event::EventHandle<OutboundTransferRateLimitedEvent>,
    ) {
        Event::emit_event(
            event_handle,
            OutboundTransferRateLimitedEvent {
                sender,
                sequence,
                amount,
                current_capacity,
            },
        );
    }
}