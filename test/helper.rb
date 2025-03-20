# frozen_string_literal: true

require 'simplecov'

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new(
  [SimpleCov::Formatter::HTMLFormatter]
)

SimpleCov.start do
  add_filter '/test/'
end

$LOAD_PATH.unshift(File.expand_path('..', __dir__))

require 'test-unit'
require 'fluent/test'
require 'fluent/test/driver/filter'
require 'fluent/test/driver/output'
require 'fluent/test/helpers'

Test::Unit::TestCase.include(Fluent::Test::Helpers)
Test::Unit::TestCase.extend(Fluent::Test::Helpers)

require 'timecop'
require 'mocha/test_unit'

require 'test/fixtures/fixture'

Test::Unit::TestCase.include(Test::Fixture)

# simulate *AuditLogMetric fluent plugin as a conf element only
FakeAuditLogMetricConf = Struct.new(
  :tag, :categories,
  :category_key, :layer_key, :request_type_key, :cluster_key,
  :user_key, :indices_key, :r_indices_key, :timestamp_key, :privilege_key,
  :rest_request_path_key, :request_body_key,
  :timestamp_format, :metadata_prefix, :aggregate_index_clean_suffix, :aggregate_interval
) do
  def initialize(tag: 'test_metric', categories: %w[GRANTED_PRIVILEGES FAILED_LOGIN],
                 category_key: 'audit_category', layer_key: 'audit_request_layer',
                 request_type_key: 'audit_transport_request_type', cluster_key: 'audit_cluster_name',
                 user_key: 'audit_request_effective_user', indices_key: 'audit_trace_indices',
                 r_indices_key: 'audit_trace_resolved_indices', timestamp_key: '@timestamp',
                 privilege_key: 'audit_request_privilege', rest_request_path_key: 'audit_rest_request_path',
                 request_body_key: 'audit_request_body',
                 timestamp_format: :iso, metadata_prefix: '',
                 aggregate_index_clean_suffix: [],
                 aggregate_interval: nil)
    super(tag, categories,
          category_key, layer_key, request_type_key, cluster_key,
          user_key, indices_key, r_indices_key, timestamp_key, privilege_key,
          rest_request_path_key, request_body_key,
          timestamp_format, metadata_prefix,
          aggregate_index_clean_suffix, aggregate_interval)
  end
end
