#!/bin/bash
# MongoDB Upgrade Step 1: 3.6.8 → 4.0.28
# Offline installation using local .deb packages

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PKG_DIR="${PROJECT_DIR}/packages/4.0"

# Verify packages exist
if [ ! -d "${PKG_DIR}" ] || [ -z "$(ls -A ${PKG_DIR}/*.deb 2>/dev/null)" ]; then
    error "No .deb packages found in ${PKG_DIR}. Run download-packages.sh first."
fi

echo "============================================="
echo " MongoDB Upgrade: 3.6 → 4.0.28"
echo "============================================="
echo ""

# Step 1: Verify prerequisites
info "Step 1: Verifying prerequisites..."

FCV=$(mongo --quiet --eval 'db.adminCommand({ getParameter: 1, featureCompatibilityVersion: 1 }).version' 2>/dev/null || echo "unknown")
if [ "$FCV" != "3.6" ]; then
    error "featureCompatibilityVersion is '${FCV}', expected '3.6'. Set it to 3.6 first."
fi
info "  featureCompatibilityVersion: 3.6 ✓"

VERSION=$(mongod --version 2>/dev/null | head -1 || echo "unknown")
info "  Current version: ${VERSION}"

# Step 2: Stop MongoDB
info "Step 2: Stopping MongoDB..."
sudo systemctl stop mongod
info "  MongoDB stopped ✓"

# Step 3: Install 4.0.28 packages
info "Step 3: Installing MongoDB 4.0.28 packages..."
for deb in "${PKG_DIR}"/*.deb; do
    info "  Installing $(basename $deb)..."
    sudo dpkg -i "$deb"
done
info "  Packages installed ✓"

# Step 4: Start MongoDB
info "Step 4: Starting MongoDB 4.0.28..."
sudo systemctl start mongod
sleep 5

# Verify it's running
if ! pgrep -x mongod &>/dev/null; then
    error "mongod failed to start! Check logs: sudo journalctl -u mongod"
fi
info "  MongoDB 4.0.28 started ✓"

# Step 5: Verify version
info "Step 5: Verifying version..."
NEW_VERSION=$(mongo --quiet --eval 'db.version()' 2>/dev/null || echo "unknown")
info "  MongoDB version: ${NEW_VERSION}"

if ! echo "$NEW_VERSION" | grep -q "4.0"; then
    error "Expected version 4.0.x, got ${NEW_VERSION}"
fi

# Step 6: Set feature compatibility version
echo ""
warn "About to set featureCompatibilityVersion to 4.0"
warn "This makes the downgrade more difficult. Continue only if the upgrade is successful."
read -p "Set featureCompatibilityVersion to 4.0? [y/N] " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    info "Setting featureCompatibilityVersion to 4.0..."
    mongo --eval 'db.adminCommand({ setFeatureCompatibilityVersion: "4.0" })'
    info "  featureCompatibilityVersion set to 4.0 ✓"
else
    warn "Skipped setting featureCompatibilityVersion. Run manually when ready:"
    warn "  mongo --eval 'db.adminCommand({ setFeatureCompatibilityVersion: \"4.0\" })'"
fi

echo ""
info "============================================="
info " Step 1 Complete: 3.6 → 4.0.28"
info "============================================="
echo ""
info "Next: Run scripts/02-upgrade-4.0-to-4.2.sh"
