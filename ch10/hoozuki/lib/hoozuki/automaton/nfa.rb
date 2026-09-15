# frozen_string_literal: true

require 'set'

class Hoozuki
  module Automaton
    class NFA
      EMPTY_STATES = Set.new.freeze
      EMPTY_CHARACTER_TRANSITIONS = {}.freeze

      attr_accessor :start
      attr_reader :accept

      def initialize(start, accept)
        @start = start
        self.accept = accept
        @transitions = Set.new
        @epsilon_transitions = {}
        @character_transitions = {}
      end

      def accept=(states)
        @accept = Set.new(states).freeze
      end

      def transitions
        snapshot = Set.new
        @transitions.each do |from, label, to|
          copied_label = label&.dup&.freeze
          snapshot << [from, copied_label, to].freeze
        end
        snapshot.freeze
      end

      def character_transitions_from(state)
        transitions = character_targets_for(state)
        return EMPTY_CHARACTER_TRANSITIONS if transitions.empty?

        transitions.each_with_object({}) do |entry, snapshot|
          char, targets = entry
          snapshot[char.dup.freeze] = targets.dup.freeze
        end.freeze
      end

      def epsilon_targets_from(state)
        targets = epsilon_targets_for(state)
        return EMPTY_STATES if targets.empty?

        Set.new(targets).freeze
      end

      def add_transition(from, char, to)
        label = char.dup.freeze
        @transitions << [from, label, to].freeze
        character_transitions_for(from)[label] ||= Set.new
        character_transitions_for(from)[label] << to
        self
      end

      def add_epsilon_transition(from, to)
        @transitions << [from, nil, to].freeze
        epsilon_transitions_for(from) << to
        self
      end

      def merge_transitions(other)
        other.transitions.each do |from, label, to|
          if label.nil?
            add_epsilon_transition(from, to)
          else
            add_transition(from, label, to)
          end
        end
        self
      end

      def epsilon_closure(start_states)
        visited = Set.new(start_states)
        queue = visited.to_a
        head = 0

        while head < queue.length
          state = queue[head]
          head += 1

          epsilon_targets_for(state).each do |next_state|
            next if visited.include?(next_state)

            visited << next_state
            queue << next_state
          end
        end

        visited.freeze
      end

      def match?(input)
        current_states = epsilon_closure(Set[@start])

        input.each_char do |char|
          next_states = Set.new

          current_states.each do |state|
            targets = character_targets_for(state).fetch(
              char,
              EMPTY_STATES
            )
            next_states.merge(targets)
          end

          return false if next_states.empty?

          current_states = epsilon_closure(next_states)
        end

        current_states.any? { |state| @accept.include?(state) }
      end

      def self.new_from_node(node, allocator)
        raise ArgumentError, 'Node cannot be nil' if node.nil?

        case node
        when Node::Literal
          build_literal(node, allocator)
        when Node::Epsilon
          build_epsilon(allocator)
        when Node::Concatenation
          build_concatenation(node, allocator)
        when Node::Choice
          build_choice(node, allocator)
        when Node::Repetition
          if node.zero_or_more?
            build_zero_or_more(node.child, allocator)
          elsif node.one_or_more?
            build_one_or_more(node.child, allocator)
          elsif node.optional?
            build_optional(node.child, allocator)
          else
            message = "Unsupported quantifier: #{node.inspect}"
            raise ArgumentError, message
          end
        else
          message = "Unsupported node type: #{node.class}"
          raise ArgumentError, message
        end
      end

      def self.build_literal(node, allocator)
        start_state = allocator.next
        accept_state = allocator.next

        nfa = new(start_state, Set[accept_state])
        nfa.add_transition(start_state, node.value, accept_state)
        nfa
      end

      def self.build_epsilon(allocator)
        start_state = allocator.next
        accept_state = allocator.next

        nfa = new(start_state, Set[accept_state])
        nfa.add_epsilon_transition(start_state, accept_state)
        nfa
      end

      def self.build_concatenation(node, allocator)
        nfas = node.children.map do |child|
          new_from_node(child, allocator)
        end

        nfa = nfas.first

        nfas.drop(1).each do |next_nfa|
          nfa.merge_transitions(next_nfa)

          nfa.accept.each do |accept_state|
            nfa.add_epsilon_transition(accept_state, next_nfa.start)
          end

          nfa.accept = next_nfa.accept
        end

        nfa
      end

      def self.build_choice(node, allocator)
        nfas = node.children.map do |child|
          new_from_node(child, allocator)
        end

        start_state = allocator.next
        accept_state = allocator.next
        nfa = new(start_state, Set[accept_state])

        nfas.each do |child_nfa|
          nfa.merge_transitions(child_nfa)
          nfa.add_epsilon_transition(start_state, child_nfa.start)
          child_nfa.accept.each do |child_accept|
            nfa.add_epsilon_transition(child_accept, accept_state)
          end
        end

        nfa
      end

      def self.build_zero_or_more(child_node, allocator)
        # 子ノードのNFAを構築
        child_nfa = new_from_node(child_node, allocator)

        # 新しい開始状態と受理状態
        start_state = allocator.next
        accept_state = allocator.next

        nfa = new(start_state, Set[accept_state])

        # 子NFAの遷移をマージ
        nfa.merge_transitions(child_nfa)

        # 新しい開始状態から子NFAの開始へ（1回目の実行）
        nfa.add_epsilon_transition(start_state, child_nfa.start)

        # 新しい開始状態から受理状態へ（0回の繰り返し）
        nfa.add_epsilon_transition(start_state, accept_state)

        # 子NFAの各受理状態から:
        child_nfa.accept.each do |child_accept|
          # 新しい受理状態へ（終了）
          nfa.add_epsilon_transition(child_accept, accept_state)

          # 子NFAの開始へ戻る（ループバック）
          nfa.add_epsilon_transition(child_accept, child_nfa.start)
        end

        nfa
      end

      def self.build_one_or_more(child_node, allocator)
        # 子ノードのNFAを構築
        child_nfa = new_from_node(child_node, allocator)

        # 新しい開始状態と受理状態
        start_state = allocator.next
        accept_state = allocator.next

        nfa = new(start_state, Set[accept_state])

        # 子NFAの遷移をマージ
        nfa.merge_transitions(child_nfa)

        # start → 子NFAの開始（必ず1回は通る）
        nfa.add_epsilon_transition(start_state, child_nfa.start)

        # 子NFAの受理 → accept（終了）
        child_nfa.accept.each do |child_accept|
          nfa.add_epsilon_transition(child_accept, accept_state)

          # 子NFAの受理 → 子NFAの開始（ループバック）
          nfa.add_epsilon_transition(child_accept, child_nfa.start)
        end

        # startからacceptへの直接遷移はない！

        nfa
      end

      def self.build_optional(child_node, allocator)
        child_nfa = new_from_node(child_node, allocator)
        start_state = allocator.next
        accept_state = allocator.next

        nfa = new(start_state, Set[accept_state])
        nfa.merge_transitions(child_nfa)

        # start → accept（0回の選択肢）
        nfa.add_epsilon_transition(start_state, accept_state)

        # start → 子NFAの開始（1回の選択肢）
        nfa.add_epsilon_transition(start_state, child_nfa.start)

        # 子NFAの受理 → accept
        child_nfa.accept.each do |child_accept|
          nfa.add_epsilon_transition(child_accept, accept_state)
        end

        nfa
      end

      private_class_method :build_literal, :build_epsilon,
                           :build_concatenation, :build_choice,
                           :build_zero_or_more, :build_one_or_more,
                           :build_optional

      private

      def epsilon_transitions_for(state)
        @epsilon_transitions[state] ||= Set.new
      end

      def character_transitions_for(state)
        @character_transitions[state] ||= {}
      end

      def epsilon_targets_for(state)
        @epsilon_transitions.fetch(state, EMPTY_STATES)
      end

      def character_targets_for(state)
        @character_transitions.fetch(
          state,
          EMPTY_CHARACTER_TRANSITIONS
        )
      end
    end
  end
end
