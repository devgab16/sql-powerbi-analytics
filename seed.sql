-- Providers
INSERT INTO providers (name, country) VALUES
('Pragmatic Play', 'Malta'),
('Evolution', 'Malta'),
('NetEnt', 'Suecia');

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
    (ARRAY['Cuiaba', 'Sao Paulo', 'Curitiba', 'Recife'])[floor(random() * 4 + 1)]
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