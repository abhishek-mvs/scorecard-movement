module scorecard::game_tests {
    use std::vector;
    use aptos_framework::account;
    use scorecard::game1;
    use scorecard::nft;

    #[test_only]
    /// Create a test signer
    fun create_test_signer(addr: address): signer {
        if (!account::exists_at(addr)) {
            account::create_account_for_test(addr);
        };
        account::create_signer_for_test(addr)
    }

    // Use your actual account address from .movement/config.yaml but with 0x prefix
    const SCORECARD_ADDR: address = @0x0043b5060654a0a34c63a0d4cd0e871a170c23cf6aef89dad50538e7f9346089;
    const TEST_TIMESTAMP: u64 = 1234567890;
    const ONE_DAY_IN_SECONDS: u64 = 86400;

    #[test]
    fun test_initialize() {
        // Create the scorecard signer
        let scorecard = create_test_signer(SCORECARD_ADDR);
        
        // Initialize game
        game1::initialize(&scorecard);

        // Ensure leaderboard is empty
        let leaderboard = game1::get_leaderboard();
        assert!(vector::length(&leaderboard) == 0, 100);
    }

    #[test]
    #[expected_failure(abort_code = 327681, location = scorecard::game1)]
    fun test_initialize_unauthorized() {
        // Create a non-admin signer
        let non_admin = create_test_signer(@0x123);
        
        // This should fail with E_UNAUTHORIZED
        game1::initialize(&non_admin);
    }

    #[test]
    fun test_submit_score() {
        // Create the scorecard signer and initialize
        let scorecard = create_test_signer(SCORECARD_ADDR);
        game1::initialize(&scorecard);
        
        // Create a player
        let player = create_test_signer(@0x123);
        
        // Submit a score
        game1::submit_score(&player, 50);

        // Check leaderboard
        let leaderboard = game1::get_leaderboard();
        assert!(vector::length(&leaderboard) == 1, 101);

        let entry = vector::borrow(&leaderboard, 0);
        let (addr, score, _timestamp) = game1::get_score_entry(entry);
        assert!(addr == @0x123, 102);
        assert!(score == 50, 103);
        
        // Check player stats
        let (best_score, total_games) = game1::get_player_stats(@0x123);
        assert!(best_score == 50, 104);
        assert!(total_games == 1, 105);
    }

    #[test]
    fun test_multiple_scores_same_user() {
        // Create the scorecard signer and initialize
        let scorecard = create_test_signer(SCORECARD_ADDR);
        game1::initialize(&scorecard);
        
        // Create a player
        let player = create_test_signer(@0x123);
        
        // Submit multiple scores for the same player
        game1::submit_score(&player, 50);
        game1::submit_score(&player, 80);
        game1::submit_score(&player, 30);

        // Check leaderboard - should have all 3 scores
        let leaderboard = game1::get_leaderboard();
        assert!(vector::length(&leaderboard) == 3, 106);
        
        // First entry should be highest score (80)
        let entry = vector::borrow(&leaderboard, 0);
        let (addr, score, _timestamp) = game1::get_score_entry(entry);
        assert!(addr == @0x123, 107);
        assert!(score == 80, 108);
        
        // Check player stats
        let (best_score, total_games) = game1::get_player_stats(@0x123);
        assert!(best_score == 80, 109); // Best score should be 80
        assert!(total_games == 3, 110); // 3 total games
    }

    #[test]
    fun test_leaderboard_ordering() {
        // Create the scorecard signer and initialize
        let scorecard = create_test_signer(SCORECARD_ADDR);
        game1::initialize(&scorecard);
        
        // Create multiple players
        let player1 = create_test_signer(@0x123);
        let player2 = create_test_signer(@0x124);
        let player3 = create_test_signer(@0x125);
        
        // Submit scores in mixed order
        game1::submit_score(&player1, 30);
        game1::submit_score(&player2, 90);
        game1::submit_score(&player3, 60);
        game1::submit_score(&player1, 75); // Another score from player1
        
        // Check leaderboard ordering
        let leaderboard = game1::get_leaderboard();
        assert!(vector::length(&leaderboard) == 4, 111);
        
        // First entry should be 90 from player2
        let entry = vector::borrow(&leaderboard, 0);
        let (addr, score, _timestamp) = game1::get_score_entry(entry);
        assert!(addr == @0x124, 112);
        assert!(score == 90, 113);
        
        // Second entry should be 75 from player1
        let entry = vector::borrow(&leaderboard, 1);
        let (addr, score, _timestamp) = game1::get_score_entry(entry);
        assert!(addr == @0x123, 114);
        assert!(score == 75, 115);
    }

    #[test]
    fun test_top_10_limit() {
        // Create the scorecard signer and initialize
        let scorecard = create_test_signer(SCORECARD_ADDR);
        game1::initialize(&scorecard);
        
        // Create a player
        let player = create_test_signer(@0x123);
        
        // Submit 15 scores
        let i = 0;
        while (i < 15) {
            game1::submit_score(&player, 100 - i); // Decreasing scores
            i = i + 1;
        };
        
        // Check leaderboard - should have only top 10
        let leaderboard = game1::get_leaderboard();
        assert!(vector::length(&leaderboard) == 10, 116);
        
        // First entry should be 100
        let entry = vector::borrow(&leaderboard, 0);
        let (addr, score, _timestamp) = game1::get_score_entry(entry);
        assert!(score == 100, 117);
    }
    
    #[test]
    fun test_daily_leaderboard() {
        // Create the scorecard signer and initialize
        let scorecard = create_test_signer(SCORECARD_ADDR);
        game1::initialize(&scorecard);
        
        // Create a player
        let player = create_test_signer(@0x123);
        
        // Base timestamp (represents today)
        let today_timestamp = TEST_TIMESTAMP;
        
        // Submit scores for today
        game1::submit_score_test_only(&player, 50, today_timestamp);
        game1::submit_score_test_only(&player, 80, today_timestamp + 3600); // 1 hour later
        
        // Check daily leaderboard - should have today's scores
        let daily_leaderboard = game1::get_daily_leaderboard_test_only(today_timestamp);
        assert!(vector::length(&daily_leaderboard) == 2, 118);
        
        // First entry should be highest score (80)
        let entry = vector::borrow(&daily_leaderboard, 0);
        let (_addr, score, _timestamp) = game1::get_score_entry(entry);
        assert!(score == 80, 119);
    }

    #[test]
    fun test_daily_winner_nft() {
        // Create the scorecard signer and initialize
        let scorecard = create_test_signer(SCORECARD_ADDR);
        game1::initialize(&scorecard);
        
        // Create players
        let player1 = create_test_signer(@0x123);
        let player2 = create_test_signer(@0x124);
        let player3 = create_test_signer(@0x125);
        
        // Base timestamp (represents yesterday)
        let yesterday_timestamp = TEST_TIMESTAMP - ONE_DAY_IN_SECONDS;
        
        // Submit scores from yesterday with different players
        game1::submit_score_test_only(&player1, 50, yesterday_timestamp);
        game1::submit_score_test_only(&player2, 80, yesterday_timestamp + 3600); // 1 hour later
        game1::submit_score_test_only(&player3, 30, yesterday_timestamp + 7200); // 2 hours later
        
        // Award the daily winner (player2 should win with score 80)
        game1::award_daily_winner(&scorecard);
        
        // Check that player2 received a trophy
        let trophy_count = nft::get_trophy_count(@0x124);
        assert!(trophy_count == 1, 120);
    }
    
    #[test]
    fun test_nft_collection_initialization() {
        // Create the scorecard signer
        let scorecard = create_test_signer(SCORECARD_ADDR);
        
        // Initialize NFT collection directly
        nft::initialize_nft_collection(&scorecard);
        
        // We can't directly check if the collection was created,
        // but the function execution without errors is a good sign
    }
    
    #[test]
    fun test_multiple_nft_awards() {
        // Create the scorecard signer and initialize
        let scorecard = create_test_signer(SCORECARD_ADDR);
        game1::initialize(&scorecard);
        
        // Create players
        let player1 = create_test_signer(@0x123);
        let player2 = create_test_signer(@0x124);
        
        // Day 1 - player1 wins
        let day1_timestamp = TEST_TIMESTAMP - (ONE_DAY_IN_SECONDS * 2); // 2 days ago
        game1::submit_score_test_only(&player1, 90, day1_timestamp);
        game1::submit_score_test_only(&player2, 70, day1_timestamp + 3600);
        
        // Day 2 - player2 wins
        let day2_timestamp = TEST_TIMESTAMP - ONE_DAY_IN_SECONDS; // Yesterday
        game1::submit_score_test_only(&player1, 60, day2_timestamp);
        game1::submit_score_test_only(&player2, 85, day2_timestamp + 3600);
        
        // Award for day 1 (player1 should win)
        // We need to mock the current time to be day2
        game1::award_daily_winner(&scorecard);
        
        // Check trophy counts
        let player1_trophies = nft::get_trophy_count(@0x123);
        let player2_trophies = nft::get_trophy_count(@0x124);
        assert!(player1_trophies == 0, 121); // Player1 doesn't get trophy for day1 since we're awarding day2
        assert!(player2_trophies == 1, 122); // Player2 gets trophy for day2
        
        // Get player2's trophies and check details
        let trophies = nft::get_player_trophies(@0x124);
        assert!(vector::length(&trophies) == 1, 123);
        
        // We can't easily check the trophy details in this test
        // but we've verified the count is correct
    }
    
    #[test]
    #[expected_failure(abort_code = 524293, location = scorecard::game1)]
    fun test_award_daily_winner_already_rewarded() {
        // Create the scorecard signer and initialize
        let scorecard = create_test_signer(SCORECARD_ADDR);
        game1::initialize(&scorecard);
        
        // Create a player and submit a score for yesterday
        let player = create_test_signer(@0x123);
        let yesterday_timestamp = TEST_TIMESTAMP - ONE_DAY_IN_SECONDS;
        game1::submit_score_test_only(&player, 50, yesterday_timestamp);
        
        // Award the daily winner
        game1::award_daily_winner(&scorecard);
        
        // Try to award again - should fail with E_ALREADY_REWARDED
        game1::award_daily_winner(&scorecard);
    }

    #[test]
    fun test_trophy_details() {
        // Create the scorecard signer and initialize
        let scorecard = create_test_signer(SCORECARD_ADDR);
        game1::initialize(&scorecard);
        
        // Create players
        let player1 = create_test_signer(@0x123);
        let player2 = create_test_signer(@0x124);
        
        // Submit scores for yesterday
        let yesterday_timestamp = TEST_TIMESTAMP - ONE_DAY_IN_SECONDS;
        game1::submit_score_test_only(&player1, 50, yesterday_timestamp);
        game1::submit_score_test_only(&player2, 80, yesterday_timestamp + 3600); // 1 hour later
        
        // Award the daily winner (player2 should win with score 80)
        game1::award_daily_winner(&scorecard);
        
        // Get trophy details for player2
        let trophy_details = nft::get_trophy_details(@0x124);
        assert!(vector::length(&trophy_details) == 1, 130);
        
        // Check trophy details
        let detail = vector::borrow(&trophy_details, 0);
        assert!(nft::get_trophy_token_id(detail) == 0, 131); // First token should have ID 0
        assert!(nft::get_trophy_score(detail) == 80, 132); // Score should match
        assert!(nft::get_trophy_day_timestamp(detail) == yesterday_timestamp, 133); // Day timestamp should match
    }

    #[test]
    fun test_all_nft_owners() {
        // Create the scorecard signer and initialize
        let scorecard = create_test_signer(SCORECARD_ADDR);
        game1::initialize(&scorecard);
        
        // Create players
        let player1 = create_test_signer(@0x123);
        let player2 = create_test_signer(@0x124);
        
        // Submit scores for two different days
        let day1_timestamp = TEST_TIMESTAMP - (ONE_DAY_IN_SECONDS * 2); // 2 days ago
        let day2_timestamp = TEST_TIMESTAMP - ONE_DAY_IN_SECONDS; // Yesterday
        
        // Day 1 scores
        game1::submit_score_test_only(&player1, 90, day1_timestamp);
        game1::submit_score_test_only(&player2, 70, day1_timestamp + 3600);
        
        // Day 2 scores
        game1::submit_score_test_only(&player1, 60, day2_timestamp);
        game1::submit_score_test_only(&player2, 85, day2_timestamp + 3600);
        
        // Award for day 2 (player2 should win)
        game1::award_daily_winner(&scorecard);
        
        // Get all NFT owners
        let owner_details = nft::get_all_nft_owners();
        assert!(vector::length(&owner_details) == 1, 140); // Should have 1 NFT
        
        // Check owner details
        let detail = vector::borrow(&owner_details, 0);
        assert!(nft::get_owner_address(detail) == @0x124, 141); // Owner should be player2
        assert!(nft::get_owner_token_id(detail) == 0, 142); // First token should have ID 0
        assert!(nft::get_owner_day_timestamp(detail) == day2_timestamp, 143); // Day timestamp should match
    }

    #[test]
    fun test_reset_nft_collection() {
        // Create the scorecard signer and initialize
        let scorecard = create_test_signer(SCORECARD_ADDR);
        game1::initialize(&scorecard);
        
        // Create a player
        let player = create_test_signer(@0x123);
        
        // Submit a score for yesterday
        let yesterday_timestamp = TEST_TIMESTAMP - ONE_DAY_IN_SECONDS;
        game1::submit_score_test_only(&player, 50, yesterday_timestamp);
        
        // Award the daily winner
        game1::award_daily_winner(&scorecard);
        
        // Check trophy count
        let trophy_count = nft::get_trophy_count(@0x123);
        assert!(trophy_count == 1, 150);
        
        // Reset NFT collection
        nft::reset_nft_collection(&scorecard);
        
        // Check trophy count again - should be 0
        trophy_count = nft::get_trophy_count(@0x123);
        assert!(trophy_count == 0, 151);
        
        // Check all NFT owners - should be empty
        let owner_details = nft::get_all_nft_owners();
        assert!(vector::length(&owner_details) == 0, 152);
    }

    #[test]
    fun test_reset_game() {
        // Create the scorecard signer and initialize
        let scorecard = create_test_signer(SCORECARD_ADDR);
        game1::initialize(&scorecard);
        
        // Create a player
        let player = create_test_signer(@0x123);
        
        // Submit scores
        game1::submit_score(&player, 50);
        game1::submit_score(&player, 80);
        
        // Submit a score for yesterday
        let yesterday_timestamp = TEST_TIMESTAMP - ONE_DAY_IN_SECONDS;
        game1::submit_score_test_only(&player, 90, yesterday_timestamp);
        
        // Award the daily winner
        game1::award_daily_winner(&scorecard);
        
        // Check leaderboard and trophy count
        let leaderboard = game1::get_leaderboard();
        assert!(vector::length(&leaderboard) == 3, 160);
        
        let trophy_count = nft::get_trophy_count(@0x123);
        assert!(trophy_count == 1, 161);
        
        // Reset game
        game1::reset_game(&scorecard);
        
        // Check leaderboard and trophy count again
        leaderboard = game1::get_leaderboard();
        assert!(vector::length(&leaderboard) == 0, 162);
        
        trophy_count = nft::get_trophy_count(@0x123);
        assert!(trophy_count == 0, 163);
    }

    #[test]
    fun test_reset_scores_only() {
        // Create the scorecard signer and initialize
        let scorecard = create_test_signer(SCORECARD_ADDR);
        game1::initialize(&scorecard);
        
        // Create a player
        let player = create_test_signer(@0x123);
        
        // Submit scores
        game1::submit_score(&player, 50);
        game1::submit_score(&player, 80);
        
        // Submit a score for yesterday
        let yesterday_timestamp = TEST_TIMESTAMP - ONE_DAY_IN_SECONDS;
        game1::submit_score_test_only(&player, 90, yesterday_timestamp);
        
        // Award the daily winner
        game1::award_daily_winner(&scorecard);
        
        // Check leaderboard and trophy count
        let leaderboard = game1::get_leaderboard();
        assert!(vector::length(&leaderboard) == 3, 170);
        
        let trophy_count = nft::get_trophy_count(@0x123);
        assert!(trophy_count == 1, 171);
        
        // Reset scores only
        game1::reset_scores_only(&scorecard);
        
        // Check leaderboard and trophy count again
        leaderboard = game1::get_leaderboard();
        assert!(vector::length(&leaderboard) == 0, 172); // Scores should be reset
        
        trophy_count = nft::get_trophy_count(@0x123);
        assert!(trophy_count == 1, 173); // Trophy should still exist
    }

    #[test]
    fun test_reset_player_stats() {
        // Create the scorecard signer and initialize
        let scorecard = create_test_signer(SCORECARD_ADDR);
        game1::initialize(&scorecard);
        
        // Create a player
        let player = create_test_signer(@0x123);
        
        // Submit scores
        game1::submit_score(&player, 50);
        game1::submit_score(&player, 80);
        
        // Check player stats
        let (best_score, total_games) = game1::get_player_stats(@0x123);
        assert!(best_score == 80, 180);
        assert!(total_games == 2, 181);
        
        // Reset player stats
        game1::reset_player_stats(&scorecard, @0x123);
        
        // Check player stats again
        let (best_score, total_games) = game1::get_player_stats(@0x123);
        assert!(best_score == 0, 182);
        assert!(total_games == 0, 183);
    }

    #[test]
    fun test_reinitialize_game() {
        // Create the scorecard signer and initialize
        let scorecard = create_test_signer(SCORECARD_ADDR);
        game1::initialize(&scorecard);
        
        // Create a player
        let player = create_test_signer(@0x123);
        
        // Submit scores
        game1::submit_score(&player, 50);
        game1::submit_score(&player, 80);
        
        // Submit a score for yesterday
        let yesterday_timestamp = TEST_TIMESTAMP - ONE_DAY_IN_SECONDS;
        game1::submit_score_test_only(&player, 90, yesterday_timestamp);
        
        // Award the daily winner
        game1::award_daily_winner(&scorecard);
        
        // Check leaderboard and trophy count
        let leaderboard = game1::get_leaderboard();
        assert!(vector::length(&leaderboard) == 3, 190);
        
        let trophy_count = nft::get_trophy_count(@0x123);
        assert!(trophy_count == 1, 191);
        
        // Reinitialize game
        game1::reinitialize_game(&scorecard);
        
        // Check leaderboard and trophy count again
        leaderboard = game1::get_leaderboard();
        assert!(vector::length(&leaderboard) == 0, 192);
        
        trophy_count = nft::get_trophy_count(@0x123);
        assert!(trophy_count == 0, 193);
    }
}