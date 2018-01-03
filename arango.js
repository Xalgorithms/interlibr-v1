const name = "xadf";
db._createDatabase(name);
db._useDatabase(name);

db._createDocumentCollection("rules");

db._collection("rules").truncate();
db._collection("rules").save({ 
    "_key" : "d98c0556-af10-42e6-a94c-0fd7af754a68", 
    "_id" : "rules/d98c0556-af10-42e6-a94c-0fd7af754a68", 
    "_rev" : "_WDR24-u---",
    "rule_id" : "RLcs303f",
    "version" : "1.2.33",
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

db._createDocumentCollection("invoices");
db._collection("invoices").truncate();

db._collection("invoices").save(
{
  "items":[
     {
        "id": "111",
        "price": {
           "value": 100,
           "currency_code": "AMD"
        },
        "quantity": {
           "value": 100,
           "unit": "AMD"
        },
        "pricing": {
           "orderable_factor": 100,
           "price": {
              "value": 100,
              "currency_code": "AMD"
           },
           "quantity": {
              "value": 100,
              "unit": "AMD"
           }
        }
     }
  ],
  "envelope": {
    "issued": "",
    "country": "CA",
    "region": "Ontario",
    "party": "committer",
    "period": {
      "timezone": "",
      "starts": "",
      "ends": ""
    }
  }
}
)