
# Apt Vault

Apt Vault is a smart contract module built on the Aptos blockchain that provides a secure and efficient vault mechanism for managing fungible assets. It allows users to deposit, withdraw, and manage funds while ensuring liquidity and strategy-based asset management.

## Features

-   **Secure Asset Vaulting**: Users can deposit and withdraw assets securely.
    
-   **Total Value Locked (TVL) Cap**: Allows setting a maximum limit for deposits.
    
-   **Deposit & Withdrawal Controls**: Pause and unpause deposit and withdrawal functionalities.
    
-   **Asset Scaling Factor**: Supports configurable scaling for asset shares.
    
-   **Multi-Strategy Management**: Supports multiple strategies to optimize asset utilization.
    

## Smart Contract Structure

### Vault

The `Vault` struct stores details about the vault including:

-   `tvl_cap`: Optional cap for total value locked.
    
-   `deposit_paused`: Boolean flag to pause deposits.
    
-   `withdrawal_paused`: Boolean flag to pause withdrawals.
    
-   `scaling_factor`: Optional scaling factor for asset shares.
    
-   `shares`: Object reference to the vault's share asset.
    
-   `available_asset`: Object storing the total available balance of the underlying asset.
    
-   `strategies`: Vector of addresses representing different strategies linked to the vault.
    

### Strategy

The `Strategy` struct defines:

-   `paused`: Boolean flag to pause the strategy.
    
-   `vault`: Reference to the associated vault.
    
-   `profits_store`: Object holding profit balances.
    

### VaultController

The `VaultController` struct provides:

-   `extend_ref`: An extension reference for managing vault operations.
    

### GlobalVaultState

Maintains a count of the vaults created on the blockchain.

## Error Codes

Code

Description

0

Invalid object owner

1

Insufficient balance

2

Cannot exceed TVL cap

3

Invalid vault object

4

Deposit is paused

5

Withdrawal is paused

6

Strategy is paused

7

Not the vault owner

8

Deposit is not paused

9

Withdrawal is not paused

## Key Functions

### Initialization

-   `init_module(account: &signer)`: Initializes the module and sets the vault count.
    

### Vault Creation

-   `create(account: &signer, tvl_cap: Option<u64>, scaling_factor: Option<u64>, underlying: Object<Metadata>)`: Creates a new vault with the given parameters.
    

### Deposit & Withdrawal

-   `deposit(account: &signer, vault: Object<Vault>, controller: Object<AssetController>, amount: u64)`: Deposits a specified amount into the vault.
    
-   `withdraw(account: &signer, vault: Object<Vault>, controller: Object<AssetController>, amount: u64)`: Withdraws a specified amount from the vault.
    

### Pausing Operations

-   `pause_deposit(account: &signer, vault: Object<Vault>)`: Pauses deposit functionality.
    
-   `unpause_deposit(account: &signer, vault: Object<Vault>)`: Resumes deposit functionality.
    
-   `pause_withdrawal(account: &signer, vault: Object<Vault>)`: Pauses withdrawal functionality.
    
-   `unpause_withdrawal(account: &signer, vault: Object<Vault>)`: Resumes withdrawal functionality.
    

### Other Functions

-   `set_tvl_cap(account: &signer, vault: Object<Vault>, tvl_cap: Option<u64>)`: Sets or updates the TVL cap for the vault.
    
-   `total_assets(vault: &Vault)`: Returns the total asset balance in the vault.
    
-   `total_shares(vault: &Vault)`: Returns the total shares issued.
    

## How to Use

1.  **Deploy the contract** on the Aptos blockchain.
    
2.  **Initialize the module** by calling `init_module()`.
    
3.  **Create a vault** using `create()`.
    
4.  **Deposit funds** into the vault via `deposit()`.
    
5.  **Withdraw funds** using `withdraw()`.
    
6.  **Pause and unpause** deposits or withdrawals as needed.
    

## License

This project is open-source and available under the MIT License.
