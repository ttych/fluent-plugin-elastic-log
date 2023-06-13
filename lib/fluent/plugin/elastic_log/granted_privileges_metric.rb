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
          'cluster:admin/' => 'admin',
          'cluster:monitor/' => 'monitor',
          'indices:admin/' => 'admin',
          'indices:data/read/' => 'read',
          'indices:data/write/' => 'write',
          'indices:monitor/' => 'monitor'
        }.freeze

        ILM_PATTERN = /^(.*)-\d{6}$/.freeze

        attr_reader :time, :record, :conf, :prefix

        def initialize(time:, record:, conf:, prefix: '')
          @time = time
          @record = record
          @conf = conf
          @prefix = prefix
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

        def query_type
          PRIVILEGE_MAP.each do |pattern, name|
            return name if record[:privilege].to_s.start_with?(pattern)
          end
          'unknown_count'
        end

        def base
          {
            'timestamp' => timestamp,
            'metric_name' => 'query_count',
            'metric_value' => 1,
            "#{prefix}user" => record[:user],
            "#{prefix}cluster" => record[:cluster],
            "#{prefix}query_type" => query_type
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
            metric_es.add(time, base.merge("#{prefix}technical_name" => indice))
          end
          metric_es
        end
      end
    end
  end
end
