#!/usr/bin/env bash
# 本机架构 Release 构建 -> 组装 .app -> ad-hoc 签名 -> 装 /Applications。
# 纯本机工具无 CI / 无分发：arch 由 swift 自动取本机，install 是必然，故无参数。
# 本机自建 .app 无 quarantine，Gatekeeper 不校验签名，直接可跑。Debug 用 `swift build`。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="$(tr -d ' \t\n\r' < "$ROOT/VERSION")"

echo "==> [1/4] 构建 (Release, $(uname -m))"
( cd "$ROOT" && swift build -c release )
APP_BIN="$(cd "$ROOT" && swift build -c release --show-bin-path)/jj-apps"
[ -x "$APP_BIN" ] || { echo "找不到 App 产物: $APP_BIN" >&2; exit 1; }

echo "==> [2/4] 组装 .app bundle"
BUNDLE="$ROOT/build/jj-apps.app"
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp "$APP_BIN" "$BUNDLE/Contents/MacOS/jj-apps"
[ -f "$ROOT/Resources/AppIcon.icns" ] && cp "$ROOT/Resources/AppIcon.icns" "$BUNDLE/Contents/Resources/AppIcon.icns"
sed "s/@VERSION@/$VERSION/g" "$ROOT/Resources/Info.plist.in" > "$BUNDLE/Contents/Info.plist"
printf 'APPL????' > "$BUNDLE/Contents/PkgInfo"

echo "==> [3/4] ad-hoc 签名"
# DR 钉 identifier-only（不含 cdhash），FDA 授权不因重建 cdhash 变化而失效
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$BUNDLE/Contents/Info.plist")"
codesign --force --sign - --identifier "$BUNDLE_ID" -r="designated => identifier \"$BUNDLE_ID\"" "$BUNDLE"

echo "==> [4/4] 安装到 /Applications"
# 关旧实例，否则占用二进制导致拷贝 / 运行异常
pkill -f '/jj-apps\.app/Contents/MacOS/jj-apps' 2>/dev/null || true
rm -rf "/Applications/jj-apps.app"
ditto "$BUNDLE" "/Applications/jj-apps.app"

echo "==> 完成: /Applications/jj-apps.app (version $VERSION, $(lipo -archs "$BUNDLE/Contents/MacOS/jj-apps" 2>/dev/null))"
