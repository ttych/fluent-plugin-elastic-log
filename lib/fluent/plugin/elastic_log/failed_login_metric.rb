# frozen_string_literal: true

require 'set'
require 'time'
require 'json'

module Fluent
  module Plugin
    module ElasticLog
      # record to metric converter
      #   for FAILED_LOGIN
      class FailedLoginMetric
        ELASTIC_URL_PATTERN = %r{(?:/(?<target>[^/]*))?/(?<action>_\w+)}.freeze
        QUERY_TYPE_MAP = {
          '_msearch' => 'msearch',
          '_bulk' => 'bulk',
          '_doc' => 'write',
          '_create' => 'write',
          '_search' => 'search'
        }.freeze

        attr_reader :record, :conf

        def initialize(record:, conf:)
          @record = record
          @conf = conf
        end

        def record_timestamp
          record[conf.timestamp_key]
        end

        def record_user
          record[conf.user_key]
        end

        def record_cluster
          record[conf.cluster_key]
        end

        def record_layer
          record[conf.layer_key]
        end

        def record_request_path
          record[conf.rest_request_path_key]
        end

        def record_request_body
          record[conf.request_body_key]
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

        def query_details
          if (match = ELASTIC_URL_PATTERN.match(record_request_path))
            return [QUERY_TYPE_MAP.fetch(match[:action], 'other'),
                    match[:target]]
          end
          ['other', nil]
        end

        def base
          {
            'timestamp' => timestamp,
            'metric_name' => 'failed_login_count',
            'metric_value' => 1,
            "#{conf.metadata_prefix}user" => record_user,
            "#{conf.metadata_prefix}cluster" => record_cluster
          }
        end

        def bulk_indices
          req_body = record_request_body || {}
          return [] if req_body.empty?

          req_body.each_line.each_slice(2).with_object(Set.new) do |(cmd_line, _data_line), acc|
            cmd = JSON.parse(cmd_line)
            acc << aggregate_index(cmd[cmd.keys.first]['_index'])
          end
        end

        def msearch_indices
          req_body = record_request_body || {}
          return [] if req_body.empty?

          req_body.each_line.each_slice(2).with_object(Set.new) do |(cmd_line, _data_line), acc|
            cmd = JSON.parse(cmd_line)
            index = cmd['index']
            [index].flatten.each { |index_i| acc << aggregate_index(index_i) }
          end
        end

        def aggregate_index(index)
          return index unless index && conf.aggregate_index_clean_suffix

          conf.aggregate_index_clean_suffix.inject(index) do |index_clean, clean_pattern|
            index_clean.sub(clean_pattern, '')
          end
        end

        def generate_metrics
          metrics = []

          query_action, = query_details

          # indices = case query_action
          #           when 'bulk' then bulk_indices
          #           when 'msearch' then msearch_indices
          #           else []
          #           end
          # indices << aggregate_index(query_index) if query_index || indices.empty?

          # indices.inject([]) do |metrics, index|
          #   metrics << base.merge("#{conf.metadata_prefix}index" => index,
          #                         "#{conf.metadata_prefix}query_type" => query_action)
          # end

          metrics << base.merge("#{conf.metadata_prefix}query_type" => query_action)
        end
      end
    end
  end
end
