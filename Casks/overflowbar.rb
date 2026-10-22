cask "overflowbar" do
  version "1.5.0"
  sha256 "7d1dd8ea6268bd138e78c327659db17f74833750ed34bddc12efec76f7d2bb3c"

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
