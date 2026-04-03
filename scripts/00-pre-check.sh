#!/bin/bash
# Pre-upgrade checks for MongoDB 3.6.8 → 4.4.30

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

check_pass() { echo -e "  ${GREEN}[PASS]${NC} $*"; ((PASS++)); }
check_fail() { echo -e "  ${RED}[FAIL]${NC} $*"; ((FAIL++)); }
check_warn() { echo -e "  ${YELLOW}[WARN]${NC} $*"; ((WARN++)); }

echo "============================================="
echo " MongoDB Pre-Upgrade Checks"
echo " Target: 3.6.8 → 4.0.28 → 4.2.24 → 4.4.30"
echo "============================================="
echo ""

# Check 1: Current MongoDB version
echo "1. Checking current MongoDB version..."
if command -v mongod &>/dev/null; then
    VERSION=$(mongod --version 2>/dev/null | head -1 || echo "unknown")
    if echo "$VERSION" | grep -q "3.6"; then
        check_pass "MongoDB version: $VERSION"
    else
        check_warn "MongoDB version: $VERSION (expected 3.6.x)"
    fi
else
    check_fail "mongod not found in PATH"
fi

# Check 2: MongoDB is running
echo ""
echo "2. Checking if MongoDB is running..."
if pgrep -x mongod &>/dev/null; then
    check_pass "mongod process is running"
else
    check_fail "mongod is not running — start it before proceeding"
fi

# Check 3: Feature compatibility version
echo ""
echo "3. Checking featureCompatibilityVersion..."
FCV=$(mongo --quiet --eval 'db.adminCommand({ getParameter: 1, featureCompatibilityVersion: 1 }).version' 2>/dev/null || echo "unknown")
if [ "$FCV" = "3.6" ]; then
    check_pass "featureCompatibilityVersion = 3.6"
elif [ "$FCV" = "unknown" ]; then
    check_warn "Could not read featureCompatibilityVersion"
else
    check_warn "featureCompatibilityVersion = $FCV (expected 3.6)"
fi

# Check 4: Storage engine
echo ""
echo "4. Checking storage engine..."
ENGINE=$(mongo --quiet --eval 'db.serverStatus().storageEngine.name' 2>/dev/null || echo "unknown")
if [ "$ENGINE" = "wiredTiger" ]; then
    check_pass "Storage engine: WiredTiger"
elif [ "$ENGINE" = "mmapv1" ]; then
    check_fail "Storage engine: MMAPv1 — MUST migrate to WiredTiger before upgrading to 4.2+"
else
    check_warn "Could not determine storage engine: $ENGINE"
fi

# Check 5: Authentication mechanism
echo ""
echo "5. Checking authentication..."
AUTH=$(mongo --quiet --eval 'db.system.users.find({}, {credentials: 1}).toArray()' admin 2>/dev/null || echo "unknown")
if echo "$AUTH" | grep -q "SCRAM-SHA-256\|SCRAM-SHA-1"; then
    check_pass "SCRAM authentication detected"
elif echo "$AUTH" | grep -q "MONGODB-CR"; then
    check_fail "Legacy MONGODB-CR detected — must upgrade to SCRAM before upgrading to 4.0"
else
    check_warn "Could not verify authentication mechanism"
fi

# Check 6: Offline packages present
echo ""
echo "6. Checking offline packages..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
for ver in 4.0 4.2 4.4; do
    PKG_DIR="${PROJECT_DIR}/packages/${ver}"
    if [ -d "$PKG_DIR" ] && ls "${PKG_DIR}"/*.deb &>/dev/null; then
        COUNT=$(ls -1 "${PKG_DIR}"/*.deb 2>/dev/null | wc -l)
        check_pass "packages/${ver}/: ${COUNT} .deb files found"
    else
        check_fail "packages/${ver}/: no .deb files found — run download-packages.sh first"
    fi
done

# Check 7: Disk space
echo ""
echo "7. Checking available disk space..."
if command -v df &>/dev/null; then
    AVAIL=$(df -h /var/lib/mongodb 2>/dev/null | tail -1 | awk '{print $4}' || df -h / | tail -1 | awk '{print $4}')
    check_warn "Available disk space on /var/lib/mongodb: ${AVAIL} — ensure sufficient space for backup"
fi

# Summary
echo ""
echo "============================================="
echo " Summary: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}, ${YELLOW}${WARN} warnings${NC}"
echo "============================================="

if [ "$FAIL" -gt 0 ]; then
    echo ""
    echo -e "${RED}Please fix all FAILED checks before proceeding with the upgrade.${NC}"
    exit 1
fi

exit 0
