# Geisterhand Build and Distribution Makefile
# Usage:
#   make build         - Build release binary
#   make app           - Create app bundle
#   make sign          - Code sign the app (requires DEVELOPER_ID)
#   make dmg           - Create DMG installer
#   make notarize      - Notarize with Apple (requires credentials)
#   make release       - Full release pipeline
#   make clean         - Clean build artifacts

# Configuration
APP_NAME := Geisterhand
BUNDLE_ID := com.geisterhand.app
VERSION := $(shell grep -A1 'CFBundleShortVersionString' Sources/GeisterhandApp/Info.plist | tail -1 | sed 's/.*<string>\(.*\)<\/string>.*/\1/')

# Paths
BUILD_DIR := .build/release
APP_BUNDLE := $(BUILD_DIR)/$(APP_NAME).app
DMG_NAME := $(APP_NAME)-$(VERSION).dmg
DMG_PATH := $(BUILD_DIR)/$(DMG_NAME)

# Code signing identity (set via environment or pass as argument)
# Example: make sign DEVELOPER_ID="Developer ID Application: Your Name (TEAMID)"
DEVELOPER_ID ?=

# Notarization credentials (set via environment)
# APPLE_ID - Your Apple ID email
# APPLE_TEAM_ID - Your Team ID
# NOTARIZE_PASSWORD - App-specific password or keychain reference (@keychain:AC_PASSWORD)
APPLE_ID ?=
APPLE_TEAM_ID ?=
NOTARIZE_PASSWORD ?=

.PHONY: all build app sign dmg notarize staple release clean help

all: build

help:
	@echo "Geisterhand Build System"
	@echo ""
	@echo "Targets:"
	@echo "  build      - Build release binaries"
	@echo "  app        - Create app bundle"
	@echo "  sign       - Code sign (requires DEVELOPER_ID)"
	@echo "  dmg        - Create DMG installer"
	@echo "  notarize   - Notarize with Apple (requires credentials)"
	@echo "  staple     - Staple notarization ticket"
	@echo "  release    - Full release pipeline"
	@echo "  clean      - Remove build artifacts"
	@echo ""
	@echo "Environment variables:"
	@echo "  DEVELOPER_ID      - Code signing identity"
	@echo "  APPLE_ID          - Apple ID for notarization"
	@echo "  APPLE_TEAM_ID     - Team ID for notarization"
	@echo "  NOTARIZE_PASSWORD - App-specific password"
	@echo ""
	@echo "Current version: $(VERSION)"

# Build release binary
build:
	@echo "Building release binary..."
	swift build -c release

# Create app bundle structure
app: build
	@echo "Creating app bundle..."
	@mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	@mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	@# Copy executable
	@cp "$(BUILD_DIR)/GeisterhandApp" "$(APP_BUNDLE)/Contents/MacOS/GeisterhandApp"
	@# Copy CLI tool
	@cp "$(BUILD_DIR)/geisterhand" "$(APP_BUNDLE)/Contents/MacOS/geisterhand"
	@# Copy Info.plist
	@cp "Sources/GeisterhandApp/Info.plist" "$(APP_BUNDLE)/Contents/Info.plist"
	@# Create PkgInfo
	@echo "APPL????" > "$(APP_BUNDLE)/Contents/PkgInfo"
	@# Copy icon if exists
	@if [ -f "Resources/AppIcon.icns" ]; then \
		cp "Resources/AppIcon.icns" "$(APP_BUNDLE)/Contents/Resources/AppIcon.icns"; \
	fi
	@echo "App bundle created at $(APP_BUNDLE)"

# Code sign the app
sign: app
ifndef DEVELOPER_ID
	$(error DEVELOPER_ID is not set. Example: make sign DEVELOPER_ID="Developer ID Application: Your Name (TEAMID)")
endif
	@echo "Signing app bundle with: $(DEVELOPER_ID)"
	@# Sign the CLI tool first
	codesign --force --options runtime \
		--entitlements Geisterhand.entitlements \
		--sign "$(DEVELOPER_ID)" \
		"$(APP_BUNDLE)/Contents/MacOS/geisterhand"
	@# Sign the main executable
	codesign --force --options runtime \
		--entitlements Geisterhand.entitlements \
		--sign "$(DEVELOPER_ID)" \
		"$(APP_BUNDLE)/Contents/MacOS/GeisterhandApp"
	@# Sign the entire bundle
	codesign --force --deep --options runtime \
		--entitlements Geisterhand.entitlements \
		--sign "$(DEVELOPER_ID)" \
		"$(APP_BUNDLE)"
	@echo "Verifying signature..."
	codesign --verify --deep --strict --verbose=2 "$(APP_BUNDLE)"
	@echo "App signed successfully"

# Create DMG installer
dmg: sign
	@echo "Creating DMG..."
	@rm -f "$(DMG_PATH)"
	@# Create a temporary directory for DMG contents
	@mkdir -p "$(BUILD_DIR)/dmg-contents"
	@cp -R "$(APP_BUNDLE)" "$(BUILD_DIR)/dmg-contents/"
	@# Create symlink to Applications
	@ln -sf /Applications "$(BUILD_DIR)/dmg-contents/Applications"
	@# Create the DMG
	hdiutil create -volname "$(APP_NAME)" \
		-srcfolder "$(BUILD_DIR)/dmg-contents" \
		-ov -format UDZO \
		"$(DMG_PATH)"
	@rm -rf "$(BUILD_DIR)/dmg-contents"
	@# Sign the DMG
	codesign --force --sign "$(DEVELOPER_ID)" "$(DMG_PATH)"
	@echo "DMG created at $(DMG_PATH)"

# Notarize with Apple
notarize: dmg
ifndef APPLE_ID
	$(error APPLE_ID is not set)
endif
ifndef APPLE_TEAM_ID
	$(error APPLE_TEAM_ID is not set)
endif
ifndef NOTARIZE_PASSWORD
	$(error NOTARIZE_PASSWORD is not set. Use app-specific password or @keychain:AC_PASSWORD)
endif
	@echo "Submitting for notarization..."
	xcrun notarytool submit "$(DMG_PATH)" \
		--apple-id "$(APPLE_ID)" \
		--team-id "$(APPLE_TEAM_ID)" \
		--password "$(NOTARIZE_PASSWORD)" \
		--wait
	@echo "Notarization complete"

# Staple the notarization ticket
staple:
	@echo "Stapling notarization ticket..."
	xcrun stapler staple "$(DMG_PATH)"
	@echo "Stapled successfully"

# Full release pipeline
release: notarize staple
	@echo ""
	@echo "========================================"
	@echo "Release complete!"
	@echo "DMG: $(DMG_PATH)"
	@echo "Version: $(VERSION)"
	@echo "========================================"
	@echo ""
	@echo "Next steps:"
	@echo "1. Test the DMG on a fresh Mac"
	@echo "2. Upload to GitHub Releases"
	@echo "3. Update Homebrew cask formula"

# Build unsigned DMG (for testing)
dmg-unsigned: app
	@echo "Creating unsigned DMG..."
	@rm -f "$(BUILD_DIR)/$(APP_NAME)-$(VERSION)-unsigned.dmg"
	@mkdir -p "$(BUILD_DIR)/dmg-contents"
	@cp -R "$(APP_BUNDLE)" "$(BUILD_DIR)/dmg-contents/"
	@ln -sf /Applications "$(BUILD_DIR)/dmg-contents/Applications"
	hdiutil create -volname "$(APP_NAME)" \
		-srcfolder "$(BUILD_DIR)/dmg-contents" \
		-ov -format UDZO \
		"$(BUILD_DIR)/$(APP_NAME)-$(VERSION)-unsigned.dmg"
	@rm -rf "$(BUILD_DIR)/dmg-contents"
	@echo "Unsigned DMG created at $(BUILD_DIR)/$(APP_NAME)-$(VERSION)-unsigned.dmg"

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	swift package clean
	rm -rf "$(BUILD_DIR)/$(APP_NAME).app"
	rm -f "$(BUILD_DIR)/$(APP_NAME)-*.dmg"
	@echo "Clean complete"

# Show signing identities
list-identities:
	@echo "Available signing identities:"
	@security find-identity -v -p codesigning

# Verify the app
verify:
	@echo "Verifying app bundle..."
	codesign --verify --deep --strict --verbose=2 "$(APP_BUNDLE)"
	@echo ""
	@echo "Checking Gatekeeper assessment..."
	spctl --assess --verbose=4 --type execute "$(APP_BUNDLE)" || true
	@echo ""
	@echo "Checking DMG assessment..."
	@if [ -f "$(DMG_PATH)" ]; then \
		spctl --assess --verbose=4 --type install "$(DMG_PATH)" || true; \
	fi
