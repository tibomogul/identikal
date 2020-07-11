# frozen_string_literal: false

require 'identikal/error'
require 'differ'

module Identikal
  autoload(:HexaPDF, 'hexapdf')
  autoload(:PDF, 'pdf-reader')

  class Compare
    COMPARE_METHODS = %i[diff text all].freeze

    class << self
      def files_same?(file_a, file_b, compare_method: :all)
        validate_arguments(file_a, file_b, compare_method)
        case compare_method
        when :diff
          diff(file_a, file_b)
        when :text
          text_only(file_a, file_b)
        else
          with_formatting(file_a, file_b)
        end
      end

      private
      def diff(file_a, file_b)
        if !with_formatting(file_a, file_b)
          reader_a = PDF::Reader.new(file_a)
          reader_b = PDF::Reader.new(file_b)
          diffs = []
          diffs << "#{file_a} <> #{file_b} are different"
          [reader_a.page_count,reader_b.page_count].min.times do |i|
            text_a = reader_a.pages[i].text # .gsub!(/\n+|\s+/, '')
            text_b = reader_b.pages[i].text # .gsub!(/\n+|\s+/, '')
            res = Differ.diff_by_line(text_a, text_b)
            res.to_s.match(/(\{\".+\"\})/) do |m|
              diffs << m.captures.join("\n")
            end
            # diffs << Differ.diff_by_word(text_a, text_b)
          end
          diffs << "Different no. of pages #{reader_a.page_count} <> #{reader_b.page_count}" if reader_a.page_count != reader_b.page_count
          diffs.join("\n")
        else
          true
        end
      end

      def text_only(file_a, file_b)
        reader_a = PDF::Reader.new(file_a)
        reader_b = PDF::Reader.new(file_b)
        return false unless reader_a.page_count == reader_b.page_count

        text_compare(reader_a, reader_b)
      end

      def with_formatting(file_a, file_b)
        reader_a = HexaPDF::Document.open(file_a)
        reader_b = HexaPDF::Document.open(file_b)
        return false unless reader_a.pages.count == reader_b.pages.count

        format_compare(reader_a, reader_b)
      end

      def format_compare(reader_a, reader_b)
        reader_a.pages.count.times do |i|
          text_a = reader_a.pages[i].contents
          text_b = reader_b.pages[i].contents
          return false unless text_a == text_b
        end
        true
      end

      def text_compare(reader_a, reader_b)
        reader_a.page_count.times do |i|
          text_a = reader_a.pages[i].text.gsub!(/\n+|\s+/, '')
          text_b = reader_b.pages[i].text.gsub!(/\n+|\s+/, '')
          return false unless text_a == text_b
        end
        true
      end

      def validate_arguments(file_a, file_b, compare_method)
        raise Identikal::Error::FileNotFound unless
          File.file?(file_a) && File.file?(file_b)

        raise Identikal::Error::InvalidComparisonMethod unless
          COMPARE_METHODS.include?(compare_method)
      end
    end
  end
end
