# frozen_string_literal: true

require 'snowplow-tracker'

module Gitlab
  module Tracking
    SNOWPLOW_NAMESPACE = 'gl'

    module ControllerConcern
      extend ActiveSupport::Concern

      protected

      def track_event(action = action_name, **args)
        category = args.delete(:category) || self.class.name
        Gitlab::Tracking.event(category, action.to_s, **args)
      end
    end

    class << self
      def enabled?
        Gitlab::CurrentSettings.snowplow_enabled?
      end

      def event(category, action, label: nil, property: nil, value: nil, context: nil)
        return unless enabled?

        snowplow.track_struct_event(category, action, label, property, value, context, Time.now.to_i)
      end

      def snowplow_options(group)
        additional_features = Feature.enabled?(:additional_snowplow_tracking, group)
        {
          namespace: SNOWPLOW_NAMESPACE,
          hostname: Gitlab::CurrentSettings.snowplow_collector_hostname,
          cookie_domain: Gitlab::CurrentSettings.snowplow_cookie_domain,
          app_id: Gitlab::CurrentSettings.snowplow_site_id,
          form_tracking: additional_features,
          link_click_tracking: additional_features
        }.transform_keys! { |key| key.to_s.camelize(:lower).to_sym }
      end

      private

      def snowplow
        @snowplow ||= SnowplowTracker::Tracker.new(
          SnowplowTracker::AsyncEmitter.new(Gitlab::CurrentSettings.snowplow_collector_hostname, protocol: 'https'),
          SnowplowTracker::Subject.new,
          SNOWPLOW_NAMESPACE,
          Gitlab::CurrentSettings.snowplow_site_id
        )
      end
    end
  end
end
