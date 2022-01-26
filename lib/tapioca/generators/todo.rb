# typed: strict
# frozen_string_literal: true

module Tapioca
  module Generators
    class Todo < Base
      include SorbetHelper

      sig do
        params(
          todo_file: String,
          file_header: T::Boolean,
          default_command: String,
          file_writer: Thor::Actions
        ).void
      end
      def initialize(todo_file:, file_header:, default_command:, file_writer: FileWriter.new)
        @todo_file = todo_file
        @file_header = file_header

        super(default_command: default_command, file_writer: file_writer)
      end

      sig { override.void }
      def generate
        say("Finding all unresolved constants, this may take a few seconds... ")

        # Clean all existing unresolved constants before regenerating the list
        # so Sorbet won't grab them as already resolved.
        File.delete(@todo_file) if File.exist?(@todo_file)

        constants = unresolved_constants

        if constants.empty?
          say("Nothing to do", :green)
          return
        end

        say("Done", :green)
        contents = rbi(constants, command: "#{@default_command} todo")
        create_file(@todo_file, contents.string, verbose: false)

        name = set_color(@todo_file, :yellow, :bold)
        say("\nAll unresolved constants have been written to #{name}.", [:green, :bold])
        say("Please review changes and commit them.", [:green, :bold])
      end

      private

      sig { params(constants: T::Array[String], command: String).returns(RBI::File) }
      def rbi(constants, command:)
        file = RBI::File.new

        if @file_header
          file.comments << RBI::Comment.new("DO NOT EDIT MANUALLY")
          file.comments << RBI::Comment.new("This is an autogenerated file for unresolved constants.")
          file.comments << RBI::Comment.new("Please instead update this file by running `#{command}`.")
          file.comments << RBI::BlankLine.new
        end

        file.comments << RBI::Comment.new("typed: false")

        constants.each do |name|
          file << RBI::Module.new(name)
        end

        file
      end

      sig { returns(T::Array[String]) }
      def unresolved_constants
        # Taken from https://github.com/sorbet/sorbet/blob/master/gems/sorbet/lib/todo-rbi.rb
        sorbet("--print=missing-constants", "--stdout-hup-hack", "--no-error-count")
          .strip
          .each_line
          .map do |line|
            next if line.include?("<")
            next if line.include?("class_of")
            line.strip.gsub("T.untyped::", "")
          end
          .compact
      end
    end
  end
end
