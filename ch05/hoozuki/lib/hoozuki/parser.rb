# frozen_string_literal: true

class Hoozuki
  class Parser
    def initialize(pattern)
      @characters = pattern.each_char.to_a.freeze
      @offset = 0
    end

    def parse
      ast = parse_choice

      unless end_of_pattern?
        message = "Unexpected character '#{current}' " \
                  "at position #{@offset}"
        raise message
      end

      ast
    end

    private

    def parse_choice
      children = []
      children << parse_concatenation

      while current == '|'
        next_char
        children << parse_concatenation
      end

      return children.first if children.length == 1

      Node::Choice.new(children)
    end

    def parse_concatenation
      children = []

      until stop_parsing_concatenation?
        children << parse_literal
      end

      return children.first if children.length == 1
      return Node::Epsilon.new if children.empty?

      Node::Concatenation.new(children)
    end

    def parse_literal
      raise 'Unexpected end of pattern' if end_of_pattern?

      char = current
      case char
      when '|'
        raise "Unexpected character: #{char}"
      else
        next_char
        Node::Literal.new(char)
      end
    end

    def stop_parsing_concatenation?
      end_of_pattern? || current == '|'
    end

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
