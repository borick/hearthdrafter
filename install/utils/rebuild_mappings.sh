#!/bin/bash

URL=http://localhost:9200/hearthdrafter?pretty

echo Deleting...
curl -XDELETE $URL
echo Rebuilding...
curl -XPUT $URL -d @hearthdrafter.json
