#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "lib/ai_connect/cli"

exit AIConnect::CLI.start(argv: ARGV, stdin: $stdin.read, cwd: Dir.pwd)
