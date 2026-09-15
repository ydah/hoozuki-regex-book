# frozen_string_literal: true

require_relative '../../../lib/hoozuki'

RSpec.describe 'automaton review regressions' do
  describe Hoozuki::Automaton::NFA do
    it 'does not expose a transitions writer' do
      nfa = described_class.new(Object.new, Set.new)

      expect(nfa).to respond_to(:transitions)
      expect(nfa).not_to respond_to(:transitions=)
    end

    it 'keeps the transition index in sync with transitions added through the API' do
      allocator = Hoozuki::Automaton::StateAllocator.new
      start = allocator.next
      accept = allocator.next
      nfa = described_class.new(start, Set[accept])

      nfa.add_transition(start, 'a', accept)

      transitions = nfa.character_transitions_from(start)
      expect(transitions['a']).to include(accept)
      expect(transitions).to be_frozen
      expect(transitions['a']).to be_frozen
      expect { transitions.clear }.to raise_error(FrozenError)
      expect { transitions['a'].clear }.to raise_error(FrozenError)
      expect(nfa.match?('a')).to be(true)

      epsilon_start = allocator.next
      epsilon_accept = allocator.next
      nfa.add_epsilon_transition(epsilon_start, epsilon_accept)
      epsilon_targets = nfa.epsilon_targets_from(epsilon_start)

      expect(epsilon_targets).to include(epsilon_accept)
      expect(epsilon_targets).to be_frozen
      expect { epsilon_targets.clear }.to raise_error(FrozenError)
    end

    it 'owns labels and does not return internal target sets from updates' do
      allocator = Hoozuki::Automaton::StateAllocator.new
      start = allocator.next
      accept = allocator.next
      nfa = described_class.new(start, Set[accept])
      label = +'a'

      expect(nfa.add_transition(start, label, accept)).to equal(nfa)
      expect(nfa.add_epsilon_transition(start, accept)).to equal(nfa)
      label.replace('b')

      expect(nfa.match?('a')).to be(true)
      expect(nfa.transitions).to include([start, 'a', accept])
    end
  end

  describe Hoozuki::Automaton::DFA do
    it 'does not create a cache when cache compatibility is requested' do
      accept_states = Set[0]
      dfa = described_class.new(0, accept_states)
      dfa.add_transition(0, 'a', 0)
      accept_states.clear

      expect(dfa.accept).to be_frozen
      expect { dfa.accept.clear }.to raise_error(FrozenError)
      expect(dfa.match?('a', true)).to be(true)
      expect(dfa.instance_variable_defined?(:@cache)).to be(false)
    end

    it 'preserves the public transition hash while using indexed lookup' do
      dfa = described_class.new(0, Set[1])
      dfa.add_transition(0, 'a', 1)

      expect(dfa.transitions).to eq([0, 'a'] => 1)
      expect(dfa.match?('a')).to be(true)
    end

    it 'owns labels and registers states through the transition API' do
      dfa = described_class.new(0, Set.new)
      label = +'a'

      expect(dfa.add_transition(0, label, 1)).to equal(dfa)
      expect(dfa.add_accept_state(1)).to equal(dfa)
      label.replace('b')

      expect(dfa.transitions).to eq([0, 'a'] => 1)
      expect { dfa.transitions.keys.first[1].replace('b') }.to raise_error(FrozenError)
      expect(dfa.match?('a')).to be(true)
      expect(dfa.state_count).to eq(2)
    end

    it 'constructs equivalent transitions for a choice' do
      node = Hoozuki::Node::Choice.new([
        Hoozuki::Node::Literal.new('a'),
        Hoozuki::Node::Literal.new('b')
      ])
      allocator = Hoozuki::Automaton::StateAllocator.new
      nfa = described_class_from_node(node, allocator)
      dfa = described_class.from_nfa(nfa)

      expect(dfa.match?('a')).to be(true)
      expect(dfa.match?('b')).to be(true)
      expect(dfa.match?('ab')).to be(false)
    end

    it 'applies epsilon closure once per character after collecting NFA moves' do
      node = Hoozuki::Node::Choice.new([
        Hoozuki::Node::Literal.new('a'),
        Hoozuki::Node::Literal.new('a')
      ])
      allocator = Hoozuki::Automaton::StateAllocator.new
      nfa = described_class_from_node(node, allocator)
      calls = []
      original_closure = nfa.method(:epsilon_closure)
      nfa.define_singleton_method(:epsilon_closure) do |states|
        calls << states
        original_closure.call(states)
      end

      Hoozuki::Automaton::DFA.from_nfa(nfa)

      expect(calls.length).to eq(2)
      expect(calls.last.length).to eq(2)
    end

    def described_class_from_node(node, allocator)
      Hoozuki::Automaton::NFA.new_from_node(node, allocator)
    end
  end

  describe Hoozuki do
    it 'does not retain the source pattern after compiling it' do
      regex = described_class.new('ab')

      expect(regex.instance_variable_defined?(:@pattern)).to be(false)
      expect(regex.match?('ab')).to be(true)
    end

    it 'rejects non-String and invalidly encoded inputs' do
      regex = described_class.new('a')

      expect { regex.match?(nil) }.to raise_error(TypeError)
      invalid = "\xFF".dup.force_encoding(Encoding::UTF_8)
      expect { regex.match?(invalid) }.to raise_error(ArgumentError)
    end
  end
end
