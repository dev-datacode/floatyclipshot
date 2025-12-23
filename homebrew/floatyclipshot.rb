cask "floatyclipshot" do
  version "2.0.0"
  sha256 "8732f47051bf146602bfa9c38df42bf33bf848501efe2fc9d34ba77cf0d24cd8"

  url "https://github.com/dev-datacode/floatyclipshot/releases/download/v#{version}/floatyclipshot-#{version}.zip"
  name "FloatyClipshot"
  desc "Floating screenshot utility for macOS developers with clipboard management"
  homepage "https://github.com/dev-datacode/floatyclipshot"

  depends_on macos: ">= :big_sur"

  app "floatyclipshot.app"

  zap trash: [
    "~/Library/Preferences/com.hooshyar.floatyclipshot.plist",
    "~/Library/Application Support/FloatyClipshot",
  ]

  caveats <<~EOS
    FloatyClipshot requires the following permissions:

    1. Screen Recording:
       System Settings → Privacy & Security → Screen Recording

    2. Accessibility (for auto-paste):
       System Settings → Privacy & Security → Accessibility

    After installation, launch the app and grant these permissions when prompted.

    If the hotkey doesn't work, toggle FloatyClipshot OFF and ON in
    System Settings → Privacy & Security → Accessibility.
  EOS
end
