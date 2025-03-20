# frozen_string_literal: true

require 'set'
require 'time'

module Fluent
  module Plugin
    module ElasticLog
      # record to metric converter
      #   for GRANTED PRIVILEGE
      class GrantedPrivilegesMetric
        # REQUEST PRIVILEGE:
        # cluster:
        #   admin/*       => admin
        #   monitor/*     => monitor
        # indices:
        #   admin/*       => admin
        #   data/read/*   => read
        #   data/write/*  => write
        #   monitor/*     => monitor
        PRIVILEGE_MAP = {
          'cluster:admin/' => 'admin',
          'cluster:monitor/' => 'monitor',
          'indices:admin/delete' => 'destroy',
          'indices:admin/' => 'admin',
          'indices:data/read/' => 'read',
          'indices:data/write/delete' => 'delete',
          'indices:data/write/' => 'write',
          'indices:monitor/' => 'monitor'
        }.freeze

        attr_reader :record, :conf

        def initialize(record:, conf:)
          @record = record
          @conf = conf
        end

        def record_timestamp
          record[conf.timestamp_key]
        end

        def record_privilege
          record[conf.privilege_key]
        end

        def record_user
          record[conf.user_key]
        end

        def record_cluster
          record[conf.cluster_key]
        end

        def record_indices
          record[conf.indices_key]
        end

        def record_r_indices
          record[conf.r_indices_key]
        end

        def record_layer
          record[conf.layer_key]
        end

        def record_request_type
          record[conf.request_type_key]
        end

        def timestamp
          timestamp = Time.parse(record_timestamp)

          if conf.aggregate_interval.to_i.positive?
            timestamp = Time.at((timestamp.to_i / conf.aggregate_interval) * conf.aggregate_interval)
          end

          return (timestamp.utc.to_f * 1000).to_i if conf.timestamp_format == :epochmillis
          return timestamp.utc.strftime('%s%3N') if conf.timestamp_format == :epochmillis_str

          timestamp.utc.iso8601(3)
        rescue StandardError
          nil
        end

        def query_type
          PRIVILEGE_MAP.each do |pattern, name|
            return name if record_privilege.to_s.start_with?(pattern)
          end
          'unknown'
        end

        def base
          {
            'timestamp' => timestamp,
            'metric_value' => 1,
            "#{conf.metadata_prefix}user" => record_user,
            "#{conf.metadata_prefix}cluster" => record_cluster,
            "#{conf.metadata_prefix}query_type" => query_type
          }
        end

        def indices
          indices = record_r_indices || record_indices || [nil]
          indices.inject(Set.new) do |acc, index|
            acc << aggregate_index(index)
          end
        end

        def aggregate_index(index)
          return index unless index && conf.aggregate_index_clean_suffix

          conf.aggregate_index_clean_suffix.inject(index) do |index_clean, clean_pattern|
            index_clean.sub(clean_pattern, '')
          end
        end

        def generate_metrics
          generate_user_metrics + generate_index_metrics
        end

        def generate_user_metrics
          [
            base.merge('metric_name' => 'user_query_count')
          ]
        end

        def generate_index_metrics
          indices.inject([]) do |metrics, index|
            metrics << base.merge(
              'metric_name' => 'index_query_count',
              "#{conf.metadata_prefix}index" => index
            )
          end
        end
      end
    end
  end
end
