# frozen_string_literal: true

require_relative '../lib/hoozuki'

RSpec.describe Hoozuki do
  describe 'input contract' do
    it 'rejects invalid patterns' do
      invalid = "\xFF".dup.force_encoding(Encoding::UTF_8)

      expect { described_class.new(nil) }.to raise_error(TypeError)
      expect { described_class.new(invalid) }.to raise_error(ArgumentError)
      expect { described_class.new('a'.encode(Encoding::UTF_16LE)) }
        .to raise_error(ArgumentError, /ASCII-compatible/)
    end
  end

  describe '#match?' do
    context 'with exact match patterns' do
      it 'matches an exact string', chapter: 2 do
        expect(described_class.new('abc').match?('abc')).to be(true)
      end

      it 'rejects shorter and longer strings' do
        regex = described_class.new('abc')

        expect(regex.match?('ab')).to be(false)
        expect(regex.match?('abcd')).to be(false)
      end

      it 'matches empty and multibyte strings' do
        expect(described_class.new('').match?('')).to be(true)
        expect(described_class.new('').match?('a')).to be(false)

        regex = described_class.new('こんにちは')
        expect(regex.match?('こんにちは')).to be(true)
        expect(regex.match?('さようなら')).to be(false)
      end
    end

    context 'with escape sequences' do
      it 'matches escaped metacharacters', chapter: 10 do
        expect(described_class.new('a\*b').match?('a*b')).to be(true)
        expect(described_class.new('a\|b').match?('a|b')).to be(true)
        expect(described_class.new('\(hello\)').match?('(hello)')).to be(true)
      end

      it 'matches an escaped backslash' do
        regex = described_class.new('a\\\\b')

        expect(regex.match?('a\b')).to be(true)
        expect(regex.match?('ab')).to be(false)
      end

      it 'matches a complex escaped pattern' do
        regex = described_class.new('\(a\|b\)\*')

        expect(regex.match?('(a|b)*')).to be(true)
        expect(regex.match?('ab')).to be(false)
      end

      it 'does not normalize Unicode representations' do
        regex = described_class.new("\u00E9")

        expect(regex.match?("e\u0301")).to be(false)
      end
    end

    context 'with grouped and repeated patterns' do
      it 'matches choices and groups', chapter: 6 do
        regex = described_class.new('a(b|c)d')

        expect(regex.match?('abd')).to be(true)
        expect(regex.match?('acd')).to be(true)
        expect(regex.match?('ad')).to be(false)
      end

      it 'matches zero-or-more repetition', chapter: 8 do
        regex = described_class.new('a(bc|de)*f')

        expect(regex.match?('af')).to be(true)
        expect(regex.match?('abcdef')).to be(true)
        expect(regex.match?('abcbcdef')).to be(true)
      end

      it 'matches one-or-more and optional repetition', chapter: 9 do
        expect(described_class.new('a+').match?('')).to be(false)
        expect(described_class.new('a+').match?('aaa')).to be(true)
        expect(described_class.new('ab?c').match?('ac')).to be(true)
        expect(described_class.new('ab?c').match?('abc')).to be(true)

        %w[()+ (a*)+ (a?)+ (a*)*].each do |pattern|
          expect(described_class.new(pattern).match?('')).to be(true)
        end

        ['', 'a', 'aa', 'b'].each do |input|
          expect(described_class.new('a+').match?(input))
            .to eq(described_class.new('aa*').match?(input))
          expect(described_class.new('a?').match?(input))
            .to eq(described_class.new('(a|)').match?(input))
        end
      end

      it 'terminates on epsilon cycles' do
        expect(described_class.new('(|)*').match?('')).to be(true)
      end

      it 'treats unsupported syntax as documented literals' do
        expect(described_class.new('.').match?('.')).to be(true)
        expect(described_class.new('[a-z]').match?('[a-z]')).to be(true)
        expect(described_class.new('a{2,3}').match?('a{2,3}')).to be(true)
        expect(described_class.new('\d').match?('d')).to be(true)
        expect(described_class.new('[a|b]').match?('[a')).to be(true)
        expect(described_class.new('[a*]').match?('[aaa]')).to be(true)
        expect(described_class.new('\**').match?('***')).to be(true)
      end
    end
  end
end
