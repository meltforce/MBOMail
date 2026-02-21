# Doc Site Generator

Generate a polished static documentation/marketing website for any project, deployed via GitHub Pages. The generated site follows the design language of [mbomail.meltforce.org](https://mbomail.meltforce.org) — a clean, responsive, Apple-inspired landing page with light/dark mode, scroll-reveal animations, and mobile-first layout.

## When to use

Use this skill when the user asks to:
- Create a project website or landing page
- Generate a documentation site for a repository
- Set up GitHub Pages for a project
- Build a marketing page for an app or library

## Instructions

### 1. Gather project information

Before generating any files, collect the following from the user or infer it from the repository:

| Field | Description | Example |
|---|---|---|
| `PROJECT_NAME` | Display name of the project | `MBOMail` |
| `PROJECT_TAGLINE` | One-line description (used in hero `<h1>`) | `Your mailbox.org, as a real Mac app` |
| `PROJECT_DESCRIPTION` | Longer description (hero subtitle, meta description) | `MBOMail wraps mailbox.org into a native macOS application...` |
| `FEATURES` | List of 6-9 features, each with icon (emoji), title, and description | See template below |
| `HIGHLIGHTS` | 2-3 deeper feature showcases with title, description, and a visual element | See template below |
| `DOWNLOAD_URL` | Primary download/install link (or `null` for libraries) | GitHub Releases URL |
| `DOWNLOAD_LABEL` | CTA button text | `Download DMG`, `Install`, `Get Started` |
| `VERSION` | Current version string (or `null` to omit badge) | `v1.0.2` |
| `REPO_URL` | GitHub repository URL | `https://github.com/org/repo` |
| `CUSTOM_DOMAIN` | Custom domain for CNAME (or `null` to skip) | `myproject.example.org` |
| `HAS_SCREENSHOT` | Whether a hero screenshot exists | `true` / `false` |
| `ACCENT_COLOR` | Primary accent color (defaults to `#2196f3`) | `#2196f3` |
| `FOOTER_TEXT` | Footer attribution line | `Made with Claude` |
| `LEGAL_CONTENT` | Privacy/legal text, or `null` to skip legal page | See template |

If the user doesn't provide all fields, infer reasonable defaults from the repository's README, package.json, Cargo.toml, Package.swift, or similar metadata files.

### 2. Create directory structure

Create the following files under `website/` in the project root:

```
website/
  index.html          # Main landing page
  style.css           # Complete responsive stylesheet
  legal.html          # Legal/privacy page (optional)
  images/             # Directory for images
    favicon.png       # Favicon (user must provide or use existing)
    icon.png          # Project icon (user must provide or use existing)
  CNAME               # Custom domain (only if CUSTOM_DOMAIN is set)
```

### 3. Generate `website/index.html`

The HTML must include these sections in order:

1. **`<head>`** — charset, viewport, title, meta description, Open Graph tags, favicon, stylesheet link
2. **`<nav>`** — fixed top bar with project icon + name, hamburger toggle for mobile, links to Features / Download / GitHub
3. **Hero section** — large heading with gradient-highlighted keyword, subtitle paragraph, primary + secondary CTA buttons, optional hero screenshot
4. **Features grid** — section label ("Features"), heading, subtitle, then a 3-column responsive grid of feature cards (icon + title + description)
5. **Highlights** — 2-3 alternating rows (text left / visual right, then swapped) for deeper feature showcases with illustrative visual elements
6. **Download CTA** — gradient background box with heading, subtitle, download button, version badge, link to releases
7. **Footer** — attribution text, navigation links (GitHub, Legal)
8. **`<script>`** — Intersection Observer for scroll-reveal, hero immediate reveal, mobile nav toggle

Use semantic HTML. All class names follow the established convention (see CSS section).

Here is the full HTML template — replace all `{{PLACEHOLDER}}` values:

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{{PROJECT_NAME}} — {{PROJECT_TAGLINE}}</title>
  <meta name="description" content="{{PROJECT_DESCRIPTION}}">
  <meta name="color-scheme" content="light dark">

  <!-- Open Graph -->
  <meta property="og:title" content="{{PROJECT_NAME}} — {{PROJECT_TAGLINE}}">
  <meta property="og:description" content="{{PROJECT_DESCRIPTION}}">
  <meta property="og:image" content="{{OG_IMAGE_URL}}">
  <meta property="og:type" content="website">

  <link rel="icon" type="image/png" href="images/favicon.png">
  <link rel="stylesheet" href="style.css">
</head>
<body>

  <!-- Nav -->
  <nav>
    <div class="container">
      <a href="/" class="nav-brand">
        <img src="images/icon.png" alt="{{PROJECT_NAME}} icon" width="32" height="32">
        {{PROJECT_NAME}}
      </a>
      <button class="nav-toggle" aria-label="Toggle navigation" aria-expanded="false">
        <span></span>
        <span></span>
        <span></span>
      </button>
      <ul class="nav-links">
        <li><a href="#features">Features</a></li>
        <li><a href="#download">Download</a></li>
        <li><a href="{{REPO_URL}}" target="_blank">GitHub</a></li>
      </ul>
    </div>
  </nav>

  <!-- Hero -->
  <section class="hero">
    <div class="container">
      <h1 class="reveal reveal-hero" style="--delay: 0">{{HERO_LINE_1}}<br>{{HERO_LINE_2_PREFIX}} <span>{{HERO_LINE_2_HIGHLIGHT}}</span></h1>
      <p class="reveal reveal-hero" style="--delay: 1">{{PROJECT_DESCRIPTION}}</p>
      <div class="hero-actions reveal reveal-hero" style="--delay: 2">
        <a href="#download" class="btn-primary">
          <svg width="16" height="16" fill="none" viewBox="0 0 16 16"><path d="M8 1v10m0 0L4 7m4 4l4-4M2 13h12" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg>
          {{DOWNLOAD_LABEL}}
        </a>
        <a href="#features" class="btn-secondary">See features</a>
      </div>
      <!-- If HAS_SCREENSHOT -->
      <div class="hero-screenshot reveal reveal-hero" style="--delay: 3">
        <img src="images/screenshot.png" alt="{{SCREENSHOT_ALT}}" width="900" height="563" loading="eager">
      </div>
    </div>
  </section>

  <!-- Features grid -->
  <section class="features" id="features">
    <div class="container">
      <span class="section-label reveal">Features</span>
      <h2 class="reveal">{{FEATURES_HEADING}}</h2>
      <p class="reveal">{{FEATURES_SUBTITLE}}</p>

      <div class="feature-grid">
        <!-- Repeat for each feature (6-9 cards) -->
        <div class="feature-card reveal">
          <div class="feature-icon">{{FEATURE_EMOJI}}</div>
          <h3>{{FEATURE_TITLE}}</h3>
          <p>{{FEATURE_DESCRIPTION}}</p>
        </div>
      </div>
    </div>
  </section>

  <!-- Highlight sections -->
  <section class="highlights">
    <div class="container">
      <!-- Repeat for each highlight (2-3 rows) -->
      <div class="highlight-row reveal">
        <div class="highlight-text">
          <h3>{{HIGHLIGHT_TITLE}}</h3>
          <p>{{HIGHLIGHT_DESCRIPTION}}</p>
        </div>
        <div class="highlight-visual">
          <!-- Custom visual element: code snippet, keyboard shortcut demo, icon badge, etc. -->
          {{HIGHLIGHT_VISUAL_HTML}}
        </div>
      </div>
    </div>
  </section>

  <!-- Download CTA -->
  <section class="cta" id="download">
    <div class="container">
      <div class="cta-box reveal">
        <h2>Get {{PROJECT_NAME}}</h2>
        <p>{{CTA_SUBTITLE}}</p>
        <a href="{{DOWNLOAD_URL}}" class="btn-primary" style="margin-bottom: 16px;">
          <svg width="16" height="16" fill="none" viewBox="0 0 16 16"><path d="M8 1v10m0 0L4 7m4 4l4-4M2 13h12" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg>
          {{DOWNLOAD_LABEL}}
        </a>
        <!-- If VERSION is set -->
        <span class="version-badge">{{VERSION}}</span>
        <p class="install-note">View all releases and changelog on <a href="{{REPO_URL}}/releases">GitHub Releases</a>.</p>
      </div>
    </div>
  </section>

  <!-- Footer -->
  <footer>
    <div class="container">
      <p>{{FOOTER_TEXT}}</p>
      <nav>
        <ul class="footer-links">
          <li><a href="{{REPO_URL}}" target="_blank">GitHub</a></li>
          <li><a href="legal.html">Legal</a></li>
        </ul>
      </nav>
    </div>
  </footer>

  <script>
    // Scroll-reveal observer
    var reveals = document.querySelectorAll('.reveal');
    var observer = new IntersectionObserver(function(entries) {
      entries.forEach(function(entry) {
        if (entry.isIntersecting) {
          entry.target.classList.add('revealed');
          observer.unobserve(entry.target);
        }
      });
    }, { threshold: 0.15 });
    reveals.forEach(function(el) { observer.observe(el); });

    // Hero elements: trigger immediately (above the fold)
    document.querySelectorAll('.reveal-hero').forEach(function(el) {
      el.classList.add('revealed');
    });

    // Mobile nav toggle
    var toggle = document.querySelector('.nav-toggle');
    var navLinks = document.querySelector('.nav-links');
    if (toggle) {
      toggle.addEventListener('click', function() {
        var expanded = toggle.getAttribute('aria-expanded') === 'true';
        toggle.setAttribute('aria-expanded', String(!expanded));
        navLinks.classList.toggle('nav-open');
      });
      navLinks.querySelectorAll('a').forEach(function(a) {
        a.addEventListener('click', function() {
          toggle.setAttribute('aria-expanded', 'false');
          navLinks.classList.remove('nav-open');
        });
      });
    }
  </script>

</body>
</html>
```

### 4. Generate `website/style.css`

The stylesheet must implement the complete design system. Copy the full CSS below, replacing `{{ACCENT_HEX}}` with the project's accent color (default `#2196f3`). The accent color derivatives should be computed as follows:
- `--blue-500`: the accent color itself
- `--blue-600`: 8% darker
- `--blue-700`: 20% darker

```css
*,
*::before,
*::after {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

:root {
  --blue-500: {{ACCENT_HEX}};
  --blue-600: {{ACCENT_HEX_DARKER_8}};
  --blue-700: {{ACCENT_HEX_DARKER_20}};
  --gray-50: #fafafa;
  --gray-100: #f5f5f5;
  --gray-200: #eeeeee;
  --gray-400: #bdbdbd;
  --gray-600: #757575;
  --gray-800: #424242;
  --gray-900: #212121;
  --bg: #fff;
  --bg-elevated: var(--gray-50);
  --border: var(--gray-200);
  --text: var(--gray-900);
  --text-secondary: var(--gray-600);
  --code-selector: var(--blue-600);
  --code-value: #7c3aed;
  --nav-bg: rgba(255, 255, 255, 0.82);
  --cta-gradient: linear-gradient(135deg, #e3f2fd 0%, #f3e5f5 100%);
  --icon-gradient: linear-gradient(135deg, #e3f2fd, #bbdefb);
  --badge-border: #fff;
  --key-bg: #fff;
  --key-shadow: var(--gray-200);
  --radius: 16px;
  --radius-sm: 10px;
}

@media (prefers-color-scheme: dark) {
  :root {
    --gray-50: #1c1c1e;
    --gray-100: #2c2c2e;
    --gray-200: #3a3a3c;
    --gray-400: #636366;
    --gray-600: #aeaeb2;
    --gray-800: #d1d1d6;
    --gray-900: #f2f2f7;
    --bg: #0d0d0f;
    --bg-elevated: #1c1c1e;
    --border: #2c2c2e;
    --text: #f2f2f7;
    --text-secondary: #aeaeb2;
    --code-selector: #64b5f6;
    --code-value: #b39ddb;
    --nav-bg: rgba(13, 13, 15, 0.82);
    --cta-gradient: linear-gradient(135deg, #1a237e 0%, #311b92 100%);
    --icon-gradient: linear-gradient(135deg, #1a237e, #0d47a1);
    --badge-border: #1c1c1e;
    --key-bg: #2c2c2e;
    --key-shadow: #1c1c1e;
  }
}

html { scroll-behavior: smooth; }

body {
  font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", sans-serif;
  color: var(--text);
  background: var(--bg);
  line-height: 1.6;
  -webkit-font-smoothing: antialiased;
}

/* --- Scroll Reveal --- */
.reveal {
  opacity: 0;
  transform: translateY(24px);
  transition: opacity 0.6s ease, transform 0.6s ease;
}
.reveal.revealed {
  opacity: 1;
  transform: translateY(0);
}
.reveal-hero {
  transition-delay: calc(var(--delay, 0) * 0.12s);
}
.feature-grid .reveal:nth-child(1) { transition-delay: 0s; }
.feature-grid .reveal:nth-child(2) { transition-delay: 0.06s; }
.feature-grid .reveal:nth-child(3) { transition-delay: 0.12s; }
.feature-grid .reveal:nth-child(4) { transition-delay: 0.18s; }
.feature-grid .reveal:nth-child(5) { transition-delay: 0.24s; }
.feature-grid .reveal:nth-child(6) { transition-delay: 0.30s; }
.feature-grid .reveal:nth-child(7) { transition-delay: 0.36s; }
.feature-grid .reveal:nth-child(8) { transition-delay: 0.42s; }
.feature-grid .reveal:nth-child(9) { transition-delay: 0.48s; }

/* --- Layout --- */
.container {
  max-width: 1080px;
  margin: 0 auto;
  padding: 0 24px;
}

/* --- Nav --- */
nav {
  position: fixed;
  top: 0; left: 0; right: 0;
  z-index: 100;
  background: var(--nav-bg);
  backdrop-filter: saturate(180%) blur(20px);
  -webkit-backdrop-filter: saturate(180%) blur(20px);
  border-bottom: 1px solid var(--border);
}
nav .container {
  display: flex;
  align-items: center;
  justify-content: space-between;
  height: 56px;
}
.nav-brand {
  display: flex;
  align-items: center;
  gap: 10px;
  text-decoration: none;
  color: var(--text);
  font-weight: 600;
  font-size: 17px;
}
.nav-brand img {
  width: 32px; height: 32px;
  border-radius: 7px;
}
.nav-links {
  display: flex;
  align-items: center;
  gap: 28px;
  list-style: none;
}
.nav-links a {
  text-decoration: none;
  color: var(--text-secondary);
  font-size: 14px;
  font-weight: 500;
  transition: color 0.15s;
}
.nav-links a:hover { color: var(--text); }
.nav-toggle {
  display: none;
  background: none;
  border: none;
  cursor: pointer;
  padding: 8px;
  flex-direction: column;
  gap: 5px;
}
.nav-toggle span {
  display: block;
  width: 20px; height: 2px;
  background: var(--text);
  border-radius: 1px;
  transition: transform 0.2s, opacity 0.2s;
}
.nav-toggle[aria-expanded="true"] span:nth-child(1) { transform: translateY(7px) rotate(45deg); }
.nav-toggle[aria-expanded="true"] span:nth-child(2) { opacity: 0; }
.nav-toggle[aria-expanded="true"] span:nth-child(3) { transform: translateY(-7px) rotate(-45deg); }

/* --- Hero --- */
.hero {
  padding: 140px 0 80px;
  text-align: center;
}
.hero h1 {
  font-size: 52px;
  font-weight: 700;
  letter-spacing: -0.025em;
  line-height: 1.1;
  margin-bottom: 16px;
}
.hero h1 span {
  background: linear-gradient(135deg, {{ACCENT_LIGHT}}, {{ACCENT_DARK}});
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}
.hero > .container > p {
  font-size: 19px;
  color: var(--text-secondary);
  max-width: 560px;
  margin: 0 auto 36px;
  line-height: 1.5;
}
.hero-actions {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 16px;
  margin-bottom: 64px;
}
.btn-primary {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  padding: 12px 28px;
  background: var(--text);
  color: var(--bg);
  border-radius: 10px;
  font-size: 15px;
  font-weight: 600;
  text-decoration: none;
  transition: opacity 0.15s, transform 0.15s;
}
.btn-primary:hover {
  opacity: 0.85;
  transform: translateY(-1px);
}
.btn-secondary {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  padding: 12px 28px;
  background: var(--bg-elevated);
  color: var(--text);
  border: 1px solid var(--border);
  border-radius: 10px;
  font-size: 15px;
  font-weight: 600;
  text-decoration: none;
  transition: border-color 0.15s, transform 0.15s;
}
.btn-secondary:hover {
  border-color: var(--gray-400);
  transform: translateY(-1px);
}
.hero-screenshot {
  max-width: 900px;
  margin: 0 auto;
}
.hero-screenshot img {
  width: 100%;
  border-radius: var(--radius);
  box-shadow: 0 1px 2px rgba(0,0,0,0.04), 0 4px 16px rgba(0,0,0,0.08), 0 24px 64px rgba(0,0,0,0.12);
}
@media (prefers-color-scheme: dark) {
  .hero-screenshot img {
    box-shadow: 0 1px 2px rgba(0,0,0,0.2), 0 4px 16px rgba(0,0,0,0.3), 0 24px 64px rgba(0,0,0,0.4);
  }
}

/* --- Features --- */
.features { padding: 80px 0; }
.section-label {
  display: inline-block;
  font-size: 13px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: var(--blue-600);
  margin-bottom: 12px;
}
@media (prefers-color-scheme: dark) {
  .section-label { color: #64b5f6; }
}
.features h2 {
  font-size: 36px;
  font-weight: 700;
  letter-spacing: -0.02em;
  margin-bottom: 12px;
}
.features > .container > p {
  font-size: 17px;
  color: var(--text-secondary);
  max-width: 520px;
  margin-bottom: 48px;
}
.feature-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 20px;
}
.feature-card {
  padding: 28px;
  border-radius: var(--radius-sm);
  background: var(--bg-elevated);
  border: 1px solid var(--border);
  transition: border-color 0.2s, box-shadow 0.2s, transform 0.2s;
}
.feature-card:hover {
  border-color: var(--gray-400);
  box-shadow: 0 2px 12px rgba(0,0,0,0.04);
  transform: translateY(-2px);
}
@media (prefers-color-scheme: dark) {
  .feature-card:hover { box-shadow: 0 2px 12px rgba(0,0,0,0.2); }
}
.feature-icon {
  width: 40px; height: 40px;
  border-radius: 10px;
  background: var(--icon-gradient);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 20px;
  margin-bottom: 16px;
}
.feature-card h3 {
  font-size: 16px;
  font-weight: 600;
  margin-bottom: 6px;
}
.feature-card p {
  font-size: 14px;
  color: var(--text-secondary);
  line-height: 1.5;
}

/* --- Highlights --- */
.highlights { padding: 40px 0 80px; }
.highlight-row {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 64px;
  align-items: center;
  padding: 48px 0;
}
.highlight-row:nth-child(even) .highlight-text { order: 2; }
.highlight-text h3 {
  font-size: 28px;
  font-weight: 700;
  letter-spacing: -0.015em;
  margin-bottom: 12px;
}
.highlight-text p {
  font-size: 16px;
  color: var(--text-secondary);
  line-height: 1.6;
}
.highlight-visual {
  background: var(--bg-elevated);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  padding: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 240px;
}

/* Highlight visual helpers */
.shortcut-demo {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 22px;
  font-weight: 600;
  font-family: "SF Mono", SFMono-Regular, Menlo, monospace;
  color: var(--gray-800);
}
.key-plus {
  color: var(--gray-400);
  font-family: "SF Mono", SFMono-Regular, Menlo, monospace;
  font-size: 22px; font-weight: 600;
}
.key {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 44px; height: 44px;
  padding: 0 14px;
  background: var(--key-bg);
  border: 1px solid var(--border);
  border-radius: 10px;
  box-shadow: 0 2px 0 var(--key-shadow);
  font-size: 18px; font-weight: 600;
  font-family: "SF Mono", SFMono-Regular, Menlo, monospace;
}
.code-snippet {
  font-family: "SF Mono", SFMono-Regular, Menlo, monospace;
  font-size: 14px;
  color: var(--gray-800);
  line-height: 1.8;
  text-align: left;
}
.code-selector { color: var(--code-selector); }
.code-value { color: var(--code-value); }
.badge-demo { position: relative; display: inline-block; }
.badge-demo img { width: 96px; height: 96px; border-radius: 22px; }
.badge-demo .badge {
  position: absolute; top: -6px; right: -6px;
  min-width: 26px; height: 26px; padding: 0 8px;
  background: #ef4444; color: #fff; border-radius: 13px;
  font-size: 14px; font-weight: 700;
  display: flex; align-items: center; justify-content: center;
  border: 2.5px solid var(--badge-border);
}

/* --- CTA --- */
.cta { padding: 80px 0; text-align: center; }
.cta-box {
  background: var(--cta-gradient);
  border-radius: var(--radius);
  padding: 64px 40px;
}
.cta-box h2 {
  font-size: 32px; font-weight: 700;
  letter-spacing: -0.02em;
  margin-bottom: 12px;
}
.cta-box p {
  font-size: 17px;
  color: var(--text-secondary);
  margin-bottom: 32px;
}
.version-badge {
  display: inline-block;
  font-size: 12px; font-weight: 600;
  font-family: "SF Mono", SFMono-Regular, Menlo, monospace;
  color: var(--text-secondary);
  background: var(--bg-elevated);
  border: 1px solid var(--border);
  border-radius: 6px;
  padding: 3px 10px;
  margin-bottom: 16px;
}
.install-note { font-size: 13px; color: var(--text-secondary); }
.install-note a { color: var(--blue-600); text-decoration: none; }
@media (prefers-color-scheme: dark) { .install-note a { color: #64b5f6; } }
.install-note a:hover { text-decoration: underline; }

/* --- Footer --- */
footer {
  border-top: 1px solid var(--border);
  padding: 32px 0;
}
footer .container {
  display: flex;
  align-items: center;
  justify-content: space-between;
}
footer p { font-size: 13px; color: var(--text-secondary); }
footer nav {
  position: static;
  background: none;
  backdrop-filter: none;
  -webkit-backdrop-filter: none;
  border: none;
}
.footer-links { display: flex; gap: 24px; list-style: none; }
.footer-links a {
  font-size: 13px;
  color: var(--text-secondary);
  text-decoration: none;
  transition: color 0.15s;
}
.footer-links a:hover { color: var(--text); }
.footer-link-inline {
  color: var(--text-secondary);
  text-decoration: none;
  transition: color 0.15s;
}
.footer-link-inline:hover { color: var(--text); }

/* --- Legal page --- */
.legal { padding: 120px 0 80px; max-width: 680px; margin: 0 auto; }
.legal h1 { font-size: 32px; font-weight: 700; margin-bottom: 32px; }
.legal-content h2 { font-size: 22px; font-weight: 700; margin-top: 40px; margin-bottom: 12px; }
.legal-content h2:first-child { margin-top: 0; }
.legal-content h3 { font-size: 17px; font-weight: 600; margin-top: 24px; margin-bottom: 8px; }
.legal-content p { font-size: 15px; color: var(--text-secondary); line-height: 1.7; margin-bottom: 12px; }
.legal-content ul { list-style: disc; padding-left: 24px; margin-bottom: 12px; }
.legal-content li { font-size: 15px; color: var(--text-secondary); line-height: 1.7; margin-bottom: 8px; }
.legal-content a { color: var(--blue-600); text-decoration: none; }
.legal-content a:hover { text-decoration: underline; }
@media (prefers-color-scheme: dark) { .legal-content a { color: #64b5f6; } }

/* --- Responsive --- */
@media (max-width: 960px) {
  .feature-grid { grid-template-columns: repeat(2, 1fr); }
}
@media (max-width: 768px) {
  .hero h1 { font-size: 36px; }
  .hero > .container > p { font-size: 17px; }
  .hero-actions { flex-direction: column; }
  .feature-grid { grid-template-columns: 1fr; }
  .highlight-row { grid-template-columns: 1fr; gap: 32px; }
  .highlight-row:nth-child(even) .highlight-text { order: 0; }
  .nav-toggle { display: flex; }
  .nav-links {
    display: none;
    position: absolute;
    top: 56px; left: 0; right: 0;
    flex-direction: column;
    background: var(--nav-bg);
    backdrop-filter: saturate(180%) blur(20px);
    -webkit-backdrop-filter: saturate(180%) blur(20px);
    border-bottom: 1px solid var(--border);
    padding: 16px 24px;
    gap: 16px;
  }
  .nav-links.nav-open { display: flex; }
  footer .container { flex-direction: column; gap: 16px; text-align: center; }
}
@media (max-width: 480px) {
  .hero { padding: 110px 0 48px; }
  .hero h1 { font-size: 28px; }
  .cta-box { padding: 40px 24px; }
}
```

When adapting the accent color, replace:
- `{{ACCENT_LIGHT}}` with a lighter variant (e.g., `#42a5f5` for blue)
- `{{ACCENT_DARK}}` with a darker variant (e.g., `#1565c0` for blue)
- CTA gradient light mode: use very light tints of the accent + a complementary color
- CTA gradient dark mode: use deep saturated versions

### 5. Generate `website/legal.html` (optional)

Only create this file if the user requests it or provides legal content. Use the same nav/footer structure as `index.html`, but with a simple prose layout using the `.legal` and `.legal-content` classes. Include sections for:

- **Privacy Policy** — what data is collected, network connections, local storage
- **Disclaimer** — independence from third-party services, trademark acknowledgments
- **Open Source License** — license type with link to the repository

### 6. Generate GitHub Actions workflow

Create `.github/workflows/pages.yml` (or update if it already exists):

```yaml
name: Deploy to GitHub Pages

on:
  push:
    branches: [main]
    paths: [website/**]
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: pages
  cancel-in-progress: false

jobs:
  deploy:
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/configure-pages@v5
      - uses: actions/upload-pages-artifact@v3
        with:
          path: website
      - id: deployment
        uses: actions/deploy-pages@v4
```

### 7. Generate `website/CNAME` (optional)

Only if `CUSTOM_DOMAIN` is provided:

```
{{CUSTOM_DOMAIN}}
```

### 8. Post-generation checklist

After generating all files, remind the user to:

1. Add image assets to `website/images/`:
   - `favicon.png` — 32x32 or 64x64 favicon
   - `icon.png` — project icon (used in nav and badge demo)
   - `screenshot.png` — hero screenshot (if `HAS_SCREENSHOT` is true)
   - `og-image.png` — Open Graph social preview (1200x630 recommended)
2. Enable GitHub Pages in repository settings (Settings > Pages > Source: GitHub Actions)
3. If using a custom domain, configure DNS (CNAME record pointing to `<user>.github.io`)
4. Push the `website/` directory to the `main` branch to trigger deployment

## Design principles

The generated site follows these principles:

- **No build step** — pure static HTML/CSS/JS, no bundler or framework required
- **System font stack** — uses `-apple-system` / SF Pro for native appearance
- **Light + dark mode** — automatic via `prefers-color-scheme` media query
- **Mobile-first responsive** — hamburger nav, single-column layout on small screens
- **Scroll-reveal animations** — Intersection Observer with staggered delays
- **Accessibility** — semantic HTML, ARIA labels, sufficient contrast ratios
- **Performance** — no external dependencies, minimal JavaScript, lazy-loaded images
- **Apple-inspired aesthetic** — frosted glass nav, subtle shadows, rounded corners, gradient accents
