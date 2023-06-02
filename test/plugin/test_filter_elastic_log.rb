require "helper"
require "fluent/plugin/filter_elastic_log.rb"

class ElasticLogFilterTest < Test::Unit::TestCase
  setup do
    Fluent::Test.setup
  end

  test "failure" do
    flunk
  end

  private

  def create_driver(conf)
    Fluent::Test::Driver::Filter.new(Fluent::Plugin::ElasticLogFilter).configure(conf)
  end
end
