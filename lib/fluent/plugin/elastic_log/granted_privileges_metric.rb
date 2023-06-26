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

        INDEX_PATTERN = /-?\*$/.freeze
        ILM_PATTERN = /-\d{6}$/.freeze

        attr_reader :record, :conf

        def initialize(record:, conf:)
          @record = record
          @conf = conf
        end

        def timestamp
          timestamp = Time.parse(record[:timestamp])

          return (timestamp.utc.to_f * 1000).to_i if conf.timestamp_format == :epochmillis
          return timestamp.utc.strftime('%s%3N') if conf.timestamp_format == :epochmillis_str

          timestamp.utc.iso8601(3)
        rescue StandardError
          nil
        end

        def query_type
          PRIVILEGE_MAP.each do |pattern, name|
            return name if record[:privilege].to_s.start_with?(pattern)
          end
          'unknown'
        end

        def base
          {
            'timestamp' => timestamp,
            'metric_name' => 'query_count',
            'metric_value' => 1,
            "#{conf.prefix}user" => record[:user],
            "#{conf.prefix}cluster" => record[:cluster],
            "#{conf.prefix}query_type" => query_type
          }
        end

        def indices
          indices = record[:r_indices] || record[:indices] || [nil]
          if conf.aggregate_index
            indices = indices.inject(Set.new) do |acc, index|
              acc << aggregate_index(index)
            end
          end
          indices
        end

        def aggregate_index(index)
          return unless index
          return index unless conf.aggregate_index

          index.sub(INDEX_PATTERN, '').sub(ILM_PATTERN, '')
        end

        def generate_metrics
          metrics = []
          indices.each do |indice|
            metrics << base.merge("#{conf.prefix}technical_name" => indice)
          end
          metrics
        end
      end
    end
  end
end
