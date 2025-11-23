# FloatyClipshot Distribution Guide

This guide explains how to distribute FloatyClipshot to other users via Homebrew Cask and GitHub Releases.

## Quick Start

### For Users (Installation)

**Option 1: Homebrew Cask (Recommended)**
```bash
brew tap hooshyar/floatyclipshot
brew install --cask floatyclipshot
```

**Option 2: Direct Download**
1. Go to [Releases](https://github.com/hooshyar/floatyclipshot/releases)
2. Download the latest `.zip` file
3. Unzip and drag `floatyclipshot.app` to `/Applications`
4. Right-click the app and select "Open" (first time only)

---

## For Maintainers (Creating Releases)

### Initial Setup

#### 1. Set Up Homebrew Tap (One-Time Setup)

Create a separate repository for your Homebrew tap:

```bash
# Create a new repository on GitHub named: homebrew-floatyclipshot
# Then locally:
git clone https://github.com/hooshyar/homebrew-floatyclipshot.git
cd homebrew-floatyclipshot

# Copy the cask formula
cp /path/to/floatyclipshot/homebrew/floatyclipshot.rb Casks/

# Commit and push
git add Casks/floatyclipshot.rb
git commit -m "Add FloatyClipshot cask"
git push
```

**Important:** Update `hooshyar` in the cask formula before committing.

#### 2. Prepare Your First Release

1. **Update version in cask formula** (`homebrew/floatyclipshot.rb`)
2. **Build and package** the app locally to get the SHA256

### Creating a Release

#### Step 1: Package Locally (Optional - for testing)

```bash
./package_for_release.sh 1.0.0
```

This will:
- Build the app in Release mode
- Create a ZIP file in `release/`
- Display the SHA256 hash

#### Step 2: Create GitHub Release

**Method A: Automatic (via GitHub Actions)**

```bash
# Create and push a version tag
git tag v1.0.0
git push origin v1.0.0
```

GitHub Actions will automatically:
- Build the app
- Create a ZIP file
- Create a GitHub Release
- Upload the ZIP to the release
- Display the SHA256 in the release notes

**Method B: Manual**

1. Run `./package_for_release.sh 1.0.0`
2. Go to GitHub → Releases → "Create a new release"
3. Tag: `v1.0.0`
4. Upload `release/floatyclipshot-1.0.0.zip`
5. Copy the SHA256 from the script output
6. Publish the release

#### Step 3: Update Homebrew Cask

After creating the GitHub release:

1. **Get the download URL** from your release:
   ```
   https://github.com/hooshyar/floatyclipshot/releases/download/v1.0.0/floatyclipshot-1.0.0.zip
   ```

2. **Update the cask formula** in your `homebrew-floatyclipshot` repository:

   ```ruby
   cask "floatyclipshot" do
     version "1.0.0"
     sha256 "abc123..."  # Use SHA256 from release notes or package script

     url "https://github.com/hooshyar/floatyclipshot/releases/download/v#{version}/floatyclipshot-#{version}.zip"
     # ... rest of the formula
   end
   ```

3. **Commit and push** the cask update:
   ```bash
   cd homebrew-floatyclipshot
   git add Casks/floatyclipshot.rb
   git commit -m "Update FloatyClipshot to v1.0.0"
   git push
   ```

#### Step 4: Test Installation

```bash
# Uninstall old version if exists
brew uninstall --cask floatyclipshot

# Update tap
brew update

# Install new version
brew install --cask floatyclipshot
```

---

## Release Checklist

- [ ] Update version number in the app (if you have a version display)
- [ ] Test the app locally
- [ ] Create git tag (e.g., `v1.0.0`)
- [ ] Push tag to trigger GitHub Actions OR run `./package_for_release.sh`
- [ ] Verify GitHub Release was created with ZIP file
- [ ] Copy SHA256 from release notes
- [ ] Update Homebrew cask formula with new version and SHA256
- [ ] Push cask formula update
- [ ] Test installation via Homebrew
- [ ] Announce the release!

---

## Troubleshooting

### "App is damaged and can't be opened"

This happens with unsigned apps on macOS. Users need to:
```bash
xattr -cr /Applications/floatyclipshot.app
```

Or right-click → Open (first time only).

### Homebrew Installation Fails

1. Check SHA256 matches the file:
   ```bash
   shasum -a 256 floatyclipshot-1.0.0.zip
   ```

2. Verify download URL is accessible:
   ```bash
   curl -I https://github.com/hooshyar/floatyclipshot/releases/download/v1.0.0/floatyclipshot-1.0.0.zip
   ```

3. Clear Homebrew cache:
   ```bash
   brew cleanup
   rm -rf ~/Library/Caches/Homebrew/downloads/*floatyclipshot*
   ```

---

## Code Signing (Optional but Recommended)

For production distribution, consider code signing:

1. Join Apple Developer Program ($99/year)
2. Create a Developer ID certificate
3. Sign the app:
   ```bash
   codesign --deep --force --verify --verbose --sign "Developer ID Application: Your Name" floatyclipshot.app
   ```
4. Notarize the app (required for macOS 10.15+)

This eliminates the "damaged app" warning for users.

---

## Alternative Distribution Methods

### Direct Download (No Homebrew)

Simply provide the GitHub Releases link in your README:
```markdown
Download the latest version from [Releases](https://github.com/hooshyar/floatyclipshot/releases/latest)
```

### DMG Distribution

If you prefer DMG over ZIP:

1. Install `create-dmg`:
   ```bash
   brew install create-dmg
   ```

2. Create DMG:
   ```bash
   create-dmg \
     --volname "FloatyClipshot" \
     --window-pos 200 120 \
     --window-size 800 400 \
     --icon-size 100 \
     --icon "floatyclipshot.app" 200 190 \
     --hide-extension "floatyclipshot.app" \
     --app-drop-link 600 185 \
     "floatyclipshot-1.0.0.dmg" \
     "path/to/floatyclipshot.app"
   ```

---

## Questions?

- **GitHub Issues**: https://github.com/hooshyar/floatyclipshot/issues
- **Email**: hooshyar@gmail.com
