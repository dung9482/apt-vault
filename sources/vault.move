module apt_vault::vault {
    use std::bcs;
    use std::error;
    use std::option;
    use std::option::Option;
    use std::signer;
    use std::string::utf8;
    use std::vector;
    use aptos_std::math128;

    use aptos_framework::object;
    use aptos_framework::fungible_asset;
    use aptos_framework::primary_fungible_store;
    use aptos_framework::fungible_asset::{FungibleStore, Metadata};
    use aptos_framework::object::{Object, ExtendRef};

    use apt_vault::asset_factory::AssetController;
    use apt_vault::asset_factory;
    use apt_vault::utils;

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct Vault has key {
        tvl_cap: Option<u64>,
        deposit_paused: bool,
        withdrawal_paused: bool,
        scaling_factor: Option<u64>,
        // Object pointing to the vault's shares asset
        shares: Object<Metadata>,
        // The total available balance of the underlying asset
        available_asset: Object<FungibleStore>,
        // The strategies that are associated with the vault
        strategies: vector<address>,
    }

    struct Strategy has key {
        paused: bool,
        vault: Object<Vault>,
        profits_store: Object<FungibleStore>
    }

    struct VaultController has key {
        extend_ref: ExtendRef
    }

    struct GlobalVaultState has key {
        count: u64,
    }

    const EINVALID_OBJECT_OWNER: u64 = 0;
    const EINSUFFICIENT_BALANCE: u64 = 1;
    const ECANNOT_EXCEED_TVL_CAP: u64 = 2;
    const EINVALID_VAULT_OBJECT: u64 = 3;
    const EDEPOSIT_PAUSED: u64 = 4;
    const EWITHDRAWAL_PAUSED: u64 = 5;
    const ESTRATEGY_PAUSED: u64 = 6;
    const ENOT_VAULT_OWNER: u64 = 7;
    const EDEPOSIT_NOT_PAUSED: u64 = 8;
    const EWITHDRAWAL_NOT_PAUSED: u64 = 9;

    fun init_module(account: &signer) {
        let state = GlobalVaultState { count: 0 };
        move_to(account, state)
    }

    public entry fun create(account: &signer, tvl_cap: Option<u64>, scaling_factor: Option<u64>, underlying: Object<Metadata>) acquires GlobalVaultState {
        let count = vaults_count();
        let constructor_ref = object::create_named_object(account, bcs::to_bytes(&count));
        let extend_ref = object::generate_extend_ref(&constructor_ref);

        increment_vaults_count();

        let vault_signer = object::generate_signer(&constructor_ref);
        let shares = initialize_shares_asset(&vault_signer, underlying);
        let asset_store = asset_factory::create_store(underlying, &constructor_ref);

        let vault = Vault {
            shares,
            tvl_cap,
            scaling_factor,
            deposit_paused: false,
            withdrawal_paused: false,
            available_asset: asset_store,
            strategies: vector::empty()
        };

        move_to(&vault_signer, vault);
        move_to(&vault_signer, VaultController { extend_ref })
    }

    public entry fun pause_deposit(account: &signer, vault: Object<Vault>) acquires Vault {
        let account_address = signer::address_of(account);
        assert!(object::owns(vault, account_address), error::permission_denied(ENOT_VAULT_OWNER));

        let vault_address = object::object_address(&vault);
        let vault = borrow_global_mut<Vault>(vault_address);
        assert!(!vault.deposit_paused, error::permission_denied(EDEPOSIT_PAUSED));

        vault.deposit_paused = true;
    }

    public entry fun unpause_deposit(account: &signer, vault: Object<Vault>) acquires Vault {
        let account_address = signer::address_of(account);
        assert!(object::owns(vault, account_address), error::permission_denied(ENOT_VAULT_OWNER));

        let vault_address = object::object_address(&vault);
        let vault = borrow_global_mut<Vault>(vault_address);
        assert!(vault.deposit_paused, error::permission_denied(EDEPOSIT_NOT_PAUSED));

        vault.deposit_paused = false;
    }

    public entry fun pause_withdrawal(account: &signer, vault: Object<Vault>) acquires Vault {
        let account_address = signer::address_of(account);
        assert!(object::owns(vault, account_address), error::permission_denied(ENOT_VAULT_OWNER));

        let vault_address = object::object_address(&vault);
        let vault = borrow_global_mut<Vault>(vault_address);
        assert!(!vault.withdrawal_paused, error::permission_denied(EWITHDRAWAL_PAUSED));

        vault.withdrawal_paused = true;
    }

    public entry fun unpause_withdrawal(account: &signer, vault: Object<Vault>) acquires Vault {
        let account_address = signer::address_of(account);
        assert!(object::owns(vault, account_address), error::permission_denied(ENOT_VAULT_OWNER));

        let vault_address = object::object_address(&vault);
        let vault = borrow_global_mut<Vault>(vault_address);
        assert!(vault.withdrawal_paused, error::permission_denied(EWITHDRAWAL_NOT_PAUSED));

        vault.withdrawal_paused = false;
    }

    public entry fun deposit(account: &signer, vault: Object<Vault>, controller: Object<AssetController>, amount: u64) acquires Vault {
        let account_address = signer::address_of(account);
        let vault_address = object::object_address(&vault);

        let vault = borrow_global<Vault>(vault_address);

        assert!(!vault.deposit_paused, error::permission_denied(EDEPOSIT_PAUSED));
        let metadata = asset_metadata(vault);

        if(option::is_some(&vault.tvl_cap)) {
            let tvl_cap = *option::borrow(&vault.tvl_cap);
            assert!(tvl_cap <= total_assets(vault) + amount, error::out_of_range(ECANNOT_EXCEED_TVL_CAP))
        };

        let account_store = primary_fungible_store::primary_store(account_address, metadata);
        assert!(fungible_asset::balance(account_store) >= amount, error::out_of_range(EINSUFFICIENT_BALANCE));

        let is_zero_total = total_assets(vault) == 0 || total_shares(vault) == 0;
        let shares = if(is_zero_total) {
            let scaling_factor = *option::borrow_with_default(&vault.scaling_factor, &0);
            amount * scaling_factor
        } else {
            (amount_to_shares(vault, amount) as u64)
        };

        asset_factory::mint_to(controller, vault.shares, account_address, shares);
    }

    public entry fun withdraw(account: &signer, vault: Object<Vault>, controller: Object<AssetController>,  amount: u64) acquires Vault, Strategy, VaultController {
        let account_address = signer::address_of(account);
        let vault_address = object::object_address(&vault);

        let vault = borrow_global<Vault>(vault_address);

        assert!(!vault.withdrawal_paused, error::permission_denied(EWITHDRAWAL_PAUSED));

        let withdraw_amount = (shares_to_amount(vault, amount) as u64);
        if(withdraw_amount > total_assets(vault)) {
            // force withdraw from strategies
            for(strategy in vault.strategies) {
                let strategy = borrow_global<Strategy>(strategy);
                assert!(!strategy.paused, error::permission_denied(ESTRATEGY_PAUSED));
                assert!(
                    object::object_address(&strategy.vault) == vault_address,
                    error::invalid_state(EINVALID_VAULT_OBJECT)
                )

                // Perform other needed actions on the strategy to balance up the vault asset
            }
        };


        asset_factory::burn_from(controller, vault.shares, account_address, amount);

        let extend_ref = borrow_global<VaultController>(vault_address).extend_ref;
        let vault_signer = object::generate_signer_for_extending(&extend_ref);

        let metadata = asset_metadata(vault);
        let account_store = primary_fungible_store::ensure_primary_store_exists(account_address, metadata);
        fungible_asset::transfer(&vault_signer, vault.available_asset, account_store, amount)
    }

    public entry fun set_tvl_cap(account: &signer, vault: Object<Vault>, tvl_cap: Option<u64>) acquires Vault {
        let account_address = signer::address_of(account);
        assert!(object::owns(vault, account_address), error::permission_denied(ENOT_VAULT_OWNER));

        let vault_address = object::object_address(&vault);
        let vault = borrow_global_mut<Vault>(vault_address);
        vault.tvl_cap = tvl_cap
    }

    fun initialize_shares_asset(vault: &signer, underlying: Object<Metadata>): Object<Metadata> {
        // Prepends "Vault " to underlying asset name, e.g "USDC" turns "Vault USDC"
        let name = utils::prepend_utf8(fungible_asset::name(underlying), b"Vault ");
        // Prepends "v" to underlying asset symbol, e.g "USDC" turns "vUSDC"
        let symbol = utils::prepend_utf8(fungible_asset::symbol(underlying), b"v");
        let decimals = fungible_asset::decimals(underlying);

        let constructor_ref = asset_factory::create_asset(vault, name, symbol, decimals,utf8(b""), utf8(b""));
        let asset_controller = asset_factory::create_controller();
        asset_factory::generate_mint_ref(&mut asset_controller, &constructor_ref);
        asset_factory::generate_burn_ref(&mut asset_controller, &constructor_ref);
        asset_factory::move_controller_to(vault, asset_controller);

        object::address_to_object<Metadata>(object::address_from_constructor_ref(&constructor_ref))
    }

    fun increment_vaults_count() acquires GlobalVaultState {
        let state = borrow_global_mut<GlobalVaultState>(@apt_vault);
        state.count = state.count + 1;
    }

    fun vaults_count(): u64 acquires GlobalVaultState {
        borrow_global<GlobalVaultState>(@apt_vault).count
    }

    fun asset_metadata(vault: &Vault): Object<Metadata> {
        fungible_asset::store_metadata(vault.available_asset)
    }

    fun total_shares(vault: &Vault): u128 {
        let supply = fungible_asset::supply(vault.shares);
        option::destroy_with_default(supply,0)
    }

    fun total_assets(vault: &Vault): u64 {
        fungible_asset::balance(vault.available_asset)
    }

    fun amount_to_shares(vault: &Vault, amount: u64): u128 {
        let total_shares = total_shares(vault);
        let total_assets = (total_assets(vault) as u128);

        math128::mul_div((amount as u128), total_shares, total_assets)
    }

    fun shares_to_amount(vault: &Vault, shares: u64): u128 {
        let total_shares = total_shares(vault);
        let total_assets = (total_assets(vault) as u128);

        math128::mul_div((shares as u128), total_assets, total_shares)
    }
}
