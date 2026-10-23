cask "overflowbar" do
  version "1.5.1"
  sha256 "5260412c515f5806db701e9b741e741e6bd352903d987d1babbffd6f1039d0f7"

  url "https://github.com/EvanProgramming/OverflowBar/releases/download/v#{version}/OverflowBar-#{version}.dmg"
  name "OverflowBar"
  desc "Menu bar utility with native icon management and a second row"
  homepage "https://github.com/EvanProgramming/OverflowBar"

  depends_on macos: :sequoia

  app "OverflowBar.app"

  caveats do
    <<~EOS
      OverflowBar is currently distributed as an ad-hoc signed community build.
      If macOS blocks the first launch, Control-click OverflowBar in Applications
      and choose Open.

      Accessibility is required for automatic icon arrangement and native clicks.
      Screen Recording enables genuine icon previews.
    EOS
  end
end
