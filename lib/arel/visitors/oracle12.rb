# frozen_string_literal: true

require_relative "oracle_common"

module Arel # :nodoc: all
  module Visitors
    class Oracle12 < Arel::Visitors::ToSql
      include OracleCommon

      private
        def visit_Arel_Nodes_SelectStatement(o, collector)
          # Oracle does not allow LIMIT clause with select for update
          if o.limit && o.lock
            raise ArgumentError, <<~MSG
              Combination of limit and lock is not supported. Because generated SQL statements
              `SELECT FOR UPDATE and FETCH FIRST n ROWS` generates ORA-02014.
            MSG
          end
          super
        end

        def visit_Arel_Nodes_SelectOptions(o, collector)
          collector = maybe_visit o.offset, collector
          collector = maybe_visit o.limit, collector
          maybe_visit o.lock, collector
        end

        def visit_Arel_Nodes_Limit(o, collector)
          collector << "FETCH FIRST "
          collector = visit o.expr, collector
          collector << " ROWS ONLY"
        end

        def visit_Arel_Nodes_Offset(o, collector)
          collector << "OFFSET "
          visit o.expr, collector
          collector << " ROWS"
        end

        def visit_Arel_Nodes_Except(o, collector)
          collector << "( "
          collector = infix_value o, collector, " MINUS "
          collector << " )"
        end

        ##
        # To avoid ORA-01795: maximum number of expressions in a list is 1000
        # tell ActiveRecord to limit us to 1000 ids at a time
        def visit_Arel_Nodes_HomogeneousIn(o, collector)
          in_clause_length = @connection.in_clause_length
          if !Array === o.casted_values || o.casted_values.length <= in_clause_length
            upstream_visit_Arel_Nodes_HomogeneousIn_for_values(o, collector, o.casted_values)
          else
            separator =
              if o.type == :in
                " OR "
              else
                " AND "
              end

            o.casted_values.each_slice(in_clause_length).each_with_index do |casted_values, i|
              collector << separator unless i == 0
              upstream_visit_Arel_Nodes_HomogeneousIn_for_values(o, collector, casted_values)
            end
          end
        end

        def upstream_visit_Arel_Nodes_HomogeneousIn_for_values(o, collector, casted_values)
          collector.preparable = false

          visit o.left, collector

          if o.type == :in
            collector << " IN ("
          else
            collector << " NOT IN ("
          end

          if casted_values.empty?
            collector << @connection.quote(nil)
          else
            collector.add_binds(casted_values, o.proc_for_binds) { |i| ":a#{i}"}
          end

          collector << ")"
        end

        def visit_Arel_Nodes_UpdateStatement(o, collector)
          # Oracle does not allow ORDER BY/LIMIT in UPDATEs.
          if o.orders.any? && o.limit.nil?
            # However, there is no harm in silently eating the ORDER BY clause if no LIMIT has been provided,
            # otherwise let the user deal with the error
            o = o.dup
            o.orders = []
          end

          super
        end

        def visit_ActiveModel_Attribute(o, collector)
          collector.add_bind(o) { |i| ":a#{i}" }
        end

        def visit_Arel_Nodes_BindParam(o, collector)
          collector.add_bind(o.value) { |i| ":a#{i}" }
        end

        def is_distinct_from(o, collector)
          collector << "DECODE("
          collector = visit [o.left, o.right, 0, 1], collector
          collector << ")"
        end

        # Oracle will occur an error `ORA-00907: missing right parenthesis`
        # when using `ORDER BY` in `UPDATE` or `DELETE`'s subquery.
        #
        # This method has been overridden based on the following code.
        # https://github.com/rails/rails/blob/v6.1.0.rc1/activerecord/lib/arel/visitors/to_sql.rb#L815-L825
        def build_subselect(key, o)
          stmt             = super
          stmt.orders      = [] # `orders` will never be set to prevent `ORA-00907`.
          stmt
        end
    end
  end
end
