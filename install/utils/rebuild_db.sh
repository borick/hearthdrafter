echo 'Rebuilding db...'
echo 'DROP KEYSPACE hearthdrafter;' | cqlsh
cqlsh < hearthdrafter.cql
echo 'Loading cards...'
./card_loader.pl
echo 'Done.'
