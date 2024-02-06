# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters # :nodoc:
    module OracleEnhanced
      class Column < ActiveRecord::ConnectionAdapters::Column
        delegate :virtual, to: :sql_type_metadata, allow_nil: true

        def initialize(name, default, sql_type_metadata = nil, null = true, comment: nil, primary_key: nil, **) # :nodoc:
          super(name, default, sql_type_metadata, null, comment: comment)
          @primary_key = primary_key
        end

        def virtual?
          virtual
        end

        def primary_key?
          @primary_key
        end
        alias_method :auto_incremented_by_db?, :primary_key?
      end
    end
  end
end
