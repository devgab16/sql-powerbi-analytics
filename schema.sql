CREATE TABLE players (
    player_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(150),
    phone VARCHAR(20),
    city VARCHAR(100),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE providers (
    provider_id SERIAL PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    country VARCHAR(100),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE games (
    game_id SERIAL PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    provider_id INTEGER REFERENCES providers(provider_id),
    rtp NUMERIC(5,2),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE bets (
    bet_id SERIAL PRIMARY KEY,
    player_id INTEGER REFERENCES players(player_id),
    game_id INTEGER REFERENCES games(game_id),
    bet_amount NUMERIC(10,2) NOT NULL,
    payout NUMERIC(10,2) NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE bonuses (
    bonus_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    bonus_amount NUMERIC(10,2) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE player_bonuses (
    player_bonus_id SERIAL PRIMARY KEY,
    player_id INTEGER REFERENCES players(player_id),
    bonus_id INTEGER REFERENCES bonuses(bonus_id),
    granted_at TIMESTAMP,
    is_redeemed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Schema evolution: track which bonus funded a bet
ALTER TABLE bets
ADD COLUMN funded_by_player_bonus_id INTEGER REFERENCES player_bonuses(player_bonus_id);