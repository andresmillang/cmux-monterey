# GhosttyTabs (cmux) for macOS Monterey

A macOS 12 (Monterey) compatible build of [cmux](https://github.com/manaflow-ai/cmux) - a terminal with vertical tabs using libghostty.

## Requirements

- macOS 12 (Monterey)
- Xcode 14.2
- Zig 0.15.2

## Building

### 1. Install Zig 0.15.2

```bash
curl -LO https://ziglang.org/download/0.15.2/zig-x86_64-macos-0.15.2.tar.xz
tar xf zig-x86_64-macos-0.15.2.tar.xz
sudo mv zig-x86_64-macos-0.15.2 /usr/local/zig
sudo ln -sf /usr/local/zig/zig /usr/local/bin/zig
```

### 2. Clone and build

```bash
git clone --recursive https://github.com/YOUR_USERNAME/cmux-monterey.git
cd cmux-monterey

# Build GhosttyKit.xcframework
cd ghostty
zig build -Demit-xcframework=true -Doptimize=ReleaseFast
cd ..

# Create xcframework manually (workaround for Xcode 14)
mkdir -p GhosttyKit.xcframework/macos-arm64_x86_64
cp -r ghostty/include GhosttyKit.xcframework/macos-arm64_x86_64/Headers
cp ghostty/.zig-cache/o/*/libghostty.a GhosttyKit.xcframework/macos-arm64_x86_64/

cat > GhosttyKit.xcframework/Info.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>AvailableLibraries</key>
    <array>
        <dict>
            <key>HeadersPath</key>
            <string>Headers</string>
            <key>LibraryIdentifier</key>
            <string>macos-arm64_x86_64</string>
            <key>LibraryPath</key>
            <string>libghostty.a</string>
            <key>SupportedArchitectures</key>
            <array>
                <string>arm64</string>
                <string>x86_64</string>
            </array>
            <key>SupportedPlatform</key>
            <string>macos</string>
        </dict>
    </array>
    <key>CFBundlePackageType</key>
    <string>XFWK</string>
    <key>XCFrameworkFormatVersion</key>
    <string>1.0</string>
</dict>
</plist>
EOF

# Build the app
xcodebuild -project GhosttyTabs.xcodeproj -scheme GhosttyTabs -configuration Release \
    -destination 'platform=macOS' CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO build

# Install
cp -r ~/Library/Developer/Xcode/DerivedData/GhosttyTabs-*/Build/Products/Release/GhosttyTabs.app /Applications/
```

## Features

- Vertical tabs sidebar
- GPU-accelerated terminal rendering via libghostty
- Reads existing Ghostty config from `~/.config/ghostty/config`

## Keyboard Shortcuts

- `Cmd+T` / `Cmd+N` - New tab
- `Cmd+W` - Close tab
- `Cmd+Shift+]` / `Ctrl+Tab` - Next tab
- `Cmd+Shift+[` / `Ctrl+Shift+Tab` - Previous tab
- `Cmd+1-9` - Jump to tab by number

## Credits

- [cmux](https://github.com/manaflow-ai/cmux) - Original project
- [ghostty-monterey](https://github.com/laojianzi/ghostty-monterey) - macOS 12 compatible Ghostty
- [Ghostty](https://github.com/mitchellh/ghostty) - Terminal emulator

## License

Same as original cmux - see LICENSE file.
