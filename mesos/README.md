These are configuration files for use with Mesos. They have two forms:

- service-*.json: These are public APIs for the Fabric. They should be
  installed with:

```$ dcos marathon app add service-<name>.json```

- *.json: These are Mesos package services. They should be installed
  with:
  
```dcos package install <name> --options=<name>.json```
