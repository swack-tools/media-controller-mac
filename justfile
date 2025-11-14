# MediaControl build automation

# Default target - show available commands
default:
    @just --list

# Generate Xcode project from project.yml
generate:
    xcodegen generate

# Build the app in Debug configuration
build: generate
    xcodebuild -project MediaControl.xcodeproj -scheme MediaControl \
      -configuration Debug -derivedDataPath build

# Build and run the app
run: build
    ./build/Build/Products/Debug/MediaControl.app/Contents/MacOS/MediaControl

# Run Swift package tests
test:
    #!/usr/bin/env bash
    set +e
    echo "Running tests..."
    swift test 2>&1 | grep -E "(Test Suite|Executed|passed|failed)"
    TEST_EXIT_CODE=${PIPESTATUS[0]}
    echo ""
    if [ $TEST_EXIT_CODE -eq 0 ]; then
        echo "✅ All tests passed!"
        exit 0
    else
        echo "❌ Tests failed!"
        exit $TEST_EXIT_CODE
    fi

# Run tests with verbose output
test-verbose:
    swift test --verbose

# Build release version
release: generate
    xcodebuild -project MediaControl.xcodeproj -scheme MediaControl \
      -configuration Release -derivedDataPath build \
      DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-}" \
      CODE_SIGN_IDENTITY="Developer ID Application"

# Archive for distribution (requires signing)
archive: generate
    xcodebuild -project MediaControl.xcodeproj -scheme MediaControl \
      -configuration Release -archivePath build/MediaControl.xcarchive \
      archive DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-}"

# Build and install to /Applications
install: release
    rm -rf /Applications/MediaControl.app
    cp -R build/Build/Products/Release/MediaControl.app /Applications/
    @echo "✅ Installed to /Applications/MediaControl.app"

# Uninstall from /Applications
uninstall:
    rm -rf /Applications/MediaControl.app
    @echo "✅ Uninstalled from /Applications"

# Clean all build artifacts
clean:
    rm -rf build
    rm -rf .build
    rm -rf MediaControl.xcodeproj
    rm -rf ~/Library/Developer/Xcode/DerivedData/MediaControl-*
    @echo "✅ Cleaned all build artifacts"

# Clean and rebuild
rebuild: clean build

# Open in Xcode
open: generate
    open MediaControl.xcodeproj

# Format code with swift-format (if installed)
format:
    @if command -v swift-format >/dev/null 2>&1; then \
        find Sources MediaControlApp -name "*.swift" -exec swift-format -i {} \; ; \
        echo "✅ Code formatted"; \
    else \
        echo "⚠️  swift-format not installed (brew install swift-format)"; \
    fi

# Lint code with swiftlint (if installed)
lint:
    @if command -v swiftlint >/dev/null 2>&1; then \
        swiftlint; \
    else \
        echo "⚠️  swiftlint not installed (brew install swiftlint)"; \
    fi

# Check for outdated dependencies
check-deps:
    swift package show-dependencies

# Update package dependencies
update-deps:
    swift package update

# Show project info
info:
    @echo "Project: MediaControl"
    @echo "Location: $(pwd)"
    @echo ""
    @echo "Targets:"
    @echo "  - ShieldClient (Swift Package)"
    @echo "  - OnkyoClient (Swift Package)"
    @echo "  - MediaControl (macOS App)"
    @echo ""
    @echo "Requirements:"
    @echo "  - macOS 13.0+"
    @echo "  - Xcode 15+"
    @echo "  - XcodeGen (brew install xcodegen)"

# Watch for changes and rebuild (requires fswatch: brew install fswatch)
watch:
    @if command -v fswatch >/dev/null 2>&1; then \
        echo "👀 Watching for changes..."; \
        fswatch -o Sources/ MediaControlApp/ | xargs -n1 -I{} just build; \
    else \
        echo "⚠️  fswatch not installed (brew install fswatch)"; \
    fi

# Kill any running MediaControl instances
kill:
    @killall MediaControl 2>/dev/null || echo "No running instances found"

# Build, kill old instance, and run new one
restart: kill build run

# View logs (if app is running)
logs:
    @log stream --predicate 'subsystem == "com.mediacontrol.app"' --level debug

# Check code signing
check-signing: build
    codesign -dv --verbose=4 build/Build/Products/Debug/MediaControl.app

# Show app bundle info
bundle-info: build
    @echo "Bundle Identifier: $(defaults read build/Build/Products/Debug/MediaControl.app/Contents/Info.plist CFBundleIdentifier)"
    @echo "Version: $(defaults read build/Build/Products/Debug/MediaControl.app/Contents/Info.plist CFBundleShortVersionString)"
    @echo "Build: $(defaults read build/Build/Products/Debug/MediaControl.app/Contents/Info.plist CFBundleVersion)"

# Create DMG for distribution (requires create-dmg: brew install create-dmg)
dmg: release
    @if command -v create-dmg >/dev/null 2>&1; then \
        rm -f build/MediaControl.dmg; \
        create-dmg \
            --volname "MediaControl" \
            --window-pos 200 120 \
            --window-size 600 400 \
            --icon-size 100 \
            --icon "MediaControl.app" 175 120 \
            --hide-extension "MediaControl.app" \
            --app-drop-link 425 120 \
            "build/MediaControl.dmg" \
            "build/Build/Products/Release/MediaControl.app"; \
        echo "✅ Created build/MediaControl.dmg"; \
    else \
        echo "⚠️  create-dmg not installed (brew install create-dmg)"; \
    fi

# Create versioned DMG from already-built app (for CI/CD after notarization)
create-dmg VERSION:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Creating DMG for MediaControl {{VERSION}}..."

    # Ensure create-dmg is installed
    if ! command -v create-dmg >/dev/null 2>&1; then
        echo "⚠️  create-dmg not installed (brew install create-dmg)"
        exit 1
    fi

    # Ensure app exists
    if [ ! -d "build/Build/Products/Release/MediaControl.app" ]; then
        echo "❌ MediaControl.app not found. Run 'just release' first."
        exit 1
    fi

    # Create dist directory
    mkdir -p dist

    # Remove old DMG if exists
    rm -f "dist/MediaControl-{{VERSION}}.dmg"

    # Create versioned DMG
    create-dmg \
        --volname "MediaControl {{VERSION}}" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 100 \
        --icon "MediaControl.app" 175 120 \
        --hide-extension "MediaControl.app" \
        --app-drop-link 425 120 \
        "dist/MediaControl-{{VERSION}}.dmg" \
        "build/Build/Products/Release/MediaControl.app"

    echo "✅ Created dist/MediaControl-{{VERSION}}.dmg"

# Package release with version (builds app and creates DMG)
package VERSION: release
    just create-dmg {{VERSION}}
