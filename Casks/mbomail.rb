cask "mbomail" do
  version "1.0.0"
  sha256 "REPLACE_WITH_ACTUAL_SHA256"

  url "https://github.com/meltforce/MBOMail/releases/download/v#{version}/MBOMail.dmg"
  name "MBOMail"
  desc "Native macOS wrapper for mailbox.org"
  homepage "https://mbomail.meltforce.org"

  depends_on macos: ">= :sequoia"

  app "MBOMail.app"

  zap trash: [
    "~/Library/Preferences/org.meltforce.mboMail.plist",
    "~/Library/Caches/org.meltforce.mboMail",
    "~/Library/WebKit/org.meltforce.mboMail",
    "~/Library/HTTPStorages/org.meltforce.mboMail",
  ]
end
