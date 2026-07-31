#!/usr/bin/env bash
# 本机架构 Release 构建 -> 组装 .app -> ad-hoc 签名 -> 装 /Applications，供本机验证。
# 用法：./scripts/install-local.sh（任意目录执行，脚本自动 cd 到工程根）
# 覆盖安装目录：INSTALL_DIR=/some/dir ./scripts/install-local.sh
# 纯本机工具无 CI / 无分发：arch 由 swift 自动取本机，install 是必然，故无参数。
# 本机自建 .app 无 quarantine，Gatekeeper 不校验签名，直接可跑。Debug 用 `swift build`。
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="jj-macos-apps"
INSTALL_DIR="${INSTALL_DIR:-/Applications}"
VERSION="$(tr -d ' \t\n\r' < VERSION)"
BUNDLE="build/${APP_NAME}.app"
DEST="${INSTALL_DIR}/${APP_NAME}.app"

echo "==> [1/4] 构建 (Release, $(uname -m))"
swift build -c release
APP_BIN="$(swift build -c release --show-bin-path)/${APP_NAME}"
[ -x "$APP_BIN" ] || { echo "找不到 App 产物: $APP_BIN" >&2; exit 1; }

echo "==> [2/4] 组装 .app bundle"
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp "$APP_BIN" "$BUNDLE/Contents/MacOS/${APP_NAME}"
if [ -f Resources/AppIcon.icns ]; then
  cp Resources/AppIcon.icns "$BUNDLE/Contents/Resources/AppIcon.icns"
fi
sed "s/@VERSION@/${VERSION}/g" Resources/Info.plist.in > "$BUNDLE/Contents/Info.plist"
printf 'APPL????' > "$BUNDLE/Contents/PkgInfo"

echo "==> [3/4] ad-hoc 签名"
# DR 钉 identifier-only（不含 cdhash），FDA 授权不因重建 cdhash 变化而失效
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$BUNDLE/Contents/Info.plist")"
codesign --force --sign - --identifier "$BUNDLE_ID" -r="designated => identifier \"$BUNDLE_ID\"" "$BUNDLE"

echo "==> [4/4] 安装到 ${INSTALL_DIR}"
# 关旧实例，否则占用二进制导致拷贝 / 运行异常；顺带清理更老命名 jj-apps.app 遗留（若有）
pkill -f "/${APP_NAME}\.app/Contents/MacOS/${APP_NAME}" 2>/dev/null || true
pkill -f '/jj-apps\.app/Contents/MacOS/jj-apps' 2>/dev/null || true
mkdir -p "$INSTALL_DIR"
rm -rf "$DEST" "${INSTALL_DIR}/jj-apps.app"
ditto "$BUNDLE" "$DEST"

echo "==> 校验"
codesign --verify --strict "$DEST"

echo "==> 完成: ${DEST} (version ${VERSION}, $(lipo -archs "$DEST/Contents/MacOS/${APP_NAME}" 2>/dev/null))"
