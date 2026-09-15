# frozen_string_literal: true

require_relative '../../../lib/hoozuki'

RSpec.describe Hoozuki::Automaton::DFA do
  def dfa_for(pattern)
    allocator = Hoozuki::Automaton::StateAllocator.new
    node = Hoozuki::Parser.new(pattern).parse
    nfa = Hoozuki::Automaton::NFA.new_from_node(node, allocator)
    described_class.from_nfa(nfa)
  end

  it 'counts initial accept states' do
    dfa = described_class.new(0, Set[1])

    expect(dfa.state_count).to eq(2)
  end

  it 'converts literal, choice, and concatenation NFAs', chapter: 7 do
    expect(dfa_for('a').state_count).to be >= 2
    expect(dfa_for('a|b').match?('b')).to be(true)
    expect(dfa_for('ab').match?('ab')).to be(true)
  end

  it 'rejects conflicting transitions' do
    dfa = described_class.new(0, Set.new)
    dfa.add_transition(0, 'a', 1)

    expect { dfa.add_transition(0, 'a', 2) }
      .to raise_error(/not deterministic/)
  end

  it 'matches using deterministic transitions' do
    dfa = dfa_for('a(b|c)d')

    expect(dfa.match?('abd')).to be(true)
    expect(dfa.match?('acd')).to be(true)
    expect(dfa.match?('ad')).to be(false)
  end

  it 'matches repetition without epsilon transitions at runtime' do
    expect(dfa_for('a*').match?('')).to be(true)
    expect(dfa_for('(ab)+').match?('abab')).to be(true)
    expect(dfa_for('b?').match?('bb')).to be(false)
  end

  it 'preserves the public transition snapshot' do
    dfa = dfa_for('a')

    expect(dfa.transitions).to be_frozen
    expect { dfa.transitions[[0, 'a']] = 2 }.to raise_error(FrozenError)
    expect(dfa.match?('a')).to be(true)
  end

  it 'accepts the compatibility cache argument without creating a cache' do
    dfa = dfa_for('a')

    expect(dfa.match?('a', true)).to be(true)
    expect(dfa.instance_variable_defined?(:@cache)).to be(false)
  end

  it 'keeps NFA and DFA equivalent for short supported inputs' do
    %w[a a|b ab (a|b)c a* (ab)* a+ b?].each do |pattern|
      allocator = Hoozuki::Automaton::StateAllocator.new
      ast = Hoozuki::Parser.new(pattern).parse
      nfa = Hoozuki::Automaton::NFA.new_from_node(ast, allocator)
      dfa = described_class.from_nfa(nfa)

      ['', 'a', 'b', 'ab', 'abc'].each do |input|
        expect(dfa.match?(input)).to eq(nfa.match?(input))
      end
    end
  end

  it 'does not expose the transition lookup method as public API' do
    expect(described_class.public_instance_methods).not_to include(:next_transition)
  end
end
