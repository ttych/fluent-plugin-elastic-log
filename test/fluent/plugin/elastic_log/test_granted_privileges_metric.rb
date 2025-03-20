# frozen_string_literal: true

require 'helper'

require 'fluent/plugin/elastic_log/granted_privileges_metric'

# unit tests
class TestGrantedPrivilegesMetric < Test::Unit::TestCase
  setup do
    @conf = FakeAuditLogMetricConf.new
    @record_admin_get = load_json_fixture('granted_privileges__transport__admin_get.json')
    @record_aliases_get = load_json_fixture('granted_privileges__transport__aliases_get.json')
    @record_delete = load_json_fixture('granted_privileges__transport__delete.json')
    @record_mappings_get = load_json_fixture('granted_privileges__transport__mappings_get.json')
    @record_read = load_json_fixture('granted_privileges__transport__read.json')
    @record_search = load_json_fixture('granted_privileges__transport__search.json')
    @record_search2 = load_json_fixture('granted_privileges__transport__search_2.json')
  end

  sub_test_case 'timestamp format' do
    test 'it can generate timestamp as iso format' do
      metric = Fluent::Plugin::ElasticLog::GrantedPrivilegesMetric.new(
        conf: @conf,
        record: @record_admin_get
      )

      assert_equal '2023-01-02T03:04:05.678Z', metric.timestamp
    end

    test 'it can generate timestamp as epoch millis format' do
      conf = FakeAuditLogMetricConf.new(timestamp_format: :epochmillis)
      metric = Fluent::Plugin::ElasticLog::GrantedPrivilegesMetric.new(
        conf: conf,
        record: @record_aliases_get
      )

      assert_equal 1_672_628_645_678, metric.timestamp
    end

    test 'it can generate timestamp as epoch millis string format' do
      conf = FakeAuditLogMetricConf.new(timestamp_format: :epochmillis_str)
      metric = Fluent::Plugin::ElasticLog::GrantedPrivilegesMetric.new(
        conf: conf,
        record: @record_delete
      )

      assert_equal '1672628645678', metric.timestamp
    end
  end

  sub_test_case 'timestamp round' do
    test 'it will not round timestamp by default' do
      1.upto(59).each do |second|
        timestamp = "2024-01-02T03:04:#{second.to_s.rjust(2, '0')}.123Z"
        record = { '@timestamp' => timestamp }
        metric = Fluent::Plugin::ElasticLog::GrantedPrivilegesMetric.new(
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
        metric = Fluent::Plugin::ElasticLog::GrantedPrivilegesMetric.new(
          conf: conf,
          record: record
        )

        assert_equal '2024-01-02T03:04:00.000Z', metric.timestamp

        timestamp = "2023-04-05T06:07:#{second.to_s.rjust(2, '0')}.890Z"
        record = { '@timestamp' => timestamp }
        metric = Fluent::Plugin::ElasticLog::GrantedPrivilegesMetric.new(
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
        metric = Fluent::Plugin::ElasticLog::GrantedPrivilegesMetric.new(
          conf: conf,
          record: record
        )

        assert_equal '2024-01-02T03:04:00.000Z', metric.timestamp
      end

      30.upto(59).each do |second|
        timestamp = "2023-04-05T06:07:#{second.to_s.rjust(2, '0')}.890Z"
        record = { '@timestamp' => timestamp }
        metric = Fluent::Plugin::ElasticLog::GrantedPrivilegesMetric.new(
          conf: conf,
          record: record
        )

        assert_equal '2023-04-05T06:07:30.000Z', metric.timestamp
      end
    end
  end

  sub_test_case 'by request privilege' do
    test 'generates metrics for indices:admin/get' do
      metric = Fluent::Plugin::ElasticLog::GrantedPrivilegesMetric.new(
        conf: @conf,
        record: @record_admin_get
      )

      metrics = metric.generate_metrics

      expected_metrics = [{ 'cluster' => 'TEST_CLUSTER',
                            'metric_name' => 'user_query_count',
                            'metric_value' => 1,
                            'query_type' => 'admin',
                            'timestamp' => '2023-01-02T03:04:05.678Z',
                            'user' => 'test_user5' },
                          { 'cluster' => 'TEST_CLUSTER',
                            'index' => 'my_log_app-000001',
                            'metric_name' => 'index_query_count',
                            'metric_value' => 1,
                            'query_type' => 'admin',
                            'timestamp' => '2023-01-02T03:04:05.678Z',
                            'user' => 'test_user5' },
                          { 'cluster' => 'TEST_CLUSTER',
                            'index' => 'my_log_app-000002',
                            'metric_name' => 'index_query_count',
                            'metric_value' => 1,
                            'query_type' => 'admin',
                            'timestamp' => '2023-01-02T03:04:05.678Z',
                            'user' => 'test_user5' },
                          { 'cluster' => 'TEST_CLUSTER',
                            'index' => 'my_log_sys-2024.01.01',
                            'metric_name' => 'index_query_count',
                            'metric_value' => 1,
                            'query_type' => 'admin',
                            'timestamp' => '2023-01-02T03:04:05.678Z',
                            'user' => 'test_user5' },
                          { 'cluster' => 'TEST_CLUSTER',
                            'index' => 'my_log_sys-2024.01.02',
                            'metric_name' => 'index_query_count',
                            'metric_value' => 1,
                            'query_type' => 'admin',
                            'timestamp' => '2023-01-02T03:04:05.678Z',
                            'user' => 'test_user5' },
                          { 'cluster' => 'TEST_CLUSTER',
                            'index' => 'my_log_test-2024.01.02',
                            'metric_name' => 'index_query_count',
                            'metric_value' => 1,
                            'query_type' => 'admin',
                            'timestamp' => '2023-01-02T03:04:05.678Z',
                            'user' => 'test_user5' }]

      assert_equal 6, metrics.size
      assert_equal expected_metrics, metrics
    end

    test 'generates aggregated metrics for indices:admin/get' do
      conf = FakeAuditLogMetricConf.new(
        aggregate_index_clean_suffix: [/-?\*$/, /-\d+$/, /-\d{4}\.\d{2}(\.\d{2})?$/]
      )
      metric = Fluent::Plugin::ElasticLog::GrantedPrivilegesMetric.new(
        conf: conf,
        record: @record_admin_get
      )

      metrics = metric.generate_metrics

      expected_metrics = [{ 'cluster' => 'TEST_CLUSTER',
                            'metric_name' => 'user_query_count',
                            'metric_value' => 1,
                            'query_type' => 'admin',
                            'timestamp' => '2023-01-02T03:04:05.678Z',
                            'user' => 'test_user5' },
                          { 'cluster' => 'TEST_CLUSTER',
                            'index' => 'my_log_app',
                            'metric_name' => 'index_query_count',
                            'metric_value' => 1,
                            'query_type' => 'admin',
                            'timestamp' => '2023-01-02T03:04:05.678Z',
                            'user' => 'test_user5' },
                          { 'cluster' => 'TEST_CLUSTER',
                            'index' => 'my_log_sys',
                            'metric_name' => 'index_query_count',
                            'metric_value' => 1,
                            'query_type' => 'admin',
                            'timestamp' => '2023-01-02T03:04:05.678Z',
                            'user' => 'test_user5' },
                          { 'cluster' => 'TEST_CLUSTER',
                            'index' => 'my_log_test',
                            'metric_name' => 'index_query_count',
                            'metric_value' => 1,
                            'query_type' => 'admin',
                            'timestamp' => '2023-01-02T03:04:05.678Z',
                            'user' => 'test_user5' }]

      assert_equal 4, metrics.size
      assert_equal expected_metrics, metrics
    end

    test 'generates metrics for indices:admin/aliases/get' do
      metric = Fluent::Plugin::ElasticLog::GrantedPrivilegesMetric.new(
        conf: @conf,
        record: @record_aliases_get
      )

      metrics = metric.generate_metrics

      expected_metrics = [{ 'cluster' => 'TEST_CLUSTER',
                            'metric_name' => 'user_query_count',
                            'metric_value' => 1,
                            'query_type' => 'admin',
                            'timestamp' => '2023-01-02T03:04:05.678Z',
                            'user' => 'test_user3' },
                          { 'cluster' => 'TEST_CLUSTER',
                            'index' => 'test-data-000001',
                            'metric_name' => 'index_query_count',
                            'metric_value' => 1,
                            'query_type' => 'admin',
                            'timestamp' => '2023-01-02T03:04:05.678Z',
                            'user' => 'test_user3' },
                          { 'cluster' => 'TEST_CLUSTER',
                            'index' => 'test-data-000002',
                            'metric_name' => 'index_query_count',
                            'metric_value' => 1,
                            'query_type' => 'admin',
                            'timestamp' => '2023-01-02T03:04:05.678Z',
                            'user' => 'test_user3' },
                          { 'cluster' => 'TEST_CLUSTER',
                            'index' => 'test-alerts-2024.01.01',
                            'metric_name' => 'index_query_count',
                            'metric_value' => 1,
                            'query_type' => 'admin',
                            'timestamp' => '2023-01-02T03:04:05.678Z',
                            'user' => 'test_user3' },
                          { 'cluster' => 'TEST_CLUSTER',
                            'index' => 'test-alerts-2024.01.02',
                            'metric_name' => 'index_query_count',
                            'metric_value' => 1,
                            'query_type' => 'admin',
                            'timestamp' => '2023-01-02T03:04:05.678Z',
                            'user' => 'test_user3' },
                          { 'cluster' => 'TEST_CLUSTER',
                            'index' => 'test-blank',
                            'metric_name' => 'index_query_count',
                            'metric_value' => 1,
                            'query_type' => 'admin',
                            'timestamp' => '2023-01-02T03:04:05.678Z',
                            'user' => 'test_user3' }]

      assert_equal 6, metrics.size
      assert_equal expected_metrics, metrics
    end

    test 'generates aggregated metrics for indices:admin/aliases/get' do
      conf = FakeAuditLogMetricConf.new(
        aggregate_index_clean_suffix: [/-?\*$/, /-\d+$/, /-\d{4}\.\d{2}(\.\d{2})?$/]
      )
      metric = Fluent::Plugin::ElasticLog::GrantedPrivilegesMetric.new(
        conf: conf,
        record: @record_aliases_get
      )

      metrics = metric.generate_metrics

      expected_metrics = [{ 'cluster' => 'TEST_CLUSTER',
                            'metric_name' => 'user_query_count',
                            'metric_value' => 1,
                            'query_type' => 'admin',
                            'timestamp' => '2023-01-02T03:04:05.678Z',
                            'user' => 'test_user3' },
                          { 'cluster' => 'TEST_CLUSTER',
                            'index' => 'test-data',
                            'metric_name' => 'index_query_count',
                            'metric_value' => 1,
                            'query_type' => 'admin',
                            'timestamp' => '2023-01-02T03:04:05.678Z',
                            'user' => 'test_user3' },
                          { 'cluster' => 'TEST_CLUSTER',
                            'index' => 'test-alerts',
                            'metric_name' => 'index_query_count',
                            'metric_value' => 1,
                            'query_type' => 'admin',
                            'timestamp' => '2023-01-02T03:04:05.678Z',
                            'user' => 'test_user3' },
                          { 'cluster' => 'TEST_CLUSTER',
                            'index' => 'test-blank',
                            'metric_name' => 'index_query_count',
                            'metric_value' => 1,
                            'query_type' => 'admin',
                            'timestamp' => '2023-01-02T03:04:05.678Z',
                            'user' => 'test_user3' }]

      assert_equal 4, metrics.size
      assert_equal expected_metrics, metrics
    end

    test 'generates metrics for indices:data/write/delete' do
      metric = Fluent::Plugin::ElasticLog::GrantedPrivilegesMetric.new(
        conf: @conf,
        record: @record_delete
      )

      metrics = metric.generate_metrics

      expected_metrics = [{ 'cluster' => 'TEST_CLUSTER',
                            'metric_name' => 'user_query_count',
                            'metric_value' => 1,
                            'query_type' => 'delete',
                            'timestamp' => '2023-01-02T03:04:05.678Z',
                            'user' => 'test_user' },
                          { 'cluster' => 'TEST_CLUSTER',
                            'index' => 'test_index_2-000001',
                            'metric_name' => 'index_query_count',
                            'metric_value' => 1,
                            'query_type' => 'delete',
                            'timestamp' => '2023-01-02T03:04:05.678Z',
                            'user' => 'test_user' },
                          { 'cluster' => 'TEST_CLUSTER',
                            'index' => 'test_index_2-000002',
                            'metric_name' => 'index_query_count',
                            'metric_value' => 1,
                            'query_type' => 'delete',
                            'timestamp' => '2023-01-02T03:04:05.678Z',
                            'user' => 'test_user' },
                          { 'cluster' => 'TEST_CLUSTER',
                            'index' => 'test_index_2-000003',
                            'metric_name' => 'index_query_count',
                            'metric_value' => 1,
                            'query_type' => 'delete',
                            'timestamp' => '2023-01-02T03:04:05.678Z',
                            'user' => 'test_user' }]

      assert_equal 4, metrics.size
      assert_equal expected_metrics, metrics
    end

    test 'generates aggregated metrics for indices:data/write/delete' do
      conf = FakeAuditLogMetricConf.new(
        aggregate_index_clean_suffix: [/-?\*$/, /-\d+$/, /-\d{4}\.\d{2}(\.\d{2})?$/]
      )
      metric = Fluent::Plugin::ElasticLog::GrantedPrivilegesMetric.new(
        conf: conf,
        record: @record_delete
      )

      metrics = metric.generate_metrics

      expected_metrics = [{ 'cluster' => 'TEST_CLUSTER',
                            'metric_name' => 'user_query_count',
                            'metric_value' => 1,
                            'query_type' => 'delete',
                            'timestamp' => '2023-01-02T03:04:05.678Z',
                            'user' => 'test_user' },
                          { 'cluster' => 'TEST_CLUSTER',
                            'index' => 'test_index_2',
                            'metric_name' => 'index_query_count',
                            'metric_value' => 1,
                            'query_type' => 'delete',
                            'timestamp' => '2023-01-02T03:04:05.678Z',
                            'user' => 'test_user' }]

      assert_equal 2, metrics.size
      assert_equal expected_metrics, metrics
    end

    test 'generates metrics for indices:admin/mappings/get' do
      metric = Fluent::Plugin::ElasticLog::GrantedPrivilegesMetric.new(
        conf: @conf,
        record: @record_mappings_get
      )

      metrics = metric.generate_metrics

      expected_metrics = [{ 'cluster' => 'TEST_CLUSTER',
                            'metric_name' => 'user_query_count',
                            'metric_value' => 1,
                            'query_type' => 'admin',
                            'timestamp' => '2023-01-02T03:04:05.678Z',
                            'user' => 'test_user4' },
                          { 'cluster' => 'TEST_CLUSTER',
                            'index' => 'test-data-000001',
                            'metric_name' => 'index_query_count',
                            'metric_value' => 1,
                            'query_type' => 'admin',
                            'timestamp' => '2023-01-02T03:04:05.678Z',
                            'user' => 'test_user4' },
                          { 'cluster' => 'TEST_CLUSTER',
                            'index' => 'test-data-000002',
                            'metric_name' => 'index_query_count',
                            'metric_value' => 1,
                            'query_type' => 'admin',
                            'timestamp' => '2023-01-02T03:04:05.678Z',
                            'user' => 'test_user4' },
                          { 'cluster' => 'TEST_CLUSTER',
                            'index' => 'test-alerts-2024.01.01',
                            'metric_name' => 'index_query_count',
                            'metric_value' => 1,
                            'query_type' => 'admin',
                            'timestamp' => '2023-01-02T03:04:05.678Z',
                            'user' => 'test_user4' },
                          { 'cluster' => 'TEST_CLUSTER',
                            'index' => 'test-alerts-2024.01.02',
                            'metric_name' => 'index_query_count',
                            'metric_value' => 1,
                            'query_type' => 'admin',
                            'timestamp' => '2023-01-02T03:04:05.678Z',
                            'user' => 'test_user4' },
                          { 'cluster' => 'TEST_CLUSTER',
                            'index' => 'test-blank',
                            'metric_name' => 'index_query_count',
                            'metric_value' => 1,
                            'query_type' => 'admin',
                            'timestamp' => '2023-01-02T03:04:05.678Z',
                            'user' => 'test_user4' },
                          { 'cluster' => 'TEST_CLUSTER',
                            'index' => '.kibana.1.2.3_-123_123_1',
                            'metric_name' => 'index_query_count',
                            'metric_value' => 1,
                            'query_type' => 'admin',
                            'timestamp' => '2023-01-02T03:04:05.678Z',
                            'user' => 'test_user4' }]

      assert_equal 7, metrics.size
      assert_equal expected_metrics, metrics
    end

    test 'generates aggregated metrics for indices:admin/mappings/get' do
      conf = FakeAuditLogMetricConf.new(
        aggregate_index_clean_suffix: [/-?\*$/, /-\d+$/, /-\d{4}\.\d{2}(\.\d{2})?$/]
      )
      metric = Fluent::Plugin::ElasticLog::GrantedPrivilegesMetric.new(
        conf: conf,
        record: @record_mappings_get
      )

      metrics = metric.generate_metrics

      expected_metrics = [{ 'cluster' => 'TEST_CLUSTER',
                            'metric_name' => 'user_query_count',
                            'metric_value' => 1,
                            'query_type' => 'admin',
                            'timestamp' => '2023-01-02T03:04:05.678Z',
                            'user' => 'test_user4' },
                          { 'cluster' => 'TEST_CLUSTER',
                            'index' => 'test-data',
                            'metric_name' => 'index_query_count',
                            'metric_value' => 1,
                            'query_type' => 'admin',
                            'timestamp' => '2023-01-02T03:04:05.678Z',
                            'user' => 'test_user4' },
                          { 'cluster' => 'TEST_CLUSTER',
                            'index' => 'test-alerts',
                            'metric_name' => 'index_query_count',
                            'metric_value' => 1,
                            'query_type' => 'admin',
                            'timestamp' => '2023-01-02T03:04:05.678Z',
                            'user' => 'test_user4' },
                          { 'cluster' => 'TEST_CLUSTER',
                            'index' => 'test-blank',
                            'metric_name' => 'index_query_count',
                            'metric_value' => 1,
                            'query_type' => 'admin',
                            'timestamp' => '2023-01-02T03:04:05.678Z',
                            'user' => 'test_user4' },
                          { 'cluster' => 'TEST_CLUSTER',
                            'index' => '.kibana.1.2.3_-123_123_1',
                            'metric_name' => 'index_query_count',
                            'metric_value' => 1,
                            'query_type' => 'admin',
                            'timestamp' => '2023-01-02T03:04:05.678Z',
                            'user' => 'test_user4' }]

      assert_equal 5, metrics.size
      assert_equal expected_metrics, metrics
    end

    test 'generates metrics for indices:data/read/search' do
      metric = Fluent::Plugin::ElasticLog::GrantedPrivilegesMetric.new(
        conf: @conf,
        record: @record_read
      )

      metrics = metric.generate_metrics

      expected_metrics = [{ 'cluster' => 'TEST_CLUSTER',
                            'metric_name' => 'user_query_count',
                            'metric_value' => 1,
                            'query_type' => 'read',
                            'timestamp' => '2023-01-02T03:04:05.678Z',
                            'user' => 'test_user' },
                          { 'cluster' => 'TEST_CLUSTER',
                            'index' => 'test_index_1-000001',
                            'metric_name' => 'index_query_count',
                            'metric_value' => 1,
                            'query_type' => 'read',
                            'timestamp' => '2023-01-02T03:04:05.678Z',
                            'user' => 'test_user' },
                          { 'cluster' => 'TEST_CLUSTER',
                            'index' => 'test_index_1-000002',
                            'metric_name' => 'index_query_count',
                            'metric_value' => 1,
                            'query_type' => 'read',
                            'timestamp' => '2023-01-02T03:04:05.678Z',
                            'user' => 'test_user' },
                          { 'cluster' => 'TEST_CLUSTER',
                            'index' => 'test_index_1-000003',
                            'metric_name' => 'index_query_count',
                            'metric_value' => 1,
                            'query_type' => 'read',
                            'timestamp' => '2023-01-02T03:04:05.678Z',
                            'user' => 'test_user' }]

      assert_equal 4, metrics.size
      assert_equal expected_metrics, metrics
    end

    test 'generates aggregated metrics for indices:data/read/search' do
      conf = FakeAuditLogMetricConf.new(
        aggregate_index_clean_suffix: [/-?\*$/, /-\d+$/, /-\d{4}\.\d{2}(\.\d{2})?$/]
      )
      metric = Fluent::Plugin::ElasticLog::GrantedPrivilegesMetric.new(
        conf: conf,
        record: @record_read
      )

      metrics = metric.generate_metrics

      expected_metrics = [{ 'cluster' => 'TEST_CLUSTER',
                            'metric_name' => 'user_query_count',
                            'metric_value' => 1,
                            'query_type' => 'read',
                            'timestamp' => '2023-01-02T03:04:05.678Z',
                            'user' => 'test_user' },
                          { 'cluster' => 'TEST_CLUSTER',
                            'index' => 'test_index_1',
                            'metric_name' => 'index_query_count',
                            'metric_value' => 1,
                            'query_type' => 'read',
                            'timestamp' => '2023-01-02T03:04:05.678Z',
                            'user' => 'test_user' }]

      assert_equal 2, metrics.size
      assert_equal expected_metrics, metrics
    end

    test 'generates metrics for indices:data/read/search bis' do
      metric = Fluent::Plugin::ElasticLog::GrantedPrivilegesMetric.new(
        conf: @conf,
        record: @record_search
      )

      metrics = metric.generate_metrics

      expected_metrics = [{ 'cluster' => 'TEST_CLUSTER',
                            'metric_name' => 'user_query_count',
                            'metric_value' => 1,
                            'query_type' => 'read',
                            'timestamp' => '2023-01-02T03:04:05.678Z',
                            'user' => 'test_user' },
                          { 'cluster' => 'TEST_CLUSTER',
                            'index' => 'test-assets-2024.01.02',
                            'metric_name' => 'index_query_count',
                            'metric_value' => 1,
                            'query_type' => 'read',
                            'timestamp' => '2023-01-02T03:04:05.678Z',
                            'user' => 'test_user' },
                          { 'cluster' => 'TEST_CLUSTER',
                            'index' => 'test-assets-2024.02.03',
                            'metric_name' => 'index_query_count',
                            'metric_value' => 1,
                            'query_type' => 'read',
                            'timestamp' => '2023-01-02T03:04:05.678Z',
                            'user' => 'test_user' },
                          { 'cluster' => 'TEST_CLUSTER',
                            'index' => 'test-assets-2024.03.04',
                            'metric_name' => 'index_query_count',
                            'metric_value' => 1,
                            'query_type' => 'read',
                            'timestamp' => '2023-01-02T03:04:05.678Z',
                            'user' => 'test_user' }]

      assert_equal 4, metrics.size
      assert_equal expected_metrics, metrics
    end

    test 'generates aggregated metrics for indices:data/read/search bis' do
      conf = FakeAuditLogMetricConf.new(
        aggregate_index_clean_suffix: [/-?\*$/, /-\d+$/, /-\d{4}\.\d{2}(\.\d{2})?$/]
      )
      metric = Fluent::Plugin::ElasticLog::GrantedPrivilegesMetric.new(
        conf: conf,
        record: @record_search
      )

      metrics = metric.generate_metrics

      expected_metrics = [{ 'cluster' => 'TEST_CLUSTER',
                            'metric_name' => 'user_query_count',
                            'metric_value' => 1,
                            'query_type' => 'read',
                            'timestamp' => '2023-01-02T03:04:05.678Z',
                            'user' => 'test_user' },
                          { 'cluster' => 'TEST_CLUSTER',
                            'index' => 'test-assets',
                            'metric_name' => 'index_query_count',
                            'metric_value' => 1,
                            'query_type' => 'read',
                            'timestamp' => '2023-01-02T03:04:05.678Z',
                            'user' => 'test_user' }]

      assert_equal 2, metrics.size
      assert_equal expected_metrics, metrics
    end

    test 'generates metrics for indices:data/read/search 2' do
      metric = Fluent::Plugin::ElasticLog::GrantedPrivilegesMetric.new(
        conf: @conf,
        record: @record_search2
      )

      metrics = metric.generate_metrics

      expected_metrics = [{ 'cluster' => 'TEST_CLUSTER',
                            'metric_name' => 'user_query_count',
                            'metric_value' => 1,
                            'query_type' => 'read',
                            'timestamp' => '2023-01-02T03:04:05.678Z',
                            'user' => 'test_user2' },
                          { 'cluster' => 'TEST_CLUSTER',
                            'index' => 'test-alerts',
                            'metric_name' => 'index_query_count',
                            'metric_value' => 1,
                            'query_type' => 'read',
                            'timestamp' => '2023-01-02T03:04:05.678Z',
                            'user' => 'test_user2' }]

      assert_equal 2, metrics.size
      assert_equal expected_metrics, metrics
    end

    test 'generates aggregated metrics for indices:data/read/search 2' do
      conf = FakeAuditLogMetricConf.new(
        aggregate_index_clean_suffix: [/-?\*$/, /-\d+$/, /-\d{4}\.\d{2}(\.\d{2})?$/]
      )
      metric = Fluent::Plugin::ElasticLog::GrantedPrivilegesMetric.new(
        conf: conf,
        record: @record_search2
      )

      metrics = metric.generate_metrics

      expected_metrics = [{ 'cluster' => 'TEST_CLUSTER',
                            'metric_name' => 'user_query_count',
                            'metric_value' => 1,
                            'query_type' => 'read',
                            'timestamp' => '2023-01-02T03:04:05.678Z',
                            'user' => 'test_user2' },
                          { 'cluster' => 'TEST_CLUSTER',
                            'index' => 'test-alerts',
                            'metric_name' => 'index_query_count',
                            'metric_value' => 1,
                            'query_type' => 'read',
                            'timestamp' => '2023-01-02T03:04:05.678Z',
                            'user' => 'test_user2' }]

      assert_equal 2, metrics.size
      assert_equal expected_metrics, metrics
    end
  end
end
