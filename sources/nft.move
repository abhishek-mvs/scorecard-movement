module scorecard::nft {
    use std::error;
    use std::signer;
    use std::string::{Self, String};
    use std::vector;
    
    /// Errors
    const E_UNAUTHORIZED: u64 = 1;
    const E_ALREADY_INITIALIZED: u64 = 2;
    const E_NOT_INITIALIZED: u64 = 3;
    const E_ALREADY_OWNS_NFT: u64 = 4;

    /// Simple NFT structure - stored at the contract address
    struct NFT has store, drop, copy {
        name: String,
        description: String,
        day_timestamp: u64,
        score: u64,
        token_id: u64,
    }

    /// NFT Collection information
    struct NFTCollectionData has key {
        name: String,
        description: String,
        token_counter: u64,
        // Map of all NFTs: player address -> vector of NFTs
        player_trophies: vector<PlayerTrophy>,
    }
    
    /// Record of a player's trophy
    struct PlayerTrophy has store, drop, copy {
        player: address,
        token_id: u64,
        nft: NFT,
    }

    /// Trophy detail structure for view functions
    struct TrophyDetail has drop, copy {
        token_id: u64,
        name: String,
        description: String,
        day_timestamp: u64,
        score: u64,
    }

    /// NFT owner detail structure for view functions
    struct OwnerDetail has drop, copy {
        owner: address,
        token_id: u64,
        name: String,
        day_timestamp: u64,
    }

    /// Initialize the NFT collection
    public entry fun initialize_nft_collection(admin: &signer) {
        let admin_addr = signer::address_of(admin);
        
        // Check that caller is the module publisher
        assert!(admin_addr == @scorecard, error::permission_denied(E_UNAUTHORIZED));
        
        // Ensure collection isn't already initialized
        assert!(!exists<NFTCollectionData>(admin_addr), error::already_exists(E_ALREADY_INITIALIZED));
        
        // Create collection data
        let name = string::utf8(b"Scorecard Champions");
        let description = string::utf8(b"Daily top winners of the Scorecard game");
        
        // Store collection data
        move_to(admin, NFTCollectionData {
            name,
            description,
            token_counter: 0,
            player_trophies: vector::empty<PlayerTrophy>(),
        });
    }

    /// Mint a new NFT for the daily winner
    public fun mint_winner_nft(
        admin: &signer,
        winner: address,
        score: u64,
        day_timestamp: u64
    ) acquires NFTCollectionData {
        let admin_addr = signer::address_of(admin);
        
        // Check that caller is the module publisher
        assert!(admin_addr == @scorecard, error::permission_denied(E_UNAUTHORIZED));
        
        // Ensure collection is initialized
        assert!(exists<NFTCollectionData>(admin_addr), error::not_found(E_NOT_INITIALIZED));
        
        let collection_data = borrow_global_mut<NFTCollectionData>(admin_addr);
        
        // Create token name and description
        let token_name = string::utf8(b"Daily Champion - ");
        string::append(&mut token_name, u64_to_string(day_timestamp));
        
        let token_description = string::utf8(b"Top score: ");
        string::append(&mut token_description, u64_to_string(score));
        
        // Create the NFT
        let nft = NFT {
            name: token_name,
            description: token_description,
            day_timestamp,
            score,
            token_id: collection_data.token_counter,
        };
        
        // Create player trophy record
        let player_trophy = PlayerTrophy {
            player: winner,
            token_id: collection_data.token_counter,
            nft,
        };
        
        // Add trophy to collection
        vector::push_back(&mut collection_data.player_trophies, player_trophy);
        
        // Increment token counter
        collection_data.token_counter = collection_data.token_counter + 1;
    }
    
    /// Get the number of trophies a player has
    #[view]
    public fun get_trophy_count(player: address): u64 acquires NFTCollectionData {
        if (!exists<NFTCollectionData>(@scorecard)) {
            return 0
        };
        
        let collection_data = borrow_global<NFTCollectionData>(@scorecard);
        let count = 0;
        
        let i = 0;
        let len = vector::length(&collection_data.player_trophies);
        
        while (i < len) {
            let trophy = vector::borrow(&collection_data.player_trophies, i);
            if (trophy.player == player) {
                count = count + 1;
            };
            i = i + 1;
        };
        
        count
    }
    
    /// Get a player's trophies
    #[view]
    public fun get_player_trophies(player: address): vector<NFT> acquires NFTCollectionData {
        if (!exists<NFTCollectionData>(@scorecard)) {
            return vector::empty<NFT>()
        };
        
        let collection_data = borrow_global<NFTCollectionData>(@scorecard);
        let trophies = vector::empty<NFT>();
        
        let i = 0;
        let len = vector::length(&collection_data.player_trophies);
        
        while (i < len) {
            let trophy = vector::borrow(&collection_data.player_trophies, i);
            if (trophy.player == player) {
                vector::push_back(&mut trophies, trophy.nft);
            };
            i = i + 1;
        };
        
        trophies
    }
    
    /// Convert u64 to string
    fun u64_to_string(value: u64): String {
        if (value == 0) {
            return string::utf8(b"0")
        };
        
        let digits = vector::empty<u8>();
        let temp_value = value;
        
        while (temp_value > 0) {
            let digit: u8 = ((temp_value % 10) as u8) + 48; // Convert to ASCII
            vector::push_back(&mut digits, digit);
            temp_value = temp_value / 10;
        };
        
        // Reverse the digits
        let len = vector::length(&digits);
        let i = 0;
        let j = len - 1;
        
        while (i < j) {
            let temp = *vector::borrow(&digits, i);
            *vector::borrow_mut(&mut digits, i) = *vector::borrow(&digits, j);
            *vector::borrow_mut(&mut digits, j) = temp;
            i = i + 1;
            j = j - 1;
        };
        
        string::utf8(digits)
    }
    
    /// Get detailed information about a player's trophies including token IDs
    #[view]
    public fun get_trophy_details(player: address): vector<TrophyDetail> acquires NFTCollectionData {
        if (!exists<NFTCollectionData>(@scorecard)) {
            return vector::empty<TrophyDetail>()
        };
        
        let collection_data = borrow_global<NFTCollectionData>(@scorecard);
        let trophy_details = vector::empty<TrophyDetail>();
        
        let i = 0;
        let len = vector::length(&collection_data.player_trophies);
        
        while (i < len) {
            let trophy = vector::borrow(&collection_data.player_trophies, i);
            if (trophy.player == player) {
                let nft = &trophy.nft;
                vector::push_back(&mut trophy_details, TrophyDetail {
                    token_id: nft.token_id,
                    name: nft.name,
                    description: nft.description,
                    day_timestamp: nft.day_timestamp,
                    score: nft.score
                });
            };
            i = i + 1;
        };
        
        trophy_details
    }

    /// Get all NFT owners with their trophy details
    #[view]
    public fun get_all_nft_owners(): vector<OwnerDetail> acquires NFTCollectionData {
        if (!exists<NFTCollectionData>(@scorecard)) {
            return vector::empty<OwnerDetail>()
        };
        
        let collection_data = borrow_global<NFTCollectionData>(@scorecard);
        let owner_details = vector::empty<OwnerDetail>();
        
        let i = 0;
        let len = vector::length(&collection_data.player_trophies);
        
        while (i < len) {
            let trophy = vector::borrow(&collection_data.player_trophies, i);
            let nft = &trophy.nft;
            
            vector::push_back(&mut owner_details, OwnerDetail {
                owner: trophy.player,
                token_id: nft.token_id,
                name: nft.name,
                day_timestamp: nft.day_timestamp
            });
            
            i = i + 1;
        };
        
        owner_details
    }

    /// Reset the NFT collection (admin only)
    public entry fun reset_nft_collection(admin: &signer) acquires NFTCollectionData {
        let admin_addr = signer::address_of(admin);
        
        // Check that caller is the module publisher
        assert!(admin_addr == @scorecard, error::permission_denied(E_UNAUTHORIZED));
        
        // Ensure collection is initialized
        assert!(exists<NFTCollectionData>(@scorecard), error::not_found(E_NOT_INITIALIZED));
        
        // Get the collection data and reset it
        let collection_data = borrow_global_mut<NFTCollectionData>(@scorecard);
        
        // Reset the player trophies
        collection_data.player_trophies = vector::empty<PlayerTrophy>();
        
        // Reset the token counter
        collection_data.token_counter = 0;
    }
    
    // Test-only functions
    #[test_only]
    public fun initialize_for_test(admin: &signer) {
        initialize_nft_collection(admin);
    }

    /// Accessor functions for TrophyDetail fields
    public fun get_trophy_token_id(detail: &TrophyDetail): u64 {
        detail.token_id
    }

    public fun get_trophy_name(detail: &TrophyDetail): String {
        detail.name
    }

    public fun get_trophy_description(detail: &TrophyDetail): String {
        detail.description
    }

    public fun get_trophy_day_timestamp(detail: &TrophyDetail): u64 {
        detail.day_timestamp
    }

    public fun get_trophy_score(detail: &TrophyDetail): u64 {
        detail.score
    }

    /// Accessor functions for OwnerDetail fields
    public fun get_owner_address(detail: &OwnerDetail): address {
        detail.owner
    }

    public fun get_owner_token_id(detail: &OwnerDetail): u64 {
        detail.token_id
    }

    public fun get_owner_name(detail: &OwnerDetail): String {
        detail.name
    }

    public fun get_owner_day_timestamp(detail: &OwnerDetail): u64 {
        detail.day_timestamp
    }
} 