# MongoDB 升级操作手册

> **升级路径：** 3.6.8 → 4.0.28 → 4.2.25 → 4.4.30
> **目标系统：** Ubuntu 20.04.5
> **预计停机时间：** 每步约 5-10 分钟，总计 20-40 分钟
> **操作人：** _______________
> **日期：** _______________

---

## 前置条件

- [ ] 已备份全部数据
- [ ] 已确认当前版本为 3.6.8
- [ ] 已将整个项目目录上传到目标服务器
- [ ] 已确认磁盘空间充足（至少预留数据大小的 2 倍）

---

## 一、升级前准备

### 1.1 备份数据

```bash
# 创建备份目录
sudo mkdir -p /backup/mongodb-$(date +%Y%m%d)

# 方式一：mongodump 逻辑备份
mongodump --out /backup/mongodb-$(date +%Y%m%d)

# 方式二（推荐）：如果数据量大，用文件系统快照
# 参考你的存储提供商文档做快照
```

### 1.2 确认当前状态

逐条执行以下命令，确认结果：

```bash
# 确认版本
mongod --version
# 期望输出包含: db version v3.6.8

# 确认 FCV (Feature Compatibility Version)
mongo --eval 'db.adminCommand({ getParameter: 1, featureCompatibilityVersion: 1 })'
# 期望输出: "version" : "3.6"
# ⚠️ 如果不是 3.6，先执行:
# mongo --eval 'db.adminCommand({ setFeatureCompatibilityVersion: "3.6" })'

# 确认存储引擎
mongo --eval 'db.serverStatus().storageEngine'
# 期望输出: "name" : "wiredTiger"
# ⚠️ 如果是 mmapv1，必须先迁移到 wiredTiger，否则无法升级到 4.2

# 确认认证方式
mongo --quiet --eval 'db.system.users.find({},{credentials:1}).toArray()' admin
# 期望看到 SCRAM-SHA-1 或 SCRAM-SHA-256
# ⚠️ 如果有 MONGODB-CR，升级 4.0 会失败
```

### 1.3 上传离线包到服务器

```bash
# 在本地机器上执行（把整个目录传过去）
scp -r mongodb-upgrade-3.6-to-4.4/ user@target-server:/opt/

# 在目标服务器上确认文件
ls -lh /opt/mongodb-upgrade-3.6-to-4.4/packages/4.0/
ls -lh /opt/mongodb-upgrade-3.6-to-4.4/packages/4.2/
ls -lh /opt/mongodb-upgrade-3.6-to-4.4/packages/4.4/
```

### 1.4 验证包完整性

```bash
cd /opt/mongodb-upgrade-3.6-to-4.4
sha256sum -c packages/checksums.sha256
# 期望输出: 所有文件 OK
```

---

## 二、Step 1：升级 3.6.8 → 4.0.28

### ⚠️ 破坏性变更
- MONGODB-CR 认证方式被移除
- `$isolated` 操作符被移除
- 必须先迁移到 SCRAM 认证

### 执行步骤

**1) 停止 MongoDB**
```bash
sudo systemctl stop mongod
sudo systemctl status mongod   # 确认已停止
```

**2) 安装 4.0.28 包**
```bash
cd /opt/mongodb-upgrade-3.6-to-4.4
sudo dpkg -i packages/4.0/mongodb-org-server_4.0.28_amd64.deb
sudo dpkg -i packages/4.0/mongodb-org-shell_4.0.28_amd64.deb
sudo dpkg -i packages/4.0/mongodb-org-mongos_4.0.28_amd64.deb
sudo dpkg -i packages/4.0/mongodb-org-tools_4.0.28_amd64.deb
```

**3) 启动 MongoDB**
```bash
sudo systemctl start mongod
```

**4) 验证**
```bash
mongo --eval 'db.version()'
# ✅ 期望输出: 4.0.28

# 如果启动失败，查看日志：
sudo journalctl -u mongod --since "5 minutes ago"
```

**5) 设置 FCV（确认一切正常后执行）**
```bash
mongo --eval 'db.adminCommand({ setFeatureCompatibilityVersion: "4.0" })'
# 确认
mongo --eval 'db.adminCommand({ getParameter: 1, featureCompatibilityVersion: 1 })'
# ✅ 期望输出: "version" : "4.0"
```

> ⏸️ **检查点 1** — 确认业务正常运行后再继续下一步

---

## 三、Step 2：升级 4.0.28 → 4.2.25

### ⚠️ 破坏性变更
- **MMAPv1 存储引擎完全移除**（必须用 wiredTiger）
- `db.eval()` / `group` 命令移除
- `copydb` / `clone` 命令移除

### 执行步骤

**1) 确认前置条件**
```bash
mongo --eval 'db.adminCommand({ getParameter: 1, featureCompatibilityVersion: 1 })'
# ✅ 必须是 "4.0"

mongo --eval 'db.serverStatus().storageEngine.name'
# ✅ 必须是 "wiredTiger"
```

**2) 停止 MongoDB**
```bash
sudo systemctl stop mongod
sudo systemctl status mongod
```

**3) 安装 4.2.25 包**
```bash
cd /opt/mongodb-upgrade-3.6-to-4.4
sudo dpkg -i packages/4.2/mongodb-org-server_4.2.25_amd64.deb
sudo dpkg -i packages/4.2/mongodb-org-shell_4.2.25_amd64.deb
sudo dpkg -i packages/4.2/mongodb-org-mongos_4.2.25_amd64.deb
sudo dpkg -i packages/4.2/mongodb-org-tools_4.2.25_amd64.deb
```

**4) 启动 MongoDB**
```bash
sudo systemctl start mongod
```

**5) 验证**
```bash
mongo --eval 'db.version()'
# ✅ 期望输出: 4.2.25

# 如果启动失败，查看日志：
sudo journalctl -u mongod --since "5 minutes ago"
```

**6) 设置 FCV（确认一切正常后执行）**
```bash
mongo --eval 'db.adminCommand({ setFeatureCompatibilityVersion: "4.2" })'
mongo --eval 'db.adminCommand({ getParameter: 1, featureCompatibilityVersion: 1 })'
# ✅ 期望输出: "version" : "4.2"
```

> ⏸️ **检查点 2** — 确认业务正常运行后再继续下一步

---

## 四、Step 3：升级 4.2.25 → 4.4.30

### ⚠️ 破坏性变更
- 日志格式改为 JSON（可能影响日志采集）
- `ctime` 时间格式不再支持
- `validate()` 不再接受布尔参数
- geoHaystack 索引废弃

### 执行步骤

**1) 确认前置条件**
```bash
mongo --eval 'db.adminCommand({ getParameter: 1, featureCompatibilityVersion: 1 })'
# ✅ 必须是 "4.2"
```

**2) 停止 MongoDB**
```bash
sudo systemctl stop mongod
sudo systemctl status mongod
```

**3) 安装 4.4.30 包**
```bash
cd /opt/mongodb-upgrade-3.6-to-4.4
sudo dpkg -i packages/4.4/mongodb-org-server_4.4.30_amd64.deb
sudo dpkg -i packages/4.4/mongodb-org-shell_4.4.30_amd64.deb
sudo dpkg -i packages/4.4/mongodb-org-mongos_4.4.30_amd64.deb
sudo dpkg -i packages/4.4/mongodb-org-tools_4.4.30_amd64.deb
sudo dpkg -i packages/4.4/mongodb-org-database-tools-extra_4.4.30_amd64.deb
```

**4) 启动 MongoDB**
```bash
sudo systemctl start mongod
```

**5) 验证**
```bash
mongo --eval 'db.version()'
# ✅ 期望输出: 4.4.30
```

**6) 设置 FCV（最终步骤）**
```bash
mongo --eval 'db.adminCommand({ setFeatureCompatibilityVersion: "4.4" })'
mongo --eval 'db.adminCommand({ getParameter: 1, featureCompatibilityVersion: 1 })'
# ✅ 期望输出: "version" : "4.4"
```

---

## 五、升级后验证

```bash
# 版本确认
mongo --eval 'db.version()'
# ✅ 4.4.30

# FCV 确认
mongo --eval 'db.adminCommand({ getParameter: 1, featureCompatibilityVersion: 1 })'
# ✅ "4.4"

# 存储引擎确认
mongo --eval 'db.serverStatus().storageEngine.name'
# ✅ wiredTiger

# 列出数据库，确认数据完整
mongo --eval 'db.adminCommand("listDatabases").databases.forEach(function(d){ print(d.name + " (" + (d.sizeOnDisk/1024/1024).toFixed(2) + " MB)") })'

# 连接数确认
mongo --eval 'db.serverStatus().connections'

# 确认服务自启动
sudo systemctl is-enabled mongod
# ✅ enabled
```

---

## 六、异常处理

### mongod 启动失败

```bash
# 查看日志
sudo journalctl -u mongod --since "10 minutes ago"

# 查看 MongoDB 日志文件
sudo tail -100 /var/log/mongodb/mongod.log
```

### 回滚（仅在未设置 FCV 的情况下可行）

```bash
# 1. 停止当前版本
sudo systemctl stop mongod

# 2. 安装上一个版本的包
sudo dpkg -i packages/{上一版本目录}/mongodb-org-server_*.deb
sudo dpkg -i packages/{上一版本目录}/mongodb-org-shell_*.deb

# 3. 启动
sudo systemctl start mongod
```

### 如果已设置 FCV 且无法回滚

```bash
# 从备份恢复
mongorestore /backup/mongodb-{日期}/
```

---

## 七、记录

| 步骤 | 开始时间 | 结束时间 | 结果 | 备注 |
|------|---------|---------|------|------|
| 备份 | | | | |
| 3.6 → 4.0 | | | | |
| 4.0 → 4.2 | | | | |
| 4.2 → 4.4 | | | | |
| 最终验证 | | | | |
| 业务确认 | | | | |

**签字确认：** _______________
