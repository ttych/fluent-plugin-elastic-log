# frozen_string_literal: true

require 'helper'

require 'fluent/plugin/elastic_log/failed_login_metric'

# unit tests
class TestFailedLoginMetric < Test::Unit::TestCase
  setup do
    @conf = FakeAuditLogMetricConf.new
    @record_failed_login_bulk = load_json_fixture('failed_login__bulk.json')
    @record_failed_login_msearch = load_json_fixture('failed_login__msearch.json')
    @record_failed_login_write = load_json_fixture('failed_login__write.json')
  end

  sub_test_case 'timestamp format' do
    test 'it can generate timestamp as iso format' do
      metric = Fluent::Plugin::ElasticLog::FailedLoginMetric.new(
        record: @record_failed_login_bulk,
        conf: @conf
      )

      assert_equal '2023-01-02T03:04:05.678Z', metric.timestamp
    end

    test 'it can generate timestamp as epoch millis format' do
      conf = FakeAuditLogMetricConf.new(timestamp_format: :epochmillis)
      metric = Fluent::Plugin::ElasticLog::FailedLoginMetric.new(
        record: @record_failed_login_bulk,
        conf: conf
      )

      assert_equal 1_672_628_645_678, metric.timestamp
    end

    test 'it can generate timestamp as epoch millis string format' do
      conf = FakeAuditLogMetricConf.new(timestamp_format: :epochmillis_str)
      metric = Fluent::Plugin::ElasticLog::FailedLoginMetric.new(
        record: @record_failed_login_bulk,
        conf: conf
      )

      assert_equal '1672628645678', metric.timestamp
    end
  end

  sub_test_case 'timestamp round' do
    test 'it will not round timestamp by default' do
      1.upto(59).each do |second|
        timestamp = "2024-01-02T03:04:#{second.to_s.rjust(2, '0')}.123Z"
        record = { '@timestamp' => timestamp }
        metric = Fluent::Plugin::ElasticLog::FailedLoginMetric.new(
          conf: @conf,
          record: record
        )

        assert_equal timestamp, metric.timestamp
      end
    end

    test 'it will round timestamp to 60seconds' do
      conf = FakeAuditLogMetricConf.new(aggregate_interval: 60)

      1.upto(59).each do |second|
        timestamp = "2024-01-02T03:04:#{second.to_s.rjust(2, '0')}.123Z"
        record = { '@timestamp' => timestamp }
        metric = Fluent::Plugin::ElasticLog::FailedLoginMetric.new(
          conf: conf,
          record: record
        )

        assert_equal '2024-01-02T03:04:00.000Z', metric.timestamp

        timestamp = "2023-04-05T06:07:#{second.to_s.rjust(2, '0')}.890Z"
        record = { '@timestamp' => timestamp }
        metric = Fluent::Plugin::ElasticLog::FailedLoginMetric.new(
          conf: conf,
          record: record
        )

        assert_equal '2023-04-05T06:07:00.000Z', metric.timestamp
      end
    end

    test 'it will round timestamp to 30seconds' do
      conf = FakeAuditLogMetricConf.new(aggregate_interval: 30)

      1.upto(29).each do |second|
        timestamp = "2024-01-02T03:04:#{second.to_s.rjust(2, '0')}.123Z"
        record = { '@timestamp' => timestamp }
        metric = Fluent::Plugin::ElasticLog::FailedLoginMetric.new(
          conf: conf,
          record: record
        )

        assert_equal '2024-01-02T03:04:00.000Z', metric.timestamp
      end

      30.upto(59).each do |second|
        timestamp = "2023-04-05T06:07:#{second.to_s.rjust(2, '0')}.890Z"
        record = { '@timestamp' => timestamp }
        metric = Fluent::Plugin::ElasticLog::FailedLoginMetric.new(
          conf: conf,
          record: record
        )

        assert_equal '2023-04-05T06:07:30.000Z', metric.timestamp
      end
    end
  end

  sub_test_case 'generate_metrics' do
    test 'generates metrics for each resolved indices' do
      metric = Fluent::Plugin::ElasticLog::FailedLoginMetric.new(
        record: @record_failed_login_bulk,
        conf: @conf
      )

      metrics = metric.generate_metrics

      expected_metrics = [{ 'timestamp' => '2023-01-02T03:04:05.678Z',
                            'metric_name' => 'failed_login_count',
                            'metric_value' => 1,
                            'user' => 'test_user',
                            'cluster' => 'TEST_CLUSTER',
                            'query_type' => 'bulk' }]

      assert_equal 1, metrics.size
      assert_equal expected_metrics, metrics
    end

    test 'generates metrics for aggregated ilm indices' do
      conf = FakeAuditLogMetricConf.new(
        aggregate_index_clean_suffix: [/-?\*$/, /-\d+$/]
      )
      metric = Fluent::Plugin::ElasticLog::FailedLoginMetric.new(
        record: @record_failed_login_msearch,
        conf: conf
      )

      metrics = metric.generate_metrics

      expected_metrics = [{ 'timestamp' => '2023-01-02T03:04:05.678Z',
                            'metric_name' => 'failed_login_count',
                            'metric_value' => 1,
                            'user' => 'test_user',
                            'cluster' => 'TEST_CLUSTER',
                            'query_type' => 'msearch' }]

      assert_equal 1, metrics.size
      assert_equal expected_metrics, metrics
    end
  end

  sub_test_case 'query_type' do
    test 'generates metrics by default with msearch query_type' do
      metric = Fluent::Plugin::ElasticLog::FailedLoginMetric.new(
        conf: @conf,
        record: @record_failed_login_msearch
      )

      metrics = metric.generate_metrics

      expected_metrics = [{ 'timestamp' => '2023-01-02T03:04:05.678Z',
                            'metric_name' => 'failed_login_count',
                            'metric_value' => 1,
                            'user' => 'test_user',
                            'cluster' => 'TEST_CLUSTER',
                            'query_type' => 'msearch' }]

      assert_equal 1, metrics.size
      assert_equal expected_metrics, metrics
    end

    test 'generates metrics with bulk query_type' do
      metric = Fluent::Plugin::ElasticLog::FailedLoginMetric.new(
        conf: @conf,
        record: @record_failed_login_bulk
      )

      metrics = metric.generate_metrics

      expected_metrics = [{ 'cluster' => 'TEST_CLUSTER',
                            'metric_name' => 'failed_login_count',
                            'metric_value' => 1,
                            'query_type' => 'bulk',
                            'timestamp' => '2023-01-02T03:04:05.678Z',
                            'user' => 'test_user' }]

      assert_equal 1, metrics.size
      assert_equal expected_metrics, metrics
    end

    test 'generates metrics with write query_type' do
      metric = Fluent::Plugin::ElasticLog::FailedLoginMetric.new(
        conf: @conf,
        record: @record_failed_login_write
      )

      metrics = metric.generate_metrics

      expected_metrics = [{ 'timestamp' => '2023-04-05T06:07:08.999Z',
                            'metric_name' => 'failed_login_count',
                            'metric_value' => 1,
                            'user' => 'test_user',
                            'cluster' => 'TEST_CLUSTER',
                            'query_type' => 'write' }]

      assert_equal 1, metrics.size
      assert_equal expected_metrics, metrics
    end
  end
end
