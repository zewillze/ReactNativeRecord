#!/bin/bash
# ============================================================
# 安装「APK 双击安装到手机」工具
# 用法: bash install-adb-tool.sh
# 功能: 双击 .apk 文件 → 自动 adb install -r 到手机
# ============================================================

set -e
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}  📱 安装「APK→手机安装」工具${NC}"
echo -e "${BLUE}==========================================${NC}"
echo ""

if [ "$(uname)" != "Darwin" ]; then
    echo -e "${RED}❌ 仅支持 macOS${NC}"; exit 1
fi

# ---- 1. 安装主脚本 ----
BIN_DIR="$HOME/bin"; mkdir -p "$BIN_DIR"
echo -e "${GREEN}📦${NC} 安装主脚本..."

cat > "$BIN_DIR/adb-install-apk" << 'SCRIPT_EOF'
#!/bin/bash
set -e
if [ $# -eq 0 ]; then
    echo "用法: adb-install-apk <文件.apk> [文件.apk ...]"; exit 1
fi
ADB_PATH=""
for p in /usr/local/bin/adb /opt/homebrew/bin/adb ~/Library/Android/sdk/platform-tools/adb; do
    [ -x "$p" ] && ADB_PATH="$p" && break
done
[ -z "$ADB_PATH" ] && ADB_PATH=$(command -v adb 2>/dev/null || true)
if [ -z "$ADB_PATH" ]; then
    echo "❌ 未找到 adb，请安装: brew install --cask android-platform-tools"
    exit 1
fi
DEVICE=$("$ADB_PATH" devices | awk 'NR>1 && $2=="device" {print $1; exit}')
if [ -z "$DEVICE" ]; then
    echo "❌ 未检测到 Android 设备，请连接手机并开启 USB 调试"
    exit 1
fi
echo "📱 已连接: $DEVICE"
TOTAL=$#; COUNT=0; SUCCESS=0; FAIL=0
for APK in "$@"; do
    COUNT=$((COUNT + 1))
    [ ! -f "$APK" ] && echo "  [$COUNT/$TOTAL] ⚠️  $APK 不存在" && FAIL=$((FAIL + 1)) && continue
    echo "  [$COUNT/$TOTAL] 📦 $(basename "$APK")"
    OUTPUT=$("$ADB_PATH" install -r "$APK" 2>&1) \
        && echo "         ✅ 成功" && SUCCESS=$((SUCCESS + 1)) \
        || { echo "         ❌ 失败: $OUTPUT"; FAIL=$((FAIL + 1)); }
done
echo "  📊 共 $TOTAL，成功 $SUCCESS，失败 $FAIL"
exit $FAIL
SCRIPT_EOF

chmod +x "$BIN_DIR/adb-install-apk"
echo -e "   ${GREEN}✅${NC} $BIN_DIR/adb-install-apk"

# 添加 PATH
if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
    for rc in "$HOME/.zshrc" "$HOME/.bash_profile"; do
        [ -f "$rc" ] && echo 'export PATH="$HOME/bin:$PATH"' >> "$rc"
    done
fi
echo ""

# ---- 2. 编译拖拽 App ----
echo -e "${GREEN}🖱️${NC} 创建桌面 App..."

cat > "/tmp/CreateADBApp.applescript" << APPLESCRIPT_EOF
on open droppedFiles
	set filePaths to ""
	repeat with aFile in droppedFiles
		set filePath to POSIX path of aFile
		set filePaths to filePaths & quoted form of filePath & " "
	end repeat
	try
		do shell script "$HOME/bin/adb-install-apk " & filePaths
		display notification "APK 安装完成！" with title "adb 安装器" subtitle "全部 APK 已安装到手机" sound name "Glass"
	on error errMsg
		display dialog "安装失败:" & return & return & errMsg buttons {"确定"} default button 1 with icon stop with title "adb 安装器"
	end try
end open
on run
	display dialog "把 .apk 文件拖拽到此图标上即可安装到手机。" & return & return & "使用前：" & return & "1. 手机连电脑并开启 USB 调试" & return & "2. 手机上允许 USB 调试授权" & return & "3. 把 APK 拖到图标上 🚀" buttons {"知道了"} default button 1 with title "adb 安装器"
end run
APPLESCRIPT_EOF

APP_PATH="$HOME/Desktop/APK安装器.app"
[ -d "$APP_PATH" ] && rm -rf "$APP_PATH"
osacompile -o "$APP_PATH" "/tmp/CreateADBApp.applescript" 2>/dev/null
rm -f "/tmp/CreateADBApp.applescript"

if [ -d "$APP_PATH" ]; then
    echo -e "   ${GREEN}✅${NC} $APP_PATH"
else
    echo -e "${RED}❌ 编译失败${NC}"; exit 1
fi
echo ""

# ---- 3. 提示设置默认打开方式 ----
echo -e "${YELLOW}📌 设置为 .apk 文件默认打开程序（双击即安装）：${NC}"
echo ""
echo "  1. 在 Finder 中找到一个 .apk 文件"
echo "  2. 右键 → 显示简介（或按 ⌘I）"
echo "  3. 在「打开方式」中选择「APK安装器」"
echo "  4. 点击「全部更改」"
echo ""
echo -e "${BLUE}==========================================${NC}"
echo -e "${GREEN}  🎉 安装完成！${NC}"
echo ""
echo "  使用方式："
echo "  🖱️  拖拽: 把 .apk 拖到桌面「APK安装器.app」"
echo "  ⌨️  命令行: adb-install-apk 应用.apk"
echo "  🖱️  双击: 设置默认打开方式后，直接双击 .apk"
echo -e "${BLUE}==========================================${NC}"
