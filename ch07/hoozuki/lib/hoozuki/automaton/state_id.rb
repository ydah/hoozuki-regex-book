# frozen_string_literal: true

class Hoozuki
  module Automaton
    class StateID
      include Comparable

      attr_reader :id

      def initialize(id)
        @id = Integer(id)
        freeze
      end

      def <=>(other)
        return nil unless other.is_a?(StateID)

        @id <=> other.id
      end

      def hash
        @id.hash
      end

      def eql?(other)
        other.is_a?(StateID) && @id == other.id
      end
    end

    class StateAllocator
      def initialize(first_id = 0)
        @next_id = Integer(first_id)
      end

      def next
        state = StateID.new(@next_id)
        @next_id += 1
        state
      end
    end
  end
end
