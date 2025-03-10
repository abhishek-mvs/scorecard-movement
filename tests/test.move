module scorecard::game_tests {
    use std::vector;
    use aptos_framework::account;
    use scorecard::game1;

    #[test_only]
    /// Create a test signer
    fun create_test_signer(addr: address): signer {
        if (!account::exists_at(addr)) {
            account::create_account_for_test(addr);
        };
        account::create_signer_for_test(addr)
    }

    // Use your actual account address from .movement/config.yaml but with 0x prefix
    const SCORECARD_ADDR: address = @0xda5c1a8dce153639093de6c95cb749f15dac969a191385407ff0ed4c98d14fa0;
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
        
        // Yesterday's timestamp
        let yesterday_timestamp = today_timestamp - ONE_DAY_IN_SECONDS;
        
        // Submit scores from different days
        game1::submit_score_test_only(&player, 50, today_timestamp); // Today
        game1::submit_score_test_only(&player, 80, today_timestamp + 3600); // Today, 1 hour later
        game1::submit_score_test_only(&player, 30, yesterday_timestamp); // Yesterday
        game1::submit_score_test_only(&player, 95, yesterday_timestamp + 3600); // Yesterday, 1 hour later
        
        // Check daily leaderboard - should only have today's scores
        let daily_leaderboard = game1::get_daily_leaderboard_test_only(today_timestamp);
        assert!(vector::length(&daily_leaderboard) == 2, 118);
        
        // First entry should be highest score from today (80)
        let entry = vector::borrow(&daily_leaderboard, 0);
        let (_addr, score, _timestamp) = game1::get_score_entry(entry);
        assert!(score == 80, 119);
    }
}