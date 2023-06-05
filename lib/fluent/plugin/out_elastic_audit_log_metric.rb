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

module Fluent
  module Plugin
    # output plugin
    #   convert audit log to metric events
    class ElasticAuditLogMetricOutput < Fluent::Plugin::Output
      NAME = 'elastic_audit_log_metric'

      Fluent::Plugin.register_output(NAME, self)

      helpers :event_emitter

      desc 'The tag to emit metric events on'
      config_param :tag, :string, default: nil

      def configure(conf)
        super
        raise Fluent::ConfigError, 'tag is mandatory' if !tag || tag.to_s.empty?
      end

      def process(_tag, es)
        es.each do |time, record|
          metric_time = Fluent::EventTime.from_time(time)
          emit_metric_for(metric_time, record)
        end
      end

      private

      def emit_metric_for(time, log_record); end
    end
  end
end
