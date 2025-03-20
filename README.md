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
* rest_request_path_key: Rest request path key in input record
* request_body_key: Request body key in input record

parameters for output metric:
* timestamp_format: Timestamp format (iso, epochmillis, epochmillis_str)
* metadata_prefix: Metadata prefix for output metric

parameters to aggregate metrics:
* aggregate_index_clean_suffix: pattern to clean on index, to aggregate events
* aggregate_interval: aggregate metrics by time interval, to reduce count of emitted events

More details from the
[elastic_audit_log_metric output plugin code](lib/fluent/plugin/out_elastic_audit_log_metric.rb#L49)


produces metrics:

| from category      | metric_name        | purpose                                             |
|--------------------|--------------------|-----------------------------------------------------|
| GRANTED_PRIVILEGES | user_query_count   | Query count made by users                           |
| GRANTED_PRIVILEGES | index_query_count  | Query count made by index / index pattern with user |
|--------------------|--------------------|-----------------------------------------------------|
| FAILED_LOGIN       | failed_login_count | Count failed login by users without index           |


Categories are :

| Category           | Meaning                                                                         |
|--------------------|---------------------------------------------------------------------------------|
| FAILED_LOGIN       | Indicates unsuccessful authentication attempts (~ 401)                          |
| MISSING_PRIVILEGES | Occurs when a user attempts an action without the necessary permissions (~ 403) |
| BAD_HEADERS        | Triggered by requests containing malformed or invalid headers                   |
| SSL_EXCEPTION      | Relates to issues with SSL/TLS connections, such as handshake failures.         |
| AUTHENTICATED      | Records successful user authentications                                         |
| GRANTED_PRIVILEGES | Logs instances where users are granted specific privileges                      |


## Installation

Manual install, by executing:

    $ gem install fluent-plugin-elastic-log

Add to Gemfile with:

    $ bundle add fluent-plugin-elastic-log


## Compatibility

plugin in 1.x.x will work with:
- ruby >= 2.7.0
- fluentd >= 1.8.0

see [gemspec](fluent-plugin-elastic-log.gemspec).


## Copyright

* Copyright(c) 2023-2025 Thomas Tych
* License
  * Apache License, Version 2.0
