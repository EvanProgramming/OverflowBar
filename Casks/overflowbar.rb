cask "overflowbar" do
  version "1.0.19"
  sha256 "e4e10f4f6ae9a88ab2b4f1f7ef96ce00d8b2090f50917e1842256e9a8d1210d0"

  url "https://github.com/EvanProgramming/OverflowBar/releases/download/v#{version}/OverflowBar-#{version}.dmg"
  name "OverflowBar"
  desc "Menu bar utility that hides selected status items behind a second row"
  homepage "https://github.com/EvanProgramming/OverflowBar"

  depends_on arch: :arm64
  depends_on macos: :sequoia

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
