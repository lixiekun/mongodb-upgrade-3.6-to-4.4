#!/bin/bash
# Post-upgrade verification for MongoDB 4.4.30

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "============================================="
echo " MongoDB Post-Upgrade Verification"
echo "============================================="
echo ""

# Version check
echo "1. MongoDB Version:"
VERSION=$(mongo --quiet --eval 'db.version()' 2>/dev/null || echo "unknown")
echo -e "   ${GREEN}${VERSION}${NC}"

# Feature compatibility version
echo ""
echo "2. Feature Compatibility Version:"
FCV=$(mongo --quiet --eval 'db.adminCommand({ getParameter: 1, featureCompatibilityVersion: 1 }).version' 2>/dev/null || echo "unknown")
echo -e "   ${GREEN}${FCV}${NC}"

# Storage engine
echo ""
echo "3. Storage Engine:"
ENGINE=$(mongo --quiet --eval 'db.serverStatus().storageEngine.name' 2>/dev/null || echo "unknown")
echo -e "   ${GREEN}${ENGINE}${NC}"

# Database list
echo ""
echo "4. Databases:"
mongo --quiet --eval 'db.adminCommand("listDatabases").databases.forEach(function(d){ print("   - " + d.name + " (" + (d.sizeOnDisk / 1024 / 1024).toFixed(2) + " MB)") })' 2>/dev/null || echo "   Could not list databases"

# Connection count
echo ""
echo "5. Active Connections:"
CONN=$(mongo --quiet --eval 'db.serverStatus().connections.current' 2>/dev/null || echo "unknown")
echo -e "   ${CONN} current connections"

# Uptime
echo ""
echo "6. Uptime:"
UPTIME=$(mongo --quiet --eval 'db.serverStatus().uptime' 2>/dev/null || echo "unknown")
echo "   ${UPTIME} seconds"

# Oplog (if replica set)
echo ""
echo "7. Replica Set Status:"
RS_STATUS=$(mongo --quiet --eval 'rs.status().ok' 2>/dev/null || echo "0")
if [ "$RS_STATUS" = "1" ]; then
    echo -e "   ${GREEN}Replica set member${NC}"
    mongo --quiet --eval 'rs.status().members.forEach(function(m){ print("   - " + m.name + ": " + m.stateStr) })' 2>/dev/null
else
    echo "   Standalone (not a replica set)"
fi

echo ""
echo "============================================="
echo -e " ${GREEN}Post-upgrade verification complete${NC}"
echo "============================================="
