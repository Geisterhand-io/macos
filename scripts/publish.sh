#!/bin/bash
set -euo pipefail

# Geisterhand publish script
# Usage: ./scripts/publish.sh 1.1.0

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
  echo "Usage: ./scripts/publish.sh <version>"
  echo "Example: ./scripts/publish.sh 1.1.0"
  exit 1
fi

APP_NAME="Geisterhand"
BUILD_DIR=".build/release"
DMG_PATH="$BUILD_DIR/$APP_NAME-$VERSION.dmg"
GITHUB_REPO="Geisterhand-io/macos"
TAP_REPO="Geisterhand-io/homebrew-tap"

echo "========================================"
echo "Publishing $APP_NAME v$VERSION..."
echo "========================================"

# 1. Bump version in Info.plist
echo ""
echo ">>> Bumping version to $VERSION..."
sed -i '' "/<key>CFBundleVersion<\/key>/{ n; s|<string>[^<]*</string>|<string>$VERSION</string>|; }" Sources/GeisterhandApp/Info.plist
sed -i '' "/<key>CFBundleShortVersionString<\/key>/{ n; s|<string>[^<]*</string>|<string>$VERSION</string>|; }" Sources/GeisterhandApp/Info.plist

# 2. Commit, tag, push
echo ">>> Committing and tagging..."
git add Sources/GeisterhandApp/Info.plist
git commit -m "Bump version to $VERSION"
git tag "v$VERSION"
git push origin main --tags

# 3. Build, sign, notarize
echo ""
echo ">>> Building, signing, notarizing..."
make clean
make release

# 4. Create GitHub release
echo ""
echo ">>> Creating GitHub release..."
gh release create "v$VERSION" "$DMG_PATH" \
  --title "$APP_NAME v$VERSION" \
  --generate-notes

# 5. Update Homebrew tap
echo ""
echo ">>> Updating Homebrew tap..."
DMG_SHA=$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')
SRC_SHA=$(curl -sL "https://github.com/$GITHUB_REPO/archive/refs/tags/v$VERSION.tar.gz" | shasum -a 256 | awk '{print $1}')

TAP_DIR=$(mktemp -d)
git clone "https://github.com/$TAP_REPO.git" "$TAP_DIR"

# Update cask
sed -i '' "s/version \"[^\"]*\"/version \"$VERSION\"/" "$TAP_DIR/Casks/geisterhand.rb"
sed -i '' "s/sha256 \"[^\"]*\"/sha256 \"$DMG_SHA\"/" "$TAP_DIR/Casks/geisterhand.rb"

# Update source formula
sed -i '' "s|/v[0-9]*\.[0-9]*\.[0-9]*.tar.gz|/v$VERSION.tar.gz|" "$TAP_DIR/Formula/geisterhand.rb"
sed -i '' "s/sha256 \"[^\"]*\"/sha256 \"$SRC_SHA\"/" "$TAP_DIR/Formula/geisterhand.rb"

cd "$TAP_DIR"
git add -A
git commit -m "Update to v$VERSION"
git push
rm -rf "$TAP_DIR"

echo ""
echo "========================================"
echo "Published $APP_NAME v$VERSION"
echo "DMG SHA256: $DMG_SHA"
echo "SRC SHA256: $SRC_SHA"
echo "========================================"
echo ""
echo "Users can upgrade with:"
echo "  brew upgrade --cask geisterhand-io/tap/geisterhand"
