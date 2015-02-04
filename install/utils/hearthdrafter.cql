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
  card_name text PRIMARY KEY,
  id text,
  cost int,
  type text,
  rarity text,
  playerClass text,
  synergy map<text, float>,
  attack int,
  health int,
  race text,
  mechanics list<text>
);

/*class specific card scores*/
CREATE TABLE IF NOT EXISTS class_card_score (
  class_name text PRIMARY KEY,
  card_score map<text, int>
);

/*allows each user to define adjustments on a class tier list*/
CREATE TABLE IF NOT EXISTS user_cards (
  user_name text,
  class_name text,
  card_score map<text, int>,
  PRIMARY KEY(user_name, class_name)
);

/*allows for users to modify synergies*/
CREATE TABLE IF NOT EXISTS user_synergies (
  user_name text,
  card_name text,
  synergy map<text, float>,
  PRIMARY KEY(user_name, card_name)
);

/*misc user settings will be created as needed*/
CREATE TABLE IF NOT EXISTS user_settings (
  user_name text
  //settings added dynamically
)

/*arena histories*/
CREATE TYPE IF NOT EXISTS cards_3 (
  card_1 text,
  card_2 text,
  card_3 text
);
CREATE TABLE IF NOT EXISTS cards_chosen (
  user_name text,
  selection map<frozen <cards_3>, text>,
  tid timeuuid,
  PRIMARY KEY(user_name, tid)
);
