# frozen_string_literal: true

require 'set'

class Hoozuki
  module Automaton
    class DFA
      attr_reader :start, :state_count

      def initialize(start, accept)
        @start = start          # Integer: 初期状態のID
        # Set: 内部で保持する受理状態のID集合
        @accept = Set.new(accept)
        @transitions = {}       # Hash: [from_id, char] => to_id
        @transition_index = {}  # Hash: state => {char => state}
        @states = Set.new([start]).merge(@accept)
        @state_count = @states.size
      end

      # 外部には変更不能なスナップショットを返す
      def accept
        @accept.dup.freeze
      end

      # DFA構築中に受理状態を追加する
      def add_accept_state(id)
        @accept << id
        add_state(id)
        self
      end

      def transitions
        @transitions.dup.freeze
      end

      def add_state(id)
        @states << id
        @state_count = @states.size
        self
      end

      def add_transition(from, char, to)
        label = char.dup.freeze
        key = [from, label].freeze
        existing = @transitions[key]
        if !existing.nil? && existing != to
          message = "DFA transition is not deterministic: " \
                    "#{key.inspect}"
          raise ArgumentError, message
        end

        @transitions[key] = to
        transitions_from(from)[label] = to
        add_state(from)
        add_state(to)
        self
      end

      def self.from_nfa(nfa)
        dfa_states = {}
        queue = []
        queue_head = 0
        nfa_accept_set = nfa.accept

        start_states = nfa.epsilon_closure(Set[nfa.start])
        dfa_states[start_states] = 0
        queue << start_states

        dfa = new(0, Set.new)

        # BFSで状態を構築。Array#shiftに依存せず先頭位置を管理する
        while queue_head < queue.length
          current_nfa_states = queue[queue_head]
          queue_head += 1
          current_dfa_id = dfa_states[current_nfa_states]

          # 受理状態の判定
          accepting = current_nfa_states.any? do |state|
            nfa_accept_set.include?(state)
          end
          if accepting
            dfa.add_accept_state(current_dfa_id)
          end

          # 遷移マップの構築
          transitions_by_char = collect_character_targets(
            nfa,
            current_nfa_states
          )

          # 新しい状態の登録と遷移の追加
          transitions_by_char.each do |char, moved_states|
            # 文字ごとに対象をまとめてからε閉包を1回だけ計算する
            next_nfa_states = nfa.epsilon_closure(moved_states)
            next_dfa_id = dfa_states[next_nfa_states]

            if next_dfa_id.nil?
              next_dfa_id = dfa_states.length
              dfa_states[next_nfa_states] = next_dfa_id
              dfa.add_state(next_dfa_id)
              queue << next_nfa_states
            end

            dfa.add_transition(current_dfa_id, char, next_dfa_id)
          end
        end

        dfa
      end

      def self.collect_character_targets(nfa, states)
        targets_by_char = Hash.new do |targets, char|
          targets[char] = Set.new
        end

        states.each do |state|
          transitions = nfa.character_transitions_from(state)
          transitions.each do |char, targets|
            targets_by_char[char].merge(targets)
          end
        end

        targets_by_char
      end

      private_class_method :collect_character_targets

      def match?(input, _use_cache = false)
        state = @start

        input.each_char do |char|
          state = next_transition(state, char)

          return false if state.nil?
        end

        @accept.include?(state)
      end

      def next_transition(current, input, _use_cache = false)
        state_transitions = @transition_index[current]
        return nil unless state_transitions

        state_transitions[input]
      end

      private :next_transition

      private

      def transitions_from(state)
        @transition_index[state] ||= {}
      end
    end
  end
end
