# Geisterhand Distribution Guide

This document explains how to build, sign, notarize, and distribute Geisterhand.

## Quick Start

### Local Development Build (Unsigned)

```bash
# Build and create unsigned app bundle
make app

# Create unsigned DMG for testing
make dmg-unsigned
```

### Full Release (Signed + Notarized)

```bash
# Set credentials
export DEVELOPER_ID="Developer ID Application: Your Name (TEAMID)"
export APPLE_ID="your@email.com"
export APPLE_TEAM_ID="TEAMID"
export NOTARIZE_PASSWORD="xxxx-xxxx-xxxx-xxxx"  # App-specific password

# Run full release pipeline
make release
```

## Prerequisites

### Apple Developer Account

1. Enroll in the [Apple Developer Program](https://developer.apple.com/programs/) ($99/year)
2. Create a Developer ID Application certificate in Certificates, Identifiers & Profiles
3. Download and install the certificate in your Keychain

### App-Specific Password

For notarization, create an app-specific password:

1. Go to [appleid.apple.com](https://appleid.apple.com)
2. Sign in and go to Security > App-Specific Passwords
3. Generate a new password for "Geisterhand Notarization"

Optionally, store it in Keychain for convenience:

```bash
xcrun notarytool store-credentials "AC_PASSWORD" \
  --apple-id "your@email.com" \
  --team-id "TEAMID" \
  --password "xxxx-xxxx-xxxx-xxxx"
```

Then use `NOTARIZE_PASSWORD="@keychain:AC_PASSWORD"` in the Makefile.

## Makefile Targets

| Target | Description |
|--------|-------------|
| `make build` | Build release binaries with Swift |
| `make app` | Create app bundle structure |
| `make sign` | Code sign with Developer ID |
| `make dmg` | Create DMG installer |
| `make notarize` | Submit to Apple for notarization |
| `make staple` | Staple notarization ticket to DMG |
| `make release` | Full pipeline (sign → dmg → notarize → staple) |
| `make clean` | Remove build artifacts |
| `make verify` | Verify signatures and Gatekeeper assessment |
| `make list-identities` | Show available signing identities |
| `make dmg-unsigned` | Create unsigned DMG for testing |

## GitHub Actions Release

The release workflow (`.github/workflows/release.yml`) automates the entire process.

### Required Secrets

Configure these in your repository settings (Settings > Secrets and variables > Actions):

| Secret | Description |
|--------|-------------|
| `DEVELOPER_CERTIFICATE_BASE64` | Base64-encoded .p12 certificate |
| `DEVELOPER_CERTIFICATE_PASSWORD` | Password for the .p12 file |
| `KEYCHAIN_PASSWORD` | Temporary password for CI keychain |
| `DEVELOPER_ID` | Full signing identity string |
| `APPLE_ID` | Apple ID email |
| `APPLE_TEAM_ID` | Team ID (10-character string) |
| `NOTARIZE_PASSWORD` | App-specific password |

### Exporting Your Certificate

```bash
# Find your certificate
security find-identity -v -p codesigning

# Export from Keychain Access:
# 1. Open Keychain Access
# 2. Find "Developer ID Application: Your Name"
# 3. Right-click > Export
# 4. Save as .p12 with a password

# Convert to base64 for GitHub secrets
base64 -i certificate.p12 | pbcopy
# Paste into DEVELOPER_CERTIFICATE_BASE64 secret
```

### Creating a Release

```bash
# Tag and push
git tag v1.0.0
git push origin v1.0.0
```

The workflow will:
1. Build the release binary
2. Create and sign the app bundle
3. Create a DMG
4. Notarize with Apple
5. Create a GitHub Release with the DMG

## Homebrew Distribution

### Setting Up Your Tap

1. Create a new repository: `homebrew-geisterhand`

2. Add the cask formula:
   ```
   homebrew-geisterhand/
   └── Casks/
       └── geisterhand.rb
   ```

3. Copy `homebrew/geisterhand.rb` to your tap and update:
   - The SHA256 hash (from GitHub Actions output or `shasum -a 256 Geisterhand-1.0.0.dmg`)
   - The GitHub repository URL

4. Optionally add the source formula:
   ```
   homebrew-geisterhand/
   ├── Casks/
   │   └── geisterhand.rb
   └── Formula/
       └── geisterhand.rb
   ```

### Updating the Formula

After each release:

1. Get the SHA256 from the GitHub Actions log or calculate it:
   ```bash
   shasum -a 256 Geisterhand-X.Y.Z.dmg
   ```

2. Update the cask formula:
   ```ruby
   version "X.Y.Z"
   sha256 "new_sha256_hash"
   ```

3. Commit and push to your tap repository

### User Installation

```bash
# First time
brew tap geisterhand-io/tap
brew install --cask geisterhand

# Or one command
brew install --cask geisterhand-io/tap/geisterhand

# CLI only (compiles from source)
brew install geisterhand-io/tap/geisterhand
```

## Verification

### Check Signature

```bash
codesign --verify --deep --strict --verbose=2 Geisterhand.app
```

### Check Gatekeeper

```bash
spctl --assess --verbose=4 --type execute Geisterhand.app
spctl --assess --verbose=4 --type install Geisterhand-1.0.0.dmg
```

### Check Notarization

```bash
xcrun stapler validate Geisterhand-1.0.0.dmg
```

## Troubleshooting

### "Developer cannot be verified" warning

The app hasn't been notarized or stapled properly. Run:
```bash
make notarize staple
```

### Certificate not found

List available identities:
```bash
make list-identities
```

Ensure your Developer ID Application certificate is installed in Keychain.

### Notarization fails

Check the submission status:
```bash
xcrun notarytool log <submission-id> \
  --apple-id "$APPLE_ID" \
  --team-id "$APPLE_TEAM_ID" \
  --password "$NOTARIZE_PASSWORD"
```

Common issues:
- Hardened runtime not enabled (fixed in entitlements)
- Unsigned nested code (fixed by signing each binary)
- Missing entitlements

### GitHub Actions fails at signing

Verify your secrets are correctly set:
- Certificate must be base64-encoded
- DEVELOPER_ID must match the certificate exactly
- Keychain password can be any strong password
