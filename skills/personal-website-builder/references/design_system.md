# Design System — Hazy Blue (雾霾蓝)

A minimalist / deconstructivist personal-site system. All tokens live in `:root` so the user can re-theme by editing a few lines.

## Palette

| Token | Value | Usage |
|-------|-------|-------|
| `--bg` | `#B5C1C8` | Primary hazy-blue background |
| `--bg-light` | `#C9D2D7` | Lighter wash / gradient top |
| `--bg-dark` | `#A9B7BF` | Deeper wash / gradient bottom |
| `--cream` | `#F5F6F8` | Off-white surfaces, stars, card text |
| `--ink` | `#1A1A1A` | Body text |
| `--accent` | `#2C4C3B` | Deep green accent (lines, focus, emphasis) |
| `--muted` | `#5C666B` | Secondary text, captions |

Neutral, low-saturation. Never use large flat color blocks or photo collages as the hero.

## Typography

- Font stack: `system-ui, -apple-system, "Segoe UI", Roboto, "PingFang SC", "Microsoft YaHei", sans-serif`
- Scale (rem): display `clamp(30px,5vw,52px)`, h1 `clamp(28px,5vw,44px)`, h2 `20–26px`, body `15px`, caption `12–13px`
- Weights: 300–500 only. No bold headings heavier than 500. Letter-spacing on eyebrows: `.18–.22em`, uppercase.
- Line-height: body `1.6–1.7`.

## Spacing & layout

- Whitespace: keep ≥ 30% empty surface per viewport. Large section padding (`72px 24px 96px`).
- Max content width: `1080px`, centered.
- Grid: CSS Grid / Flexbox; mobile-first (single column, then `minmax` auto-fit).
- Border-radius: soft (`14–22px`) on cards; full circles for stars/cores.

## Motion grammar

- Micro only: drift, breathe, twinkle, float. No sliding carousels or parallax hijacks.
- Durations: `3s` twinkle, `20–44s` slow galaxy rotation, `26s` background drift.
- Always wrap in `@media (prefers-reduced-motion: reduce){ *{animation:none!important} }`.

## Accessibility checklist (must pass before deploy)

- [ ] Keyboard: every interactive element reachable via Tab; visible `:focus-visible` outline (use `--accent`).
- [ ] `role` / `aria-label` on icon buttons, SVGs (`role="img"` + label), lightboxes (`aria-modal="true"`).
- [ ] Decorative SVG/gradients get `aria-hidden="true"`.
- [ ] Meaningful images have `alt`; the contact QR has descriptive `title`.
- [ ] Color contrast ≥ WCAG AA for text on background.
- [ ] `prefers-reduced-motion` disables all animation.
- [ ] viewport meta present; layout usable at 360px width.

## Section visual specs

### Hero
- Name (display) + one-line identity (muted). Optional micro-motion: a faint drifting nebula or floating feather behind, opacity ≤ .3.

### Home / constellation star map
- Draw a real constellation (e.g. Libra) directly on `--bg`, no card background.
- 7–8 stars positioned by approximate real coordinates; one central "home" star.
- Each star is an `<a>` / `<button>` linking to a section; `aria-label` = section name.
- Subtle twinkle on stars.

### Work — winding trail timeline
- Vertical trail (`height` large, e.g. `2600px`), gentle sinusoidal wander (amplitude ±24%, ~2.3 turns).
- Nodes: project cards with hazy-blue cover SVG.
- Cover SVG spec: rectangular (`viewBox` fill), base gradient `#BFC9CF → #A9B7BF`; bottom-left 3 thin reed spikes (`#5C666B`) with cream oval tips rotated slightly; mid-right a simple **line pony** (stroke `#2C4C3B`, no fill, rounded, small mane/tail/round eye). 1–2 faint arcs opacity .2–.3; 1–2 translucent white circles behind for depth. Hand-drawn, low-saturation, no realism.
- Card shows project name + one-line intro; no photos.

### Cosmos / About — rotating galaxies
- Field of 4 galaxies (self-intro / gallery / notes / interests).
- Each galaxy: SVG `viewBox 0 0 200 200`, center (100,100). Dark disk (`#1a2029→#050608`), bright core radial gradient, two logarithmic-spiral arms (dots + faint dust ellipses), disk field stars. Whole arm group rotates `0→360` over ~44s; core stays fixed. Stars twinkle.
- Clicking a galaxy drills into a sub-view (self-intro facts orbiting a core; gallery as scattered photo-stars opening a lightbox; notes as a list; interests as floating tags).
- Keep all Cosmos CSS/JS scoped (prefix `.cosmos`, `cosmosShow`, `cOpenLb`) so it can't collide with site-wide lightboxes.

### Contact
- Cards: email (`mailto:`), a QR code (Feishu/WeChat/etc., `FEISHU_QR` style base64 or `<img>`), GitHub block.
- GitHub: real `<a href="https://github.com/USER" target="_blank" rel="noopener noreferrer">` once provided; before that a labeled placeholder button "敬请期待".
- Footer note: "邮箱 / 飞书" style, matching the active QR source.

### Blog / Design Book / Journal (optional)
- Keep section present but empty with a "内容正在整理中，敬请期待" note if content isn't ready. Preserve the data array (e.g. `GALLERY`, `JOURNAL`) so backfill is trivial.
