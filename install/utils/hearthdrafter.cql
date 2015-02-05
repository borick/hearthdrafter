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

/*preload the cards for each class*/
CREATE TABLE IF NOT EXISTS cards (
  name TEXT PRIMARY KEY,
  id TEXT,
  cost INT,
  type TEXT,
  rarity TEXT,
  playerclass TEXT,
  synergy MAP<TEXT, FLOAT>,
  attack INT,
  health INT,
  race TEXT,
  score INT,
  mechanics LIST<TEXT>
) WITH caching = {'keys':'ALL', 'rows_per_partition':'ALL'};

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
