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
        attr_reader :record, :conf

        ELASTIC_URL_PATTERN = %r{(?:/(?<target>[^/]*))?/(?<action>_\w+)}.freeze
        QUERY_TYPE_MAP = {
          '_msearch' => 'msearch',
          '_bulk' => 'bulk',
          '_doc' => 'write',
          '_create' => 'write',
          '_search' => 'search'
        }.freeze

        INDEX_PATTERN = /-?\*$/.freeze
        ILM_PATTERN = /-\d{6}$/.freeze

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

        def query_details
          if (match = ELASTIC_URL_PATTERN.match(record[:request_path]))
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
            "#{conf.prefix}user" => record[:user],
            "#{conf.prefix}cluster" => record[:cluster]
          }
        end

        def bulk_indices
          req_body = record[:request_body] || {}
          return [] if req_body.empty?

          req_body.each_line.each_slice(2).with_object(Set.new) do |(cmd_line, _data_line), acc|
            cmd = JSON.parse(cmd_line)
            acc << aggregate_index(cmd[cmd.keys.first]['_index'])
          end
        end

        def msearch_indices
          req_body = record[:request_body] || {}
          return [] if req_body.empty?

          req_body.each_line.each_slice(2).with_object(Set.new) do |(cmd_line, _data_line), acc|
            cmd = JSON.parse(cmd_line)
            index = cmd['index']
            [index].flatten.each { |index_i| acc << aggregate_index(index_i) }
          end
        end

        def aggregate_index(index)
          return unless index
          return index unless conf.aggregate_index

          index.sub(INDEX_PATTERN, '').sub(ILM_PATTERN, '')
        end

        def generate_metrics
          query_action, query_index = query_details
          indices = case query_action
                    when 'bulk' then bulk_indices
                    when 'msearch' then msearch_indices
                    else []
                    end
          indices << aggregate_index(query_index) if query_index || indices.empty?

          indices.inject([]) do |metrics, index|
            metrics << base.merge("#{conf.prefix}index" => index,
                                  "#{conf.prefix}query_type" => query_action)
          end
        end
      end
    end
  end
end
