# frozen_string_literal: true

require 'helper'

require 'fluent/plugin/elastic_log/failed_login_metric'

# unit tests
class TestFailedLoginMetric < Test::Unit::TestCase
  setup do
    @conf = FakeAuditLogMetricConf.new
    @record = {
      timestamp: '2023-02-03T04:05:06.777Z',
      user: 'test_user',
      cluster: 'TEST_CLUSTER',
      layer: 'TRANSPORT',
      request_path: '/',
      request_body: '{}'
    }
  end

  sub_test_case 'time_event' do
    test 'it can generate timestamp as iso format' do
      conf = FakeAuditLogMetricConf.new
      metric = Fluent::Plugin::ElasticLog::FailedLoginMetric.new(
        record: @record,
        conf: conf
      )

      assert_equal '2023-02-03T04:05:06.777Z', metric.timestamp
    end

    test 'it can generate timestamp as epoch millis format' do
      conf = FakeAuditLogMetricConf.new(timestamp_format: :epochmillis)
      metric = Fluent::Plugin::ElasticLog::FailedLoginMetric.new(
        record: @record,
        conf: conf
      )

      assert_equal 1_675_397_106_777, metric.timestamp
    end

    test 'it can generate timestamp as epoch millis string format' do
      conf = FakeAuditLogMetricConf.new(timestamp_format: :epochmillis_str)
      metric = Fluent::Plugin::ElasticLog::FailedLoginMetric.new(
        record: @record,
        conf: conf
      )

      assert_equal '1675397106777', metric.timestamp
    end
  end

  sub_test_case 'generate_metrics' do
    test 'generates metrics for each resolved indices' do
      conf = FakeAuditLogMetricConf.new(aggregate_index: false)
      metric = Fluent::Plugin::ElasticLog::FailedLoginMetric.new(
        record: @record,
        conf: conf
      )

      metrics = metric.generate_metrics

      expected_metrics = [{ 'timestamp' => '2023-02-03T04:05:06.777Z',
                            'metric_name' => 'failed_login_count',
                            'metric_value' => 1,
                            'user' => 'test_user',
                            'cluster' => 'TEST_CLUSTER',
                            'query_type' => 'other',
                            'index' => nil }]

      assert_equal 1, metrics.size
      assert_equal expected_metrics, metrics
    end

    test 'generates metrics for aggregated ilm indices' do
      conf = FakeAuditLogMetricConf.new(aggregate_index: true)
      metric = Fluent::Plugin::ElasticLog::FailedLoginMetric.new(
        record: @record,
        conf: conf
      )

      metrics = metric.generate_metrics

      expected_metrics = [{ 'timestamp' => '2023-02-03T04:05:06.777Z',
                            'metric_name' => 'failed_login_count',
                            'metric_value' => 1,
                            'user' => 'test_user',
                            'cluster' => 'TEST_CLUSTER',
                            'query_type' => 'other',
                            'index' => nil }]

      assert_equal 1, metrics.size
      assert_equal expected_metrics, metrics
    end
  end

  sub_test_case 'query_type' do
    test 'generates metrics by default with other query_type' do
      record = @record
      metric = Fluent::Plugin::ElasticLog::FailedLoginMetric.new(
        record: record,
        conf: @conf
      )

      metrics = metric.generate_metrics

      expected_metrics = [{ 'timestamp' => '2023-02-03T04:05:06.777Z',
                            'metric_name' => 'failed_login_count',
                            'metric_value' => 1,
                            'user' => 'test_user',
                            'cluster' => 'TEST_CLUSTER',
                            'query_type' => 'other',
                            'index' => nil }]

      assert_equal 1, metrics.size
      assert_equal expected_metrics, metrics
    end

    test 'generates metrics with bulk query_type' do
      record = @record.merge(
        request_path: '/_bulk',
        request_body: "{\"index\": {\"_index\":\"test_index1\",\"_type\":\"_doc\"}}\n" \
        "{}\n" \
        "{\"index\": {\"_index\":\"test_index2\",\"_type\":\"_doc\"}}\n" \
        "{}\n"
      )
      metric = Fluent::Plugin::ElasticLog::FailedLoginMetric.new(
        record: record,
        conf: @conf
      )

      metrics = metric.generate_metrics

      expected_metrics = [{ 'cluster' => 'TEST_CLUSTER',
                            'index' => 'test_index1',
                            'metric_name' => 'failed_login_count',
                            'metric_value' => 1,
                            'query_type' => 'bulk',
                            'timestamp' => '2023-02-03T04:05:06.777Z',
                            'user' => 'test_user' },
                          { 'cluster' => 'TEST_CLUSTER',
                            'index' => 'test_index2',
                            'metric_name' => 'failed_login_count',
                            'metric_value' => 1,
                            'query_type' => 'bulk',
                            'timestamp' => '2023-02-03T04:05:06.777Z',
                            'user' => 'test_user' }]

      assert_equal 2, metrics.size
      assert_equal expected_metrics, metrics
    end

    test 'generates metrics with write query_type' do
      record = @record.merge(
        request_path: '/test_index_write/_doc'
      )
      metric = Fluent::Plugin::ElasticLog::FailedLoginMetric.new(
        record: record,
        conf: @conf
      )

      metrics = metric.generate_metrics

      expected_metrics = [{ 'timestamp' => '2023-02-03T04:05:06.777Z',
                            'metric_name' => 'failed_login_count',
                            'metric_value' => 1,
                            'user' => 'test_user',
                            'cluster' => 'TEST_CLUSTER',
                            'query_type' => 'write',
                            'index' => 'test_index_write' }]

      assert_equal 1, metrics.size
      assert_equal expected_metrics, metrics
    end

    test 'generates metrics with msearch query_type' do
      record = @record.merge(
        request_path: '/test_index_search/_msearch',
        request_body: '{"ignore_unavailble": true,' \
        '"index":"test_index_pattern*",' \
        "\"search_type\":\"query_then_fetch\"}\n" \
        "{}\n"
      )
      metric = Fluent::Plugin::ElasticLog::FailedLoginMetric.new(
        record: record,
        conf: FakeAuditLogMetricConf.new(aggregate_index: true)
      )

      metrics = metric.generate_metrics

      expected_metrics = [{ 'cluster' => 'TEST_CLUSTER',
                            'index' => 'test_index_pattern',
                            'metric_name' => 'failed_login_count',
                            'metric_value' => 1,
                            'query_type' => 'msearch',
                            'timestamp' => '2023-02-03T04:05:06.777Z',
                            'user' => 'test_user' },
                          { 'cluster' => 'TEST_CLUSTER',
                            'index' => 'test_index_search',
                            'metric_name' => 'failed_login_count',
                            'metric_value' => 1,
                            'query_type' => 'msearch',
                            'timestamp' => '2023-02-03T04:05:06.777Z',
                            'user' => 'test_user' }]

      assert_equal 2, metrics.size
      assert_equal expected_metrics, metrics
    end

    test 'generates metrics with msearch query_type and index list' do
      record = @record.merge(
        request_path: '/test_index_pattern_list1*/_msearch',
        request_body: "{\"index\":[\"test_index_pattern_list1*\",\"test_index_pattern_list2*\"]}\n" \
        "{}\n"
      )
      metric = Fluent::Plugin::ElasticLog::FailedLoginMetric.new(
        record: record,
        conf: FakeAuditLogMetricConf.new(aggregate_index: true)
      )

      metrics = metric.generate_metrics

      expected_metrics = [{ 'cluster' => 'TEST_CLUSTER',
                            'index' => 'test_index_pattern_list1',
                            'metric_name' => 'failed_login_count',
                            'metric_value' => 1,
                            'query_type' => 'msearch',
                            'timestamp' => '2023-02-03T04:05:06.777Z',
                            'user' => 'test_user' },
                          { 'cluster' => 'TEST_CLUSTER',
                            'index' => 'test_index_pattern_list2',
                            'metric_name' => 'failed_login_count',
                            'metric_value' => 1,
                            'query_type' => 'msearch',
                            'timestamp' => '2023-02-03T04:05:06.777Z',
                            'user' => 'test_user' }]

      assert_equal 2, metrics.size
      assert_equal expected_metrics, metrics
    end

    test 'generates metrics with search query_type' do
      record = @record.merge(
        request_path: '/test_index_read/_search'
      )
      metric = Fluent::Plugin::ElasticLog::FailedLoginMetric.new(
        record: record,
        conf: @conf
      )

      metrics = metric.generate_metrics

      expected_metrics = [{ 'timestamp' => '2023-02-03T04:05:06.777Z',
                            'metric_name' => 'failed_login_count',
                            'metric_value' => 1,
                            'user' => 'test_user',
                            'cluster' => 'TEST_CLUSTER',
                            'query_type' => 'search',
                            'index' => 'test_index_read' }]

      assert_equal 1, metrics.size
      assert_equal expected_metrics, metrics
    end
  end
end
