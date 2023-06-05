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
  end

  private

  DEFAULT_CONF = %(
  )

  def create_driver(conf = DEFAULT_CONF)
    Fluent::Test::Driver::Output.new(Fluent::Plugin::ElasticAuditLogMetricOutput).configure(conf)
  end
end
