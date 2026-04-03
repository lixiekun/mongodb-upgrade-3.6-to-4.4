#!/bin/bash
# Download all offline .deb packages for MongoDB upgrade 3.6 → 4.4
# Run this on a machine with internet access, then transfer to target server

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

check_command() {
    if ! command -v "$1" &>/dev/null; then
        error "$1 is required but not installed"
    fi
}

download_deb() {
    local url="$1"
    local output="$2"
    if command -v wget &>/dev/null; then
        wget -q --show-progress -O "$output" "$url"
    elif command -v curl &>/dev/null; then
        curl -L -o "$output" "$url"
    else
        error "Neither wget nor curl found"
    fi
}

main() {
    check_command shasum

    # =============================================
    # MongoDB 4.0.28 (Bionic - compatible with Focal)
    # =============================================
    VERSION="4.0.28"
    DIST="bionic"
    BASE_URL="https://repo.mongodb.org/apt/ubuntu/dists/${DIST}/mongodb-org/4.0/multiverse/binary-amd64"
    PKG_DIR="${PROJECT_DIR}/packages/4.0"

    mkdir -p "${PKG_DIR}"
    info "Downloading MongoDB ${VERSION} packages..."

    for pkg in server shell mongos tools; do
        FILE="mongodb-org-${pkg}_${VERSION}_amd64.deb"
        URL="${BASE_URL}/${FILE}"
        info "  Downloading ${FILE}..."
        download_deb "${URL}" "${PKG_DIR}/${FILE}"
    done

    # =============================================
    # MongoDB 4.2.25 (Bionic - latest 4.2.x)
    # =============================================
    VERSION="4.2.25"
    DIST="bionic"
    BASE_URL="https://repo.mongodb.org/apt/ubuntu/dists/${DIST}/mongodb-org/4.2/multiverse/binary-amd64"
    PKG_DIR="${PROJECT_DIR}/packages/4.2"

    mkdir -p "${PKG_DIR}"
    info "Downloading MongoDB ${VERSION} packages..."

    for pkg in server shell mongos tools; do
        FILE="mongodb-org-${pkg}_${VERSION}_amd64.deb"
        URL="${BASE_URL}/${FILE}"
        info "  Downloading ${FILE}..."
        download_deb "${URL}" "${PKG_DIR}/${FILE}"
    done

    # =============================================
    # MongoDB 4.4.30 (Focal)
    # =============================================
    VERSION="4.4.30"
    DIST="focal"
    BASE_URL="https://repo.mongodb.org/apt/ubuntu/dists/${DIST}/mongodb-org/4.4/multiverse/binary-amd64"
    PKG_DIR="${PROJECT_DIR}/packages/4.4"

    mkdir -p "${PKG_DIR}"
    info "Downloading MongoDB ${VERSION} packages..."

    for pkg in server shell mongos tools; do
        FILE="mongodb-org-${pkg}_${VERSION}_amd64.deb"
        URL="${BASE_URL}/${FILE}"
        info "  Downloading ${FILE}..."
        download_deb "${URL}" "${PKG_DIR}/${FILE}"
    done

    # Also download database-tools-extra (tools are bundled in server from 4.4+)
    info "  Downloading mongodb-org-database-tools-extra_${VERSION}..."
    download_deb "${BASE_URL}/mongodb-org-database-tools-extra_${VERSION}_amd64.deb" "${PKG_DIR}/mongodb-org-database-tools-extra_${VERSION}_amd64.deb"

    # =============================================
    # Generate checksums
    # =============================================
    info "Generating checksums..."
    find "${PROJECT_DIR}/packages" -name "*.deb" -exec shasum -a 256 {} \; > "${PROJECT_DIR}/packages/checksums.sha256"
    info "Checksums saved to packages/checksums.sha256"

    # =============================================
    # Summary
    # =============================================
    echo ""
    info "============================================="
    info "Download complete!"
    info "============================================="
    echo ""
    for ver in 4.0 4.2 4.4; do
        DIR="${PROJECT_DIR}/packages/${ver}"
        if [ -d "$DIR" ]; then
            COUNT=$(ls -1 "${DIR}"/*.deb 2>/dev/null | wc -l)
            SIZE=$(du -sh "${DIR}" 2>/dev/null | cut -f1)
            info "  packages/${ver}/: ${COUNT} packages, ${SIZE}"
        fi
    done
    echo ""
    info "Transfer the entire 'mongodb-upgrade-3.6-to-4.4' directory to the target server"
}

main "$@"
