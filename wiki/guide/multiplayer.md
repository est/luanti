# 多人游戏

## 自己开服

Luanti 自带服务器功能，不需要额外软件。

### 快速开服

1. 启动 Luanti
2. 点击 **Start Game** (开始游戏)
3. 选择 MineClonia，创建或选择一个世界
4. 点击 **Host** (主持) 而不是 Play
5. 设置端口（默认 30000）和密码
6. 朋友通过你的 IP 地址 + 端口连接

### 局域网开服

在同一局域网内：

1. 按上述步骤开服
2. 朋友在 **Join Game** 中输入你的局域网 IP（如 `192.168.1.x:30000`）

### 公网开服

需要端口转发或使用内网穿透：

1. 在路由器设置中转发 UDP 端口 30000
2. 朋友使用你的公网 IP 连接
3. 或使用 frp / ngrok 等内网穿透工具

::: tip 提示
公网 IP 可以在 [ip.sb](https://ip.sb) 查看。
:::

## 加入服务器

1. 主菜单 → **Join Game** (加入游戏)
2. 输入服务器地址（格式：`IP:端口`）
3. 输入密码（如果服务器设置了的话）
4. 点击 **Connect** (连接)

## 服务器配置

服务器配置文件为 `minetest.conf`，常用选项：

```ini
# 服务器名称
server_name = My MineClonia Server
server_description = 欢迎来玩！

# 端口
port = 30000

# 最大玩家数
max_users = 20

# 是否需要密码
default_password = mypassword

# PvP
enable_pvp = true

# 游戏模式
gameid = mineclonia
```

## 权限系统

Luanti 有内置的权限系统：

| 权限 | 说明 |
|------|------|
| `interact` | 基本交互（挖掘、放置） |
| `shout` | 聊天 |
| `privs` | 管理其他用户权限 |
| `server` | 服务器管理 |
| `ban` | 封禁用户 |
| `give` | 给予物品 |
| `fly` | 飞行 |
| `fast` | 快速移动 |

### 管理员操作

在服务器控制台或游戏中：

```bash
# 给予管理员权限
grant playername all

# 封禁用户
ban playername

# 踢出用户
kick playername reason
```
