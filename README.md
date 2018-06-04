# Summary

This is Interlibr - a document-oriented map/reduce platform for the
Internet of Rules. The platform runs on Apache Mesos and is designed
against the SMACK (Spark, Mesos, Akka, Cassandra, Kafka) collective of
frameworks. This platform is [designed](./docs/arch-2.0.md) to retain,
discover and execute [rules](./docs/xalgo.md) against documents
(hierarchical key-value maps or JSON documents).

# Components

The platform is made up of a number of independent services and
support libraries:

| Component                                                    | Category   | Language   | Core Technologies | Description |
|--------------------------------------------------------------|------------|------------|-------------------|-------------|
| [Execute](/Xalgorithms/service-il-execute)                   | service    | Scala      | Akka, Kafka       |             |
| [Events](/Xalgorithms/service-il-events)                     | service    | Javascript | Kafka, WebSockets |             |
| [Schedule](/Xalgorithms/service-il-schedule)                 | service    | Scala      | Play, Akka, Kafka |             |
| [Query](/Xalgorithms/service-il-query)                       | service    | Ruby       | Sinatra           |             |
| [Jobs](/Xalgorithms/service-il-jobs)                         | spark jobs | Scala      | Kafka, Spark      |             |
| [GitHub Revisions](/Xalgorithms/service-il-revisions-github) | service    | Ruby       | Sinatra           |             |
| [Rule Parser](/Xalgorithms/lib-rules-parse-ruby)             | lib        | Ruby       | Parselet          |             |
| [Rule Interpreter (Naive)](/Xalgorithms/lib-rules-int-scala) | lib        | Scala      |                   |             |
