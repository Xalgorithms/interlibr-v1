const name = "xadf";
db._createDatabase(name);
db._useDatabase(name);

db._createDocumentCollection("rules");

db._collection("rules").truncate();
db._collection("rules").save({ 
    "_key" : "d98c0556-af10-42e6-a94c-0fd7af754a68", 
    "_id" : "rules/d98c0556-af10-42e6-a94c-0fd7af754a68", 
    "_rev" : "_WDR24-u---", 
    "items" : [ 
      [ 
        { 
          "whens" : { 
            "envelope" : [ 
              { 
                "expr" : { 
                  "left" : { 
                    "type" : "key", 
                    "value" : "type" 
                  }, 
                  "right" : { 
                    "type" : "string", 
                    "value" : "invoice" 
                  }, 
                  "op" : "eq" 
                } 
              } 
            ] 
          } 
        }, 
        { 
          "whens" : { 
            "omega" : [ 
              { 
                "expr" : { 
                  "left" : { 
                    "type" : "key", 
                    "value" : "x.y.z" 
                  }, 
                  "right" : { 
                    "type" : "number", 
                    "value" : "2" 
                  }, 
                  "op" : "lte" 
                } 
              } 
            ] 
          } 
        } 
      ] 
    ] 
} );
db._collection("rules").all().toArray();