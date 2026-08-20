# Moonlight 个人网站 — 源文件主本（Single Source of Truth）

本目录是 Moonlight 两个个人网站的**唯一主本（master copy）**。

> 规则：任何修改（你自己、WorkBuddy、或其他 AI）都应该改这里的文件，并把改动 `commit` + `push` 回 GitHub 的 `main` 分支。这样永远只有一份"最新版"，不会出现多份互相矛盾的副本。

---

## 目录结构

```
sites/
├── README.md                    # 本说明
├── portfolio/
│   └── moonlight-portfolio.html # 作品集站（单文件 HTML，约 2.4MB）
└── blog/
    ├── index.html               # 个人博客站（单文件 HTML，约 4.3MB）
    └── vercel.json              # 博客站部署配置（Vercel 用，已写好）
```

两个站都是**单文件 HTML**（HTML + CSS + JS 全部内联在一个 `.html` 里），不需要构建步骤，浏览器直接打开即可。

---

## 两个站点概览

| 站点 | 文件 | 板块 |
|------|------|------|
| 作品集 portfolio | `portfolio/moonlight-portfolio.html` | 首页（星宿图）/ Work（蜿蜒小路时间线）/ Cosmos（旋转星系）/ 视频 / 联系 |
| 个人博客 blog | `blog/index.html` | 首页（星宿图）/ Work / Cosmos / 视频 / **Design Book（设计册，目前留空）** / 联系 |

两站共用同一套设计语言：**雾霾蓝 `#B5C1C8` + 米白 + 深绿 `#2C4C3B`、极简/解构风格、≥30% 留白、无障碍（键盘导航 / 屏幕阅读器 / `prefers-reduced-motion`）**。
风格规范请看仓库根目录的 `skills/personal-website-builder/`。

---

## 怎么改内容（按变量名找，不要乱改结构）

两个文件里都集中放了"最常改的内容"，搜索下面这些关键词即可定位：

### 1. 站点基本信息 —— `const SITE = {`
- portfolio 约第 **893** 行
- blog 约第 **949** 行
- 里面放：站点标题、作者名、简介、邮箱、导航等。改文字在这里。

### 2. 作品 / 项目列表 —— `const PROJECTS = [`
- portfolio 约第 **951** 行
- blog 约第 **1007** 行
- 每个项目是一个对象（标题、年份、简介、链接等）。增删项目改这里。

### 3. 博客"视频"板块 —— `const VIDEOS = [`
- 仅 blog，约第 **1394** 行
- 目前填的是 B站 嵌入链接（`https://player.bilibili.com/...`）。要换视频，把 `bvid` 改成新视频的 BV 号即可。
- 注：暂未接入本地 mp4；若放本地视频，需把文件放进 `blog/` 并改用 `<video>` 标签。

### 4. 博客"设计册 / Design Book" —— `const GALLERY = [`
- 仅 blog，约第 **1232** 行
- 目前**留空**（数组为空，页面显示"内容正在整理中"）。想上线设计册时，把图片/作品对象填进这个数组即可，渲染函数已预留。

### 5. 联系方式
- **邮箱 / 飞书**：邮箱在 `const SITE` 里；飞书二维码是一段 base64 图片，搜索 `FEISHU_QR`（portfolio 约 1492 行 / blog 约 1831 行 使用）。要换二维码，替换该 base64 字符串。
- **GitHub**：已填 `https://github.com/moonlightxie`，搜索 `github.com/moonlightxie`（portfolio 约 838 行 / blog 约 894 行）即可改。

### 6. 板块文案
- Cosmos（原"关于我"，旋转星系页）：portfolio 约 715 行 / blog 约 738 行。
- Work（蜿蜒小路时间线）：portfolio 约 676 行 / blog 约 699 行。

---

## 怎么部署

### 当前方式（已在用）
- 由 WorkBuddy 内置的 CloudStudio 部署（单文件静态托管），改完文件后重新部署即生效。

### 想自定义域名 / 更稳定托管
- **博客站**：已带 `blog/vercel.json`，可直接连 Vercel（导入仓库 → 指定 `blog/` 目录）开启自定义域名。
- **作品集站**：同样可放 Vercel / 腾讯云 EdgeOne Pages / Netlify / GitHub Pages，指定对应目录即可。
- 用中国大陆服务器需做 ICP 备案；用境外托管（Vercel 等）可不做备案，但国内访问略慢。

---

## 怎么交给别的 AI 帮你改

1. 把本仓库地址 `https://github.com/moonlightxie/work-apps-skills` 发给对方，或下载对应的 `sites/portfolio/moonlight-portfolio.html` / `sites/blog/index.html` 发给对方。
2. 告诉它：
   - "这是单文件 HTML 网站，所有内容都在一个 `.html` 里"
   - "改完请把文件推回这个 GitHub 仓库的 `main` 分支（或把改好的文件发回给我）"
   - "改的时候保持现有设计风格，风格规范参考仓库里的 `skills/personal-website-builder/`"
3. 接手方改完、你确认无误后，**务必重新部署**才能让线上生效。

> 关键：永远从本仓库拿"最新版"去改，改完放回本仓库。不要另存一份在别处长期编辑，否则会分叉。
