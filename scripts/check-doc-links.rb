#!/usr/bin/env ruby

require "pathname"
require "uri"

root = Pathname.new(__dir__).parent
documents = [root / "README.md", root / "CONTRIBUTING.md"] + (root / "docs").glob("*.md")
failures = []

documents.each do |document|
  document.read.scan(/!?(?:\[[^\]]*\])\(([^)]+)\)/).flatten.each do |raw_target|
    target = raw_target.strip.split(/\s+["']/, 2).first
    next if target.nil? || target.empty? || target.start_with?("#")
    next if target.match?(%r{\A(?:https?|mailto):}i)

    path = URI.decode_www_form_component(target.split("#", 2).first)
    resolved = (document.dirname / path).cleanpath
    failures << "#{document.relative_path_from(root)} -> #{target}" unless resolved.exist?
  end
end

if failures.empty?
  puts "Documentation links OK (#{documents.length} files)."
else
  warn "Broken local documentation links:"
  failures.each { |failure| warn "  #{failure}" }
  exit 1
end
