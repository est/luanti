import { defineConfig } from 'vitepress'

export default defineConfig({
  title: 'MineClonia Wiki',
  description: 'MineClonia 游戏百科 — 自动同步源码，永远最新',

  head: [
    ['link', { rel: 'icon', href: '/favicon.ico' }],
  ],

  themeConfig: {
    logo: '/logo.svg',
    siteTitle: 'MineClonia Wiki',

    nav: [
      { text: '首页', link: '/' },
      { text: '入门', link: '/guide/quickstart' },
      {
        text: '图鉴',
        items: [
          { text: '方块', link: '/items/blocks' },
          { text: '物品', link: '/items/items' },
          { text: '工具', link: '/items/tools' },
          { text: '生物', link: '/items/mobs' },
        ]
      },
      {
        text: '合成',
        items: [
          { text: '工作台', link: '/recipes/crafting' },
          { text: '烧炼', link: '/recipes/smelting' },
          { text: '酿造', link: '/recipes/brewing' },
        ]
      },
      { text: '从 MC 迁移', link: '/guide/migration' },
    ],

    sidebar: {
      '/guide/': [
        {
          text: '入门指南',
          items: [
            { text: '快速开始', link: '/guide/quickstart' },
            { text: '从 Minecraft 迁移', link: '/guide/migration' },
            { text: '多人游戏', link: '/guide/multiplayer' },
          ]
        }
      ],
      '/items/': [
        {
          text: '图鉴',
          items: [
            { text: '方块', link: '/items/blocks' },
            { text: '物品', link: '/items/items' },
            { text: '工具与武器', link: '/items/tools' },
            { text: '生物', link: '/items/mobs' },
          ]
        }
      ],
      '/recipes/': [
        {
          text: '合成表',
          items: [
            { text: '工作台合成', link: '/recipes/crafting' },
            { text: '烧炼', link: '/recipes/smelting' },
            { text: '酿造', link: '/recipes/brewing' },
          ]
        }
      ],
    },

    socialLinks: [
      { icon: 'github', link: 'https://github.com/EleonGameDevelopers/mineclonia' },
    ],

    search: {
      provider: 'local',
    },

    footer: {
      message: '基于 MineClonia 源码自动同步生成',
      copyright: 'MIT License',
    },

    outline: {
      level: [2, 3],
      label: '页面导航',
    },

    docFooter: {
      prev: '上一页',
      next: '下一页',
    },

    lastUpdated: {
      text: '最后更新',
    },

    editLink: {
      pattern: 'https://github.com/est/luanti/edit/main/wiki/:path',
      text: '在 GitHub 上编辑此页',
    },
  },
})
