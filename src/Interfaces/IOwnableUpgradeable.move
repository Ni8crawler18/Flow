module OwnableUpgradeable {
    struct OwnableUpgradeable has key {
        owner: address,
    }

    public fun owner(ownable: &OwnableUpgradeable): address {
        ownable.owner
    }
}