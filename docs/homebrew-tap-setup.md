# Homebrew Tap Setup

MBOMail is distributed via a Homebrew tap, allowing users to install with:

```bash
brew tap meltforce/mbomail
brew install --cask mbomail
```

## Creating the Tap Repository

1. Create a new GitHub repository named `homebrew-mbomail` under the `meltforce` organization:
   - Repository: `meltforce/homebrew-mbomail`
   - Public repository (required for Homebrew taps)

2. Create the Cask formula at `Casks/mbomail.rb` in that repository. Use the template from this project's `Casks/mbomail.rb` as a starting point.

3. The repository structure should be:
   ```
   homebrew-mbomail/
   └── Casks/
       └── mbomail.rb
   ```

## Cask Formula Template

```ruby
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
```

## Updating After a Release

After each release, update the Cask with the new version and SHA256:

1. The release workflow prints the SHA256 in the GitHub Actions summary
2. Update `Casks/mbomail.rb` in the tap repository:
   ```ruby
   version "X.Y.Z"
   sha256 "new-sha256-hash"
   ```
3. Commit and push to the tap repository

Alternatively, use `brew bump-cask-pr` if the tap is set up with Homebrew's auto-update infrastructure.

## Testing the Tap

```bash
# Add the tap
brew tap meltforce/mbomail

# Install
brew install --cask mbomail

# Verify
brew info --cask mbomail

# Uninstall
brew uninstall --cask mbomail

# Remove the tap
brew untap meltforce/mbomail
```
