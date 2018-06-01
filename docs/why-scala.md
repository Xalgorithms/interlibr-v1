# Context

Originally, much of the prototyping of Interlibr was done in Ruby
using a number of frameworks (Rails, Sinatra, etc). When development
of the core platform called Interlibr was started (Fall 2017), the
SMACK collective of technologies was selected as the basis of the
platform. Public services were written in Ruby + Sintra and internal
services (Spark jobs) were written in Scala.

Over time, it became apparent that Scala would dominate the platform
development. Therefore, the team decided that the **majority** of the
platform would *eventually* be written in or moved to Scala. The only
service that would remain in Ruby would be the [revisions
service](https://github.com/Xalgorithms/xadf-revisions) due to a
reliance on the Rugged gem.

# Status

| Project                                                               | Status      |
| --------                                                              | ---------   |
| [xadf-jobs](https://github.com/Xalgorithms/xadf-jobs)                 | Complete    |
| [rules-interpreter](https://github.com/Xalgorithms/rules-interpreter) | Complete    |
| [xadf-schedule](https://github.com/Xalgorithms/xadf-schedule)         | In Progress |
| [xadf-events](https://github.com/Xalgorithms/xadf-events)             | Scheduled   |
| [xadf-query](https://github.com/Xalgorithms/xadf-query)               | Scheduled   |
| [xadf-revisions](https://github.com/Xalgorithms/xadf-revisions)       | Complete    |
