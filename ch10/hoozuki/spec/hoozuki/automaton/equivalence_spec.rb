# frozen_string_literal: true

require_relative '../../../lib/hoozuki'

RSpec.describe 'supported regular expression equivalence' do
  PATTERNS = [
    '',
    'a',
    'a|b',
    'ab',
    '(a|b)c',
    'a*',
    '(ab)*',
    'a+',
    'b?',
    '(a|b)*',
    'a\*b',
    'a\\\\b',
    '\(a\|b\)\*'
  ].freeze

  INPUTS = [''] + (%w[a b * ( ) |] + ['\\']).repeated_permutation(4).flat_map do |suffix|
    (0..4).map { |length| suffix.first(length).join }
  end.uniq.freeze

  it 'agrees with Ruby Regexp for the supported grammar' do
    PATTERNS.each do |pattern|
      hoozuki = Hoozuki.new(pattern)
      ruby_regexp = Regexp.new("\\A(?:#{pattern})\\z")

      INPUTS.each do |input|
        expect(hoozuki.match?(input)).to eq(ruby_regexp.match?(input)),
          "pattern=#{pattern.inspect}, input=#{input.inspect}"
      end
    end
  end

  it 'keeps NFA and DFA results identical for the same AST' do
    PATTERNS.each do |pattern|
      ast = Hoozuki::Parser.new(pattern).parse
      allocator = Hoozuki::Automaton::StateAllocator.new
      nfa = Hoozuki::Automaton::NFA.new_from_node(ast, allocator)
      dfa = Hoozuki::Automaton::DFA.from_nfa(nfa)

      INPUTS.each do |input|
        expect(dfa.match?(input)).to eq(nfa.match?(input)),
          "pattern=#{pattern.inspect}, input=#{input.inspect}"
      end
    end
  end
end
