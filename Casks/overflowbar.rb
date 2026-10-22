cask "overflowbar" do
  version "1.5.0"
  sha256 "f18b2e8b9156e84e3d05083eb33a06d647fe6243f64fc641202051091d2db566"

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
