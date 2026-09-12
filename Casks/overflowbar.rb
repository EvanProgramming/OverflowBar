cask "overflowbar" do
  version "1.0.18"
  sha256 "9fff4290e30452db77414340ac46da8a4e18ab0559e7aa1b8ca3d31c603044fb"

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
