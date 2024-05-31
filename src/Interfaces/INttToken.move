module NttToken {
    use 0x1::Errors;

    const CALLER_NOT_MINTER: u64 = 0;
    const INVALID_MINTER_ZERO_ADDRESS: u64 = 1;
    const INSUFFICIENT_BALANCE: u64 = 2;

    struct NttToken has key {
        minter: address,
        total_supply: u64,
        balances: vector<(address, u64)>, // (address, balance)
    }

    struct NewMinterEvent has copy, drop {
        previous_minter: address,
        new_minter: address,
    }

    public fun mint(token: &mut NttToken, account: address, amount: u64) {
        assert!(token.minter == @ntt_token, Errors::requires_address(CALLER_NOT_MINTER));
        let balance_ref = vector::borrow_mut(&mut token.balances, account);
        *balance_ref = *balance_ref + amount;
        token.total_supply = token.total_supply + amount;
    }

    public entry fun set_minter(token: &mut NttToken, new_minter: address, signer: &signer) acquires NttToken {
        assert!(token.minter == @ntt_token, Errors::requires_address(CALLER_NOT_MINTER));
        assert!(new_minter != @0x0, Errors::invalid_argument(INVALID_MINTER_ZERO_ADDRESS));
        let previous_minter = token.minter;
        token.minter = new_minter;
        emit NewMinterEvent { previous_minter, new_minter };
    }

    public entry fun burn(token: &mut NttToken, amount: u64, signer: &signer) acquires NttToken {
        let sender = signer::address_of(signer);
        let balance_ref = vector::borrow_mut(&mut token.balances, sender);
        assert!(*balance_ref >= amount, Errors::invalid_argument(INSUFFICIENT_BALANCE));
        *balance_ref = *balance_ref - amount;
        token.total_supply = token.total_supply - amount;
    }

    // Additional functions for querying balances, total supply, etc. can be added here
}