#[contract]
mod Upgradeable {
    use starknet::class_hash::ClassHash;
    use zeroable::Zeroable;
    use result::ResultTrait;
    use starknet::SyscallResult;

    struct Storage {
        impl_hash: ClassHash, 
    }

    #[event]
    fn Upgraded(implementation: ClassHash) {}

    #[internal]
    fn upgrade(impl_hash: ClassHash) {
        assert(!impl_hash.is_zero(), 'Class hash cannot be zero');
        starknet::replace_class_syscall(impl_hash).unwrap_syscall();
        impl_hash::write(impl_hash);
        Upgraded(impl_hash);
    }

    #[view]
    fn get_implementation_hash() -> ClassHash {
        impl_hash::read()
    }
}
