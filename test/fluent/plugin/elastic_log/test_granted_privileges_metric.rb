# frozen_string_literal: true

require 'helper'

require 'fluent/plugin/elastic_log/granted_privileges_metric'

# unit tests
class TestGrantedPrivilegesMetric < Test::Unit::TestCase
  setup do
    @conf = FakeAuditLogMetricConf.new
    @record = {
      timestamp: '2023-02-03T04:05:06.777Z',
      privilege: 'indices:data/read/search',
      user: 'test_user',
      cluster: 'TEST_CLUSTER',

      indices: 'test_index_1',
      r_indices: %w[
        test_index_1-000001
        test_index_1-000002
        test_index_1-000003
      ],
      layer: 'TRANSPORT',
      request_type: 'SearchRequest'
    }
  end

  sub_test_case 'time_event' do
    test 'it can generate timestamp as iso format' do
      conf = FakeAuditLogMetricConf.new
      metric = Fluent::Plugin::ElasticLog::GrantedPrivilegesMetric.new(
        record: @record,
        conf: conf
      )

      assert_equal '2023-02-03T04:05:06.777Z', metric.timestamp
    end

    test 'it can generate timestamp as epoch millis format' do
      conf = FakeAuditLogMetricConf.new(timestamp_format: :epochmillis)
      metric = Fluent::Plugin::ElasticLog::GrantedPrivilegesMetric.new(
        record: @record,
        conf: conf
      )

      assert_equal 1_675_397_106_777, metric.timestamp
    end

    test 'it can generate timestamp as epoch millis string format' do
      conf = FakeAuditLogMetricConf.new(timestamp_format: :epochmillis_str)
      metric = Fluent::Plugin::ElasticLog::GrantedPrivilegesMetric.new(
        record: @record,
        conf: conf
      )

      assert_equal '1675397106777', metric.timestamp
    end
  end

  sub_test_case 'generate_metrics' do
    test 'generates metrics for each resolved indices' do
      conf = FakeAuditLogMetricConf.new(aggregate_index: false)
      metric = Fluent::Plugin::ElasticLog::GrantedPrivilegesMetric.new(
        record: @record,
        conf: conf
      )

      metrics = metric.generate_metrics

      expected_metrics = [{ 'timestamp' => '2023-02-03T04:05:06.777Z',
                            'metric_name' => 'query_count',
                            'metric_value' => 1,
                            'user' => 'test_user',
                            'cluster' => 'TEST_CLUSTER',
                            'query_type' => 'read',
                            'index' => 'test_index_1-000001' },
                          { 'timestamp' => '2023-02-03T04:05:06.777Z',
                            'metric_name' => 'query_count',
                            'metric_value' => 1,
                            'user' => 'test_user',
                            'cluster' => 'TEST_CLUSTER',
                            'query_type' => 'read',
                            'index' => 'test_index_1-000002' },
                          { 'timestamp' => '2023-02-03T04:05:06.777Z',
                            'metric_name' => 'query_count',
                            'metric_value' => 1,
                            'user' => 'test_user',
                            'cluster' => 'TEST_CLUSTER',
                            'query_type' => 'read',
                            'index' => 'test_index_1-000003' }]

      assert_equal 3, metrics.size
      assert_equal expected_metrics, metrics
    end

    test 'generates metrics for aggregated ilm indices' do
      conf = FakeAuditLogMetricConf.new(aggregate_index: true)
      metric = Fluent::Plugin::ElasticLog::GrantedPrivilegesMetric.new(
        record: @record,
        conf: conf
      )

      metrics = metric.generate_metrics

      expected_metrics = [{ 'timestamp' => '2023-02-03T04:05:06.777Z',
                            'metric_name' => 'query_count',
                            'metric_value' => 1,
                            'user' => 'test_user',
                            'cluster' => 'TEST_CLUSTER',
                            'query_type' => 'read',
                            'index' => 'test_index_1' }]

      assert_equal 1, metrics.size
      assert_equal expected_metrics, metrics
    end
  end

  sub_test_case 'query_type' do
    test 'generates metrics with unknown query type when not mapped' do
      record = @record.merge(privilege: 'test')
      metric = Fluent::Plugin::ElasticLog::GrantedPrivilegesMetric.new(
        record: record,
        conf: @conf
      )

      metrics = metric.generate_metrics

      expected_metrics = [{ 'timestamp' => '2023-02-03T04:05:06.777Z',
                            'metric_name' => 'query_count',
                            'metric_value' => 1,
                            'user' => 'test_user',
                            'cluster' => 'TEST_CLUSTER',
                            'query_type' => 'unknown',
                            'index' => 'test_index_1' }]

      assert_equal 1, metrics.size
      assert_equal expected_metrics, metrics
    end

    test 'generates metrics with destroy for indices:admin/delete privilege' do
      record = @record.merge(privilege: 'indices:admin/delete')
      metric = Fluent::Plugin::ElasticLog::GrantedPrivilegesMetric.new(
        record: record,
        conf: @conf
      )

      metrics = metric.generate_metrics

      expected_metrics = [{ 'timestamp' => '2023-02-03T04:05:06.777Z',
                            'metric_name' => 'query_count',
                            'metric_value' => 1,
                            'user' => 'test_user',
                            'cluster' => 'TEST_CLUSTER',
                            'query_type' => 'destroy',
                            'index' => 'test_index_1' }]

      assert_equal 1, metrics.size
      assert_equal expected_metrics, metrics
    end
  end
end
