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
// test user
INSERT INTO users (user_name,password) VALUES ('test', '{X-PBKDF2}HMACSHA2+512:AAAnEA:1NG8Y6NGYG8qLw==:G8nT1+a529UFcTyMOv2Ss7mpcT/8QlBfDtmzfN7B5stKreGoXHUKoAK35mZ/6VXJqubdPDmkG3XFVhBLEdqpFw==');

// all the cards
CREATE TABLE IF NOT EXISTS cards (
  name TEXT PRIMARY KEY,
  id TEXT,
  cost INT,
  type TEXT,
  rarity TEXT,
  playerclass TEXT,
  attack INT,
  health INT,
  race TEXT,
  score INT,
  mechanics LIST<TEXT>
) WITH caching = {'keys':'ALL', 'rows_per_partition':'ALL'};
// preload all cards by class
CREATE TABLE IF NOT EXISTS cards_by_class (
  class_name TEXT PRIMARY KEY,
  cards LIST<TEXT>
);

/*allows each user to define adjustments on a class tier*/
CREATE TABLE IF NOT EXISTS user_cards (
  user_name TEXT,
  class_name TEXT,
  key LIST<TEXT>,
  value LIST<TEXT>,
  PRIMARY KEY(user_name, class_name)
);

/*misc user settings will be created as needed*/
CREATE TABLE IF NOT EXISTS user_settings (
  user_name TEXT,
  user_key TEXT,
  user_value TEXT,
  PRIMARY KEY(user_name, user_key)
);

/*arena histories*/
CREATE TABLE IF NOT EXISTS arena_history (
  user_name TEXT,
  selection LIST<TEXT>,
  class TEXT,
  tid TIMEUUID,
  deck_score INT,
  win INT,
  loss INT,
  gold INT,
  dust INT,
  packs INT,
  reward LIST<TEXT>,
  PRIMARY KEY(user_name, tid)
);

/*synergy lookup*/
CREATE TABLE IF NOT EXISTS card_synergy (
  card_name TEXT,
  card_name_has_synergy TEXT,
  reason TEXT,
  PRIMARY KEY (card_name, card_name_has_synergy)
);