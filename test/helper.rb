# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path('..', __dir__))

require 'test-unit'
require 'fluent/test'
require 'fluent/test/driver/filter'
require 'fluent/test/driver/output'
require 'fluent/test/helpers'

Test::Unit::TestCase.include(Fluent::Test::Helpers)
Test::Unit::TestCase.extend(Fluent::Test::Helpers)

require 'test/fixtures/fixture'

Test::Unit::TestCase.include(Test::Fixture)

# simulate *AuditLogMetric fluent plugin as a conf element only
FakeAuditLogMetricConf = Struct.new(
  :tag, :categories,
  :category_key, :layer_key, :request_type_key, :cluster_key,
  :user_key, :indices_key, :r_indices_key, :timestamp_key, :privilege_key,
  :timestamp_format, :prefix, :aggregate_ilm
) do
  def initialize(tag: 'test_metric', categories: ['GRANTED_PRIVILEGES'],
                 category_key: 'audit_category', layer_key: 'audit_request_layer',
                 request_type_key: 'audit_transport_request_type', cluster_key: 'audit_cluster_name',
                 user_key: 'audit_request_effective_user', indices_key: 'audit_trace_indices',
                 r_indices_key: 'audit_trace_resolved_indices', timestamp_key: '@timestamp',
                 privilege_key: 'audit_request_privilege',
                 timestamp_format: :iso, prefix: '', aggregate_ilm: true)

    super(tag, categories,
          category_key, layer_key, request_type_key, cluster_key,
          user_key, indices_key, r_indices_key, timestamp_key, privilege_key,
          timestamp_format, prefix, aggregate_ilm)
  end
end
