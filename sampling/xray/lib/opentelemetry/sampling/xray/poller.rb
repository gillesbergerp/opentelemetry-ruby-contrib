# frozen_string_literal: true

# Copyright The OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

module OpenTelemetry
  module Sampling
    module XRay
      class Poller
        # @param [Client] client
        # @param [Cache] cache
        # @param [Integer] rule_interval
        # @param [Integer] target_interval
        def initialize(client:, cache:, rule_interval:, target_interval:)
          @cache = cache
          @client = client
          @rule_interval = rule_interval
          @running = false
          @target_interval = target_interval
        end

        def start
          return if @running

          @running = true
          start_worker
          OpenTelemetry.logger.debug('Started polling')
        end

        def stop
          @running = false
          OpenTelemetry.logger.debug('Stopped polling')
        end

        private

        def start_worker
          refresh_rules

          Thread.new do
            while @running
              sleep(@target_interval)
              @rule_interval_elapsed += @target_interval

              refresh_targets
              refresh_rules if @rule_interval_elapsed >= @rule_interval
            end
          end
        end

        def refresh_rules
          OpenTelemetry.logger.debug('Refreshing sampling rules')
          @cache.update_rules(@client.fetch_sampling_rules.map(&:sampling_rule))
          @rule_interval_elapsed = 0
        end

        def refresh_targets
          matched_rules = @cache.get_matched_rules
          if matched_rules.empty?
            OpenTelemetry.logger.debug('Not refreshing sampling targets because no rules matched')
            return
          end

          OpenTelemetry.logger.debug('Refreshing sampling targets')
          @cache.update_targets(
            @client.fetch_sampling_targets(matched_rules)
          )
        end
      end
    end
  end
end
