#!/usr/bin/env ruby
# Print ARGV, STDIN, STDERR, realpath of the script, and current working directory
user_promt = STDIN.read
argv = ARGV.dup
cwd = Dir.pwd

def extract_code_from_markdown(response)
  if response =~ /```[a-zA-Z]*\n(.*?)```/m
    $1.strip
  else
    response.strip
  end
end

# Format detection from ARGV file extension
format = if argv[0] && argv[0].include?(".")
  File.extname(argv[0]).sub(".", "")
else
  "plain"
end

# Read context file if available
context_file = File.expand_path(argv[0].to_s, cwd)
context = File.exist?(context_file) ? File.read(context_file) : ""

# Build Copilot prompt
prompt = <<~PROMT
  You are an expert .#{format} developer. Only output valid .#{format} code.
  Ensure consistency with the following context:
  #{context}

  Implement the following prompt in .#{format} and return only the implementation.
  #{user_promt}
PROMT

# Call Copilot CLI
require 'open3'
copilot_cmd = ["copilot", "--model", "gpt-4.1", "-p", prompt, "-s"]
response = nil
Open3.popen3(*copilot_cmd) do |stdin, stdout, stderr, wait_thr|
  stdin.close
  response = stdout.read
  unless wait_thr.value.success?
    warn "Copilot error: #{stderr.read}"
  end
end

clean_response = extract_code_from_markdown(response)

puts "#{user_promt}\n"
puts "#{clean_response}"
