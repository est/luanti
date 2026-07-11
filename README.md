# MineClonia Wiki (Auto-Updating)

一个自动更新的 MineClonia 游戏 Wiki。通过 GitHub Actions 定时检测游戏源码变更，自动同步 Wiki 内容。

## 工作原理

```
┌─────────────┐    定时检测     ┌──────────────┐
│  MineClonia │ ◄──────────── │ GitHub Actions│
│  源码仓库    │               │  (cron)       │
└──────┬──────┘               └──────┬───────┘
       │ 有更新                       │
       ▼                             ▼
┌─────────────┐    生成/更新    ┌──────────────┐
│  Lua Mock    │ ─────────────►│  Wiki 页面    │
│  解析脚本    │               │  (VitePress)  │
└─────────────┘               └──────────────┘
```

1. GitHub Actions 按计划检查 MineClonia 仓库是否有新版本
2. 检测到更新时，拉取最新源码
3. 用 Lua mock API 脚本解析所有物品、合成表、生物数据
4. 生成 Markdown Wiki 页面，VitePress 构建并部署到 GitHub Pages

## 技术栈

- **Wiki 框架**: [VitePress](https://vitepress.dev/) — 现代静态站点生成器
- **数据解析**: Lua mock API — 直接加载 MineClonia 源码，拦截注册调用
- **自动更新**: GitHub Actions — 定时检测 + 自动构建部署

## 本地开发

```bash
# 安装依赖
npm install

# 启动开发服务器
npm run dev

# 构建
npm run build
```

## 项目结构

```
├── .github/workflows/   # GitHub Actions 工作流
├── docs/ADR/            # 架构决策记录
├── scripts/             # Lua 解析脚本
├── wiki/                # VitePress Wiki 内容
│   ├── .vitepress/      # VitePress 配置
│   ├── guide/           # 入门指南
│   ├── items/           # 物品图鉴
│   └── recipes/         # 合成表
├── luanti/              # [gitignored] Luanti 引擎参考源码
└── mineclonia/          # [gitignored] MineClonia 游戏参考源码
```

## License

[MIT](LICENSE)
