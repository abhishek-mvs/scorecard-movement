module scorecard::game1 {
    use std::error;
    use std::signer;
    use std::vector;
    use aptos_std::smart_vector;  // If needed for view attribute support
    use std::timestamp; 
    
    /// Errors
    const E_UNAUTHORIZED: u64 = 1;
    const E_ALREADY_INITIALIZED: u64 = 2;
    const E_NOT_INITIALIZED: u64 = 3;
    const E_INVALID_SCORE: u64 = 4;
    /// Get the current timestamp
    /// If running in test mode, this will return a fixed timestamp
    /// In production, it returns the actual blockchain timestamp
    fun get_current_timestamp(): u64 {
        let time = timestamp::now_seconds();
        if (time == 0) {
            // We're in a test environment
            1234567890
        } else {
            // We're in production
            time
        }
    }
    /// Constants for time calculations
    const SECONDS_PER_DAY: u64 = 86400; // 60 * 60 * 24
    
    /// Score entry structure
    struct ScoreEntry has store, drop, copy {
        player: address,
        score: u64,
        timestamp: u64,
    }
    
    /// Game state structure - stored at contract address
    struct GameState has key {
        scores: vector<ScoreEntry>,
    }
    
    /// Player stats structure - stored at player's address
    struct PlayerStats has key {
        best_score: u64,
        total_games: u64,
    }
    
    /// Initialize the game state
    public entry fun initialize(admin: &signer) {
        let admin_addr = signer::address_of(admin);
        
        // Check that caller is the module publisher
        assert!(admin_addr == @scorecard, error::permission_denied(E_UNAUTHORIZED));
        
        // Ensure game state isn't already initialized
        assert!(!exists<GameState>(admin_addr), error::already_exists(E_ALREADY_INITIALIZED));
        
        // Create empty scores list
        let scores = vector::empty<ScoreEntry>();
        
        // Move resource to admin account
        move_to(admin, GameState { scores });
    }
    
    /// Submit a new score
    public entry fun submit_score(player: &signer, score: u64) acquires GameState, PlayerStats {
        // Use current timestamp (now)
        submit_score_internal(player, score, get_current_timestamp())
    }
    
    /// Internal function to submit a score with a specific timestamp
    fun submit_score_internal(player: &signer, score: u64, timestamp_value: u64) acquires GameState, PlayerStats {
        let player_addr = signer::address_of(player);
        
        // Validate score is positive
        assert!(score > 0, error::invalid_argument(E_INVALID_SCORE));
        
        // Ensure game state is initialized
        assert!(exists<GameState>(@scorecard), error::not_found(E_NOT_INITIALIZED));
        
        // Initialize player stats if they don't exist yet
        if (!exists<PlayerStats>(player_addr)) {
            move_to(player, PlayerStats { best_score: 0, total_games: 0 });
        };
        
        // Create new score entry
        let new_entry = ScoreEntry {
            player: player_addr,
            score: score,
            timestamp: timestamp_value,
        };
        
        // Add score to game state
        let game_state = borrow_global_mut<GameState>(@scorecard);
        vector::push_back(&mut game_state.scores, new_entry);
        
        // Update player stats
        let player_stats = borrow_global_mut<PlayerStats>(player_addr);
        player_stats.total_games = player_stats.total_games + 1;
        if (score > player_stats.best_score) {
            player_stats.best_score = score;
        };
    }
    
    /// Get top 10 scores globally
    #[view]
    public fun get_leaderboard(): vector<ScoreEntry> acquires GameState {
        // Ensure game state is initialized
        assert!(exists<GameState>(@scorecard), error::not_found(E_NOT_INITIALIZED));
        
        let game_state = borrow_global<GameState>(@scorecard);
        let scores = &game_state.scores;
        
        // Create a copy of all scores
        let all_scores = vector::empty<ScoreEntry>();
        let scores_len = vector::length(scores);
        let i = 0;
        
        while (i < scores_len) {
            vector::push_back(&mut all_scores, *vector::borrow(scores, i));
            i = i + 1;
        };
        
        // Sort all scores (descending)
        sort_scores_desc(&mut all_scores);
        
        // Return top 10 scores (or all if less than 10)
        let top_scores = vector::empty<ScoreEntry>();
        let total_len = vector::length(&all_scores);
        let top_count = if (total_len > 10) { 10 } else { total_len };
        
        i = 0;
        while (i < top_count) {
            vector::push_back(&mut top_scores, *vector::borrow(&all_scores, i));
            i = i + 1;
        };
        
        top_scores
    }
    
    /// Get top 10 scores for the current day
    #[view]
    public fun get_daily_leaderboard(): vector<ScoreEntry> acquires GameState {
        get_daily_leaderboard_internal(get_current_timestamp())
    }
    
    /// Internal function to get daily leaderboard with a specific timestamp
    fun get_daily_leaderboard_internal(current_time: u64): vector<ScoreEntry> acquires GameState {
        // Ensure game state is initialized
        assert!(exists<GameState>(@scorecard), error::not_found(E_NOT_INITIALIZED));
        
        let game_state = borrow_global<GameState>(@scorecard);
        let scores = &game_state.scores;
        
        // Calculate start of the current day (midnight)
        let day_start = current_time - (current_time % SECONDS_PER_DAY);
        
        // Create a copy of today's scores
        let today_scores = vector::empty<ScoreEntry>();
        let scores_len = vector::length(scores);
        let i = 0;
        
        while (i < scores_len) {
            let entry = vector::borrow(scores, i);
            if (entry.timestamp >= day_start) {
                vector::push_back(&mut today_scores, *entry);
            };
            i = i + 1;
        };
        
        // Sort today's scores (descending)
        sort_scores_desc(&mut today_scores);
        
        // Return top 10 scores (or all if less than 10)
        let top_scores = vector::empty<ScoreEntry>();
        let total_len = vector::length(&today_scores);
        let top_count = if (total_len > 10) { 10 } else { total_len };
        
        i = 0;
        while (i < top_count) {
            vector::push_back(&mut top_scores, *vector::borrow(&today_scores, i));
            i = i + 1;
        };
        
        top_scores
    }
    
    /// Helper function to sort scores in descending order
    fun sort_scores_desc(scores: &mut vector<ScoreEntry>) {
        let len = vector::length(scores);
        if (len < 2) {
            return
        };
        
        let i = 0;
        while (i < len - 1) {
            let j = 0;
            while (j < len - i - 1) {
                let score1 = vector::borrow(scores, j).score;
                let score2 = vector::borrow(scores, j + 1).score;
                
                if (score1 < score2) {
                    vector::swap(scores, j, j + 1);
                };
                
                j = j + 1;
            };
            i = i + 1;
        };
    }
    
    /// Get player's stats
    #[view]
    public fun get_player_stats(player: address): (u64, u64) acquires PlayerStats {
        if (!exists<PlayerStats>(player)) {
            return (0, 0)
        };
        
        let stats = borrow_global<PlayerStats>(player);
        (stats.best_score, stats.total_games)
    }
    
    /// Public getter for ScoreEntry fields
    public fun get_score_entry(entry: &ScoreEntry): (address, u64, u64) {
        (entry.player, entry.score, entry.timestamp)
    }
    
    // Test-only functions
    #[test_only]
    public fun submit_score_test_only(player: &signer, score: u64, timestamp_value: u64) acquires GameState, PlayerStats {
        submit_score_internal(player, score, timestamp_value)
    }
    
    #[test_only]
    public fun get_daily_leaderboard_test_only(current_time: u64): vector<ScoreEntry> acquires GameState {
        get_daily_leaderboard_internal(current_time)
    }
}
