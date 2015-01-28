/* make the db */
CREATE KEYSPACE IF NOT EXISTS hearthdrafter
  WITH REPLICATION = { 'class' : 'SimpleStrategy', 'replication_factor' : 1 };
  
/* use it :) */
USE hearthdrafter;

/* users table */
CREATE TABLE IF NOT EXISTS users (
  user_name text PRIMARY KEY,
  password text,
  email text,
);

/*a list of cards*/
CREATE TABLE IF NOT EXISTS cards (
  name text PRIMARY KEY,
  mana int,
  race text,
  score int,
  synergy map<text, float>
);

/*adjustments for card scores, based on class*/
CREATE TABLE IF NOT EXISTS card_classes (
  name text PRIMARY KEY,
  card_adjustments map<text, int>
);

/*allows each user to define adjustments on a tier list*/
CREATE TABLE IF NOT EXISTS user_cards (
  user_name text,
  tier_list_id timeuuid,
  card_adjustments map<text, int>,
  PRIMARY KEY(user_name, tier_list_id)
);

/*allows for the creation of multiple tiers*/
CREATE TABLE IF NOT EXISTS tiers (
  id timeuuid PRIMARY KEY,
  cards map <text, int>
);


