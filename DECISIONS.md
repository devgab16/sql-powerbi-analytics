# Architecture Decisions

Record of the technical decisions made in this project and the reasoning behind each one.

## 1. SQL before Python
The starting point already included theoretical relational modeling
(ER modeling, normalization), but no hands-on programming experience.
Entry roles in iGaming (Data Analyst, Casino Content, Game Operations and others) list SQL as a required skill in most postings; Python usually appears as a differentiator, not an entry requirement. SQL is also the shortest path between the theory already mastered and a deliverable project. Python is planned for Project 2.

## 2. Metrics are never columns
GGR, NGR, churn, LTV, and bet count can all be derived from `bet_amount`
and `payout` in `bets`. Storing these values as columns would duplicate
data and require manual recalculation on every new bet, violating
normalization. Every metric is extracted via `SUM`, `COUNT`, or `GROUP BY` at query time, never stored.

## 3. RTP is the exception
RTP is a configuration attribute of the game itself, set by the house,
not a result calculated from real bets. That's why it lives as a fixed
column in `games`, unlike the other metrics.

## 4. Payout depends on bet_amount
To make the database simulate a real casino (rather than unrelated random
values), `payout` is calculated as a fraction of `bet_amount`, with a
random multiplier between 0.85 and 1.10. This approximates the industry's
average RTP (~96%) while keeping statistical variation, ensuring the
resulting GGR makes sense as a business metric.

## 5. 90 days of synthetic history
Churn depends on elapsed time (e.g. "no bets in 30 days") to make sense.
Generating all bets with the same timestamp would make that calculation
impossible. The 2000 bets were randomly distributed across the last 90
days using `generate_series` + a `CTE`, simulating a real history.

## 6. Private repository until used in applications
The repository stays private while the project is under construction, to
avoid exposing incomplete work. Commit activity remains publicly visible
on the GitHub profile via the "private contributions" setting, preserving
the consistency history even while the content stays closed.

## 7. Payout is not yet linked to per-game RTP
The current `payout` generation uses a fixed random multiplier (0.85-1.10) applied uniformly across all games, regardless of each game's configured `rtp` value. A more accurate version would calculate `payout` using each game's actual RTP via a `JOIN` between `bets` and `games`. This is documented as a known simplification of the current dataset version, to be addressed in a future iteration.

## 8. Churn required a deliberate data adjustment
The original synthetic bet data simulated only continuously active players, resulting in 0% churn regardless of the time window used — no player had a gap of 30+ days without a bet, since bets were randomly distributed with no "dropout" behavior modeled. To make the churn metric meaningful, bets from a subset of players (10 out of 50) were shifted 45 days back in time via an `UPDATE`, simulating players who stopped betting. This produced a realistic 20% churn rate over a 30-day window.