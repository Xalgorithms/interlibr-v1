# Summary

As documented in detail elsewhere, the projects managed by the
Foundation fall into four high-level categories:

- [Lichen](https://github.com/orgs/Xalgorithms/teams/lichen): A UBL
  document processing system that sends business documents to the XADF
  for rule discovery and execution. This categories includes web and
  mobile applications that interact with Lichen document services.
  
- [XAlgo](https://github.com/orgs/Xalgorithms/teams/common): A
  high-level declarative language for specifying rules that operate on
  hierarchical documents (JSON-like).

- [XADF](https://github.com/orgs/Xalgorithms/teams/xadf): The XA Data
  Fabric - A compute service that performs rule discovery and
  execution for using the XAlgo specification.
  
- [XalgoAuthor](https://github.com/orgs/Xalgorithms/teams/xalgoauthor):
  A Jupyter-based authoring interface for tables and rules used by the
  XADF.
  
# Active Projects

| Name                  | Category      | Language   | Core Technologies | Description                                                                                                    |
|-----------------------|---------------|------------|-------------------|----------------------------------------------------------------------------------------------------------------|
| general-documentation | Documentation | Markdown   |                   | Shared documentation used in each category                                                                     |
| xa-assembly           | Common        | YAML       | Docker            | Tools and and Dockerfiles for common shared containers                                                         |
| xa-rules              | Common        | Ruby       | Parslet           | Common library for parsing XAlgo rules.                                                                        |
| xa-ubl                | Common        | Ruby       |                   | Common library for parsing UBL documents.                                                                      |
| xadf-jobs             | XADF          | Scala      | Spark, Kafka      | The core functionality of the Data Fabric. Includes jobs that implement the [pipeline process](./pipeline.md). |
| xadf-deploy           | XADF          | Ruby, YAML | Docker            | Deployment and testing scripts / tools for the XADF                                                            |
| xadf-revisions        | XADF          | Ruby       | Sinatra           | Monitors GitHub (or other SCM systems) for new rules added by the Authoring UI                                 |
| xadf-schedule         | XADF          | Ruby       | Sinatra           | Part of the public API for the XADF. External requests for process are asynchronously submitted here.          |
| general-examples      | XADF          | XAlgo      |                   | Common examples demonstrating the Fabric                                                                       |
| xadf-query            | XADF          | Ruby       | Sinatra           | Service offering public API for retrieving data synchronously from the Fabric.                                 |
| xadf-respond          | XADF          | Javascript | NodeJS            | A WebSocket service that outputs notifications related to submitted requests                                   |
| documents-service     | Lichen        | Ruby       | Grape             | A webservice used by the Lichen applications to process UBL and submit it to the Fabric                        |
| lichen-deploy         | Lichen        |            |                   | Deployment tooling for Lichen applications                                                                     |





