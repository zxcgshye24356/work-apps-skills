# Deployment Guide

Two paths. Default is CloudStudio (zero-config, file-delivered). Upgrade to Vercel + Decap only when the user wants a login-backed CMS to edit content themselves.

## Path A — CloudStudio (default, single file)

Best for: a finished single-file `index.html`, no backend, no domain.

Steps:
1. Ensure the site is a single `index.html` (all CSS/JS/SVG inline).
2. Put it in a folder, e.g. `dist/` or `personal-blog/`.
3. Deploy with the CloudStudio deploy tool:
   - `action`: `deploy`
   - `directory`: absolute path to the folder containing `index.html`
   - `entry`: `index.html`
4. The tool returns a `shareLink` (currently `*.app.workbuddy.link`). The old `agentos-app.net` links are deprecated — always use the latest returned link.
5. Tell the user they can manage / delete the published app from **「设置 - 数据管理 - 我发布的应用」**.

Notes:
- Deploy is **cover-style**: deploying the same folder updates the same app.
- If upload fails (`401` / `tar gzip` errors), retry once; the service is occasionally flaky.
- To take a site offline: `action: unpublish` with the `shareLink`.

## Path B — Vercel + Decap CMS (login-backed, editable)

Best for: user wants to write posts / change content from a browser without touching code.

Prerequisites the user must provide:
- A GitHub repository containing the site.
- A Vercel account (connect GitHub, import the repo, set build = none / static, output = the folder).
- A Decap CMS `admin/config.yml` pointing at the repo; an OAuth App (GitHub) for login.

Steps (high level):
1. Convert the single file into a small static project: `index.html` + `admin/` (Decap) + a `posts/` collection if blogging.
2. Push to GitHub.
3. In Vercel: import repo → framework "Other" → output directory = site folder.
4. Add `admin/index.html` (Decap CDN script) + `admin/config.yml` (backend: github, branch: main, media folder, collections: posts).
5. Register a GitHub OAuth App, put client ID/secret into Decap's auth provider.
6. Visit `/admin`, log in with GitHub, edit content.

## Domain / DNS / ICP (only when user buys a domain)

- Domain purchase: via any registrar (e.g. Namecheap, Tencent Cloud DNSPod). Cost is recurring.
- DNS: add an `A` record (Vercel IP) or `CNAME` (Vercel/CloudStudio provided host) at the registrar.
- ICP filing (备案): required if the site is hosted on mainland-China servers and uses a CN domain. Overseas hosting (Vercel default) generally does not require ICP for a personal non-commercial site, but rules change — advise the user to check current MIIT guidance.
- Until the user is ready, the `*.app.workbuddy.link` share link is sufficient for sharing.

## Pre-deploy checklist
- [ ] Single `index.html`, no external `http(s)` asset references
- [ ] All images inlined (base64) or drawn as SVG
- [ ] Accessibility pass done
- [ ] Contact links (email / QR / GitHub) filled or clearly placeholders
- [ ] Local open in browser verified (no console errors)
