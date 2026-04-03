# MongoDB Upgrade: 3.6.8 → 4.4.30 (Ubuntu 20.04.5)

## Upgrade Path

```
3.6.8 ──→ 4.0.28 ──→ 4.2.25 ──→ 4.4.30
```

Each arrow is a separate major version upgrade step. **You cannot skip versions.**

## Prerequisites

- Ubuntu 20.04.5 (Focal Fossa)
- Current MongoDB version: 3.6.8
- **Complete backup** of all data before starting
- Access to the offline `.deb` packages (in `packages/` directory)

## Quick Start (Offline)

```bash
# 1. Run pre-upgrade checks
sudo bash scripts/00-pre-check.sh

# 2. Upgrade step by step
sudo bash scripts/01-upgrade-3.6-to-4.0.sh
sudo bash scripts/02-upgrade-4.0-to-4.2.sh
sudo bash scripts/03-upgrade-4.2-to-4.4.sh

# 3. Run post-upgrade verification
sudo bash scripts/04-post-check.sh
```

## Directory Structure

```
.
├── packages/            # Offline .deb packages
│   ├── 4.0/            # MongoDB 4.0.28 packages
│   ├── 4.2/            # MongoDB 4.2.25 packages
│   └── 4.4/            # MongoDB 4.4.30 packages
├── scripts/            # Automated upgrade scripts
│   ├── 00-pre-check.sh
│   ├── 01-upgrade-3.6-to-4.0.sh
│   ├── 02-upgrade-4.0-to-4.2.sh
│   ├── 03-upgrade-4.2-to-4.4.sh
│   ├── 04-post-check.sh
│   └── download-packages.sh
└── README.md
```

## Detailed Upgrade Steps

### Step 0: Pre-upgrade Checks

1. **Backup all data**:
   ```bash
   mongodump --out /backup/mongodb-$(date +%Y%m%d)
   ```
2. **Verify current version**: `mongod --version` should show 3.6.8
3. **Check featureCompatibilityVersion**:
   ```bash
   mongo --eval 'db.adminCommand({ getParameter: 1, featureCompatibilityVersion: 1 })'
   # Must return "3.6"
   ```
4. **Check authentication**: Ensure SCRAM is used (not legacy MONGODB-CR)
5. **Check storage engine**: Must be WiredTiger (MMAPv1 removed in 4.2+)

### Step 1: 3.6.8 → 4.0.28

**Key Breaking Changes:**
- MONGODB-CR authentication removed → must use SCRAM
- `$isolated` operator removed
- Collection UUID required for all collections
- `authSchemaUpgrade` command removed

**Procedure:**
```bash
# Stop MongoDB
sudo systemctl stop mongod

# Install 4.0.28 packages
sudo dpkg -i packages/4.0/mongodb-org-server_4.0.28_amd64.deb
sudo dpkg -i packages/4.0/mongodb-org-shell_4.0.28_amd64.deb
sudo dpkg -i packages/4.0/mongodb-org-mongos_4.0.28_amd64.deb
sudo dpkg -i packages/4.0/mongodb-org-tools_4.0.28_amd64.deb

# Start MongoDB
sudo systemctl start mongod

# Verify version
mongo --eval 'db.version()'  # Should show 4.0.28

# Set feature compatibility version
mongo --eval 'db.adminCommand({ setFeatureCompatibilityVersion: "4.0" })'
```

### Step 2: 4.0.28 → 4.2.25

**Key Breaking Changes:**
- **MMAPv1 storage engine completely removed** → must use WiredTiger
- `group` command removed → use `aggregate()` + `$group`
- `eval` command removed → `db.eval()` no longer works
- `copydb` and `clone` commands removed
- `geoNear` command removed → use `$geoNear` aggregation stage
- File descriptor requirement doubled per connection
- Retryable Writes enabled by default in drivers

**Procedure:**
```bash
# Verify FCV is 4.0
mongo --eval 'db.adminCommand({ getParameter: 1, featureCompatibilityVersion: 1 })'

# Check storage engine is WiredTiger (NOT MMAPv1!)
mongo --eval 'db.serverStatus().storageEngine'

# Stop MongoDB
sudo systemctl stop mongod

# Install 4.2.24 packages
sudo dpkg -i packages/4.2/mongodb-org-server_4.2.25_amd64.deb
sudo dpkg -i packages/4.2/mongodb-org-shell_4.2.25_amd64.deb
sudo dpkg -i packages/4.2/mongodb-org-mongos_4.2.25_amd64.deb
sudo dpkg -i packages/4.2/mongodb-org-tools_4.2.25_amd64.deb

# Start MongoDB
sudo systemctl start mongod

# Verify version
mongo --eval 'db.version()'  # Should show 4.2.25

# Set feature compatibility version
mongo --eval 'db.adminCommand({ setFeatureCompatibilityVersion: "4.2" })'
```

### Step 3: 4.2.25 → 4.4.30

**Key Breaking Changes:**
- `failIndexKeyTooLong` parameter removed
- Structured JSON log format (may break log parsers)
- `ctime` timestamp format no longer supported → use `iso8601`
- `--noIndexBuildRetry` removed
- Projection behavior changes (accepts aggregation expressions)
- `mapReduce` behavior changes
- `validate()` no longer accepts boolean arguments
- geoHaystack index deprecated → use 2d index

**Procedure:**
```bash
# Verify FCV is 4.2
mongo --eval 'db.adminCommand({ getParameter: 1, featureCompatibilityVersion: 1 })'

# Stop MongoDB
sudo systemctl stop mongod

# Install 4.4.30 packages
sudo dpkg -i packages/4.4/mongodb-org-server_4.4.30_amd64.deb
sudo dpkg -i packages/4.4/mongodb-org-shell_4.4.30_amd64.deb
sudo dpkg -i packages/4.4/mongodb-org-mongos_4.4.30_amd64.deb
sudo dpkg -i packages/4.4/mongodb-org-tools_4.4.30_amd64.deb

# Start MongoDB
sudo systemctl start mongod

# Verify version
mongo --eval 'db.version()'  # Should show 4.4.30

# Set feature compatibility version
mongo --eval 'db.adminCommand({ setFeatureCompatibilityVersion: "4.4" })'
```

## Replica Set Upgrade

If running a replica set, use rolling upgrades:

1. Upgrade all **Secondary** nodes one at a time
2. `rs.stepDown()` the **Primary**
3. Upgrade the stepped-down Primary (now Secondary)
4. Only set `setFeatureCompatibilityVersion` after **all** nodes are upgraded

## Rollback Plan

If issues occur at any step:

1. Stop the upgraded mongod
2. Start the previous version's mongod binary
3. **Important**: Rollback only works if `setFeatureCompatibilityVersion` was NOT yet set to the new version
4. If FCV was already set, rollback is much more complex — restore from backup

## Important Notes

- All these MongoDB versions (3.6, 4.0, 4.2, 4.4) are **EOL** (End of Life) and no longer receive security updates
- Consider upgrading to MongoDB 5.0+ or 6.0+ for continued support
- Always test in a staging environment before production
- Monitor logs closely during and after each upgrade step
