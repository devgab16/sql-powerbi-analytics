# iGaming SQL Analytics

## Situation
Online casino operations generate large volumes of betting data that need to be structured and analyzed to answer real business questions: how much revenue the house generates, which games perform best, and how many players stop playing over time.

## Task
Design and populate a relational database simulating a casino operation, then extract the core industry metrics used across the iGaming sector — GGR (Gross Gaming Revenue), NGR (Net Gaming Revenue), and player churn — using SQL alone.

## Action
- Modeled a 6-table relational schema (`players`, `providers`, `games`, `bets`, `bonuses`, `player_bonuses`) with primary/foreign keys and normalization applied throughout — see `schema.sql`.
- Generated 90 days of synthetic betting history (2,000 bets across 50 players) using PostgreSQL's `generate_series` and CTEs, with `payout` calculated as a randomized fraction of `bet_amount` to approximate a realistic house edge — see `seed.sql`.
- Identified and corrected a data generation gap: the original dataset simulated only continuously active players, making churn always equal to 0%. Fixed by deliberately shifting a subset of players' bet history, producing a realistic churn rate.
- Wrote and validated four analytical queries — total GGR, GGR by game, NGR, and 30-day churn — see `queries.sql`.
- Documented every non-obvious design decision and its reasoning in `DECISIONS.md`, including two data limitations identified during development.

## Result
- **Total GGR:** R$5,568.33 (on R$207,314.68 wagered across 2000 bets)
- **NGR:** R$2,958.33 (after R$2,610.00 in bonuses granted)
- **Top-performing game by GGR:** Sweet Bonanza (R$1,271.00)
- **30-day churn rate:** 20.00% (10 of 50 players)

## Tech Stack
PostgreSQL, SQL (DDL, DML, DQL, joins, subqueries, CTEs, window-free aggregation), Git/GitHub.

## Project Structure
- `schema.sql` — database schema (DDL)
- `seed.sql` — synthetic data generation (reproducible)
- `queries.sql` — core metric queries
- `DECISIONS.md` — architecture decisions and reasoning