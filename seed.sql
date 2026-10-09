-- Providers
INSERT INTO providers (name, country) VALUES
('Pragmatic Play', 'Malta'),
('Evolution', 'Malta'),
('NetEnt', 'Sweden');

-- Games
INSERT INTO games (name, provider_id, rtp) VALUES
('Sweet Bonanza', 1, 96.51),
('Gates of Olympus', 1, 96.50),
('Crazy Time', 2, 96.08),
('Lightning Roulette', 2, 97.30),
('Starburst', 3, 96.09);

-- Bonuses
INSERT INTO bonuses (name, bonus_amount) VALUES
('Welcome Bonus', 50.00),
('Weekly Cashback', 20.00),
('Reload Bonus', 30.00);

-- Players
INSERT INTO players (name, email, city)
SELECT
    'Player ' || i,
    'player' || i || '@test.com',
    (ARRAY['Valletta', 'Dublin', 'Helsinki', 'Berlin'])[floor(random() * 4 + 1)]
FROM generate_series(1, 50) AS i;

-- Bets
INSERT INTO bets (player_id, game_id, bet_amount, payout, created_at)
WITH raw_bets AS (
    SELECT
        floor(random() * 50 + 1)::int AS player_id,
        floor(random() * 5 + 1)::int AS game_id,
        round((random() * 190 + 10)::numeric, 2) AS bet_amount,
        NOW() - (random() * interval '90 days') AS created_at
    FROM generate_series(1, 2000)
)
SELECT
    player_id,
    game_id,
    bet_amount,
    round((bet_amount * (0.85 + random() * 0.25))::numeric, 2) AS payout,
    created_at
FROM raw_bets;

-- Player Bonuses
INSERT INTO player_bonuses (player_id, bonus_id, granted_at, is_redeemed)
SELECT
    floor(random() * 50 + 1)::int,
    floor(random() * 3 + 1)::int,
    NOW() - (random() * interval '90 days'),
    (random() < 0.6)
FROM generate_series(1, 80) AS i;

-- Simulate player dropout for churn analysis
UPDATE bets
SET created_at = created_at - INTERVAL '45 days'
WHERE player_id IN (1, 2, 3, 4, 5, 6, 7, 8, 9, 10)
AND created_at > NOW() - INTERVAL '30 days';

-- Additional bets: nighttime peak hours (19h-23h), players 11-50 only
INSERT INTO bets (player_id, game_id, bet_amount, payout, created_at)
WITH raw_bets AS (
    SELECT
        floor(random() * 40 + 11)::int AS player_id,
        floor(random() * 5 + 1)::int AS game_id,
        round((random() * 190 + 10)::numeric, 2) AS bet_amount,
        date_trunc('day', NOW() - (floor(random() * 90) * interval '1 day'))
            + ((floor(random() * 5) + 19) * interval '1 hour')
            + (floor(random() * 60) * interval '1 minute') AS created_at
    FROM generate_series(1, 500)
)
SELECT
    player_id,
    game_id,
    bet_amount,
    round((bet_amount * (0.85 + random() * 0.25))::numeric, 2) AS payout,
    created_at
FROM raw_bets;

-- Additional bets: single-day high-volume event, players 11-50 only
INSERT INTO bets (player_id, game_id, bet_amount, payout, created_at)
WITH raw_bets AS (
    SELECT
        floor(random() * 40 + 11)::int AS player_id,
        floor(random() * 5 + 1)::int AS game_id,
        round((random() * 190 + 10)::numeric, 2) AS bet_amount,
        (CURRENT_DATE - INTERVAL '15 days')
            + (floor(random() * 24) * interval '1 hour')
            + (floor(random() * 60) * interval '1 minute') AS created_at
    FROM generate_series(1, 800)
)
SELECT
    player_id,
    game_id,
    bet_amount,
    round((bet_amount * (0.85 + random() * 0.25))::numeric, 2) AS payout,
    created_at
FROM raw_bets;

-- Data consistency: a bonus cannot be redeemed after the player's last bet
UPDATE player_bonuses pb
SET is_redeemed = false
WHERE pb.is_redeemed = true
  AND pb.granted_at > (SELECT MAX(b.created_at)
                       FROM bets b
                       WHERE b.player_id = pb.player_id);

-- Bonus abuse scenario: players 1-5 claim a Reload Bonus and leave after one bet
INSERT INTO player_bonuses (player_id, bonus_id, granted_at, is_redeemed)
SELECT
    b.player_id,
    (SELECT bonus_id FROM bonuses WHERE name = 'Reload Bonus'),
    MAX(b.created_at) - INTERVAL '2 hours',
    true
FROM bets b
WHERE b.player_id BETWEEN 1 AND 5
GROUP BY b.player_id;

UPDATE bets b
SET funded_by_player_bonus_id = pb.player_bonus_id,
    bet_amount = bo.bonus_amount,
    payout = ROUND(b.payout / b.bet_amount * bo.bonus_amount, 2)
FROM player_bonuses pb
JOIN bonuses bo ON bo.bonus_id = pb.bonus_id
WHERE pb.player_id = b.player_id
  AND pb.player_id BETWEEN 1 AND 5
  AND bo.name = 'Reload Bonus'
  AND pb.granted_at = b.created_at - INTERVAL '2 hours'
  AND b.created_at = (SELECT MAX(created_at)
                      FROM bets
                      WHERE player_id = b.player_id);

-- Link every other redeemed bonus to the first unfunded bet placed after it
-- (safe to re-run: bonuses already linked are skipped)
WITH first_bets AS (
    SELECT DISTINCT ON (pb.player_bonus_id)
        pb.player_bonus_id,
        b.bet_id,
        bo.bonus_amount
    FROM player_bonuses pb
    JOIN bonuses bo ON bo.bonus_id = pb.bonus_id
    JOIN bets b ON b.player_id = pb.player_id
               AND b.created_at > pb.granted_at
               AND b.funded_by_player_bonus_id IS NULL
    WHERE pb.is_redeemed = true
      AND NOT EXISTS (SELECT 1 FROM bets x
                      WHERE x.funded_by_player_bonus_id = pb.player_bonus_id)
    ORDER BY pb.player_bonus_id, b.created_at
)
UPDATE bets b
SET funded_by_player_bonus_id = fb.player_bonus_id,
    bet_amount = fb.bonus_amount,
    payout = ROUND(b.payout / b.bet_amount * fb.bonus_amount, 2)
FROM first_bets fb
WHERE b.bet_id = fb.bet_id;