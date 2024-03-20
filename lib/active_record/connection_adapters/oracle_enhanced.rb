# frozen_string_literal: true
require "active_support/deprecation"

module ActiveRecord
  module ConnectionAdapters
    module OracleEnhanced
      def self.deprecator
        @deprecator ||= ActiveSupport::Deprecation.new("8.0", "ActiveRecord::ConnectionAdapters::OracleEnhanced::DatabaseLimits")
      end
    end
  end
end

