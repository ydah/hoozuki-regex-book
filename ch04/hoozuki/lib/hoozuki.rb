# frozen_string_literal: true

require 'set'
require_relative 'hoozuki/node'
require_relative 'hoozuki/parser'

class Hoozuki
  def initialize(pattern)
    @pattern = pattern
    @ast = Parser.new(pattern).parse
  end

  def match?(input)
    positions = match_node(@ast, input, Set.new([0]))
    positions.include?(input.length)
  end

  private

  def match_node(node, input, positions)
    case node
    when Node::Literal
      match_literal(node, input, positions)
    when Node::Concatenation
      match_concatenation(node, input, positions)
    when Node::Choice
      match_choice(node, input, positions)
    when Node::Epsilon
      positions
    else
      Set.new
    end
  end

  def match_literal(node, input, positions)
    positions.each_with_object(Set.new) do |pos, next_positions|
      next if pos >= input.length
      next unless input[pos] == node.value

      next_positions.add(pos + 1)
    end
  end

  def match_concatenation(node, input, positions)
    node.children.reduce(positions) do |current_positions, child|
      match_node(child, input, current_positions)
    end
  end

  def match_choice(node, input, positions)
    node.children.each_with_object(Set.new) do |child, result|
      result.merge(match_node(child, input, positions))
    end
  end
end
