cask "floatyclipshot" do
  version "1.0.0"
  sha256 "REPLACE_WITH_ACTUAL_SHA256_FROM_RELEASE"

  url "https://github.com/hooshyar/floatyclipshot/releases/download/v#{version}/floatyclipshot-#{version}.zip"
  name "FloatyClipshot"
  desc "Floating button screenshot utility for macOS developers"
  homepage "https://github.com/hooshyar/floatyclipshot"

  depends_on macos: ">= :big_sur"

  app "floatyclipshot.app"

  zap trash: [
    "~/Library/Preferences/com.hooshyar.floatyclipshot.plist",
    "~/Library/Application Support/floatyclipshot",
  ]

  caveats <<~EOS
    FloatyClipshot requires the following permissions:

    1. Screen Recording permission:
       System Preferences → Security & Privacy → Screen Recording

    2. Accessibility permission (for auto-paste):
       System Preferences → Security & Privacy → Accessibility

    After installation, launch the app and grant these permissions when prompted.
  EOS
end
