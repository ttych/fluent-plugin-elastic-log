# frozen_string_literal: true

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
          metric_es = []

          log_es.each do |time, record|
            next unless record
            next unless (category = record[conf.category_key])
            next unless conf.categories.include? category

            new_records = send("generate_#{category.downcase}_metrics_for", record)
            new_records&.each { |new_record| metric_es << [time, new_record] }
          end
          metric_es
        end

        private

        # rubocop:disable Metrics/AbcSize
        def generate_granted_privileges_metrics_for(record)
          return [] unless record[conf.privilege_key]

          GrantedPrivilegesMetric.new(
            record: {
              timestamp: record[conf.timestamp_key],
              privilege: record[conf.privilege_key],
              user: record[conf.user_key],
              cluster: record[conf.cluster_key],
              indices: record[conf.indices_key],
              r_indices: record[conf.r_indices_key],
              layer: record[conf.layer_key],
              request_type: record[conf.request_type_key]
            },
            conf: conf
          ).generate_metrics
        end
        # rubocop:enable Metrics/AbcSize

        # rubocop:disable Metrics/AbcSize
        def generate_failed_login_metrics_for(record)
          FailedLoginMetric.new(
            record: {
              timestamp: record[conf.timestamp_key],
              user: record[conf.user_key],
              cluster: record[conf.cluster_key],
              layer: record[conf.layer_key],
              request_path: record[conf.rest_request_path_key],
              request_body: record[conf.request_body_key]
            },
            conf: conf
          ).generate_metrics
        end
        # rubocop:enable Metrics/AbcSize
      end
    end
  end
end
