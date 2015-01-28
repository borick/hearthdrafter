echo 'Rebuilding db...'
echo 'DROP KEYSPACE hearthdrafter;' | cqlsh
cqlsh < hearthdrafter.cql
echo 'Done.