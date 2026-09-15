# frozen_string_literal: true

require_relative '../../lib/hoozuki'

RSpec.describe Hoozuki::Parser do
  describe '#parse' do
    it 'parses literals and concatenation', chapter: 3 do
      expect(described_class.new('a').parse).to be_a(Hoozuki::Node::Literal)
      ast = described_class.new('abc').parse

      expect(ast).to be_a(Hoozuki::Node::Concatenation)
      expect(ast.children.map(&:value)).to eq(%w[a b c])
    end

    it 'parses multibyte literals' do
      ast = described_class.new('こんにちは').parse

      expect(ast.children.map(&:value)).to eq(%w[こ ん に ち は])
    end

    it 'owns a character snapshot of the source pattern' do
      pattern = +'あい'
      parser = described_class.new(pattern)
      pattern.replace('う')

      expect(parser.parse.children.map(&:value)).to eq(%w[あ い])
    end

    it 'parses choices and empty alternatives', chapter: 4 do
      ast = described_class.new('cat|dog|').parse

      expect(ast).to be_a(Hoozuki::Node::Choice)
      expect(ast.children.length).to eq(3)
      expect(ast.children.last).to be_a(Hoozuki::Node::Epsilon)
    end

    it 'parses grouped choices' do
      ast = described_class.new('a(b|c)d').parse

      expect(ast).to be_a(Hoozuki::Node::Concatenation)
      expect(ast.children[1]).to be_a(Hoozuki::Node::Choice)
    end

    it 'parses nested and empty groups' do
      expect(described_class.new('(a|(b|c))').parse).to be_a(Hoozuki::Node::Choice)
      expect(described_class.new('()').parse).to be_a(Hoozuki::Node::Epsilon)
    end

    it 'parses zero-or-more repetition' do
      ast = described_class.new('(ab)*').parse

      expect(ast).to be_a(Hoozuki::Node::Repetition)
      expect(ast.zero_or_more?).to be(true)
    end

    it 'parses one-or-more and optional repetition' do
      expect(described_class.new('a+').parse.one_or_more?).to be(true)
      expect(described_class.new('a?').parse.optional?).to be(true)
    end

    it 'parses escaped metacharacters as literals' do
      ast = described_class.new('\(a\|b\)\*').parse

      expect(ast.children.map(&:value)).to eq(%w[( a | b ) *])
    end

    it 'parses an escaped backslash' do
      ast = described_class.new('a\\\\b').parse

      expect(ast.children.map(&:value)).to eq(['a', '\\', 'b'])
    end

    it 'quotes an unknown escape one character at a time' do
      ast = described_class.new('\a\b').parse

      expect(ast.children.map(&:value)).to eq(%w[a b])
    end

    it 'rejects incomplete escapes' do
      expect { described_class.new('a\\').parse }
        .to raise_error(/Incomplete escape sequence/)
    end

    it 'reports unmatched parentheses with the opening position' do
      expect { described_class.new('a(b').parse }
        .to raise_error(
          "Expected closing parenthesis for '(' at position 1. Got: end of pattern"
        )
      expect { described_class.new('a((b|c)').parse }
        .to raise_error(/Expected closing parenthesis.*position 1/)
      expect { described_class.new('a)b').parse }
        .to raise_error(/Unexpected character.*position 1/)
    end

    it 'rejects non-String and invalidly encoded patterns' do
      expect { described_class.new(nil) }.to raise_error(TypeError)

      invalid = "\xFF".dup.force_encoding(Encoding::UTF_8)
      expect { described_class.new(invalid) }.to raise_error(ArgumentError)
    end

    it 'rejects ASCII-incompatible pattern encodings' do
      pattern = 'a*'.encode(Encoding::UTF_16LE)

      expect { described_class.new(pattern) }
        .to raise_error(ArgumentError, /ASCII-compatible/)
    end
  end
end
