#!/bin/bash

URL=http://localhost:9200/hearthdrafter

echo Deleting...
curl -XDELETE "$URL?pretty"
echo Rebuilding...
curl -XPUT "$URL?pretty" -d @hearthdrafter.json
echo Recreating test user...
curl -XPUT "$URL/user/test?pretty" -d '{
    "name" : "test",
    "email" : "test",
    "first_name" : "test",
    "last_name" : "test",
    "password" : "{X-PBKDF2}HMACSHA2+512:AAAnEA:WDWVXCV4W1YKPA==:95KTsQJuGxNNN4RbCM3sSj2RhtkNGD+rEfUQ7BoRjQXj5owtFJSQrHU1aaivQP2bgHUfpaXcXuymwJHEDX5egQ=="
}'
echo Reloading cards...
./reload_cards.pl