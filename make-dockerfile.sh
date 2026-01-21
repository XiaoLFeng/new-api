#!/bin/bash

# ============================================================================
# NewAPI Docker Build Script (Docker Hub)
# Image: xiaolfeng/newapi-fix
# ============================================================================

set -e

# 颜色定义（兼容不支持 gum 的情况）
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 检查 gum 是否安装
USE_GUM=false
if command -v gum >/dev/null 2>&1; then
    USE_GUM=true
fi

log_info() {
    if [ "$USE_GUM" = true ]; then
        gum style --foreground 39 "$(gum style --bold '[INFO]') $1"
    else
        echo -e "${BLUE}[INFO]${NC} $1"
    fi
}

log_success() {
    if [ "$USE_GUM" = true ]; then
        gum style --foreground 82 "$(gum style --bold '[SUCCESS]') $1"
    else
        echo -e "${GREEN}[SUCCESS]${NC} $1"
    fi
}

log_warn() {
    if [ "$USE_GUM" = true ]; then
        gum style --foreground 214 "$(gum style --bold '[WARN]') $1"
    else
        echo -e "${YELLOW}[WARN]${NC} $1"
    fi
}

log_error() {
    if [ "$USE_GUM" = true ]; then
        gum style --foreground 196 "$(gum style --bold '[ERROR]') $1"
    else
        echo -e "${RED}[ERROR]${NC} $1"
    fi
}

print_separator() {
    if [ "$USE_GUM" = true ]; then
        gum style --foreground 240 "────────────────────────────────────────────────────────────"
    else
        echo "────────────────────────────────────────────────────────────"
    fi
}

print_step() {
    local step_num=$1
    local step_title=$2
    echo ""
    if [ "$USE_GUM" = true ]; then
        gum style --foreground 39 --bold "[$step_num] $step_title"
    else
        echo -e "${BLUE}[$step_num] $step_title${NC}"
    fi
    print_separator
}

print_banner() {
    if [ "$USE_GUM" = true ]; then
        gum style \
            --foreground 57 --bold \
            " _   _                _    ____   ___ " \
            "| \\ | | _____      __/_\\  |  _ \\ / _ \\" \
            "|  \\| |/ _ \\ \\ /\\ / //_\\\\ | | | | | | |" \
            "| |\\  |  __/\\ V  V /  _  \\| |_| | |_| |" \
            "|_| \\_|\\___| \\_/\\_/__/ \\__\\____/ \\___/ " \
            "" \
            "        Docker Build System"
    else
        echo -e "${BLUE} _   _                _    ____   ___${NC}"
        echo -e "${BLUE}| \\ | | _____      __/_\\  |  _ \\ / _ \\${NC}"
        echo -e "${BLUE}|  \\| |/ _ \\ \\ /\\ / //_\\\\ | | | | | | |${NC}"
        echo -e "${BLUE}| |\\  |  __/\\ V  V /  _  \\| |_| | |_| |${NC}"
        echo -e "${BLUE}|_| \\_|\\___| \\_/\\_/__/ \\__\\____/ \\___/ ${NC}"
        echo ""
        echo -e "${BLUE}       Docker Build System${NC}"
    fi
}

# 参数检查：默认不需要账号密码（系统已登录）
if [ -z "$1" ]; then
    print_banner
    echo ""
    log_error "缺少必要参数"
    echo ""
    echo "使用方法: ./make-dockerfile.sh <version>"
    echo ""
    echo "参数说明:"
    echo "  version   - 版本号 (可选，不指定则自动递增)"
    echo ""
    echo "示例:"
    echo "  ./make-dockerfile.sh"
    echo "  ./make-dockerfile.sh 1.0.0"
    echo ""
    exit 1
fi

SPECIFIED_VERSION=$1

# 配置
REGISTRY="docker.io"
NAMESPACE="xiaolfeng"
IMAGE_NAME="newapi-fix"
TARGET_PLATFORM="linux/amd64"
FULL_IMAGE_NAME="$NAMESPACE/$IMAGE_NAME"

print_banner
echo ""

# ============================================================================
# STEP 1: 确定版本号
# ============================================================================
print_step "1/4" "确定版本号"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
cd "$PROJECT_ROOT"

if [ -n "$SPECIFIED_VERSION" ]; then
    VERSION=$SPECIFIED_VERSION
    log_info "使用指定版本: ${VERSION}"
else
    log_info "未指定版本，尝试从 Docker Hub 获取最新版本..."

    LATEST_VERSION=$(curl -s "https://hub.docker.com/v2/repositories/$FULL_IMAGE_NAME/tags?page_size=100" 2>/dev/null | \
        python3 -c "import sys, json; tags=json.load(sys.stdin).get('results', []);
version_tags=[t.get('name','') for t in tags if t.get('name','') not in ('latest',)];
version_tags=[v for v in version_tags if v.replace('.','').isdigit()];
print(max(version_tags)) if version_tags else print('')" 2>/dev/null || echo "")

    if [ -z "$LATEST_VERSION" ]; then
        VERSION="1.0.0"
        log_warn "未找到远程版本，使用初始版本: $VERSION"
    else
        MAJOR=$(echo "$LATEST_VERSION" | cut -d. -f1)
        MINOR=$(echo "$LATEST_VERSION" | cut -d. -f2)
        PATCH=$(echo "$LATEST_VERSION" | cut -d. -f3)
        PATCH=$((PATCH + 1))
        VERSION="$MAJOR.$MINOR.$PATCH"
        log_success "最新版本: $LATEST_VERSION → 新版本: $VERSION"
    fi
fi

echo ""

# ============================================================================
# STEP 2: 环境检查
# ============================================================================
print_step "2/4" "环境检查"

if ! command -v docker >/dev/null 2>&1; then
    log_error "Docker 未安装，请先安装 Docker"
    exit 1
fi
log_success "Docker 已安装"

if [ ! -f "Dockerfile" ]; then
    log_error "Dockerfile 不存在于项目根目录"
    exit 1
fi
log_success "Dockerfile 已找到"

if [ ! -f "go.mod" ]; then
    log_error "go.mod 不存在，请确保在项目根目录运行"
    exit 1
fi
log_success "go.mod 已找到"

echo ""

# ============================================================================
# STEP 3: 构建并推送 Docker 镜像
# ============================================================================
print_step "3/3" "构建并推送 Docker 镜像"

VERSION_TAG="$FULL_IMAGE_NAME:$VERSION"
LATEST_TAG="$FULL_IMAGE_NAME:latest"

log_info "构建配置: $VERSION_TAG (latest 同步)"

build_cmd="docker buildx build \
    --platform $TARGET_PLATFORM \
    -f Dockerfile \
    -t '$VERSION_TAG' \
    -t '$LATEST_TAG' \
    --push ."

if eval "$build_cmd"; then
    log_success "镜像已推送: $VERSION_TAG"
    log_success "镜像已推送: $LATEST_TAG"
    exit 0
else
    log_error "Docker 镜像构建失败，请检查错误信息"
    exit 1
fi
