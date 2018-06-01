# Summary

Document processing in XADF occurs along a *pipeline* of jobs loosely
connected via Kafka topics. Each Job in the pipeline performs a
specific function - similar to a [cloud
function](https://en.wikipedia.org/wiki/Function_as_a_service) - and
submits the results of that function to a subsequent Kafka topic. The
majority of these are implemented as Spark Jobs (therefore we commonly
call all of them *jobs*), but there is no hard requirement that they
must be Spark Jobs. Some of the processors may be implemented in a
different way that could be more suitable to the required work. The
primary Jobs are:

1. Assembling the rules which are valid in a document's jurisdication and efficacy (effective rules)
1. Filtering these rules based on envelope criteria (applicable rules)
1. Loading the tables associated with the rule
1. Running individual rules against the document's table of items

# Effective rules

A rule is *effective* if it matches the jurisdiction (country and
region) specified by a document. The jurisdication will be drawn from
the participating parties in the envelope of the ingested document
(refer to [documents](./documents.md) for this structure). A party
(one of "supplier", "customer", "payee", "buyer", "seller", "tax" or
"any") must be elected for the *effectiveness* of the rule. These
correspond to the [parties in
UBL](http://docs.oasis-open.org/ubl/csprd01-UBL-2.2/mod/summary/reports/UBL-Invoice-2.2.html). The
*any* selector indicates that the rule is effective if **any of the
parties** fall within the rule's jurisdication.

If effective dates and times are specified in the [rule
package](./xalgo.md), then the issued date and time in the document
**must fall within** this effective period.

# Applicable rules

A rule is *applicable* if **all** of the *when conditions* pertaining
to the *envelope* section specified in the rule are met. If there are
no items in the document which would match the *item when conditions*,
then the rule is considering not applicable because it would result in
an empty revision after the application of the rule.

# Effective versus applicable

On first glance, it seems as if *effective* and *applicable* are very
similar and could possibly be expressed in a single manner. Therefore,
we should consider why the two different ideas exist.

The rules that are retained in the Fabric are each entries in a large
ontology classified according to industry, jurisdication, time,
etc. The *effectiveness* of a rule is a form of meta-organization
within this ontology. Authors are able to use this classification to
broadly partition documents that will be processed. Therefore,
*effectiveness* is the classification of a rule.

Each individual rule represents a very small *program* or
*computation*. As part of the expression of this computation, we can
indicate what types of data a rule will modify. Furthermore, we can
base this indication on *values* within the document itself. This is
the *applicability* of a rule.

# Loading required tables

A rule may specify a number of data tables to be loaded into the
execution context of the rule. This will result in *dynamic* tables
being created in Cassandra. These tables will be *named* according to
the name and version of the table specified. The data in the tables
will be loaded from the CSV tables that are stored in ArangoDB when
the rule is published.

The reason that we have decided to *actually import* the table data
into Cassandra (rather than merely load it into memory) is
twofold. First, we feel that the data needs to be truly in-memory
during the rule execution for performance reasons. It is a complicated
process to determine perform this dynamic loading, therefore we have
decided that a distinct Spark Job should be used for this task. Since
there is a distinct job, we require some place to retain this data
between phases. The simplest place to keep it is in Cassandra.

# Execution of rules

When all applicable rules have been discovered and all tables loaded,
a rule will be executed. This will occur in a single Spark Job that
applies all steps from the rule, generating a single revision
resulting from the execution. It is critical that *each* rule
execution lead to a single revision - this will eventually allow the
systems to indicate to a user (or foreign system) *where* a value in
the final revised document originated.

All *steps* specified in the rule are run *in order*, with no
exceptions. This means that a REVISE statement may occur in the
*middle* of a rule's execution. This merely means that the values used
in the revision come from the *execution context* that was valid *at
that time*. The actual revision that is stored against the document is
only generated as the accumulation of *all* REVISE statements *at the
end of the execution* of the rule.

## Execution context

When a rule is executing, there is a special collection of data that
is called the *context*. This is an in-memory data stucture that
preserves all of the data manipulation performed by the rule. It is
divided into *sections* that provide a nominal form of scoping of
data. Further details on how to reference these sections is explaining
in the [xalgo](./xalgo.md) document. The existing sections are:

- *envelope*: the envelope of the document being processed; read-only
- *item*: the current item in the document; read-only
- *tables*: tables that have temporarily been committed during the execution
