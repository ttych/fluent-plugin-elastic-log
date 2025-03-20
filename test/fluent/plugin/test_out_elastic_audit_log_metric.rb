# frozen_string_literal: true

require 'helper'

require 'fluent/plugin/out_elastic_audit_log_metric'

# unit test for ElasticAuditLogMetricOutput / elastic_audit_log_metric plugin
class TestElasticAuditLogMetricOutput < Test::Unit::TestCase
  DEFAULT_CONF = %(
    tag test_tag
  )

  TEST_TIME = '2024-03-04T05:06:07.890Z'
  TEST_FLUENT_TIME = Fluent::EventTime.parse(TEST_TIME)

  setup do
    Fluent::Test.setup

    Fluent::EventTime.stubs(:now).returns(TEST_FLUENT_TIME)
  end

  # configuration

  sub_test_case 'configuration' do
    test 'tag is mandatory' do
      assert_raise(Fluent::ConfigError) do
        create_driver('')
      end
    end

    test 'default allowed categories' do
      driver = create_driver
      output = driver.instance

      assert_equal ['GRANTED_PRIVILEGES'], output.categories
    end

    test 'events type are filtered with allowed' do
      conf = %(
        #{DEFAULT_CONF}
        categories GRANTED_PRIVILEGES, BAD_HEADERS
      )
      driver = create_driver(conf)
      output = driver.instance

      assert_equal ['GRANTED_PRIVILEGES'], output.categories
    end

    test 'default timestamp format is iso' do
      conf = %(
        #{DEFAULT_CONF}
      )
      driver = create_driver(conf)
      output = driver.instance

      assert_equal :iso, output.timestamp_format
    end

    test 'timestamp format can be iso' do
      conf = %(
        #{DEFAULT_CONF}
        timestamp_format iso
      )
      driver = create_driver(conf)
      output = driver.instance

      assert_equal :iso, output.timestamp_format
    end

    test 'timestamp format can be epochmillis' do
      conf = %(
        #{DEFAULT_CONF}
        timestamp_format epochmillis
      )
      driver = create_driver(conf)
      output = driver.instance

      assert_equal :epochmillis, output.timestamp_format
    end

    test 'default metadata_prefix is empty' do
      conf = %(
        #{DEFAULT_CONF}
      )
      driver = create_driver(conf)
      output = driver.instance

      assert_equal '', output.metadata_prefix
    end

    test 'default metadata_prefix can be defined' do
      conf = %(
        #{DEFAULT_CONF}
        metadata_prefix test_
      )
      driver = create_driver(conf)
      output = driver.instance

      assert_equal 'test_', output.metadata_prefix
    end

    test 'default aggregate_index options' do
      driver = create_driver
      output = driver.instance

      assert_equal [], output.aggregate_index_clean_suffix
      assert_equal nil, output.aggregate_interval
    end

    test 'default event_stream_size' do
      driver = create_driver
      output = driver.instance

      assert_equal 1000, output.event_stream_size
    end
  end

  # GRANTED_PRIVILEGES

  sub_test_case 'GRANTED_PRIVILEGES' do
    test 'process GRANTED_PRIVILEGES record' do
      record_content = load_json_fixture('granted_privileges__transport__read.json')

      conf = %(
        #{DEFAULT_CONF}
        aggregate_index_clean_suffix /-?\\*$/ , /-\\\d+$/
      )
      driver = create_driver(conf)
      timestamp = event_time('2023-01-02T03:04:05.678Z')
      driver.run do
        driver.feed('tag', timestamp, record_content)
      end

      emitted = driver.events
      assert_equal([['test_tag',
                     TEST_FLUENT_TIME,
                     { 'cluster' => 'TEST_CLUSTER',
                       'metric_name' => 'user_query_count',
                       'metric_value' => 1,
                       'query_type' => 'read',
                       'timestamp' => '2023-01-02T03:04:05.678Z',
                       'user' => 'test_user' }],
                    ['test_tag',
                     TEST_FLUENT_TIME,
                     { 'cluster' => 'TEST_CLUSTER',
                       'index' => 'test_index_1',
                       'metric_name' => 'index_query_count',
                       'metric_value' => 1,
                       'query_type' => 'read',
                       'timestamp' => '2023-01-02T03:04:05.678Z',
                       'user' => 'test_user' }]], emitted)
    end
  end

  # FAILED_LOGIN

  sub_test_case 'FAILED_LOGIN' do
    test 'process FAILED_LOGIN record' do
      record_content = load_json_fixture('failed_login__msearch.json')

      conf = %(
        #{DEFAULT_CONF}
        categories GRANTED_PRIVILEGES, FAILED_LOGIN
        aggregate_index_clean_suffix '/-?\\*$/'
      )
      driver = create_driver(conf)
      timestamp = event_time('2023-01-02T03:04:05.678Z')
      driver.run do
        driver.feed('tag', timestamp, record_content)
      end

      emitted = driver.events
      assert_equal([['test_tag',
                     TEST_FLUENT_TIME,
                     { 'timestamp' => '2023-01-02T03:04:05.678Z',
                       'metric_name' => 'failed_login_count',
                       'metric_value' => 1,
                       'query_type' => 'msearch',
                       'user' => 'test_user',
                       'cluster' => 'TEST_CLUSTER' }]], emitted)
    end
  end

  private

  def create_driver(conf = DEFAULT_CONF)
    Fluent::Test::Driver::Output.new(Fluent::Plugin::ElasticAuditLogMetricOutput).configure(conf)
  end
end
