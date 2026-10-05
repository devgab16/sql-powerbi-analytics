-- All time-based metrics use a fixed reference date: the most recent bet in
-- the dataset. Results do not drift as calendar time passes.

-- Total GGR (Gross Gaming Revenue)
SELECT
    SUM(bet_amount) AS total_wagered,
    SUM(payout) AS total_paid_out,
    SUM(bet_amount) - SUM(payout) AS ggr
FROM bets;

-- GGR by game
SELECT
    g.name AS game,
    SUM(b.bet_amount) AS total_wagered,
    SUM(b.payout) AS total_paid_out,
    SUM(b.bet_amount) - SUM(b.payout) AS ggr
FROM bets b
JOIN games g ON b.game_id = g.game_id
GROUP BY g.name
ORDER BY ggr DESC;

-- NGR (Net Gaming Revenue): GGR minus the cost of redeemed bonuses only
SELECT
    (SELECT SUM(bet_amount) - SUM(payout) FROM bets) AS ggr,
    (SELECT SUM(bo.bonus_amount)
     FROM player_bonuses pb
     JOIN bonuses bo ON pb.bonus_id = bo.bonus_id
     WHERE pb.is_redeemed = true) AS redeemed_bonus_cost,
    (SELECT SUM(bet_amount) - SUM(payout) FROM bets)
      - (SELECT SUM(bo.bonus_amount)
         FROM player_bonuses pb
         JOIN bonuses bo ON pb.bonus_id = bo.bonus_id
         WHERE pb.is_redeemed = true) AS ngr;

-- 30-day churn rate, relative to the reference date
WITH ref AS (
    SELECT MAX(created_at) AS reference_date FROM bets
)
SELECT
    COUNT(*) AS churned_players,
    (SELECT COUNT(*) FROM players) AS total_players,
    ROUND(COUNT(*)::numeric / (SELECT COUNT(*) FROM players) * 100, 2) AS churn_rate
FROM (SELECT player_id, MAX(created_at) AS last_bet
      FROM bets
      GROUP BY player_id) p, ref
WHERE p.last_bet < ref.reference_date - INTERVAL '30 days';

-- Bonus abuse rate: share of bonus-funded bets with no further bet from the
-- player within 7 days. Bets placed in the last 7 days before the reference
-- date are excluded, since their 7-day window has not closed yet.
WITH ref AS (
    SELECT MAX(created_at) AS reference_date FROM bets
),
funded AS (
    SELECT
        b.player_id,
        b.created_at AS funded_bet_at,
        NOT EXISTS (
            SELECT 1 FROM bets b2
            WHERE b2.player_id = b.player_id
              AND b2.created_at > b.created_at
              AND b2.created_at <= b.created_at + INTERVAL '7 days'
        ) AS is_abuse
    FROM bets b
    WHERE b.funded_by_player_bonus_id IS NOT NULL
)
SELECT
    COUNT(*) AS eligible_bonuses,
    COUNT(*) FILTER (WHERE is_abuse) AS abused_bonuses,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_abuse) / COUNT(*), 2) AS abuse_rate
FROM funded, ref
WHERE funded.funded_bet_at <= ref.reference_date - INTERVAL '7 days';