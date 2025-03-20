# frozen_string_literal: true

#
# Copyright 2023- Thomas Tych
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'fluent/plugin/output'
require 'fluent/event'

require_relative 'elastic_log/audit_log_to_metric_processor'

module Fluent
  module Plugin
    # output plugin
    #   convert audit log to metric events
    class ElasticAuditLogMetricOutput < Fluent::Plugin::Output
      NAME = 'elastic_audit_log_metric'

      Fluent::Plugin.register_output(NAME, self)

      helpers :event_emitter

      ALLOWED_CATEGORIES = %w[GRANTED_PRIVILEGES FAILED_LOGIN].freeze
      # FAILED_LOGIN AUTHENTICATED MISSING_PRIVILEGES SSL_EXCEPTION
      # OPENDISTRO_SECURITY_INDEX_ATTEMPT BAD_HEADERS
      DEFAULT_CATEGORIES = %w[GRANTED_PRIVILEGES].freeze

      CONFIGURATION_KEYS = %w[category layer request_type cluster user indices r_indices timestamp privilege].freeze
      DEFAULT_CATEGORY_KEY = 'audit_category'
      DEFAULT_LAYER_KEY = 'audit_request_layer'
      DEFAULT_REQUEST_TYPE = 'audit_transport_request_type'
      DEFAULT_CLUSTER_KEY = 'audit_cluster_name'
      DEFAULT_USER_KEY = 'audit_request_effective_user'
      DEFAULT_INDICES_KEY = 'audit_trace_indices'
      DEFAULT_R_INDICES_KEY = 'audit_trace_resolved_indices'
      DEFAULT_REST_REQUEST_PATH = 'audit_rest_request_path'
      DEFAULT_REQUEST_BODY = 'audit_request_body'
      DEFAULT_TIMESTAMP_KEY = '@timestamp'
      DEFAULT_PRIVILEGE_KEY = 'audit_request_privilege'

      DEFAULT_AGGREGATE_INDEX_CLEAN_SUFFIX = [].freeze
      DEFAULT_AGGREGATE_INTERVAL = nil

      DEFAULT_METADATA_PREFIX = ''

      desc 'Tag to emit metric events on'
      config_param :tag, :string, default: nil
      desc 'Categories selected to be converted to metrics'
      config_param :categories, :array, default: DEFAULT_CATEGORIES, value_type: :string

      desc 'Category key'
      config_param :category_key, :string, default: DEFAULT_CATEGORY_KEY
      desc 'Layer key'
      config_param :layer_key, :string, default: DEFAULT_LAYER_KEY
      desc 'Request type key'
      config_param :request_type_key, :string, default: DEFAULT_REQUEST_TYPE
      desc 'Cluster key'
      config_param :cluster_key, :string, default: DEFAULT_CLUSTER_KEY
      desc 'Request user key'
      config_param :user_key, :string, default: DEFAULT_USER_KEY
      desc 'Indices key'
      config_param :indices_key, :string, default: DEFAULT_INDICES_KEY
      desc 'Resolved indices key'
      config_param :r_indices_key, :string, default: DEFAULT_R_INDICES_KEY
      desc 'Timestamp key'
      config_param :timestamp_key, :string, default: DEFAULT_TIMESTAMP_KEY
      desc 'Request privilege key'
      config_param :privilege_key, :string, default: DEFAULT_PRIVILEGE_KEY
      desc 'Rest request path key'
      config_param :rest_request_path_key, :string, default: DEFAULT_REST_REQUEST_PATH
      desc 'Request body key'
      config_param :request_body_key, :string, default: DEFAULT_REQUEST_BODY

      desc 'Timestamp format'
      config_param :timestamp_format, :enum, list: %i[iso epochmillis epochmillis_str], default: :iso

      desc 'Metadata prefix'
      config_param :metadata_prefix, :string, default: DEFAULT_METADATA_PREFIX

      desc 'Index suffix to clean, to aggregate_index'
      config_param :aggregate_index_clean_suffix, :array, value_type: :regexp,
                                                          default: DEFAULT_AGGREGATE_INDEX_CLEAN_SUFFIX

      desc 'Aggregate interval, to aggregate metrics by time'
      config_param :aggregate_interval, :integer, default: DEFAULT_AGGREGATE_INTERVAL

      desc 'Events block size'
      config_param :event_stream_size, :integer, default: 1000

      attr_reader :metric_processor

      def configure(conf)
        super
        raise Fluent::ConfigError, "#{NAME}: tag is mandatory" if !tag || tag.to_s.empty?

        check_configuration_keys

        unsupported_categories = categories - ALLOWED_CATEGORIES
        unless unsupported_categories.empty?
          log.warn("#{NAME}: unsupported categories #{unsupported_categories}")
          @categories = categories - unsupported_categories
        end

        @metric_processor = ElasticLog::AuditLogToMetricProcessor.new(conf: self)

        true
      end

      def check_configuration_keys
        keys = CONFIGURATION_KEYS
        invalid_keys = keys.each_with_object([]) do |key, invalid|
          key_label = "#{key}_key"
          key_value = send(key_label)
          invalid << key_label if !key_value || key_value.to_s.empty?
        end

        raise Fluent::ConfigError, "#{NAME}: #{invalid_keys} are empty" if invalid_keys.any?
      end

      def process(es_tag, es)
        time = Fluent::EventTime.now
        metrics = metric_processor.process(es_tag, es) || []
        metrics.each_slice(event_stream_size) do |metrics_slice|
          metrics_es = MultiEventStream.new
          metrics_slice.each { |record| metrics_es.add(time, record) }
          router.emit_stream(tag, metrics_es)
        end
      end
    end
  end
end
