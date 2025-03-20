# frozen_string_literal: true

require 'helper'

require 'fluent/plugin/elastic_log/audit_log_to_metric_processor'

# unit tests
class TestAuditLogToMetricProcessor < Test::Unit::TestCase
  setup do
    @time = event_time('2023-01-02T03:04:05.678Z')
    @conf = FakeAuditLogMetricConf.new(
      aggregate_index_clean_suffix: [/-?\*$/, /-\d+$/]
    )
    @processor = Fluent::Plugin::ElasticLog::AuditLogToMetricProcessor.new(conf: @conf)
  end

  sub_test_case 'process GRANTED_PRIVILEGES' do
    test 'process standard record' do
      record_read = load_json_fixture('granted_privileges__transport__read.json')

      in_events = Fluent::MultiEventStream.new
      in_events.add(@time, record_read)

      out_events = @processor.process('test', in_events)

      assert_equal 2, out_events.size
      assert_equal([{ 'cluster' => 'TEST_CLUSTER',
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
                      'user' => 'test_user' }], out_events)
    end

    test 'process 2 standard records' do
      record_read = load_json_fixture('granted_privileges__transport__read.json')
      record_delete = load_json_fixture('granted_privileges__transport__delete.json')

      in_events = Fluent::MultiEventStream.new
      in_events.add(@time, record_read)
      in_events.add(@time, record_delete)

      out_events = @processor.process('test', in_events)

      assert_equal 4, out_events.size
      assert_equal([
                     { 'cluster' => 'TEST_CLUSTER',
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
                       'user' => 'test_user' },

                     { 'cluster' => 'TEST_CLUSTER',
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
                       'user' => 'test_user' }
                   ], out_events)
    end
  end

  sub_test_case 'process FAILED_LOGIN' do
    test 'process standard record' do
      record_msearch = load_json_fixture('failed_login__msearch.json')

      in_events = Fluent::MultiEventStream.new
      in_events.add(@time, record_msearch)

      out_events = @processor.process('test', in_events)

      assert_equal 1, out_events.size
      assert_equal([{ 'timestamp' => '2023-01-02T03:04:05.678Z',
                      'metric_name' => 'failed_login_count',
                      'metric_value' => 1,
                      'user' => 'test_user',
                      'cluster' => 'TEST_CLUSTER',
                      'query_type' => 'msearch' }], out_events)
    end

    test 'process 2 standard records' do
      record_msearch = load_json_fixture('failed_login__msearch.json')
      record_bulk = load_json_fixture('failed_login__bulk.json')

      in_events = Fluent::MultiEventStream.new
      in_events.add(@time, record_msearch)
      in_events.add(@time, record_bulk)

      out_events = @processor.process('test', in_events)

      assert_equal 2, out_events.size
      assert_equal([{ 'timestamp' => '2023-01-02T03:04:05.678Z',
                      'metric_name' => 'failed_login_count',
                      'metric_value' => 1,
                      'user' => 'test_user',
                      'cluster' => 'TEST_CLUSTER',
                      'query_type' => 'msearch' },
                    { 'cluster' => 'TEST_CLUSTER',
                      'metric_name' => 'failed_login_count',
                      'metric_value' => 1,
                      'query_type' => 'bulk',

                      'timestamp' => '2023-01-02T03:04:05.678Z',
                      'user' => 'test_user' }], out_events)
    end
  end
end
