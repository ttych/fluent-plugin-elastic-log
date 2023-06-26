# frozen_string_literal: true

require 'helper'

require 'fluent/plugin/elastic_log/audit_log_to_metric_processor'

# unit tests
class TestAuditLogToMetricProcessor < Test::Unit::TestCase
  setup do
    @time = event_time('2023-01-02T03:04:05.678Z')
    @conf = FakeAuditLogMetricConf.new
    @processor = Fluent::Plugin::ElasticLog::AuditLogToMetricProcessor.new(conf: @conf)
  end

  sub_test_case 'process GRANTED_PRIVILEGES' do
    test 'process standard record' do
      record_read = load_json_fixture('granted_privileges__transport__read.json')

      in_es = Fluent::MultiEventStream.new
      in_es.add(@time, record_read)

      out_es = @processor.process('test', in_es)
      out_es_a = []
      out_es.each { |time, record| out_es_a << [time, record] }

      assert_equal 1, out_es.size
      assert_equal([[@time, { 'timestamp' => '2023-01-02T03:04:05.678Z',
                              'metric_name' => 'query_count',
                              'metric_value' => 1,
                              'user' => 'test_user',
                              'cluster' => 'TEST_CLUSTER',
                              'query_type' => 'read',
                              'index' => 'test_index_1' }]], out_es_a)
    end

    test 'process 2 standard records' do
      record_read = load_json_fixture('granted_privileges__transport__read.json')
      record_delete = load_json_fixture('granted_privileges__transport__delete.json')

      in_es = Fluent::MultiEventStream.new
      in_es.add(@time, record_read)
      in_es.add(@time, record_delete)

      out_es = @processor.process('test', in_es)
      out_es_a = []
      out_es.each { |time, record| out_es_a << [time, record] }

      assert_equal 2, out_es.size
      assert_equal([[@time, { 'timestamp' => '2023-01-02T03:04:05.678Z',
                              'metric_name' => 'query_count',
                              'metric_value' => 1,
                              'user' => 'test_user',
                              'cluster' => 'TEST_CLUSTER',
                              'query_type' => 'read',
                              'index' => 'test_index_1' }],
                    [@time, { 'cluster' => 'TEST_CLUSTER',
                              'metric_name' => 'query_count',
                              'metric_value' => 1,
                              'query_type' => 'delete',
                              'index' => 'test_index_2',
                              'timestamp' => '2023-01-02T03:04:05.678Z',
                              'user' => 'test_user' }]], out_es_a)
    end
  end

  sub_test_case 'process FAILED_LOGIN' do
    test 'process standard record' do
      record_msearch = load_json_fixture('failed_login__msearch.json')

      in_es = Fluent::MultiEventStream.new
      in_es.add(@time, record_msearch)

      out_es = @processor.process('test', in_es)
      out_es_a = []
      out_es.each { |time, record| out_es_a << [time, record] }

      assert_equal 1, out_es.size
      assert_equal([[@time, { 'timestamp' => '2023-01-02T03:04:05.678Z',
                              'metric_name' => 'failed_login_count',
                              'metric_value' => 1,
                              'user' => 'test_user',
                              'cluster' => 'TEST_CLUSTER',
                              'query_type' => 'msearch',
                              'index' => 'test_index' }]], out_es_a)
    end

    test 'process 2 standard records' do
      record_msearch = load_json_fixture('failed_login__msearch.json')
      record_bulk = load_json_fixture('failed_login__bulk.json')

      in_es = Fluent::MultiEventStream.new
      in_es.add(@time, record_msearch)
      in_es.add(@time, record_bulk)

      out_es = @processor.process('test', in_es)
      out_es_a = []
      out_es.each { |time, record| out_es_a << [time, record] }

      assert_equal 2, out_es.size
      assert_equal([[@time, { 'timestamp' => '2023-01-02T03:04:05.678Z',
                              'metric_name' => 'failed_login_count',
                              'metric_value' => 1,
                              'user' => 'test_user',
                              'cluster' => 'TEST_CLUSTER',
                              'query_type' => 'msearch',
                              'index' => 'test_index' }],
                    [@time, { 'cluster' => 'TEST_CLUSTER',
                              'metric_name' => 'failed_login_count',
                              'metric_value' => 1,
                              'query_type' => 'bulk',
                              'index' => 'test_index',
                              'timestamp' => '2023-01-02T03:04:05.678Z',
                              'user' => 'test_user' }]], out_es_a)
    end
  end
end
