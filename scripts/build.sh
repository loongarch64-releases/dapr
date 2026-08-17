#!/bin/bash
set -euo pipefail

UPSTREAM_OWNER=dapr
UPSTREAM_REPO=dapr
VERSION="${1}"
echo "   🏢 Org:   ${UPSTREAM_OWNER}"
echo "   📦 Proj:  ${UPSTREAM_REPO}"
echo "   🏷️  Ver:   ${VERSION}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "${SCRIPT_DIR}")"
DISTS="${ROOT_DIR}/dists"
SRCS="${ROOT_DIR}/srcs"

mkdir -p "${DISTS}/${VERSION}" "${SRCS}"

# ==========================================
# 👇 用户自定义构建逻辑 (示例)
# ==========================================

echo "🔧 Compiling ${UPSTREAM_OWNER}/${UPSTREAM_REPO} ${VERSION}..."

# 1. 准备阶段：安装依赖、下载代码、应用补丁等
prepare()
{
    echo "📦 [Prepare] Setting up build environment..."
    
    git clone -b "${VERSION}" --depth 1 "https://github.com/${UPSTREAM_OWNER}/${UPSTREAM_REPO}.git" "${SRCS}/${VERSION}"

    sed -i '/else ifeq (\$(shell echo \$(LOCAL_ARCH) | head -c 7),aarch64)/i\
else ifeq ($(shell echo $(LOCAL_ARCH) | head -c 11),loongarch64)\
	TARGET_ARCH_LOCAL=loong64' "${SRCS}/${VERSION}/Makefile"

    # 该项目需要的 go 版本一般都是最新的，所以直接下载上游的包
    local GO_VER=$(awk '$1 == "go" { print $2; exit }' "${SRCS}/${VERSION}/go.mod")
    local GO_HOME="/usr/local/go"
    export PATH="${GO_HOME}/bin:${PATH}"
    wget -O /tmp/go.tar.gz "https://golang.google.cn/dl/go${GO_VER}.linux-loong64.tar.gz"
    mkdir -p "${GO_HOME}"
    tar -xzf /tmp/go.tar.gz -C "${GO_HOME}" --strip-components=1

    echo "✅ [Prepare] Environment ready."
}

# 2. 编译阶段：核心构建命令
build()
{
    echo "🔨 [Build] Compiling source code..."
    pushd "${SRCS}/${VERSION}"   
    make build-linux REL_VERSION=${VERSION}
    popd
    echo "✅ [Build] Compilation finished."
}

# 3. 后处理阶段：整理产物、清理临时文件、验证版本
post_build()
{
    echo "📦 [Post-Build] Organizing artifacts..."
    
    local PRODUCT="${DISTS}/${VERSION}/dapr_linux_loong64_${VERSION}.tar.gz"
    tar -czf "${PRODUCT}" -C "${SRCS}/${VERSION}/dist/linux_loong64/release/" .

    chown -R "${HOST_UID}:${HOST_GID}" "${DISTS}" "${SRCS}"
    
    echo "✅ [Post-Build] Artifacts ready in ./dists/${VERSION}."
}

# 主入口
main()
{
    prepare
    build
    post_build
}

main

# ==========================================
# 👆 自定义逻辑结束
# ==========================================

cat > "${DISTS}/${VERSION}/release.txt" <<EOF
Project: ${UPSTREAM_REPO}
Organization: ${UPSTREAM_OWNER}
Version: ${VERSION}
Build Time: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF

echo "✅ Compilation finished."
ls -lh "${DISTS}/${VERSION}"
