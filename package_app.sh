#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

PRODUCT_NAME="TransitStudio"
BUNDLE_ID="com.gacu.TransitStudio"
APP_VERSION="1.2.0"
BUILD_VERSION="36"
SWIFTPM_BUILD_PATH="${SWIFTPM_BUILD_PATH:-/private/tmp/astrotransit-package-build}"
BUILD_DIR="$SWIFTPM_BUILD_PATH/arm64-apple-macosx/release"
OUTPUT_ROOT="${APP_OUTPUT_DIR:-$ROOT_DIR/dist}"
APP_DIR="$OUTPUT_ROOT/${PRODUCT_NAME}.app"
STAGING_ROOT="${APP_STAGING_ROOT:-/private/tmp/${PRODUCT_NAME}-package-stage}"
STAGED_APP_DIR="$STAGING_ROOT/${PRODUCT_NAME}.app"
INSTALL_ROOT="${APP_INSTALL_ROOT:-/Applications}"
INSTALL_APP_PATH="${APP_INSTALL_PATH:-$INSTALL_ROOT/${PRODUCT_NAME}.app}"
SKIP_INSTALL="${SKIP_INSTALL:-0}"
CONTENTS_DIR="$STAGED_APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICONSET_DIR="/private/tmp/TransitStudio.iconset"
APP_ICON_ICNS="$ROOT_DIR/assets/AppIcon.icns"

clean_xattrs() {
    local target="${1:?target required}"
    xattr -cr "$target" || true
    find "$target" -exec xattr -c {} + 2>/dev/null || true
    while IFS= read -r path; do
        xattr -d com.apple.FinderInfo "$path" 2>/dev/null || true
        xattr -d "com.apple.fileprovider.fpfs#P" "$path" 2>/dev/null || true
        xattr -d com.apple.provenance "$path" 2>/dev/null || true
    done < <(find "$target" -print)
}

swift build -c release --build-path "$SWIFTPM_BUILD_PATH"

mkdir -p "$OUTPUT_ROOT"
rm -rf "$APP_DIR" "$STAGED_APP_DIR" "$ICONSET_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$ICONSET_DIR"

cp "$BUILD_DIR/$PRODUCT_NAME" "$MACOS_DIR/$PRODUCT_NAME"
chmod +x "$MACOS_DIR/$PRODUCT_NAME"

ditto --noextattr --noqtn "$BUILD_DIR/AstroTransitMac_TransitStudio.bundle" "$RESOURCES_DIR/AstroTransitMac_TransitStudio.bundle"
find "$STAGED_APP_DIR" -name '*.pyc' -delete
find "$STAGED_APP_DIR" -name '__pycache__' -type d -empty -delete

if [[ -f "$APP_ICON_ICNS" ]]; then
    cp "$APP_ICON_ICNS" "$RESOURCES_DIR/AppIcon.icns"
else
    # 回退：仓库内没有预生成的 assets/AppIcon.icns 时才逐像素重新生成（纯 CPython 约 1-2 分钟）
    python3 - <<'PY'
from pathlib import Path
import math
import struct
import zlib

root = Path("/private/tmp/TransitStudio.iconset")
root.mkdir(parents=True, exist_ok=True)

targets = {
    "icon_16x16.png": 16,
    "icon_16x16@2x.png": 32,
    "icon_32x32.png": 32,
    "icon_32x32@2x.png": 64,
    "icon_128x128.png": 128,
    "icon_128x128@2x.png": 256,
    "icon_256x256.png": 256,
    "icon_256x256@2x.png": 512,
    "icon_512x512.png": 512,
    "icon_512x512@2x.png": 1024,
}

def chunk(tag, data):
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

def write_png(path, size):
    rows = []
    cx = cy = (size - 1) / 2
    radius = size * 0.46
    for y in range(size):
        row = bytearray([0])
        for x in range(size):
            dx, dy = x - cx, y - cy
            dist = math.hypot(dx, dy)
            edge = max(0.0, min(1.0, (radius - dist) / (size * 0.035)))
            if edge <= 0:
                row.extend((0, 0, 0, 0))
                continue

            t = (x + y) / (2 * size)
            r = int(21 + 56 * t)
            g = int(43 + 28 * (1 - t))
            b = int(88 + 132 * t)

            orbit = abs((dist / radius) - 0.62)
            angle = math.atan2(dy, dx)
            arc = orbit < 0.018 and (angle > -2.6 and angle < 1.2)
            if arc:
                r, g, b = 142, 222, 255

            star = False
            for sx, sy, sr in [(0.30, 0.28, 0.022), (0.69, 0.31, 0.018), (0.72, 0.70, 0.016)]:
                if math.hypot(x - size * sx, y - size * sy) < size * sr:
                    star = True
            if star:
                r, g, b = 255, 236, 155

            # Simple "T" mark.
            in_bar = size * 0.30 < x < size * 0.70 and size * 0.43 < y < size * 0.51
            in_stem = size * 0.46 < x < size * 0.54 and size * 0.43 < y < size * 0.72
            if in_bar or in_stem:
                r, g, b = 246, 248, 255

            row.extend((r, g, b, int(255 * edge)))
        rows.append(bytes(row))

    raw = b"".join(rows)
    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )
    path.write_bytes(png)

for name, size in targets.items():
    write_png(root / name, size)
PY
    iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns"
fi

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_CN</string>
    <key>CFBundleDisplayName</key>
    <string>Transit Studio</string>
    <key>CFBundleExecutable</key>
    <string>${PRODUCT_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Transit Studio</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${APP_VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_VERSION}</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>用于在 Horary 起盘时自动填入当前提问地点的经纬度与地点名。</string>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
PLIST

sleep 0.5
clean_xattrs "$STAGED_APP_DIR"
codesign --force --deep --sign - "$STAGED_APP_DIR"
sleep 0.2
clean_xattrs "$STAGED_APP_DIR"

rm -rf "$APP_DIR"
ditto --noextattr --noqtn "$STAGED_APP_DIR" "$APP_DIR"
clean_xattrs "$APP_DIR"

if [[ "$SKIP_INSTALL" != "1" ]]; then
    rm -rf "$INSTALL_APP_PATH"
    ditto --noextattr --noqtn "$STAGED_APP_DIR" "$INSTALL_APP_PATH"
    clean_xattrs "$INSTALL_APP_PATH"
fi

echo "$APP_DIR"
if [[ "$SKIP_INSTALL" != "1" ]]; then
    echo "$INSTALL_APP_PATH"
fi
