# frozen_string_literal: true

require 'helper'
require 'fluent/plugin/elastic_log/granted_privileges_metric'

class TestGrantedPrivilegesMetric < Test::Unit::TestCase
  FakeConf = Struct.new(:timestamp_format, :aggregate_ilm, :prefix) do
    def initialize(timestamp_format: :iso, aggregate_ilm: true, prefix: '')
      super(timestamp_format, aggregate_ilm, prefix)
    end
  end

  setup do
    @conf = FakeConf.new
    @time = event_time('2023-01-02T03:04:05.678Z'),
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
      conf = FakeConf.new
      metric = Fluent::Plugin::ElasticLog::GrantedPrivilegesMetric.new(
        time: @time,
        record: @record,
        conf: conf
      )

      assert_equal '2023-02-03T04:05:06.777Z', metric.timestamp
    end

    test 'it can generate timestamp as epoch millis format' do
      conf = FakeConf.new(timestamp_format: :epochmillis)
      metric = Fluent::Plugin::ElasticLog::GrantedPrivilegesMetric.new(
        time: @time,
        record: @record,
        conf: conf
      )

      assert_equal 1_675_397_106_777, metric.timestamp
    end

    test 'it can generate timestamp as epoch millis string format' do
      conf = FakeConf.new(timestamp_format: :epochmillis_str)
      metric = Fluent::Plugin::ElasticLog::GrantedPrivilegesMetric.new(
        time: @time,
        record: @record,
        conf: conf
      )

      assert_equal '1675397106777', metric.timestamp
    end
  end

  sub_test_case 'generate_event_stream' do
    test 'generates metric events for each resolved indices' do
      conf = FakeConf.new(aggregate_ilm: false)
      metric = Fluent::Plugin::ElasticLog::GrantedPrivilegesMetric.new(
        time: @time,
        record: @record,
        conf: conf
      )

      event_stream = metric.generate_event_stream
      events = []
      event_stream.each do |time, event|
        events << [time, event]
      end

      expected_events = [[@time, { 'timestamp' => '2023-02-03T04:05:06.777Z',
                                   'metric_name' => 'query_count',
                                   'metric_value' => 1,
                                   'user' => 'test_user',
                                   'cluster' => 'TEST_CLUSTER',
                                   'query_type' => 'read',
                                   'technical_name' => 'test_index_1-000001' }],
                         [@time,  { 'timestamp' => '2023-02-03T04:05:06.777Z',
                                    'metric_name' => 'query_count',
                                    'metric_value' => 1,
                                    'user' => 'test_user',
                                    'cluster' => 'TEST_CLUSTER',
                                    'query_type' => 'read',
                                    'technical_name' => 'test_index_1-000002' }],
                         [@time,  { 'timestamp' => '2023-02-03T04:05:06.777Z',
                                    'metric_name' => 'query_count',
                                    'metric_value' => 1,
                                    'user' => 'test_user',
                                    'cluster' => 'TEST_CLUSTER',
                                    'query_type' => 'read',
                                    'technical_name' => 'test_index_1-000003' }]]

      assert_equal 3, event_stream.size
      assert_equal expected_events, events
    end

    test 'generates metric events for aggregated ilm indices' do
      conf = FakeConf.new(aggregate_ilm: true)
      metric = Fluent::Plugin::ElasticLog::GrantedPrivilegesMetric.new(
        time: @time,
        record: @record,
        conf: conf
      )

      event_stream = metric.generate_event_stream
      events = []
      event_stream.each do |time, event|
        events << [time, event]
      end

      expected_events = [[@time, { 'timestamp' => '2023-02-03T04:05:06.777Z',
                                   'metric_name' => 'query_count',
                                   'metric_value' => 1,
                                   'user' => 'test_user',
                                   'cluster' => 'TEST_CLUSTER',
                                   'query_type' => 'read',
                                   'technical_name' => 'test_index_1' }]]

      assert_equal 1, event_stream.size
      assert_equal expected_events, events
    end
  end
end
