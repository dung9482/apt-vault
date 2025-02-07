module apt_vault::asset_factory {
    use std::error;
    use std::option;
    use std::option::Option;
    use std::signer;
    use std::string::String;
    use aptos_framework::fungible_asset;
    use aptos_framework::fungible_asset::{MintRef, BurnRef, TransferRef, Metadata, FungibleStore};
    use aptos_framework::object;
    use aptos_framework::object::{ConstructorRef, Object};
    use aptos_framework::primary_fungible_store;

    struct AssetController has key {
        mint_ref: Option<MintRef>,
        burn_ref: Option<BurnRef>,
        transfer_ref: Option<TransferRef>
    }

    const EINSUFICIENT_BALANCE: u64 = 0;

    public fun create_asset(account: &signer, name: String, symbol: String, decimals: u8, icon_uri: String, project_uri: String): ConstructorRef {
        let constructor_ref = object::create_object(signer::address_of(account));
        let maximum_supply = option::none();

        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            &constructor_ref,
            maximum_supply,
            name,
            symbol,
            decimals,
            icon_uri,
            project_uri
        );

        constructor_ref
    }

    public fun create_controller(): AssetController {
        AssetController {
            mint_ref: option::none(),
            burn_ref: option::none(),
            transfer_ref: option::none()
        }
    }

    public fun generate_mint_ref(controller: &mut AssetController, constructor_ref: &ConstructorRef) {
        // aborts if mint_ref is `some`
        option::fill(&mut controller.mint_ref, fungible_asset::generate_mint_ref(constructor_ref))
    }

    public fun generate_burn_ref(controller: &mut AssetController, constructor_ref: &ConstructorRef) {
        // aborts if burn_ref is `some`
        option::fill(&mut controller.burn_ref, fungible_asset::generate_burn_ref(constructor_ref))
    }

    public fun generate_transfer_ref(controller: &mut AssetController, constructor_ref: &ConstructorRef) {
        // aborts if transfer_ref is `some`
        option::fill(&mut controller.transfer_ref, fungible_asset::generate_transfer_ref(constructor_ref))
    }

    public fun remove_mint_ref(controller: &mut AssetController) {
        // aborts if mint_ref is `none`
        option::extract(&mut controller.mint_ref);
    }

    public fun remove_burn_ref(controller: &mut AssetController) {
        // aborts if burn_ref is `none`
        option::extract(&mut controller.burn_ref);
    }

    public fun remove_transfer_ref(controller: &mut AssetController) {
        // aborts if transfer_ref is `none`
        option::extract(&mut controller.transfer_ref);
    }

    // ===== View functions =====

    public fun mint_to(controller: Object<AssetController>, asset: Object<Metadata>, to: address, amount: u64) acquires AssetController {
        let store = primary_fungible_store::ensure_primary_store_exists(to, asset);
        mint_to_store(controller, store, amount)
    }

    public fun mint_to_store(controller: Object<AssetController>, to: Object<FungibleStore>, amount: u64) acquires AssetController {
        // aborts if `none`
        let mint_ref = option::borrow(&borrow_controller(&controller).mint_ref);
        fungible_asset::mint_to(mint_ref, to, amount)
    }

    public fun burn_from(controller: Object<AssetController>, asset: Object<Metadata>, from: address, amount: u64) acquires AssetController {
        let store = primary_fungible_store::ensure_primary_store_exists(from, asset);
        burn_from_store(controller, store, amount)
    }

    public fun burn_from_store(controller: Object<AssetController>, from: Object<FungibleStore>, amount: u64) acquires AssetController {
        // aborts if `none`
        let burn_ref = option::borrow(&borrow_controller(&controller).burn_ref);
        fungible_asset::burn_from(burn_ref, from, amount)
    }

    public fun transfer_from(controller: Object<AssetController>, asset: Object<Metadata>, from: Object<FungibleStore>, to: address, amount: u64) acquires AssetController {
        assert!(fungible_asset::balance(from) >= amount, error::out_of_range(EINSUFICIENT_BALANCE));
        let to_store = primary_fungible_store::ensure_primary_store_exists(to, asset);
        transfer_to_store(controller, from, to_store, amount)
    }

    public fun transfer_to_store(controller: Object<AssetController>, from: Object<FungibleStore>, to: Object<FungibleStore>, amount: u64) acquires AssetController {
        let transfer_ref = option::borrow(&borrow_controller(&controller).transfer_ref);
        fungible_asset::transfer_with_ref(transfer_ref, from, to, amount)
    }

    public fun create_store(asset: Object<Metadata>, constructor_ref: &ConstructorRef): Object<FungibleStore> {
        fungible_asset::create_store(constructor_ref, asset)
    }

    public fun move_controller_to(owner: &signer, controller: AssetController) {
        move_to(owner, controller);
    }

    inline fun borrow_controller(controller: &Object<AssetController>): &AssetController acquires AssetController {
        let controller_address = object::object_address(controller);
        borrow_global<AssetController>(controller_address)
    }
}
