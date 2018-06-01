# Summary

This document explains the format of rules in XALGO 0.2.0. It includes
the textual representation of the rule as well as the prescribed
layout of rules as stored in Git repositories. Included with this
explanation is a high-level explanation of rule storage in the XADF.

# Components of Rule Packages

## Packaging

Rules operate on *JSON documents*. For the initial release of the
XADF, these documents are refined JSON representations of UBL
documents.

Rules are packaged and distributed using Git repositories. The
repository must follow a specific layout with specific naming
conventions. Each top-level directory in the repository represents a
single *rule package*. A single rule package is made up of three types
of files:

- *Package*: This is a single file that contains metainformation about
  the package including rule versions, effective dates and
  jurisdications. It **must be** named <ns>.package where <ns> is the
  name of the directory that constitutes the particular rule
  package. The format of this file is described in the next section.

- *Table*: This is a file that contain tabular data that may be specific
  to a single rule, or that may be used by two or more rule packages. A table
  is stored in CSV format. The file name **must be** in the format
  <name>.table, and must correspond to an entry in at least one .package file.

- *Rule*: This is a series of map/reduce steps to be performed on a single
  document. A rule is stored in the *XALGO expression language*. The
  file name **must be** <name>.rule, and must correspond to an entry in at least one the
  .package file.

## Package meta data format

The package file follows this format:

```
{
  "rules" : {
    // we assume this corresponds to a rule file in this directory
    // called 'foo.rule'
    "foo"    : {
      // a specifically generated identifier documented in the
      // entity id section
      "id" :      "RLcs303f",
      // version of this rule (http://semver.org)
      "version"   : "1.2.33",
      // ISO-8601 datetimes for when this rule should be applied
      // these require UTC offsets (see effective section)
      "effective" : [
        // timezone: tz style or abbrev
        { "timezone": "AST", "starts" : "2007-04-05T12:30", "ends" : "2008-04-05T12:30" }
      ],
      "jurisdiction" : {
        // ISO 3166-1 (alpha2, alpha3 or numeric)
        "country" : "CA",
        // ISO 3166-2 - must be valid in the country
        "region"  : "QC"
      },
      // specific XA requirements (see section on XA requirements)
      "xa" : {
        "version", "1.2.33"
      },
      // (see section on criticality)
      "criticality" : "high",
      // canonical URL where the source of the this rule/table is retained
      // if missing, generated from the repo URL
      "url" : "",
      // see section on roles
      "roles" {
        "manager" : {
          "name"  : "",
          "email" : "",
          "url"   : ""
        },
        "author" : {
          "name"  : "",
          "email" : "",
          "url"   : ""
        }
        // generated from repository metadata, reproduced here for
        // clarity based on the roles section
        "committer" : {
          "name"  : "",
          "email" : "",
          "url"   : ""
        }
      }
    }
  },
  "tables" : {
    "foo" : {
      // same
    }
  }
}
```

As illustrated in the example's comment lines, the file is a map of
component type and name to meta data that applies to the similarly
named file in the same direction. Everything specified in this file is
**mandatory** with the exception of the committer role that is
generated based on the latest commit referencing this file in the
repository.

### Rule Id

Rules and tables have a **very particular** identification scheme used
to provide a unique id for the component. This id *includes*
information about the component so that some minor decisions can be
made knowing only the id. The scheme is structured as follows:

- [0]: The first character in the id denotes the type of entity. It
  can be either S, R or T (signifying System, Rule or Table)

- [1-23]: A monotonically increasing ordinal, left-padded with zeros
  and stored as a string.

*This identifier is optional*. If not present it will be added by the
authoring system described below. The six characters will be derived
from the name of the notebook, unless the resulting string is already in use.

### Rule Version

The rule version should follow [SemVer](http://semver.org). *This
value is optional*. If it is not present, it will be derived from the
release tag.

### Effective times

The effective times section of the component meta information
indicates a time period when the component is valid for use. Outside
of this period, the rule **will not** be applied to documents. These
times are expressed in **local time** with an attached time zone
(using a common abbreviation or the [IANA tz
database](https://www.iana.org/time-zones) specifier). Since a
juridiction may include *multiple* time zones, this field allows
specifying multiple effective dates.

### Jurisdication

The *jurisdiction* of a component is specified with a combination of
ISO-3166-1 and ISO-3166-2 codes. Both fields are optional. To make the
rule **apply globally**, the jurisdication key should be omitted from
the meta information.

### Criticality

A component can indicate criticality. Typically, this will control the
ordering of the rule against other rules of higher or lower
criticality. Valid values are

- *imperative*: Must always be active
- *business*: Must be active to uptime guaranteed tolerances
- *experimental*: May be deactivated to support business and
  imperative requirements

### Roles

The meta information specifies three roles:

- *manager*: This is a person responsible for the applied section of
  the rule. For example, they may be a public servant in the taxation
  department of a government.
  
- *author*: This is a person primarily responsible for the ongoing
  correctness of the *rule's implementation*.
  
- *committer*: The last person to make a change to this
  component. This is not specified in the meta information, it will be
  generated when the rule is updated.


## XALGO 0.2.0 Expressions

Rules are represented using the syntax of the XALGO 0.2.0 expression
language. This is so that there is an easily readable version of the
rule's logic retained somewhere in the system. It is this format that
should be committed to the rule package git repository. Other tools
may represent the rule in this format or they may present the rule
differently, depending on the representation needs of that tool.

```
# rule only applies to invoices
WHEN envelope:type == 'invoice';

# rule only applies to suppliers in the consumer petrol industry
WHEN envelope:parties.supplier.industry.code.value == 'G4711';

# rule only affects items that are petrol products (non-wholesale) as
# classified using the UNSPSC scheme
WHEN item:classification.code.list_name == 'UNSPSC';
WHEN item:classification.code.value == '506505';

# empty sales are not affected
WHEN item:quantity.value > 0;

REQUIRE TA_gas_qc_distances INDEX [EffectiveUserID] AS distances;
REQUIRE TA_gas_qc_reductions INDEX [2R3(a)_Distance] AS reductions;

# build a table of reductions that are relevant to the supplier in the invoice
ASSEMBLE seller_reductions
  # table is implied by FROM + @
  COLUMN distance FROM table:distances WHEN envelope:parties.supplier.id.value == @EffectiveUserID
  # distance is automatically understood as the previously created distance column (it's a name in this scope)
  COLUMN reduction FROM table:reductions WHEN distance <= @2R3a_Distance;

# build a table derived from the items table in the invoice that
# includes a price reduction calculation
# what does items mean in this case
# currently we are suggesting that there's a default table called items...
MAP table:items
 USING price_reduction = multiply(@quantity.value, subtract(@price.value, first(table:seller_reductions).reduction)));


# indicate a revision of the document
REVISE table:items
 USING @price.value = subtract(@price.value, @price_reduction);
```

Generally, the statements in an XALGO rule fall into specific categories:

- *refining the applicability of the rule*: The effectiveness and
  jurisdication of a rule are high-level constructs used to broadly
  reduce the rule search space. Using *WHEN* statements *inside* the
  specification of the rule, an author can more specifically tune the
  applicability. These can apply to the *envelope* of a document or
  specific predefined *parts* of the document (in this example, the
  items of an invoice).
  
- *assembling tables*: A rule is provided with predefined tables, but
  it may also need to build more computing tables based on the input
  document. These are built in memory during the computation phase of
  the rule and referenced by name.
  
- *map/reduce*: These are statements that expand or refine tabular
  data during the computation of the rule.

- *revision*: These are explicit statements about with computed data
  should be output into the new document revision.

# Storage

The full content of rules and tables are stored in the XADF document
database. Information related to rule matching and inference is stored
in Cassandra. Further details about this and the matching logic are
available in [data storage](data.storage.md).

# Authoring with Jupyter

## Structure

Rules and tables (as rule packages) are edited in [Jupyter
notebooks](http://jupyter.org/) alongside informational documentation
about the rule package. A single Jupyter notebook represents an entire
rule package. To support this relationship, we will add kernels and UI
to the core Jupyter project and host an instance of the system
alongside the XADF. This will be built on
(JupyterHub)[https://jupyterhub.readthedocs.io/en/latest/]. Notebooks
created in this instance will be persisted to GitHub repositories as
rule packages (described above).

When creating a notebook using the project's instance of JupyterHub,
the notebook will be required to contain a reference to a GitHub
repository. When the notebook is saved, it will be committed (or
updated) in the root of the repository. A directory with the same name
as the notebook will also be created. This directory will contain the
rule package that is associated with the notebook. Any rules or tables
that are created within the UI of the notebook will be persisted in
this directory and **merely referenced** from within the
notebook. Based on information captured using UI extensions, the
packaging data will also be updated in the rule package. This includes
versioning, selection of effective dates, selection of jurisdictions
and assignment of roles. The roles themselves will be associated with
users from the original JupyterHub instance.

## Authoring and Publishing

Any user of the XA Authoring environment based on JupyterHub will be
automatically allocated a *sandbox* for editing the notebook, tables
and rules. This environment will be preserved as a specially named
*branch* in GitHub. As the author makes changes to the package or its
contents, changes will be *comitted* to their sandbox branch. The
package on such a branch can be deployed to a *sandbox* within the
Fabric (see Execution) with the same name as the author's snadbox
branch. When they want to *publish* these changes to the *official*
version of the package, the branch will be *merged* into the *master*
branch of the repo and a new version tag (this is the version of the
**entire repository**) will be created. This publication will trigger
a *rebuild* of the package within the Fabric.

In addition to the master branch of the repo, there will exist a
*development* branch that an author can optionally select as a target
for their changes. This is a fully functional edition of the rule
package running *live* on the Fabric with precisely the same
capabilities as a *production* version published on the *master*
branch. The *development* branch has some differences from the
*master* (or *production*) branch:

- incoming documents must be *specifically targeted* to run using
  rules from the branch

- references to tables within a rule in the package will automatically
  use the *development* version of the referenced table even if there
  is a production version of the table with the same version

# Rules on the Fabric

## Deployment

As described above, Rule packages are deployed to the Fabric when a
merge occurs on the *master* branch of the repository. The deployment
steps are:

1. *Revisions Service* detects a merge and pulls the branch from
   GitHub

1. For all rules or tables in the package that have updated versions,
   new versions are added to the document database; any package-level
   data is updated
   
1. The job processing tables in Cassandra are updated

As soon as this deployment is completed, incoming documents will be
processed using the latest versions of the rules.

## Sandboxes

If a user would like to test their rules, the XADF will provide a
*sandbox environment* on the Fabric. This will allow the user to run
their rules against simple input documents. To isolate the changes
that the user is testing in their sandbox, GitHub branches will be
used. When the user is happy with their changes, they will be able to
merge the sandbox into the master branch of the GitHub repository **as
a new version**.

An author's *default sandbox* branch can always be deployed to the
Fabric for testing in this manner. The sandbox on the Fabric will
automatically have the same name.

Additional UI will be added to JupyterHub to support selecting and
deploying sandboxes.

## Targeted Execution

When documents are submitted to the [Schedule Service](./arch-2.0.md),
they are processed by rules that have been published as
*production*. In order to properly use the sandboxes described
previously, rule authors will be able to target *development* or
*sandbox* branches. When targeting sandbox branches, they will also be
able to bypass the rule filtering aspects of the pipeline by
specifying the *precise* rule that they would like to execute.

## Telemetry

To assist in debugging and development, all aspects of processing on
the Fabric will be available to roles specified in a rule
package. This will incude:

- when and why a rule was marked as *effective* or *applicable*

- the full execution context for any execution of the rule, at every
  step of the rule

- the revisions made to a document (some redaction may be required)

# Syntax

A rule is a set of statements that include preconditions (or *whens*)
and a series of steps to perform during the execution. This section
documents the syntax of the textual representation of the rule
language. It is broken into sections that correspond to the *phases*
of the rule's execution (see [pipline](./pipeline.md) for more
details).

During rule execution, a single in-memory, *virtual* table is
retained. For example, if a ``MAP`` is executed, the result of that
``MAP`` is in this virtual table.

## Common elements

### Expressions

The specifications of the statements below include some common
expressions:

- ``<name>``: a simple variable name (must be [a-zA-Z0-9_])

- ``<key>``: a path of dot separated names denoting hierarchy within
  data (aka JSON paths)

- ``<value>``: an immediate value; either a string ('') or a number

- ``<reference>``: a reference to some data in the execution context;
  it should have the forms:

  - ``<section>:<key>`` to refer to some preserved section in the
    context

  - ``@<key>`` to refer to something in the *current statement* (for
    example the columns in a table during a MAP)
    
  - ``$`` to refer to the current *virtual table*

- ``<operator>``: an operator symbol (see *operators*)

- ``<compute_expression>``: a set of calls to formulae in a recursive
  style (for example: ``multiply(add(a, b), subtract(c, d))``) or a
  simple ``<reference>``

- ``<table_reference>``: a reference to a specific table in the Fabric
  using the rule_id format

### Sections

- ``envelope``: Refers to the envelope section of the ingested
  document. This is **not** a table, so it cannot be use as a source
  in ASSEMBLE, MAP or REDUCE. This section is *retained* after
  execution.

- ``item``: Refers to the table of items in the ingested
  document. This section is *specifically named* and not in the table
  section so that it may be used in WHEN statements. When working with
  items in table-oriented statements (MAP, REDUCE), the reference
  **must be** ``table:items``.
  
- ``table``: Refers to any of the *named tables* assembled during the
  rule execution or preloaded before execution. The items in the
  document are preloaded as ``table:items`` as are any table mentioned
  with ``REQUIRE``. The ``table:items`` section is *retained* after
  execution and will be used to generate a revision.

## Conditions of execution

Statements in this section all rule authors to specific conditions
that will control whether or not the rule is executed given conditions
in the ingested document.

### WHEN

```WHEN <reference> <operator> <value>;```

The *WHEN* statement is used to specify the conditions that will
indicate applicability of the rule to a document *or* an item in the
body of the document. This information is used to indicate that
documents would effectively not generate revisions of the document.

This statement **must use** either the ``envelope`` or ``item``
section in the context.

### REQUIRE

```REQUIRE <table_reference> (INDEX [(<name>)+])? (AS <name>)?```

Instructs the Fabric to preload a specific table from the Fabric
*before* executing this rule. This statement may *optionally* include
a list of columns to index. The table will be available in the
execution context *table* section during rule execution. If the AS
component is specified, then this will set the name of the table in
the section; otherwise, the original table name in the reference will
be used.

## Assembling in-memory tables

### ASSEMBLE

```ASSEMBLE <name> (COLUMN <name> AS <name> FROM <reference> WHEN <reference> <operator> <reference>)+```
```ASSEMBLE <name> (COLUMNS FROM <reference> WHEN <reference> <operator> <reference>)+```

Rule authors will require dynamic, in-memory tables derived from
preloaded, computed or document data. This statement controls the
construction of such a table. The ``<name>`` element of the statement
will be the final name of the table in the ``table`` section.

Authors may specific *one or more* named columns to appear in the
final table. These columns are derived from earlier references in the
context that resolve to a table (therefore, the ``envelope`` section
is excluded). By default, the name of the column in the assembled
table is the *same as the column in the referenced table*, but the
``AS`` expression may be used to change the name in the assembled
table. If **all** columns from the source table are required, then use
the ``COLUMNS`` alternate syntax.

The ``WHEN`` expression is used to specific which rows from the source
table are used. It is very similar to an SQL WHERE expression.

### KEEP

```KEEP <name>```

At any time, the author may choose to preserve the current *virtual
table* represented by ``$`` in the execution context. When this is
done, the virtual table is retained until the next modifying statement
but the state of the table at the time of the ``KEEP`` is available in
``table:<name>``.

## Map/Reduce

### MAP

```MAP <reference> (USING <name> = <compute_expression>)+```

Where the ``ASSEMBLE`` statement is use to create new tables, this
statement is used to transform them. Therefore, it is a sequence of
one or more ``USING`` expressions that reference a
``compute_expression``. The formulae in the expression are used to
***add or replace*** columns to the table, linearly. If ``<name>`` is
an existing column in the table, it will be replaced. The result of
this statement is a new **virtual table**.

### REDUCE

*Work in progress*

### FORMULA

This statement will be used to define rule-specific formulae. It is a
*work in progress*.

## Revisions

### REVISE

```REVISE <reference> (USING <name> = <compute_expression>)+```

This statement is used to specify a *permanent change* to the
``<reference>``. The section in the reference **must be** a section
that is *retained after rule execution*. The form of this statement
matches that of the ``MAP`` statement.
