# frozen_string_literal: true

require 'set'
require 'time'

require 'fluent/event'

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
          'cluster:admin/' => 'admin_query',
          'cluster:monitor/' => 'monitor_query',
          'indices:admin/' => 'admin_query',
          'indices:data/read/' => 'read_query',
          'indices:data/write/bulk' => 'bulk_write_query',
          'indices:data/write/' => 'write_query',
          'indices:monitor/' => 'monitor_query'
        }.freeze

        ILM_PATTERN = /^(.*)-\d{6}$/.freeze

        attr_reader :time, :record, :conf

        def initialize(time:, record:, conf:)
          @time = time
          @record = record
          @conf = conf
        end

        # rubocop:disable Metrics/AbcSize
        def timestamp
          begin
            timestamp = Time.parse(record[:timestamp])
          rescue StandardError
            timestamp = time.to_time
          end

          return (timestamp.utc.to_f * 1000).to_i if conf.timestamp_format == :epochmillis
          return timestamp.utc.strftime('%s%3N') if conf.timestamp_format == :epochmillis_str

          timestamp.utc.iso8601(3)
        end
        # rubocop:enable Metrics/AbcSize

        def metric_name
          PRIVILEGE_MAP.each do |pattern, name|
            return "#{name}_count" if record[:privilege].to_s.start_with?(pattern)
          end
          'unknown_count'
        end

        def base
          {
            'timestamp' => timestamp,
            'metric_name' => metric_name,
            'metric_value' => 1,
            'tags_user' => record[:user],
            'tags_cluster' => record[:cluster]
          }
        end

        def indices
          indices = record[:r_indices] || record[:indices] || [nil]
          if conf.aggregate_ilm
            indices = indices.inject(Set.new) do |acc, index|
              aggregated_format = index[ILM_PATTERN, 1]
              acc << (aggregated_format || index)
            end.to_a
          end
          indices
        end

        def generate_event_stream
          metric_es = MultiEventStream.new
          indices.each do |indice|
            metric_es.add(time, base.merge(tags_technical_name: indice))
          end
          metric_es
        end
      end
    end
  end
end
