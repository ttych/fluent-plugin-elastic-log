# frozen_string_literal: true

module Fluent
  module Plugin
    module ElasticLog
      class MetricAccumulator
        attr_reader :value_key

        def initialize(value_key:)
          @value_key = value_key

          @data = []
        end

        def <<(metric)
          @data << metric

          self
        end

        def to_a
          group.to_a
        end

        def group
          grouped_data = @data.group_by { |metric| metric.reject { |k, _| k == value_key } }
          grouped_data.map do |metric_base, metrics|
            accumulated_value = metrics.sum { |metric| metric.fetch(value_key, 0) }
            metric_base.update(
              value_key => accumulated_value
            )
          end
        end
      end
    end
  end
end
