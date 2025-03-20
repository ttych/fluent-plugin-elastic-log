# frozen_string_literal: true

require_relative 'metric_accumulator'
require_relative 'granted_privileges_metric'
require_relative 'failed_login_metric'

module Fluent
  module Plugin
    module ElasticLog
      # convert audit log event stream to metric event stream
      class AuditLogToMetricProcessor
        attr_reader :conf

        def initialize(conf:)
          @conf = conf
        end

        def process(_tag, log_es)
          metric_acc = new_metric_accumulator

          log_es.each_value do |record|
            next unless record
            next unless (category = record[conf.category_key])
            next unless conf.categories.include? category

            new_records = send("generate_#{category.downcase}_metrics_for", record)
            new_records&.each { |new_record| metric_acc << new_record }
          end
          metric_acc.to_a
        end

        private

        def new_metric_accumulator
          MetricAccumulator.new(value_key: 'metric_value')
        end

        def generate_granted_privileges_metrics_for(record)
          GrantedPrivilegesMetric.new(
            conf: conf,
            record: record
          ).generate_metrics
        end

        def generate_failed_login_metrics_for(record)
          FailedLoginMetric.new(
            conf: conf,
            record: record
          ).generate_metrics
        end
      end
    end
  end
end
