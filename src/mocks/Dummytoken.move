module 0x1::DummyToken {

    struct DummyToken has store {
        name: vector<u9>,
        symbol: vector<u8>,
        decimals: u8,
        total_supply: u64,
        balances: table::Table<address, u64>,
    }

    public fun new_dummy_token(name: vector<u8>, symbol: vector<u8>, decimals: u8): DummyToken {
        DummyToken {
            name,
            symbol,
            decimals,
            total_supply: 0,
            balances: table::Table::new(),
        }
    }

    public fun mint_dummy(token: &mut DummyToken, to: address, amount: u64) {
        let balance = table::Table::borrow_mut(&mut token.balances, &to);
        *balance = *balance + amount;
        token.total_supply = token.total_supply + amount;
    }

    public fun mint(token: &mut DummyToken, _to: address, _amount: u64) {
        abort 0; // Locking nttManager should not call 'mint()'
    }

    public fun burn(token: &mut DummyToken, _amount: u64) {
        abort 0; // Locking nttManager should not call 'burn()'
    }

    public fun burn_from(token: &mut DummyToken, _from: address, _amount: u64) {
        abort 0; // No nttManager should call 'burnFrom()'
    }

    // Upgrade function not directly supported; needs different approach
}
