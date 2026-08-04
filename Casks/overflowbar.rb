cask "overflowbar" do
  version "1.0.16"
  sha256 "9a1eb47e50a2fc9ef49f6bfedfd4d56142bd1b09d63d47380cc2653de155414b"

  url "https://github.com/EvanProgramming/OverflowBar/releases/download/v#{version}/OverflowBar-#{version}.dmg"
  name "OverflowBar"
  desc "Menu bar utility that hides selected status items behind a second row"
  homepage "https://github.com/EvanProgramming/OverflowBar"

  depends_on macos: :sequoia
  depends_on arch: :arm64

  app "OverflowBar.app"

  caveats do
    <<~EOS
      OverflowBar is currently distributed as an ad-hoc signed community build.
      If macOS blocks the first launch, Control-click OverflowBar in Applications
      and choose Open.

      OverflowBar also needs Accessibility and Screen Recording permissions for
      its complete feature set.
    EOS
  end
end
