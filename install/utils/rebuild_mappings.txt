#!/bin/bash

URL=http://localhost:9200/hearthdrafter

echo Deleting...
curl -XDELETE "$URL?pretty"
echo Rebuilding...
curl -XPUT "$URL?pretty" -d @hearthdrafter.json
echo Reloading cards...
./reload_cards.pl