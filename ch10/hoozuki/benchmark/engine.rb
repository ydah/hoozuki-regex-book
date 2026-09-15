# frozen_string_literal: true

require_relative '../lib/hoozuki'

def measure(label)
  started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  yield
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
  puts format('%-12s %8.4f s', label, elapsed)
end

pattern = ENV.fetch('PATTERN', '(a|b)*abb')
input = ENV.fetch('INPUT', 'ab' * 100 + 'abb')
iterations = Integer(ENV.fetch('ITERATIONS', '1000'))

ast = Hoozuki::Parser.new(pattern).parse
nfa = Hoozuki::Automaton::NFA.new_from_node(
  ast,
  Hoozuki::Automaton::StateAllocator.new
)
dfa = Hoozuki::Automaton::DFA.from_nfa(nfa)

measure('parse') do
  iterations.times { Hoozuki::Parser.new(pattern).parse }
end
measure('build NFA') do
  iterations.times do
    Hoozuki::Automaton::NFA.new_from_node(
      ast,
      Hoozuki::Automaton::StateAllocator.new
    )
  end
end
measure('build DFA') { iterations.times { Hoozuki::Automaton::DFA.from_nfa(nfa) } }
measure('match NFA') { iterations.times { nfa.match?(input) } }
measure('match DFA') { iterations.times { dfa.match?(input) } }
