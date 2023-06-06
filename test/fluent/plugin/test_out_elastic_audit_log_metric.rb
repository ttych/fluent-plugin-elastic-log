# frozen_string_literal: true

require 'helper'
require 'fluent/plugin/out_elastic_audit_log_metric'

# unit test for ElasticAuditLogMetricOutput / elastic_audit_log_metric plugin
class TestElasticAuditLogMetricOutput < Test::Unit::TestCase
  setup do
    Fluent::Test.setup
  end

  # configuration

  sub_test_case 'configuration' do
    test 'tag is mandatory' do
      assert_raise(Fluent::ConfigError) do
        create_driver('')
      end
    end

    test 'events are set to GRANTED_PRIVILEGES by default' do
      driver = create_driver
      output = driver.instance

      assert_equal ['GRANTED_PRIVILEGES'], output.categories
    end

    test 'events type are filtered with allowed' do
      conf = %(
        #{DEFAULT_CONF}
        events GRANTED_PRIVILEGES, BAD_HEADERS
      )
      driver = create_driver(conf)
      output = driver.instance

      assert_equal ['GRANTED_PRIVILEGES'], output.categories
    end

    test 'timestamp format is iso' do
      # FIXME
    end

    test 'timestamp format is epochmillis' do
      # FIXME
    end
  end

  sub_test_case 'GRANTED_PRIVILEGES' do
    test 'privilege indices:data/read/search' do
      record_content = load_json_fixture('granted_privileges__transport__data_read_search.json')

      driver = create_driver
      timestamp = event_time('2023-01-02T03:04:05.678Z')
      driver.run do
        driver.feed('tag', timestamp, record_content)
      end

      emitted = driver.events
      assert_equal([['test_tag',
                     timestamp,
                     { 'timestamp' => '2023-01-02T03:04:05.678Z',
                       'metric_name' => 'read_query_count',
                       'metric_value' => 1,
                       'tags_user' => 'test_user',
                       'tags_cluster' => 'TEST_CLUSTER',
                       :tags_technical_name => 'test_index_1' }]], emitted)
    end
  end

  private

  DEFAULT_CONF = %(
    tag test_tag
  )

  def create_driver(conf = DEFAULT_CONF)
    Fluent::Test::Driver::Output.new(Fluent::Plugin::ElasticAuditLogMetricOutput).configure(conf)
  end
end
