# MongoDB 离线升级工具包：3.6.8 → 4.4.30（Ubuntu 20.04.5）

## 升级路径

```
3.6.8 ──→ 4.0.28 ──→ 4.2.25 ──→ 4.4.30
```

每个箭头代表一次独立的大版本升级，**不能跳版本**。

## 前置条件

- Ubuntu 20.04.5（Focal Fossa）
- 当前 MongoDB 版本：3.6.8
- 开始前**必须完成全量数据备份**
- 离线 `.deb` 安装包已准备好（在 `packages/` 目录下）

## 快速开始

```bash
# 1. 升级前检查
sudo bash scripts/00-pre-check.sh

# 2. 依次执行升级
sudo bash scripts/01-upgrade-3.6-to-4.0.sh
sudo bash scripts/02-upgrade-4.0-to-4.2.sh
sudo bash scripts/03-upgrade-4.2-to-4.4.sh

# 3. 升级后验证
sudo bash scripts/04-post-check.sh
```

## 目录结构

```
.
├── packages/            # 离线 .deb 安装包
│   ├── 4.0/            # MongoDB 4.0.28 安装包（4 个）
│   ├── 4.2/            # MongoDB 4.2.25 安装包（4 个）
│   ├── 4.4/            # MongoDB 4.4.30 安装包（6 个）
│   └── checksums.sha256 # SHA256 校验文件
├── scripts/            # 自动化脚本
│   ├── 00-pre-check.sh        # 升级前检查
│   ├── 01-upgrade-3.6-to-4.0.sh  # 第一步升级
│   ├── 02-upgrade-4.0-to-4.2.sh  # 第二步升级
│   ├── 03-upgrade-4.2-to-4.4.sh  # 第三步升级
│   ├── 04-post-check.sh       # 升级后验证
│   └── download-packages.sh   # 重新下载安装包
├── docs/
│   └── operations-runbook.md  # 详细操作手册
└── README.md
```

## 详细操作手册

👉 **推荐查看 [docs/operations-runbook.md](docs/operations-runbook.md)**，包含可复制粘贴的完整命令、检查点和回滚方案。

以下为简要步骤。

## 各步骤概要

### Step 0：升级前检查

1. **备份数据**：
   ```bash
   mongodump --out /backup/mongodb-$(date +%Y%m%d)
   ```
2. **确认当前版本**：`mongod --version` 应显示 3.6.8
3. **确认 FCV**：
   ```bash
   mongo --eval 'db.adminCommand({ getParameter: 1, featureCompatibilityVersion: 1 })'
   # 必须返回 "3.6"
   ```
4. **确认认证方式**：必须使用 SCRAM（不能是旧的 MONGODB-CR）
5. **确认存储引擎**：必须是 WiredTiger（MMAPv1 在 4.2 被移除）

### Step 1：3.6.8 → 4.0.28

**主要破坏性变更：**
- MONGODB-CR 认证方式移除 → 必须使用 SCRAM
- `$isolated` 操作符移除
- 所有集合必须有 UUID
- `authSchemaUpgrade` 命令移除

**操作流程：**
```bash
# 停止 MongoDB
sudo systemctl stop mongod

# 安装 4.0.28
sudo dpkg -i packages/4.0/mongodb-org-server_4.0.28_amd64.deb
sudo dpkg -i packages/4.0/mongodb-org-shell_4.0.28_amd64.deb
sudo dpkg -i packages/4.0/mongodb-org-mongos_4.0.28_amd64.deb
sudo dpkg -i packages/4.0/mongodb-org-tools_4.0.28_amd64.deb

# 启动 MongoDB
sudo systemctl start mongod

# 验证版本
mongo --eval 'db.version()'  # 应显示 4.0.28

# 设置 FCV（确认运行正常后）
mongo --eval 'db.adminCommand({ setFeatureCompatibilityVersion: "4.0" })'
```

### Step 2：4.0.28 → 4.2.25

**主要破坏性变更：**
- **MMAPv1 存储引擎完全移除** → 必须使用 WiredTiger
- `group` 命令移除 → 用 `aggregate()` + `$group` 替代
- `eval` 命令移除 → `db.eval()` 不再可用
- `copydb` 和 `clone` 命令移除
- `geoNear` 命令移除 → 用 `$geoNear` 聚合阶段替代
- 每个连接的文件描述符需求翻倍
- 驱动默认启用 Retryable Writes

**操作流程：**
```bash
# 确认 FCV 为 4.0
mongo --eval 'db.adminCommand({ getParameter: 1, featureCompatibilityVersion: 1 })'

# 确认存储引擎为 wiredTiger（不能是 MMAPv1！）
mongo --eval 'db.serverStatus().storageEngine'

# 停止 MongoDB
sudo systemctl stop mongod

# 安装 4.2.25
sudo dpkg -i packages/4.2/mongodb-org-server_4.2.25_amd64.deb
sudo dpkg -i packages/4.2/mongodb-org-shell_4.2.25_amd64.deb
sudo dpkg -i packages/4.2/mongodb-org-mongos_4.2.25_amd64.deb
sudo dpkg -i packages/4.2/mongodb-org-tools_4.2.25_amd64.deb

# 启动 MongoDB
sudo systemctl start mongod

# 验证版本
mongo --eval 'db.version()'  # 应显示 4.2.25

# 设置 FCV
mongo --eval 'db.adminCommand({ setFeatureCompatibilityVersion: "4.2" })'
```

### Step 3：4.2.25 → 4.4.30

**主要破坏性变更：**
- `failIndexKeyTooLong` 参数移除
- 日志格式改为 JSON（可能影响日志采集工具）
- `ctime` 时间戳格式不再支持 → 使用 `iso8601`
- `--noIndexBuildRetry` 移除
- `validate()` 不再接受布尔参数，必须用 `{ full: true/false }`
- geoHaystack 索引废弃 → 使用 2d 索引
- `mapReduce` 行为变更

**操作流程：**
```bash
# 确认 FCV 为 4.2
mongo --eval 'db.adminCommand({ getParameter: 1, featureCompatibilityVersion: 1 })'

# 停止 MongoDB
sudo systemctl stop mongod

# 安装 4.4.30
sudo dpkg -i packages/4.4/mongodb-org-server_4.4.30_amd64.deb
sudo dpkg -i packages/4.4/mongodb-org-shell_4.4.30_amd64.deb
sudo dpkg -i packages/4.4/mongodb-org-mongos_4.4.30_amd64.deb
sudo dpkg -i packages/4.4/mongodb-org-tools_4.4.30_amd64.deb
sudo dpkg -i packages/4.4/mongodb-org-database-tools-extra_4.4.30_amd64.deb

# 启动 MongoDB
sudo systemctl start mongod

# 验证版本
mongo --eval 'db.version()'  # 应显示 4.4.30

# 设置 FCV
mongo --eval 'db.adminCommand({ setFeatureCompatibilityVersion: "4.4" })'
```

## 副本集升级

如果是副本集，需采用滚动升级方式：

1. 逐个升级所有 **Secondary** 节点
2. 对 Primary 执行 `rs.stepDown()`
3. 升级原 Primary（现在是 Secondary）
4. **所有节点升级完成后**，再统一设置 `setFeatureCompatibilityVersion`

## 回滚方案

出现问题时的回滚：

1. 停止当前版本的 mongod
2. 安装上一个版本的 .deb 包并启动
3. **注意**：只有在**未设置** `setFeatureCompatibilityVersion` 的情况下才能回滚
4. 如果已设置 FCV，回滚非常复杂，建议从备份恢复

## 重要提醒

- 所有涉及的版本（3.6、4.0、4.2、4.4）均已 **EOL（停止维护）**，不再有安全更新
- 建议后续升级到 MongoDB 5.0+ 或 6.0+ 以获得持续支持
- 生产环境操作前务必在测试环境验证
- 升级过程中密切监控日志
