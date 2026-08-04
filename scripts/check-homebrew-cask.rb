#!/usr/bin/env ruby

require "open3"

ROOT = File.expand_path("..", __dir__)
CASK = File.join(ROOT, "Casks", "overflowbar.rb")
PLIST = File.join(ROOT, "OverflowBar", "Resources", "Info.plist")

abort "Missing #{CASK}" unless File.file?(CASK)
abort "Missing #{PLIST}" unless File.file?(PLIST)

cask = File.read(CASK)
version_match = cask.match(/^\s*version\s+"([^"]+)"\s*$/)
sha_match = cask.match(/^\s*sha256\s+"([0-9a-f]{64})"\s*$/)
url_match = cask.match(%r{https://github\.com/EvanProgramming/OverflowBar/releases/download/v#\{version\}/OverflowBar-#\{version\}\.dmg})

abort "Cask is missing a concrete version" unless version_match
abort "Cask is missing a 64-character SHA-256" unless sha_match
abort "Cask URL must use the versioned GitHub release asset" unless url_match
abort 'Cask must install OverflowBar.app with the app artifact' unless cask.match?(/^\s*app\s+"OverflowBar\.app"\s*$/)

plist_version, stderr, status = Open3.capture3(
  "/usr/libexec/PlistBuddy",
  "-c",
  "Print :CFBundleShortVersionString",
  PLIST,
)
abort "Could not read app version: #{stderr}" unless status.success?

unless plist_version.strip == version_match[1]
  abort "Cask version #{version_match[1]} does not match app version #{plist_version.strip}"
end

puts "Homebrew Cask metadata is valid for OverflowBar #{version_match[1]}"
