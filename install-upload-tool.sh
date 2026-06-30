#!/bin/bash
# ============================================================
# 安装「拖拽上传到公司」工具 v2（内置自动登录）
# 用法: bash install-upload-tool.sh
# ============================================================

# ---------- 配置区（已填示例地址，发布前确认即可） ----------
DEFAULT_UPLOAD_URL="https://upload.公司内部.com/upload"
DEFAULT_FORM_FIELD="file"
DEFAULT_LOGIN_URL="https://login.公司内部.com/login"
DEFAULT_LOGIN_USER_FIELD="username"
DEFAULT_LOGIN_PASS_FIELD="password"
# ---------------------------------------------------------

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}  🔧 安装「拖拽上传到公司」工具 v2${NC}"
echo -e "${BLUE}==========================================${NC}"
echo ""

if [ "$(uname)" != "Darwin" ]; then
    echo -e "${RED}❌ 此工具仅支持 macOS${NC}"; exit 1
fi

# ---- 1. 安装主脚本 ----
BIN_DIR="$HOME/bin"; mkdir -p "$BIN_DIR"
echo -e "${GREEN}📦${NC} 安装主脚本..."

cat > "$BIN_DIR/upload-xml" << 'SCRIPT_EOF'
#!/bin/bash
# ============================================================
# upload-xml — 登录公司 → 复制文件并改 .xml → 上传
# 用法:
#   upload-xml <文件1> [文件2] ...
#   upload-xml --login      # 手动登录（刷新 Cookie）
#   upload-xml --logout     # 清除 Cookie
# ============================================================

set -e
CONFIG_FILE="$HOME/.upload-xml.conf"

# ---------- 加载配置 ----------
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ 未找到配置文件 $CONFIG_FILE"
    echo "   请先运行安装脚本，或手动创建该文件。"
    exit 1
fi
source "$CONFIG_FILE"

# ---------- 默认值 ----------
: "${FORM_FIELD:=file}"
: "${COOKIE_FILE:=$HOME/.upload-cookies.txt}"
: "${LOGIN_USER_FIELD:=username}"
: "${LOGIN_PASS_FIELD:=password}"

# ---------- 工具函数 ----------
usage() {
    echo "用法:"
    echo "  upload-xml <文件1> [文件2] ...    复制→改.xml→上传"
    echo "  upload-xml --login                用配置文件中的账号密码登录"
    echo "  upload-xml --logout               清除已保存的 Cookie"
    exit 0
}

do_login() {
    if [ -z "$LOGIN_URL" ] || [ "$LOGIN_URL" = "https://company.com/login" ]; then
        echo "❌ 请先在 $CONFIG_FILE 中设置 LOGIN_URL"
        return 1
    fi
    if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
        echo "❌ 请先在 $CONFIG_FILE 中设置 USERNAME 和 PASSWORD"
        return 1
    fi

    echo "🔑 正在登录 $LOGIN_URL ..."
    
    # 构造表单数据（兼容字段名含特殊字符的情况）
    FORM_DATA="${LOGIN_USER_FIELD}=${USERNAME}&${LOGIN_PASS_FIELD}=${PASSWORD}"
    
    # 发送登录请求，捕获 Cookie，跟随重定向
    HTTP_CODE=$(curl -s -o /tmp/upload_login_resp.txt -w "%{http_code}" \
        -c "$COOKIE_FILE" -L \
        -X POST \
        -d "$FORM_DATA" \
        "$LOGIN_URL" 2>/dev/null || echo "000")

    COOKIE_SIZE=0
    [ -f "$COOKIE_FILE" ] && COOKIE_SIZE=$(wc -c < "$COOKIE_FILE")

    if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 400 ] && [ "$COOKIE_SIZE" -gt 50 ]; then
        chmod 600 "$COOKIE_FILE"
        echo "✅ 登录成功！Cookie 已保存到 $COOKIE_FILE"
        rm -f /tmp/upload_login_resp.txt
        return 0
    else
        echo "❌ 登录失败 (HTTP $HTTP_CODE)"
        if [ -f /tmp/upload_login_resp.txt ]; then
            echo "   响应内容: $(head -c 300 /tmp/upload_login_resp.txt)"
            rm -f /tmp/upload_login_resp.txt
        fi
        return 1
    fi
}

do_logout() {
    rm -f "$COOKIE_FILE"
    echo "🗑️  Cookie 已清除"
}

check_login() {
    # 检查 Cookie 是否存在且非空
    if [ ! -f "$COOKIE_FILE" ] || [ ! -s "$COOKIE_FILE" ]; then
        echo "🔑 Cookie 不存在或为空，尝试自动登录..."
        do_login || {
            echo "❌ 自动登录失败，请检查配置或网络"
            return 1
        }
    fi
    return 0
}

# ---------- 命令分发 ----------
case "${1:-}" in
    --login|-l)
        do_login
        exit $?
        ;;
    --logout|--clear)
        do_logout
        exit 0
        ;;
    --help|-h)
        usage
        ;;
esac

# ---------- 参数检查 ----------
if [ $# -eq 0 ]; then
    usage
fi

# ---------- 确保已登录 ----------
check_login || exit 1

# ---------- 逐个上传 ----------
TOTAL=$#; COUNT=0; SUCCESS=0; FAIL=0
echo "=========================================="
echo "  🚀 开始处理 $TOTAL 个文件"
echo "=========================================="

for FILE_PATH in "$@"; do
    COUNT=$((COUNT + 1))
    if [ ! -f "$FILE_PATH" ]; then
        echo "  [$COUNT/$TOTAL] ⚠️  跳过: 文件不存在 — $FILE_PATH"
        FAIL=$((FAIL + 1))
        continue
    fi

    BASE_NAME=$(basename "$FILE_PATH")
    NAME_NO_EXT="${BASE_NAME%.*}"
    TEMP_FILE="/tmp/${NAME_NO_EXT}_upload_$$.xml"

    echo "  [$COUNT/$TOTAL] 📄 $BASE_NAME → ${NAME_NO_EXT}.xml"
    cp "$FILE_PATH" "$TEMP_FILE"

    HTTP_CODE=$(curl -s -o /tmp/upload_resp_$$.txt -w "%{http_code}" \
        -X POST -b "$COOKIE_FILE" \
        -F "${FORM_FIELD}=@${TEMP_FILE}" \
        "$UPLOAD_URL" 2>/dev/null || echo "000")
    rm -f "$TEMP_FILE"

    if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 400 ]; then
        echo "         ✅ 成功 (HTTP $HTTP_CODE)"
        SUCCESS=$((SUCCESS + 1))
    else
        echo "         ❌ 失败 (HTTP $HTTP_CODE)"
        if [ -f /tmp/upload_resp_$$.txt ]; then
            echo "            响应: $(head -c 500 /tmp/upload_resp_$$.txt)"
            rm -f /tmp/upload_resp_$$.txt
        fi
        FAIL=$((FAIL + 1))
    fi
done

rm -f /tmp/upload_resp_*.txt
echo "=========================================="
echo "  📊 汇总: 共 $TOTAL 个，成功 $SUCCESS，失败 $FAIL"
exit $FAIL
SCRIPT_EOF

chmod +x "$BIN_DIR/upload-xml"
echo -e "   ${GREEN}✅${NC} $BIN_DIR/upload-xml"

# 添加 PATH
if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
    for rc in "$HOME/.zshrc" "$HOME/.bash_profile"; do
        [ -f "$rc" ] && echo 'export PATH="$HOME/bin:$PATH"' >> "$rc" && \
            echo -e "   ${YELLOW}📎${NC} 已添加 PATH 到 $rc"
    done
fi
echo ""

# ---- 2. 创建配置文件 ----
echo -e "${GREEN}📄${NC} 创建配置文件..."
if [ -f "$HOME/.upload-xml.conf" ]; then
    echo -e "   ${YELLOW}⚠️  ~/.upload-xml.conf 已存在，跳过${NC}"
else
    cat > "$HOME/.upload-xml.conf" << CONF_EOF
# ============================================================
# 上传配置 — 请根据实际情况修改
# ============================================================

# ---------- 上传接口 ----------
UPLOAD_URL="${DEFAULT_UPLOAD_URL}"
FORM_FIELD="${DEFAULT_FORM_FIELD}"

# ---------- 登录信息（首次运行 upload-xml --login 前填好） ----------
LOGIN_URL="${DEFAULT_LOGIN_URL}"
LOGIN_USER_FIELD="${DEFAULT_LOGIN_USER_FIELD}"
LOGIN_PASS_FIELD="${DEFAULT_LOGIN_PASS_FIELD}"
USERNAME="你的用户名"
PASSWORD="你的密码"

# ---------- Cookie 文件（自动生成，一般不用改） ----------
COOKIE_FILE="\$HOME/.upload-cookies.txt"
CONF_EOF
    echo -e "   ${GREEN}✅${NC} 已创建 ~/.upload-xml.conf"
    echo -e "   ${YELLOW}✏️  请编辑它填写公司地址、你的账号密码！${NC}"
fi
echo ""

# ---- 3. 编译拖拽 App ----
echo -e "${GREEN}🖱️${NC} 创建桌面拖拽 App..."

cat > "/tmp/CreateUploadApp.applescript" << APPLESCRIPT_EOF
-- 将文件拖拽到图标上 → 自动登录(如需要) + 改后缀 + 上传

on open droppedFiles
	set filePaths to ""
	repeat with aFile in droppedFiles
		set filePath to POSIX path of aFile
		set filePaths to filePaths & quoted form of filePath & " "
	end repeat
	try
		do shell script "$HOME/bin/upload-xml " & filePaths
		display notification "上传完成！" with title "上传到公司" subtitle "全部文件已处理" sound name "Glass"
	on error errMsg
		display dialog "上传失败:" & return & return & errMsg buttons {"确定"} default button 1 with icon stop with title "上传到公司"
	end try
end open

on run
	display dialog "将文件拖拽到「上传到公司」图标上即可自动上传。" & return & return & "首次使用：" & return & "1. 编辑 ~/.upload-xml.conf 填账号密码" & return & "2. 终端执行: upload-xml --login" & return & "3. 把文件拖到图标上 🚀" buttons {"知道了"} default button 1 with title "上传到公司"
end run
APPLESCRIPT_EOF

APP_PATH="$HOME/Desktop/上传到公司.app"
[ -d "$APP_PATH" ] && rm -rf "$APP_PATH"
osacompile -o "$APP_PATH" "/tmp/CreateUploadApp.applescript" 2>/dev/null
if [ $? -eq 0 ]; then
    echo -e "   ${GREEN}✅${NC} $APP_PATH"
else
    echo -e "   ${RED}❌ 编译失败${NC}"
fi
rm -f "/tmp/CreateUploadApp.applescript"
echo ""

# ---- 4. 完成 ----
echo -e "${BLUE}==========================================${NC}"
echo -e "${GREEN}  🎉 安装完成！${NC}"
echo ""
echo -e "  接下来："
echo ""
echo -e "  ${YELLOW}1️⃣  编辑配置文件，填公司地址和你的账号密码${NC}"
echo "     open ~/.upload-xml.conf"
echo ""
echo -e "  ${YELLOW}2️⃣  执行一次登录，验证账号密码是否正确${NC}"
echo "     upload-xml --login"
echo "     或重启终端后执行（PATH 生效后）"
echo ""
echo -e "  ${YELLOW}3️⃣  把文件拖到桌面「上传到公司.app」开始用！${NC}"
echo ""
echo -e "  ${BLUE}💡 常用命令：${NC}"
echo "     upload-xml --login         手动登录/刷新 Cookie"
echo "     upload-xml --logout        清除登录状态"
echo "     upload-xml 文件1 文件2...  命令行上传"
echo -e "${BLUE}==========================================${NC}"
