# frozen_string_literal: true

require_relative '../../../lib/hoozuki'

RSpec.describe Hoozuki::Automaton::NFA do
  def nfa_for(pattern)
    allocator = Hoozuki::Automaton::StateAllocator.new
    node = Hoozuki::Parser.new(pattern).parse
    described_class.new_from_node(node, allocator)
  end

  it 'builds immutable state IDs' do
    allocator = Hoozuki::Automaton::StateAllocator.new
    first = allocator.next
    second = allocator.next

    expect(first.id).to eq(0)
    expect(second.id).to eq(1)
    expect(first).to be_frozen
  end

  it 'builds literal, epsilon, concatenation, and choice NFAs', chapter: 5 do
    expect(nfa_for('a').transitions.size).to eq(1)
    expect(nfa_for('').match?('')).to be(true)
    expect(nfa_for('ab').transitions.size).to eq(3)
    expect(nfa_for('a|b').match?('a')).to be(true)
  end

  it 'computes epsilon closure' do
    allocator = Hoozuki::Automaton::StateAllocator.new
    first = allocator.next
    middle = allocator.next
    last = allocator.next
    nfa = described_class.new(first, Set[last])
    nfa.add_epsilon_transition(first, middle)
    nfa.add_epsilon_transition(middle, last)

    expect(nfa.epsilon_closure(Set[first])).to include(first, middle, last)
  end

  it 'matches literals, concatenation, and choices' do
    expect(nfa_for('a').match?('a')).to be(true)
    expect(nfa_for('ab').match?('ab')).to be(true)
    expect(nfa_for('a|b').match?('b')).to be(true)
    expect(nfa_for('ab').match?('a')).to be(false)
  end

  it 'matches all repetition operators' do
    expect(nfa_for('a*').match?('')).to be(true)
    expect(nfa_for('a*').match?('aaa')).to be(true)
    expect(nfa_for('a+').match?('')).to be(false)
    expect(nfa_for('a+').match?('aaa')).to be(true)
    expect(nfa_for('a?').match?('')).to be(true)
    expect(nfa_for('a?').match?('aa')).to be(false)
  end

  it 'keeps transition snapshots immutable' do
    nfa = nfa_for('a')

    expect(nfa.transitions).to be_frozen
    expect { nfa.transitions << [nfa.start, 'b', nfa.accept.first] }
      .to raise_error(FrozenError)
  end

  it 'keeps indexed transitions consistent with the public snapshot' do
    nfa = nfa_for('a')

    expect(nfa.transitions).to include([nfa.start, 'a', nfa.accept.first])
    expect(nfa.character_transitions_from(nfa.start)['a']).to include(nfa.accept.first)
  end

  it 'does not loop on epsilon cycles' do
    expect(nfa_for('(|)*').match?('')).to be(true)
  end

  it 'rejects unsupported AST nodes' do
    node = Object.new
    allocator = Hoozuki::Automaton::StateAllocator.new

    expect { described_class.new_from_node(node, allocator) }
      .to raise_error(/Unsupported node type/)
  end

  it 'rejects a nil AST node' do
    allocator = Hoozuki::Automaton::StateAllocator.new

    expect { described_class.new_from_node(nil, allocator) }
      .to raise_error(ArgumentError, 'Node cannot be nil')
  end

  it 'does not expose a transition writer' do
    nfa = described_class.new(Object.new, Set.new)

    expect(nfa).not_to respond_to(:transitions=)
  end
end
