echo 'Rebuilding db...'
echo 'DROP KEYSPACE hearthdrafter;' | cqlsh
cqlsh < hearthdrafter.cql
echo 'Loading cards...'
./reload_cards.pl
echo 'Done.'
