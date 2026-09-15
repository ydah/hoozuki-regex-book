# frozen_string_literal: true

class Hoozuki
  class Parser
    def initialize(pattern)
      raise TypeError, 'pattern must be a String' unless pattern.is_a?(String)
      raise ArgumentError, 'pattern must have a valid encoding' unless pattern.valid_encoding?
      unless pattern.encoding.ascii_compatible?
        raise ArgumentError, 'pattern encoding must be ASCII-compatible'
      end

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
        # parse_groupからparse_repetitionに変更
        children << parse_repetition
      end

      return children.first if children.length == 1
      return Node::Epsilon.new if children.empty?

      Node::Concatenation.new(children)
    end

    def parse_repetition
      child = parse_group

      quantifier =
        case current
        when '*' then :zero_or_more
        when '+' then :one_or_more
        when '?' then :optional
        end

      return child unless quantifier

      next_char
      Node::Repetition.new(child, quantifier)
    end

    def parse_group
      return parse_literal if current != '('

      paren_pos = @offset
      next_char
      child = parse_choice

      if current != ')'
        message = "Expected closing parenthesis for '(' " \
                  "at position #{paren_pos}. " \
                  "Got: #{current || 'end of pattern'}"
        raise message
      end

      next_char
      child
    end

    def parse_literal
      raise 'Unexpected end of pattern' if end_of_pattern?

      char = current

      # バックスラッシュの処理
      if char == '\\'
        return parse_escape
      end

      # メタ文字のチェック
      case char
      when '(', ')', '|', '*', '+', '?'
        message = "Unexpected character '#{char}' " \
                  "at position #{@offset}"
        raise message
      else
        next_char
        Node::Literal.new(char)
      end
    end

    def parse_escape
      # 現在は '\\' の位置
      escape_pos = @offset
      next_char  # '\\' をスキップ

      if end_of_pattern?
        raise "Incomplete escape sequence at position #{escape_pos}"
      end

      escaped_char = current
      next_char

      # メタ文字でも通常の文字でも、次の1文字をリテラルとして扱う
      Node::Literal.new(escaped_char)
    end

    def stop_parsing_concatenation?
      end_of_pattern? || current == '|' || current == ')'
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
