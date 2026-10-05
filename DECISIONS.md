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

## 9. Added realistic time-based patterns to the dataset
The original dataset distributed all bets uniformly across the 90-day window, with no variation by time of day or date. To better simulate real casino traffic patterns, two additional batches of bets were added: 500 bets concentrated in nighttime peak hours (19h-23h), and 800 bets concentrated on a single date, simulating a high-volume event day (~36x the average daily volume).

Both additions were restricted to players 11-50, deliberately excluding players 1-10. This preserves the churn scenario established in decision #8 (players 1-10 simulate deliberate dropout) — if the new batches had sampled from the full player pool, there was a real risk of generating recent bets for an "inactive" player, silently invalidating the documented 20% churn rate. Verified after insertion: churn remained exactly 20% (10/50), confirming the constraint worked as intended.

## 10. Monetary values are labeled in EUR
The schema stores amounts as plain numeric values with no currency column, assuming a single-currency operation. Values were originally labeled in BRL; the label was switched to EUR to match the regulated European online casino market (e.g. Malta) this dataset simulates. No data changed, only the label used in documentation and the dashboard. A real operator would handle multiple currencies, which is out of scope here.

## 11. Bonus usage is tracked with an explicit foreign key
Originally, nothing linked a bet to the bonus that funded it: `bets` and `player_bonuses` only shared `player_id`. A time-based approximation (treating any bet after a bonus as bonus usage) was considered and rejected, since it would leave a known gap in a dataset meant to simulate a real operation. Instead, `bets` gained a nullable column, `funded_by_player_bonus_id`, referencing `player_bonuses`. It was added with `ALTER TABLE` as a schema evolution step, rather than by rewriting the original `CREATE TABLE`. Most bets keep it NULL, since they are placed with the player's own balance.

## 12. Inconsistent bonus records were corrected by rule, not by ID
Linking bets to bonuses exposed an impossible state: bonuses marked as redeemed but granted after the player's last bet. The cause was that `player_bonuses` was generated independently of `bets`, and the churn adjustment (#8) moved bet dates but not bonus dates. All such bonuses were set to not redeemed, which matches a real pattern: reactivation bonuses sent to players who already left, and never used. The fix is written as a rule (granted after the player's last bet) instead of a list of IDs, because IDs come from random generation and would point to unrelated rows if the seed were run again.

## 13. Each redeemed bonus is consumed in a single bet of the same value
A bet funded by a bonus cannot stake more than the bonus itself. Each redeemed bonus is linked to the first bet the player placed after receiving it, among bets not already linked to a bonus, and that bet's `bet_amount` is set to the bonus value. Its `payout` is rescaled with the multiplier the bet already had, keeping decision #4 intact. This is a deliberate simplification: real operators let players split a bonus across several bets and apply wagering requirements before withdrawal.

## 14. NGR deducts only redeemed bonuses
NGR originally subtracted every bonus granted, including bonuses never used. An unused bonus costs the operator nothing, so NGR now deducts only redeemed bonuses: €1,680.00, instead of the €2,760.00 granted in total.

## 15. Time-based metrics use a fixed reference date
Churn was originally calculated against `NOW()`. Since the data was generated at a fixed point in time, results would drift as calendar days passed, and every active player would eventually look churned. All time-based queries now measure against the most recent bet in the dataset (2026-09-25 23:54), calculated by the query itself, so results stay stable and remain valid if the seed is regenerated.

## 16. Bonus abuse: designed scenario and metric definition
Only one bonus naturally fit an abuse pattern, and only by a margin of hours, which is too fragile to support a metric. As with churn (#8), the scenario was designed deliberately: players 1-5, part of the churned group, each receive a Reload Bonus two hours before their last bet, and that last bet becomes the bonus-funded bet. They claim the bonus, bet once and leave. A bonus counts as abused when the player places no other bet in the 7 days after the bonus-funded bet. Bonus-funded bets placed in the last 7 days before the reference date are excluded, because their window has not closed yet (censoring). Result: 6 of 52 eligible bonuses (11.54%). Five are the designed cases. The sixth is a false positive: player 24 paused for 7 days and 1 hour, then returned. This boundary effect is a known limitation of a fixed window; a production system would combine the time window with other behavioral signals.