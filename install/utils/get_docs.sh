curl http://localhost:9200/$1/$2/_search?pretty=true -d '
{ 
    "query" : { 
        "match_all" : {} 
    },
    "_source":"*",
    "size": 999999999,
    "fields": []
}
'
