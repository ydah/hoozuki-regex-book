# frozen_string_literal: true

require_relative 'hoozuki/node'
require_relative 'hoozuki/parser'
require_relative 'hoozuki/automaton'

class Hoozuki
  def initialize(pattern)
    ast = Parser.new(pattern).parse
    allocator = Automaton::StateAllocator.new
    nfa = Automaton::NFA.new_from_node(ast, allocator)
    @dfa = Automaton::DFA.from_nfa(nfa)
  end

  def match?(input)
    raise TypeError, 'input must be a String' unless input.is_a?(String)
    raise ArgumentError, 'input must have a valid encoding' unless input.valid_encoding?

    @dfa.match?(input)
  end
end
