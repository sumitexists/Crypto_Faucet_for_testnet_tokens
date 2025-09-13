module MyModule::CryptoFaucet {
    use aptos_framework::signer;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::timestamp;

    /// Struct representing the faucet state and user claim tracking.
    struct Faucet has store, key {
        faucet_balance: u64,        // Total tokens available in faucet
        claim_amount: u64,          // Amount each user can claim
        cooldown_period: u64,       // Time between claims (in seconds)
    }

    /// Struct to track individual user claims.
    struct UserClaim has store, key {
        last_claim_time: u64,       // Timestamp of last claim
        total_claimed: u64,         // Total amount claimed by user
    }

    /// Function to initialize the faucet with initial balance and claim settings.
    public fun initialize_faucet(
        owner: &signer, 
        initial_balance: u64, 
        claim_amount: u64, 
        cooldown_hours: u64
    ) {
        let faucet = Faucet {
            faucet_balance: initial_balance,
            claim_amount,
            cooldown_period: cooldown_hours * 3600, // Convert hours to seconds
        };
        move_to(owner, faucet);
    }

    /// Function for users to claim testnet tokens from the faucet.
    public fun claim_tokens(
        faucet_owner: &signer,
        user_addr: address
    ) acquires Faucet, UserClaim {
        let current_time = timestamp::now_seconds();
        let faucet = borrow_global_mut<Faucet>(signer::address_of(faucet_owner));
        
        // Check if faucet has enough balance
        assert!(faucet.faucet_balance >= faucet.claim_amount, 1);
        
        // Check user's claim history and cooldown
        if (exists<UserClaim>(user_addr)) {
            let user_claim = borrow_global_mut<UserClaim>(user_addr);
            assert!(current_time >= user_claim.last_claim_time + faucet.cooldown_period, 2);
            user_claim.last_claim_time = current_time;
            user_claim.total_claimed = user_claim.total_claimed + faucet.claim_amount;
        } else {
            // First-time user - create claim record at user's address
            let new_user_claim = UserClaim {
                last_claim_time: current_time,
                total_claimed: faucet.claim_amount,
            };
            move_to(faucet_owner, new_user_claim);
        };
        
        // Transfer tokens from faucet owner to user
        let tokens = coin::withdraw<AptosCoin>(faucet_owner, faucet.claim_amount);
        coin::deposit<AptosCoin>(user_addr, tokens);
        
        // Update faucet balance
        faucet.faucet_balance = faucet.faucet_balance - faucet.claim_amount;
    }
}