# frozen_string_literal: true

require 'helper'

require 'fluent/plugin/elastic_log/metric_accumulator'

class TestMetricAccumulator < Test::Unit::TestCase
  setup do
    @accumulator = Fluent::Plugin::ElasticLog::MetricAccumulator.new(
      value_key: 'metric_value'
    )
  end

  sub_test_case 'with distinct events' do
    test 'with distinct timestamp, it returns metrics as received' do
      metrics = 1.upto(30).map do |second|
        {
          'timestamp' => "2020-01-02T03:04:#{second}.000Z",
          'metric_name' => 'metric_test',
          'metric_value' => 1
        }
      end
      metrics.each do |metric|
        @accumulator << metric
      end

      accumulated_metrics = @accumulator.to_a
      assert_equal metrics.size, accumulated_metrics.size
      assert_equal metrics, accumulated_metrics
    end

    test 'with distinct metric_name, it returns metrics as received' do
      metrics = 1.upto(30).map do |metric_id|
        {
          'timestamp' => '2020-01-02T03:04:05.000Z',
          'metric_name' => "metric_#{metric_id}",
          'metric_value' => 1
        }
      end
      metrics.each do |metric|
        @accumulator << metric
      end

      accumulated_metrics = @accumulator.to_a
      assert_equal metrics.size, accumulated_metrics.size
      assert_equal metrics, accumulated_metrics
    end
  end

  sub_test_case 'with same events' do
    test 'it sums the metric_value' do
      metrics = 10.times.map do |_loop_id|
        {
          'timestamp' => '2020-01-02T03:04:05.000Z',
          'metric_name' => 'metric_test',
          'metric_value' => 1
        }
      end

      metrics.each do |metric|
        @accumulator << metric
      end

      accumulated_metrics = @accumulator.to_a
      expected_metrics = [
        {
          'timestamp' => '2020-01-02T03:04:05.000Z',
          'metric_name' => 'metric_test',
          'metric_value' => 10
        }
      ]

      assert_equal expected_metrics, accumulated_metrics
    end

    test 'it groups by same events' do
      metrics = 10.times.map do |_loop_id|
        {
          'timestamp' => '2020-01-02T03:04:05.000Z',
          'metric_name' => 'metric_test',
          'metric_value' => 1
        }
      end
      metrics += 20.times.map do |_loop_id|
        {
          'timestamp' => '2020-01-02T03:04:05.000Z',
          'metric_name' => 'metric_test_2',
          'metric_value' => 1
        }
      end

      metrics.each do |metric|
        @accumulator << metric
      end

      accumulated_metrics = @accumulator.to_a
      expected_metrics = [
        {
          'timestamp' => '2020-01-02T03:04:05.000Z',
          'metric_name' => 'metric_test',
          'metric_value' => 10
        },
        {
          'timestamp' => '2020-01-02T03:04:05.000Z',
          'metric_name' => 'metric_test_2',
          'metric_value' => 20
        }
      ]

      assert_equal expected_metrics, accumulated_metrics
    end
  end
end
