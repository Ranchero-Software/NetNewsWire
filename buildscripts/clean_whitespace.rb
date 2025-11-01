#!/usr/bin/env ruby

if ARGV.length != 1
  puts "Usage: #{$0} <filename>"
  exit 1
end

filename = ARGV[0]

unless File.exist?(filename)
  puts "Error: File '#{filename}' does not exist"
  exit 1
end

content = File.read(filename)

# Replace lines that contain only whitespace with just a newline
cleaned_content = content.gsub(/^[ \t]+$/, '')

File.write(filename, cleaned_content)

puts "Cleaned whitespace-only lines in '#{filename}'"

