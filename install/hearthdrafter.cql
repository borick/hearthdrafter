/* make the db */
CREATE KEYSPACE IF NOT EXISTS hearthdrafter
  WITH REPLICATION = { 'class' : 'SimpleStrategy', 'replication_factor' : 1 };
  
/* then use it */
USE hearthdrafter;

/* for the users */
CREATE TABLE IF NOT EXISTS users (
  user_name text PRIMARY KEY,
  password text,
  email text,
);

/*card info*/
CREATE TABLE IF NOT EXISTS cards (
  id text PRIMARY KEY,
  card_name text,
  cost int,
  type text,
  rarity text,
  playerClass text,
  score int,
  synergy map<text, float>,
  attack int,
  health int,
  race text,
  mechanics list<text>
);

/*adjustments for card scores, based on class*/
CREATE TABLE IF NOT EXISTS card_classes (
  name text PRIMARY KEY,
  card_score_adjustments map<text, int>
);

/*allows each user to define adjustments on a tier list*/
CREATE TABLE IF NOT EXISTS user_cards (
  user_name text,
  tier_list_id timeuuid,
  card_score_adjustments map<text, int>,
  PRIMARY KEY(user_name, tier_list_id)
);

/*allows for players to modify synergies*/
CREATE TABLE IF NOT EXISTS user_synergies (
  user_name text,
  card_name text,
  synergy map<text, float>,
  PRIMARY KEY(user_name, card_name)
);
