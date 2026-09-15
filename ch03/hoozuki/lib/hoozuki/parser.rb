# frozen_string_literal: true

class Hoozuki
  class Parser
    def initialize(pattern)
      @characters = pattern.each_char.to_a.freeze
      @offset = 0
    end

    def parse
      children = []

      until end_of_pattern?
        char = current
        children << Node::Literal.new(char)
        next_char
      end

      return children.first if children.length == 1

      Node::Concatenation.new(children)
    end

    private

    def current
      @characters[@offset]
    end

    def end_of_pattern?
      @offset >= @characters.length
    end

    def next_char
      @offset += 1
    end
  end
end
