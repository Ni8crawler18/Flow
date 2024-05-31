module SpecialRelayer {
    public fun quote_delivery_price(
        source_contract: address,
        target_chain: u16,
        additional_value: u64,
    ): u64 {
        // Implement logic to quote delivery price
        0
    }

    public entry fun request_delivery(
        source_contract: address,
        target_chain: u16,
        additional_value: u64,
        sequence: u64,
    ) {
        // Implement logic to request delivery
    }
}