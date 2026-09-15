# frozen_string_literal: true

require_relative '../../../lib/hoozuki'
require_relative '../../../lib/hoozuki/automaton'

RSpec.describe Hoozuki::Automaton::DFA do
  describe '#initialize' do
    it 'counts initial accept states' do
      dfa = described_class.new(0, Set[1])

      expect(dfa.state_count).to eq(2)
    end
  end

  describe '.from_nfa' do
    it 'converts simple NFA to DFA' do
      # NFAを構築: パターン 'a'
      node = Hoozuki::Node::Literal.new('a')
      allocator = Hoozuki::Automaton::StateAllocator.new
      nfa = Hoozuki::Automaton::NFA
        .new_from_node(node, allocator)

      # DFAに変換
      dfa = described_class.from_nfa(nfa)

      expect(dfa.start).to be_an(Integer)
      expect(dfa.accept).to be_a(Set)
      expect(dfa.accept).not_to be_empty
      expect(dfa.transitions).to be_a(Hash)
      expect(dfa.transitions).not_to be_empty
      expect(dfa.state_count).to be >= 2
    end

    it 'converts choice NFA to DFA' do
      # NFAを構築: パターン 'a|b'
      node = Hoozuki::Node::Choice.new([
        Hoozuki::Node::Literal.new('a'),
        Hoozuki::Node::Literal.new('b')
      ])
      allocator = Hoozuki::Automaton::StateAllocator.new
      nfa = Hoozuki::Automaton::NFA
        .new_from_node(node, allocator)

      # DFAに変換
      dfa = described_class.from_nfa(nfa)

      expect(dfa.start).to be_an(Integer)
      expect(dfa.accept.size).to be >= 1
      # 'a' と 'b' 両方の遷移があるはず
      transitions_chars = dfa.transitions.keys.map(&:last)
      expect(transitions_chars).to include('a', 'b')
    end

    it 'converts concatenation NFA to DFA' do
      # NFAを構築: パターン 'ab'
      node = Hoozuki::Node::Concatenation.new([
        Hoozuki::Node::Literal.new('a'),
        Hoozuki::Node::Literal.new('b')
      ])
      allocator = Hoozuki::Automaton::StateAllocator.new
      nfa = Hoozuki::Automaton::NFA
        .new_from_node(node, allocator)

      # DFAに変換
      dfa = described_class.from_nfa(nfa)

      expect(dfa.start).to be_an(Integer)
      expect(dfa.accept).not_to be_empty
    end
  end

  describe '#add_transition' do
    it 'rejects nondeterministic transitions' do
      dfa = described_class.new(0, Set.new)
      dfa.add_transition(0, 'a', 1)

      expect {
        dfa.add_transition(0, 'a', 2)
      }.to raise_error(/not deterministic/)
    end
  end

  describe '#match?' do
    it 'matches using DFA' do
      # NFAを構築してDFAに変換
      node = Hoozuki::Node::Literal.new('a')
      allocator = Hoozuki::Automaton::StateAllocator.new
      nfa = Hoozuki::Automaton::NFA
        .new_from_node(node, allocator)
      dfa = described_class.from_nfa(nfa)

      expect(dfa.match?('a')).to be true
      expect(dfa.match?('b')).to be false
    end

    it 'matches choice pattern using DFA' do
      node = Hoozuki::Node::Choice.new([
        Hoozuki::Node::Literal.new('a'),
        Hoozuki::Node::Literal.new('b')
      ])
      allocator = Hoozuki::Automaton::StateAllocator.new
      nfa = Hoozuki::Automaton::NFA
        .new_from_node(node, allocator)
      dfa = described_class.from_nfa(nfa)

      expect(dfa.match?('a')).to be true
      expect(dfa.match?('b')).to be true
      expect(dfa.match?('c')).to be false
    end

    it 'matches concatenation pattern using DFA' do
      node = Hoozuki::Node::Concatenation.new([
        Hoozuki::Node::Literal.new('a'),
        Hoozuki::Node::Literal.new('b')
      ])
      allocator = Hoozuki::Automaton::StateAllocator.new
      nfa = Hoozuki::Automaton::NFA
        .new_from_node(node, allocator)
      dfa = described_class.from_nfa(nfa)

      expect(dfa.match?('ab')).to be true
      expect(dfa.match?('a')).to be false
      expect(dfa.match?('b')).to be false
    end
  end
end

RSpec.describe 'NFA and DFA equivalence' do
  it 'returns the same result for every short input' do
    patterns = ['a', 'a|b', 'ab', '(a|b)c']
    alphabet = %w[a b c]
    inputs = [''] + (1..3).flat_map do |length|
      alphabet.repeated_permutation(length).map(&:join)
    end

    patterns.each do |pattern|
      ast = Hoozuki::Parser.new(pattern).parse
      allocator = Hoozuki::Automaton::StateAllocator.new
      nfa = Hoozuki::Automaton::NFA
        .new_from_node(ast, allocator)
      dfa = Hoozuki::Automaton::DFA.from_nfa(nfa)

      inputs.each do |input|
        expect(dfa.match?(input)).to eq(nfa.match?(input))
      end
    end
  end
end

patterns = ['', 'a', 'a|b', 'ab', '(a|b)c']
permutations = %w[a b c].repeated_permutation(4)
combinations = permutations.flat_map do |chars|
  (0..4).map { |length| chars.first(length).join }
end.uniq
inputs = [''] + combinations

patterns.each do |pattern|
  hoozuki = Hoozuki.new(pattern)
  ruby_regexp = Regexp.new("\\A(?:#{pattern})\\z")

  inputs.each do |input|
    matches = hoozuki.match?(input) == ruby_regexp.match?(input)
    details = "#{pattern.inspect}, #{input.inspect}"
    raise "mismatch: #{details}" unless matches
  end
end
