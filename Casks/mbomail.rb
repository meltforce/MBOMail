cask "mbomail" do
  version "1.0.0"
  sha256 "REPLACE_WITH_SHA256_OF_DMG"

  url "https://github.com/OWNER/mboMail/releases/download/v#{version}/mboMail.dmg"
  name "mboMail"
  desc "Native macOS wrapper for mailbox.org"
  homepage "https://github.com/OWNER/mboMail"

  depends_on macos: ">= :sequoia"

  app "mboMail.app"

  zap trash: [
    "~/Library/Preferences/org.meltforce.mboMail.plist",
    "~/Library/Caches/org.meltforce.mboMail",
    "~/Library/WebKit/org.meltforce.mboMail",
    "~/Library/HTTPStorages/org.meltforce.mboMail",
  ]
end
