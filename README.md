# fluent-plugin-elastic-log

[Fluentd](https://fluentd.org/) filter plugin to process elastic logs.

## plugins

### out - elastic_audit_log_metric

process audit logs and transform to metrics.

Example:

``` conf
<match my_tag_pattern>
  @type elastic_audit_log_metric

  tag elastic_audit_log_metric
  timestamp_key timestamp
  timestamp_format epochmillis
  prefix tags_
</match>
```

parameters are:
* tag : Tag to emit metric events

parameters for input record:
* categories: Categories selected to be converted to metrics
* category_key: Category key in input record
* layer_key: Layer key in input record
* request_type_key: Request type key in input record
* cluster_key: Cluster key in input record
* user_key: Request user key in input record
* indices_key: Indices key in input record
* r_indices_key: Resolved indices key in input record
* timestamp_key: Timestamp key in input record
* privilege_key: Request privilege key in input record

parameters for output metric:
* timestamp_format: Timestamp format (iso, epochmillis, epochmillis_str)
* prefix: Attribute prefix for output metric
* aggregate_ilm: Aggregate ILM on resolved indices

More details from the
[elastic_audit_log_metric output plugin code](../blob/master/lib/fluent/plugin/out_elastic_audit_log_metric.rb)

## Installation


Manual install, by executing:

    $ gem install fluent-plugin-elastic-log

Add to Gemfile with:

    $ bundle add fluent-plugin-elastic-log

## Compatibility

plugin in 1.x.x will work with:
- ruby >= 2.4.10
- td-agent >= 3.8.1-0

## Copyright

* Copyright(c) 2023- Thomas Tych
* License
  * Apache License, Version 2.0
