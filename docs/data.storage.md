# Summary

This document explains the internal data storage of rules and
tables. It also explains the mechanisms for matching rules against
input documents. This is related to the [processing
pipeline](pipline.md).

The [XA Data Fabric](./arch-2.0.md) implements a heterogeneous data
storage services layer for optimized storage and query capabilities 
across differing functional contexts.

For *persistence-optimized* storage, the system employs
[MongoDB](https://en.wikipedia.org/wiki/MongoDB). This provides for 
storage of documents, tables and rules in a document-oriented format. 
Its data model is *very close* to the format in which the data is
submitted to the system (discrete documents).

For *query-optimized* storage, the system employs [Cassandra](https://en.wikipedia.org/wiki/Apache_Cassandra). Generally,
the queries originate from Spark jobs that form the [core processing
pipline](./pipeline.md). Data that is originally submitted via the
[schedule
service](https://github.com/Xalgorithms/xadf-schedule-service) and that is
critical to the performance of the Spark jobs will be stored in one or
more [CQL](https://cassandra.apache.org/doc/latest/cql/) tables. The Spark jobs will generally use data from
these tables to perform computations; only fetching from Mongo when
detailed information about a document, table or rule is required.

# Mongo structure

## Documents

UBL documents submitted to Lichen are transformed into a *common
format* and sent to the XA Data Fabric via the Schedule service. These
documents are stored *as-is* in the MongoDB as part of the *documents*
collection.

## Rules and Tables

When the [Revisions
service](https://github.com/Xalgorithms/xadf-revisions-service)
determines that new *rules* or *tables* have appeared, then they are
parsed and stored in MongoDB as intermediate formats in the *rules*
and *tables* collections, respectively. The intermediate format for
rules is the output from the [rules
parser](https://github.com/Xalgorithms/xa-rules). Tables are stored as
a JSON-like version of the CSV that was originally stored in the
package repository.

# Cassandra structure

The structure of tables in Cassandra will be determine by the types of
queries that will be needed to satisfy the Spark Jobs in the data
processing pipeline. Currently, these Jobs are:

1. Determining which rules are valid and effective in the
   jurisdiction of a document. These are called the *effective*
   rules.
   
1. Filtering the effective rules based on envelope data in the
   document. These are called *applicable* rules.
   
## Document envelopes

For every document submitted to the XADF, there exists an *envelope*
that describes meta-data about the document itself. This includes
parties in the transaction, dates, etc. This envelope data is used to
determine [efficacy](./pipeline.md). Rather than fetching and
reorganizing the data that could be retrieved from MongoDB (the
envelope is *part* of the document), we store a simple table in
Cassandra:

* *document_id*: The public_id of the document stored in MongoDB
* *party*: One of "supplier", "customer", "payee", "buyer", "seller" or "tax"
* *country*: An ISO-3166-1 country code for the referenced party
* *region*:  An ISO-3166-2 region code for the referenced party
* *timezone*: The IANA tz identifier for the jurisdiction of the transaction
* *issued*: The effective issuing date and time for the document

## Effective rules

When new or updated rules are stored in the ArangoDB, this will cause
rows to be added or updated in the *effective* table in
Cassandra. This table has these columns:

* *rule_id*: A reference to the the rule as stored in ArangoDB
* *country*: An ISO-3166-1 country code (*null* if the rule applies in **all** jurisdications)
* *region*:  An ISO-3166-2 region code (*null* if the rule applies to **all** regions in the country)
* *timezone*: An IANA tz identifier
* *starts*: A date and time in *local time* indicating when the rule takes effect
* *ends*: A date and time in *local time* indicating when the rule ceases to take effect
* *party*: One of "supplier", "customer", "payee", "buyer", "seller", "tax" or "any"

## Applicable rules

To determine applicable rules, we use two tables in Cassandra. The use
of these tables is described in [processing pipeline](pipline.md).

We have one table which records **all** sections and keys that have
been used in submitted rules (in *WHEN* statements) to specify
applicability. The data in this table is used to prefilter envelope
data from an ingested document. It has these columns:

* *section*: The name of the document section that pertains to this
  condition.

* *key*: A dotted-path key that references a key in a section
   (eg. parties.seller.name, currency, period.starts...)
  
A second table will be used to record all conditions that a rule
should match:

* *rule_id*: A reference to the the rule as stored in ArangoDB

* *section*: The name of the document section that pertains to this
  condition.
  
* *key*: A dotted-path key that references a key in a section
   (eg. parties.seller.name, currency, period.starts...)
  
* *operator*: An envelope filter operator (see syntax for *WHEN* in
  [XALGO-2.0](xalgo-2.0.md].

* *value*: The required value for the *key* given the *operator*
  (stored as a string)
