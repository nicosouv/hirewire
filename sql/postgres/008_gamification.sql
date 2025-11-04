-- Gamification System
-- Badges, achievements, and points to motivate users during job search

-- Achievements/Badges catalog
CREATE TABLE IF NOT EXISTS hirewire.achievements (
    id SERIAL PRIMARY KEY,
    code VARCHAR(100) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    category VARCHAR(50) NOT NULL, -- 'applications', 'interviews', 'streak', 'special'
    icon VARCHAR(50) NOT NULL, -- emoji or icon name
    points INTEGER NOT NULL DEFAULT 0,
    rarity VARCHAR(20) NOT NULL DEFAULT 'common', -- 'common', 'rare', 'epic', 'legendary'
    criteria JSONB NOT NULL, -- {type: 'count', target: 10, metric: 'applications'}
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW()
);

-- User achievements (unlocked badges)
CREATE TABLE IF NOT EXISTS hirewire.user_achievements (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES hirewire.users(id) ON DELETE CASCADE,
    achievement_id INTEGER NOT NULL REFERENCES hirewire.achievements(id) ON DELETE CASCADE,
    unlocked_at TIMESTAMP DEFAULT NOW(),
    progress INTEGER DEFAULT 0, -- for progressive achievements
    is_new BOOLEAN DEFAULT TRUE, -- to show "NEW" badge
    UNIQUE(user_id, achievement_id)
);

-- User stats (for leaderboard and progress tracking)
CREATE TABLE IF NOT EXISTS hirewire.user_stats (
    id SERIAL PRIMARY KEY,
    user_id INTEGER UNIQUE NOT NULL REFERENCES hirewire.users(id) ON DELETE CASCADE,
    total_points INTEGER DEFAULT 0,
    level INTEGER DEFAULT 1,
    applications_count INTEGER DEFAULT 0,
    interviews_count INTEGER DEFAULT 0,
    offers_count INTEGER DEFAULT 0,
    current_streak INTEGER DEFAULT 0,
    longest_streak INTEGER DEFAULT 0,
    last_activity_date DATE,
    achievements_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Activity log (for streak calculation)
CREATE TABLE IF NOT EXISTS hirewire.activity_log (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES hirewire.users(id) ON DELETE CASCADE,
    activity_type VARCHAR(50) NOT NULL, -- 'application', 'interview', 'profile_update', 'login'
    activity_date DATE NOT NULL DEFAULT CURRENT_DATE,
    metadata JSONB,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_user_achievements_user_id ON hirewire.user_achievements(user_id);
CREATE INDEX IF NOT EXISTS idx_user_achievements_achievement_id ON hirewire.user_achievements(achievement_id);
CREATE INDEX IF NOT EXISTS idx_user_stats_user_id ON hirewire.user_stats(user_id);
CREATE INDEX IF NOT EXISTS idx_user_stats_total_points ON hirewire.user_stats(total_points DESC);
CREATE INDEX IF NOT EXISTS idx_activity_log_user_date ON hirewire.activity_log(user_id, activity_date);

-- Insert predefined achievements
INSERT INTO hirewire.achievements (code, name, description, category, icon, points, rarity, criteria) VALUES
-- Application achievements
('first_app', 'First Step', 'Submit your first application', 'applications', '🎯', 10, 'common', '{"type": "count", "target": 1, "metric": "applications"}'),
('app_10', 'Go Getter', 'Submit 10 applications', 'applications', '🚀', 50, 'common', '{"type": "count", "target": 10, "metric": "applications"}'),
('app_25', 'Job Hunter', 'Submit 25 applications', 'applications', '🏹', 100, 'rare', '{"type": "count", "target": 25, "metric": "applications"}'),
('app_50', 'Application Master', 'Submit 50 applications', 'applications', '👑', 250, 'epic', '{"type": "count", "target": 50, "metric": "applications"}'),
('app_100', 'Unstoppable', 'Submit 100 applications', 'applications', '💎', 500, 'legendary', '{"type": "count", "target": 100, "metric": "applications"}'),

-- Interview achievements
('first_interview', 'Breaking the Ice', 'Complete your first interview', 'interviews', '🎤', 20, 'common', '{"type": "count", "target": 1, "metric": "interviews"}'),
('interview_5', 'Interviewing Pro', 'Complete 5 interviews', 'interviews', '🌟', 75, 'rare', '{"type": "count", "target": 5, "metric": "interviews"}'),
('interview_10', 'Interview Ninja', 'Complete 10 interviews', 'interviews', '🥷', 150, 'epic', '{"type": "count", "target": 10, "metric": "interviews"}'),
('interview_25', 'Interview Legend', 'Complete 25 interviews', 'interviews', '🔥', 400, 'legendary', '{"type": "count", "target": 25, "metric": "interviews"}'),

-- Offer achievements
('first_offer', 'You Got This!', 'Receive your first offer', 'special', '🎉', 100, 'epic', '{"type": "count", "target": 1, "metric": "offers"}'),
('offer_3', 'Hot Commodity', 'Receive 3 offers', 'special', '💼', 300, 'legendary', '{"type": "count", "target": 3, "metric": "offers"}'),

-- Streak achievements
('streak_3', 'On a Roll', 'Stay active for 3 days in a row', 'streak', '🔥', 30, 'common', '{"type": "streak", "target": 3}'),
('streak_7', 'Week Warrior', 'Stay active for 7 days in a row', 'streak', '⚡', 70, 'rare', '{"type": "streak", "target": 7}'),
('streak_14', 'Fortnight Fighter', 'Stay active for 14 days in a row', 'streak', '💪', 150, 'epic', '{"type": "streak", "target": 14}'),
('streak_30', 'Monthly Maverick', 'Stay active for 30 days in a row', 'streak', '🏆', 350, 'legendary', '{"type": "streak", "target": 30}'),

-- Special achievements
('complete_profile', 'Profile Complete', 'Fill out your complete profile', 'special', '✨', 25, 'common', '{"type": "special", "check": "profile_complete"}'),
('early_bird', 'Early Bird', 'Apply to a job before 8 AM', 'special', '🌅', 15, 'rare', '{"type": "special", "check": "early_application"}'),
('night_owl', 'Night Owl', 'Apply to a job after 10 PM', 'special', '🦉', 15, 'rare', '{"type": "special", "check": "night_application"}'),
('speed_demon', 'Speed Demon', 'Go from application to interview in less than 7 days', 'special', '⚡', 50, 'epic', '{"type": "special", "check": "fast_response"}'),
('comeback_kid', 'Comeback Kid', 'Apply to the same company after rejection', 'special', '💪', 40, 'rare', '{"type": "special", "check": "relance"}')
ON CONFLICT (code) DO NOTHING;

-- Function to update user stats
CREATE OR REPLACE FUNCTION hirewire.update_user_stats()
RETURNS TRIGGER AS $$
DECLARE
    v_user_id INTEGER;
BEGIN
    -- Get user_id based on the table
    IF TG_TABLE_NAME = 'interview_processes' THEN
        v_user_id := NEW.user_id;
    ELSIF TG_TABLE_NAME = 'interviews' THEN
        -- Get user_id from the associated process
        SELECT user_id INTO v_user_id
        FROM hirewire.interview_processes
        WHERE id = NEW.process_id;
    ELSIF TG_TABLE_NAME = 'interview_outcomes' THEN
        -- Get user_id from the associated process
        SELECT user_id INTO v_user_id
        FROM hirewire.interview_processes
        WHERE id = NEW.process_id;
    END IF;

    -- Initialize stats if not exists
    INSERT INTO hirewire.user_stats (user_id)
    VALUES (v_user_id)
    ON CONFLICT (user_id) DO NOTHING;

    -- Update counts based on activity type
    IF TG_TABLE_NAME = 'interview_processes' THEN
        UPDATE hirewire.user_stats
        SET applications_count = applications_count + 1,
            updated_at = NOW()
        WHERE user_id = v_user_id;
    ELSIF TG_TABLE_NAME = 'interviews' THEN
        UPDATE hirewire.user_stats
        SET interviews_count = interviews_count + 1,
            updated_at = NOW()
        WHERE user_id = v_user_id;
    ELSIF TG_TABLE_NAME = 'interview_outcomes' AND NEW.outcome = 'offer' THEN
        UPDATE hirewire.user_stats
        SET offers_count = offers_count + 1,
            updated_at = NOW()
        WHERE user_id = v_user_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers to update stats
DROP TRIGGER IF EXISTS trigger_update_stats_process ON hirewire.interview_processes;
CREATE TRIGGER trigger_update_stats_process
    AFTER INSERT ON hirewire.interview_processes
    FOR EACH ROW
    EXECUTE FUNCTION hirewire.update_user_stats();

DROP TRIGGER IF EXISTS trigger_update_stats_interview ON hirewire.interviews;
CREATE TRIGGER trigger_update_stats_interview
    AFTER INSERT ON hirewire.interviews
    FOR EACH ROW
    EXECUTE FUNCTION hirewire.update_user_stats();

DROP TRIGGER IF EXISTS trigger_update_stats_outcome ON hirewire.interview_outcomes;
CREATE TRIGGER trigger_update_stats_outcome
    AFTER INSERT ON hirewire.interview_outcomes
    FOR EACH ROW
    EXECUTE FUNCTION hirewire.update_user_stats();

-- Function to check and unlock achievements
CREATE OR REPLACE FUNCTION hirewire.check_achievements(p_user_id INTEGER)
RETURNS TABLE(newly_unlocked_id INTEGER, achievement_code VARCHAR) AS $$
DECLARE
    v_stats RECORD;
    v_achievement RECORD;
    v_criteria JSONB;
    v_target INTEGER;
    v_current INTEGER;
BEGIN
    -- Get user stats
    SELECT * INTO v_stats FROM hirewire.user_stats WHERE user_id = p_user_id;

    IF v_stats IS NULL THEN
        RETURN;
    END IF;

    -- Check each achievement
    FOR v_achievement IN
        SELECT a.* FROM hirewire.achievements a
        WHERE a.is_active = TRUE
        AND NOT EXISTS (
            SELECT 1 FROM hirewire.user_achievements ua
            WHERE ua.user_id = p_user_id AND ua.achievement_id = a.id
        )
    LOOP
        v_criteria := v_achievement.criteria;

        -- Count-based achievements
        IF v_criteria->>'type' = 'count' THEN
            v_target := (v_criteria->>'target')::INTEGER;

            -- Check metric
            IF v_criteria->>'metric' = 'applications' AND v_stats.applications_count >= v_target THEN
                INSERT INTO hirewire.user_achievements (user_id, achievement_id, progress)
                VALUES (p_user_id, v_achievement.id, v_stats.applications_count)
                ON CONFLICT DO NOTHING;

                -- Award points
                UPDATE hirewire.user_stats
                SET total_points = total_points + v_achievement.points,
                    achievements_count = achievements_count + 1
                WHERE user_id = p_user_id;

                newly_unlocked_id := v_achievement.id;
                achievement_code := v_achievement.code;
                RETURN NEXT;

            ELSIF v_criteria->>'metric' = 'interviews' AND v_stats.interviews_count >= v_target THEN
                INSERT INTO hirewire.user_achievements (user_id, achievement_id, progress)
                VALUES (p_user_id, v_achievement.id, v_stats.interviews_count)
                ON CONFLICT DO NOTHING;

                UPDATE hirewire.user_stats
                SET total_points = total_points + v_achievement.points,
                    achievements_count = achievements_count + 1
                WHERE user_id = p_user_id;

                newly_unlocked_id := v_achievement.id;
                achievement_code := v_achievement.code;
                RETURN NEXT;

            ELSIF v_criteria->>'metric' = 'offers' AND v_stats.offers_count >= v_target THEN
                INSERT INTO hirewire.user_achievements (user_id, achievement_id, progress)
                VALUES (p_user_id, v_achievement.id, v_stats.offers_count)
                ON CONFLICT DO NOTHING;

                UPDATE hirewire.user_stats
                SET total_points = total_points + v_achievement.points,
                    achievements_count = achievements_count + 1
                WHERE user_id = p_user_id;

                newly_unlocked_id := v_achievement.id;
                achievement_code := v_achievement.code;
                RETURN NEXT;
            END IF;

        -- Streak-based achievements
        ELSIF v_criteria->>'type' = 'streak' THEN
            v_target := (v_criteria->>'target')::INTEGER;

            IF v_stats.current_streak >= v_target THEN
                INSERT INTO hirewire.user_achievements (user_id, achievement_id, progress)
                VALUES (p_user_id, v_achievement.id, v_stats.current_streak)
                ON CONFLICT DO NOTHING;

                UPDATE hirewire.user_stats
                SET total_points = total_points + v_achievement.points,
                    achievements_count = achievements_count + 1
                WHERE user_id = p_user_id;

                newly_unlocked_id := v_achievement.id;
                achievement_code := v_achievement.code;
                RETURN NEXT;
            END IF;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;
