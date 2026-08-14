---
name: personal-website-builder
description: This skill should be used when a user wants to design and build a personal portfolio, personal homepage, or personal blog from scratch (single-file HTML, minimalist/deconstructivist style, accessible). It encodes a "design-first, demo-then-implement" workflow, a reusable hazy-blue design system, accessible single-page patterns (hero, constellation home, winding-trail Work timeline, rotating-galaxy Cosmos/About, contact with QR + GitHub), and CloudStudio deployment. Trigger on requests like "帮我做个个人网站/作品集/博客", "把我的作品集做成单页网站", or when the user wants a non-technical, file-delivered personal site.
agent_created: true
---

# Personal Website Builder

## Overview

Build a personal website (portfolio / homepage / blog) as a **single self-contained HTML file** with zero external dependencies, in a minimalist / deconstructivist visual language. The skill favors a **design-first** process: produce small visual demos, get the user's confirmation, then assemble the final site from the approved demos. It ships a reusable "hazy blue" design system, accessible section patterns, and a one-command CloudStudio deploy.

Use this skill for non-technical or low-code users who want a finished file they can preview, host, and later hand-edit.

## When to use

- "帮我做一个个人网站 / 作品集 / 博客"
- "用单文件 HTML 做一个极简风格的个人主页"
- "把我的项目/文章做成可以在线看的网站"
- Any request where the deliverable is a personal site that must be **accessible**, **mobile-first**, and **easy to re-host**

Do **not** use this for: heavy multi-page apps, server-side logic, or frameworks-based builds (React/Vue/Next). Those need a different skill.

## Core principles

1. **Single file, zero dependencies.** Everything (CSS, SVG, JS) lives in one `index.html`. No CDN, no build step. Easy to host anywhere.
2. **Design-first, demo-then-implement.** Never ship a whole site blind. For any non-trivial visual (hero motion, home map, work timeline, cosmos/about galaxies), first produce a standalone `*-demo.html`, confirm, then integrate.
3. **Whitespace ≥ 30%.** Deconstructivist layout, generous margins, few elements per screen.
4. **Accessibility is non-negotiable.** Mobile-first, keyboard navigable, screen-reader labels, `alt` text, `prefers-reduced-motion` honored.
5. **Deliver files, not advice.** The user receives the actual `.html` (and a deploy link), not just instructions.
6. **Unified visual language.** One palette, one type scale, one motion grammar across every section.

## Workflow

### Step 1 · Intake (narrow scope)
Ask only what blocks design. Prefer a short structured set:
- Site type: portfolio / homepage / blog / combo
- Name to display (and any English label, e.g. "Moonlight")
- Sections wanted (pick from pattern library below)
- Palette: default hazy-blue, or user-specified
- Vibe words (minimal / deconstructivist / warm / cosmic)
- Content readiness: real copy now, or placeholders to fill later
- Deployment target: CloudStudio (default) or Vercel+Decap (if they later want a CMS)

If the user is unsure, propose the default stack and let them trim.

### Step 2 · Build the design system first
Load `references/design_system.md`. Apply the CSS variables, type scale, spacing, and motion tokens. Keep all tokens in `:root` so the user can re-theme by editing a few lines.

### Step 3 · Produce demos for risky visuals
For each non-trivial section, create a standalone demo file:
- `hero-demo.html` (subtle motion: floating feather / drifting nebula)
- `home-star-demo.html` (constellation star map linking sections)
- `work-trail-demo.html` (vertical winding trail timeline with card covers)
- `cosmos-galaxy-demo.html` (rotating double-arm galaxies with drill-down)
- any custom visual the user requests

Show the demo and wait for explicit "可以 / 就要这个". Do not integrate until confirmed.

### Step 4 · Assemble the final single-file site
Combine approved demos into one `index.html` using a hash-router SPA shell (see `assets/starter.html`). Keep each section in its own scoped CSS/JS block to avoid collisions. Reuse the exact markup/animation from the approved demos — do not "improve" them silently.

### Step 5 · Accessibility pass
Verify against `references/design_system.md → Accessibility checklist`:
- Keyboard reachable + visible focus on every interactive element
- `aria-label` / `role` on icon buttons, SVGs, lightboxes
- `alt` on meaningful images; `aria-hidden` on decorative ones
- `prefers-reduced-motion: reduce` disables all animation
- Color contrast meets WCAG AA on text

### Step 6 · Deploy
Follow `references/deploy.md`. Default: CloudStudio single-file deploy (returns a share link). Optional: Vercel + Decap CMS for a login-backed editable site.

## Pattern library (copy-paste starting points)

- **Hero** — name + one-line identity, micro-motion only (drift / breathe). No clutter.
- **Home / star map** — a constellation (e.g. Libra) where each star is a section link; no card background, drawn directly on the page background.
- **Work** — vertical winding trail; each node is a project card with a hazy-blue cover SVG (thin reeds + a simple line pony, hand-drawn feel, low saturation). No photos, no heavy textures.
- **Cosmos / About** — replace a plain "About" with a field of 4 rotating double-arm galaxies (bright core + spiral arms + twinkling stars). Each galaxy drills into a sub-view (self-intro / gallery / notes / interests).
- **Contact** — email, a QR-code card (Feishu / WeChat / etc.), and a GitHub block. Use a real `<a href>` once the user provides the link; before that, a labeled placeholder button.
- **Blog / Design Book / Journal** — optional. Keep blank with a "内容整理中" note if content isn't ready; preserve the data array so it's easy to backfill.

## Resources

### references/
- `design_system.md` — palette, type scale, spacing, motion tokens, accessibility checklist, section visual specs.
- `deploy.md` — CloudStudio deploy steps, Vercel+Decap upgrade path, domain/DNS/ICP notes for later.

### assets/
- `starter.html` — a minimal accessible single-file SPA shell (hash router, design tokens, one sample section) to copy as the project's `index.html`.

### scripts/
- (none required; delete if present)
