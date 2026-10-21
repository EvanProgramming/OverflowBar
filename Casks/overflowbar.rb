cask "overflowbar" do
  version "1.5.0"
  sha256 "134257ed76438a29b4358840036dd6fcc4f5b102fa1544437b0b2714aafc9d7d"

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
