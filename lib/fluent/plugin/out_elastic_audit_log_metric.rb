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
require 'fluent/plugin/elastic_log/granted_privileges_metric'

module Fluent
  module Plugin
    # output plugin
    #   convert audit log to metric events
    class ElasticAuditLogMetricOutput < Fluent::Plugin::Output
      NAME = 'elastic_audit_log_metric'

      Fluent::Plugin.register_output(NAME, self)

      helpers :event_emitter

      ALLOWED_CATEGORIES = %w[GRANTED_PRIVILEGES].freeze
      # FAILED_LOGIN AUTHENTICATED MISSING_PRIVILEGES SSL_EXCEPTION
      # OPENDISTRO_SECURITY_INDEX_ATTEMPT BAD_HEADERS

      DEFAULT_CATEGORY_KEY = 'audit_category'
      DEFAULT_LAYER_KEY = 'audit_request_layer'
      DEFAULT_REQUEST_TYPE = 'audit_transport_request_type'
      DEFAULT_CLUSTER_KEY = 'audit_cluster_name'
      DEFAULT_USER_KEY = 'audit_request_effective_user'
      DEFAULT_INDICES_KEY = 'audit_trace_indices'
      DEFAULT_R_INDICES_KEY = 'audit_trace_resolved_indices'
      DEFAULT_TIMESTAMP_KEY = '@timestamp'
      DEFAULT_PRIVILEGE_KEY = 'audit_request_privilege'

      # REQUEST PRIVILEGE:
      # cluster:
      #   admin/*       => admin
      #   monitor/*     => monitor
      # indices:
      #   admin/*       => admin
      #   data/read/*   => read
      #   data/write/*  => write
      #   monitor/*     => monitor

      desc 'Tag to emit metric events on'
      config_param :tag, :string, default: nil
      desc 'Categories selected to be converted to metrics'
      config_param :categories, :array, default: ALLOWED_CATEGORIES, value_type: :string

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

      desc 'Timestamp format'
      config_param :timestamp_format, :enum, list: %i[iso epochmillis epochmillis_str], default: :iso

      desc 'Aggregate ILM'
      config_param :aggregate_ilm, :bool, default: true

      def configure(conf)
        super
        raise Fluent::ConfigError, "#{NAME}: tag is mandatory" if !tag || tag.to_s.empty?

        check_configuration_keys

        unsupported_categories = categories - ALLOWED_CATEGORIES
        unless unsupported_categories.empty?
          log.warn("#{NAME}: unsupported categories #{unsupported_categories}")
          @categories = categories - unsupported_categories
        end

        true
      end

      def check_configuration_keys
        keys = %w[category layer request_type cluster user indices r_indices timestamp privilege]
        invalid_keys = keys.each_with_object([]) do |key, invalid|
          key_label = "#{key}_key"
          key_value = send(key_label)
          invalid << key_label if !key_value || key_value.to_s.empty?
        end

        raise Fluent::ConfigError, "#{NAME}: #{invalid_keys} are empty" if invalid_keys.any?
      end

      def process(_tag, es)
        es.each do |time, record|
          next unless record
          next unless (category = record[category_key])
          next unless ALLOWED_CATEGORIES.include? category

          event_time = Fluent::EventTime.from_time(time)
          metric_es = send("generate_#{category.downcase}_metrics_for", event_time, record)
          router.emit_stream(tag, metric_es) if metric_es
        end
      end

      # es = Fluent::MultiEventStream.new
      # router.emit_stream(tag, es)

      private

      # rubocop:disable Metrics/AbcSize
      def generate_granted_privileges_metrics_for(time, record)
        return unless record[privilege_key]

        Fluent::Plugin::ElasticLog::GrantedPrivilegesMetric.new(
          time: time,
          record: {
            timestamp: record[timestamp_key],
            privilege: record[privilege_key],
            user: record[user_key],
            cluster: record[cluster_key],
            indices: record[indices_key],
            r_indices: record[r_indices_key],
            layer: record[layer_key],
            request_type: record[request_type_key]
          },
          conf: self
        ).generate_event_stream
      end
      # rubocop:enable Metrics/AbcSize
    end
  end
end
