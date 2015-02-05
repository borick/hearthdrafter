/* make the db */
CREATE KEYSPACE IF NOT EXISTS hearthdrafter
  WITH REPLICATION = { 'class' : 'SimpleStrategy', 'replication_factor' : 1 };
  
/* then use it */
USE hearthdrafter;

/* for the users */
CREATE TABLE IF NOT EXISTS users (
  user_name TEXT PRIMARY KEY,
  password TEXT,
  email TEXT,
  first_name TEXT,
  last_name TEXT
);

/*card info*/
CREATE TYPE IF NOT EXISTS card (
  name TEXT,
  id TEXT,
  cost INT,
  type TEXT,
  rarity TEXT,
  playerclass TEXT,
  synergy MAP<TEXT, FLOAT>,
  attack INT,
  health INT,
  race TEXT,
  mechanics LIST<TEXT>
);
/*preload the cards for each class*/
CREATE TABLE IF NOT EXISTS class_cards (
  class_name TEXT PRIMARY KEY,
  cards LIST<FROZEN<card>>,
);
CREATE INDEX IF NOT EXISTS class_cards_cards ON class_cards (cards);

/*class specific card scores*/
CREATE TABLE IF NOT EXISTS class_card_score (
  class_name TEXT PRIMARY KEY,
  card_score MAP<TEXT, INT>
);

/*allows each user to define adjustments on a class tier*/
CREATE TABLE IF NOT EXISTS user_cards (
  user_name TEXT,
  class_name TEXT,
  card_score MAP<TEXT, INT>,
  PRIMARY KEY(user_name, class_name)
);

/*allows for users to modify synergies*/
CREATE TYPE IF NOT EXISTS card_synergy (
  card TEXT,
  amount FLOAT,
);
CREATE TABLE IF NOT EXISTS user_synergies (
  user_name TEXT,
  card_name TEXT,
  synergy MAP<TEXT, FROZEN <card_synergy>>,
  PRIMARY KEY(user_name, card_name)
);

/*misc user settings will be created as needed*/
CREATE TABLE IF NOT EXISTS user_settings (
  user_name TEXT,
  key TEXT,
  value TEXT,
  PRIMARY KEY(user_name, key)
);

/*arena histories*/
CREATE TYPE IF NOT EXISTS cards_3 (
  card_1 TEXT,
  card_2 TEXT,
  card_3 TEXT
);
CREATE TYPE card_reward (
  name TEXT,
  rarity TEXT,
  golden BOOLEAN
);
CREATE TABLE IF NOT EXISTS arena_history (
  user_name TEXT,
  selection MAP<FROZEN <cards_3>, TEXT>,
  class TEXT,
  tid TIMEUUID,
  deck_score INT,
  win INT,
  loss INT,
  gold INT,
  dust INT,
  packs INT,
  cards LIST<FROZEN<card_reward>>,
  PRIMARY KEY(user_name, tid)
);
