# 避坑手册与根因清单 (Pitfalls & Root Causes)

整理自真实迁移过程中遭遇的各类隐蔽故障、假象与对症解法。

---

### 1. Docker 跨环境迁移中的权限静默崩溃 (Permission Denied)
- **踩坑现象**：容器显示 `Up` 几秒后即变为 `Restarting (133)`，或应用日志无明显提示。
- **真因**：数据卷被 `rsync` 拷过来后，宿主机属主为普通用户（如 `tq:tq`，权限 `755`）。而容器内守护进程以非 root 用户（如 Kvrocks、Postgres、Redis、Vaultwarden）运行，创建新一天的日志文件或持久化追加时因无写权限直接抛 `SIGABRT (6)`。
- **避坑法**：
  - 数据卷同步后，对数据库和有写需求的挂载目录统一执行：
    ```bash
    sudo chmod -R 777 /data/nvme/docker/<app>/data
    ```
  - 排查容器闪退先看 `docker logs --tail 50 <container_name>`，重点搜索 `Permission denied` 或 `throw_spdlog_ex`。

---

### 2. 出站打洞隧道与公网域名漏迁 (Tunnel Blackhole)
- **踩坑现象**：局域网内所有 30 个服务通过 `192.168.2.151:<port>` 验证全通，源机关机后，所有外部域名（如 `*.domain.com`）全部报 502 Bad Gateway。
- **真因**：
  1. `cloudflared` 和反向 SSH（`ssh -R`）属于出站连接，本地端口大多只监听回环（`127.0.0.1`），在按局域网暴露端口盘点时容易被当做系统网络进程漏掉；
  2. Cloudflare Zero Trust 远程托管隧道本地无 `config.yml`，Token 直接藏在 `/etc/systemd/system/cloudflared.service` 的启动参数中；
  3. 验收时只测试了内网 IP 直连，没有进行外网域名的端到端探测。
- **避坑法**：
  - 关机前必须跑 `detect_outbound_tunnels.sh`；
  - 验收脚本必须将公网域名（`https://*.domain.com`）与局域网 IP 一同纳入探活列表。

---

### 3. 局域网 ARP 缓存漂移导致网络黑洞
- **踩坑现象**：目标机成功挂载了源机的 IP，但局域网某些设备访问时报错 `Destination Host Unreachable` 或连接旧主机。
- **真因**：三层交换机与终端设备的 ARP 表项有几分钟到十几分钟的生存期（TTL），缓存中仍记录着该 IP 对应源机的旧 MAC 地址。
- **避坑法**：
  - IP 挂载后，立即向全网广播无应答 ARP（Gratuitous ARP）：
    ```bash
    sudo arping -c 5 -A -I <接口> <IP>
    sudo arping -c 5 -U -I <接口> <IP>
    ```

---

### 4. WSL / drvfs 残留 index.lock 与 DNS 瞬断
- **踩坑现象**：定时备份脚本报 `Unable to create '/.git/index.lock': File exists` 或 `Could not resolve host: github.com`。
- **真因**：
  - 在 Windows/WSL 跨界文件系统（drvfs）下，文件锁的 mtime 不可信，git 异常退出留下的空锁文件不会自动消失；
  - WSL 镜像网络模式下，Windows 睡眠唤醒或 Wi-Fi 重连会有 1~2 秒的 DNS 丢包。
- **避坑法**：
  - 同步脚本必须设计两轮确认机制（连续两轮见锁且无活跃 git 进程再判为残锁清理）；
  - 区分瞬时网络报错与真正的数据冲突，遇瞬时报错自动重试，不盲目报警。
