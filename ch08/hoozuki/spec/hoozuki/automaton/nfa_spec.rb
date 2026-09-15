# frozen_string_literal: true

require_relative '../../../lib/hoozuki'
require_relative '../../../lib/hoozuki/automaton'

RSpec.describe Hoozuki::Automaton::NFA do
  describe Hoozuki::Automaton::StateAllocator do
    it 'allocates immutable state IDs' do
      allocator = described_class.new
      first = allocator.next
      second = allocator.next

      expect(first.id).to eq(0)
      expect(second.id).to eq(1)
      expect(first).to be_frozen
    end
  end

  describe '.new_from_node' do
    it 'builds NFA from Literal node' do
      node = Hoozuki::Node::Literal.new('a')
      allocator = Hoozuki::Automaton::StateAllocator.new

      nfa = described_class.new_from_node(node, allocator)

      expect(nfa.start).to be_a(Hoozuki::Automaton::StateID)
      expect(nfa.accept).to be_a(Set)
      expect(nfa.accept.length).to eq(1)
      expect(nfa.transitions.size).to eq(1)
    end

    it 'builds NFA from Epsilon node' do
      node = Hoozuki::Node::Epsilon.new
      allocator = Hoozuki::Automaton::StateAllocator.new

      nfa = described_class.new_from_node(node, allocator)

      expect(nfa.start).to be_a(Hoozuki::Automaton::StateID)
      expect(nfa.accept.length).to eq(1)
      epsilon_transitions =
        nfa.transitions.select do |_, label, _|
          label.nil?
        end
      expect(epsilon_transitions.size).to eq(1)
    end

    it 'builds NFA from Concatenation node' do
      node = Hoozuki::Node::Concatenation.new([
        Hoozuki::Node::Literal.new('a'),
        Hoozuki::Node::Literal.new('b')
      ])
      allocator = Hoozuki::Automaton::StateAllocator.new

      nfa = described_class.new_from_node(node, allocator)

      expect(nfa.start).to be_a(Hoozuki::Automaton::StateID)
      expect(nfa.accept.length).to eq(1)
      expect(nfa.transitions.size).to eq(3)
    end

    it 'builds NFA from Choice node' do
      node = Hoozuki::Node::Choice.new([
        Hoozuki::Node::Literal.new('a'),
        Hoozuki::Node::Literal.new('b')
      ])
      allocator = Hoozuki::Automaton::StateAllocator.new

      nfa = described_class.new_from_node(node, allocator)

      expect(nfa.start).to be_a(Hoozuki::Automaton::StateID)
      expect(nfa.accept.length).to eq(1)
      epsilon_transitions =
        nfa.transitions.select do |_, label, _|
          label.nil?
        end
      expect(epsilon_transitions.size).to eq(4)
    end

    it 'builds NFA from Repetition node' do
      node = Hoozuki::Node::Repetition.new(
        Hoozuki::Node::Literal.new('a'),
        :zero_or_more
      )
      allocator = Hoozuki::Automaton::StateAllocator.new

      nfa = described_class.new_from_node(node, allocator)

      expect(nfa.start).to be_a(Hoozuki::Automaton::StateID)
      expect(nfa.accept.length).to eq(1)
      # ε遷移によるループ構造があるはず
      epsilon_transitions =
        nfa.transitions.select do |_, label, _|
        label.nil?
      end
      # 最低4つのε遷移
      expect(epsilon_transitions.size).to be >= 4
    end
  end

  describe '#epsilon_closure' do
    it 'computes epsilon closure of a single state' do
      allocator = Hoozuki::Automaton::StateAllocator.new
      s0 = allocator.next
      s1 = allocator.next
      s2 = allocator.next

      nfa = described_class.new(s0, Set[s2])
      nfa.add_epsilon_transition(s0, s1)
      nfa.add_epsilon_transition(s1, s2)

      closure = nfa.epsilon_closure(Set[s0])
      expect(closure).to include(s0, s1, s2)
    end
  end

  describe '#match?' do
    it 'matches single character' do
      node = Hoozuki::Node::Literal.new('a')
      allocator = Hoozuki::Automaton::StateAllocator.new
      nfa = described_class.new_from_node(node, allocator)

      expect(nfa.match?('a')).to be true
      expect(nfa.match?('b')).to be false
      expect(nfa.match?('')).to be false
    end

    it 'matches concatenation' do
      node = Hoozuki::Node::Concatenation.new([
        Hoozuki::Node::Literal.new('a'),
        Hoozuki::Node::Literal.new('b')
      ])
      allocator = Hoozuki::Automaton::StateAllocator.new
      nfa = described_class.new_from_node(node, allocator)

      expect(nfa.match?('ab')).to be true
      expect(nfa.match?('a')).to be false
      expect(nfa.match?('b')).to be false
      expect(nfa.match?('abc')).to be false
    end

    it 'matches choice' do
      node = Hoozuki::Node::Choice.new([
        Hoozuki::Node::Literal.new('a'),
        Hoozuki::Node::Literal.new('b')
      ])
      allocator = Hoozuki::Automaton::StateAllocator.new
      nfa = described_class.new_from_node(node, allocator)

      expect(nfa.match?('a')).to be true
      expect(nfa.match?('b')).to be true
      expect(nfa.match?('c')).to be false
      expect(nfa.match?('ab')).to be false
    end

    it 'matches repetition pattern' do
      node = Hoozuki::Node::Repetition.new(
        Hoozuki::Node::Literal.new('a'),
        :zero_or_more
      )
      allocator = Hoozuki::Automaton::StateAllocator.new
      nfa = described_class.new_from_node(node, allocator)

      expect(nfa.match?('')).to be true     # 0回
      expect(nfa.match?('a')).to be true    # 1回
      expect(nfa.match?('aaa')).to be true  # 3回
      expect(nfa.match?('b')).to be false   # マッチしない
    end
  end
end
