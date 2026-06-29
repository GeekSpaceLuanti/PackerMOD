/*
 * Dummy data + DOM builder for PackerMOD UI mockups.
 * Each theme HTML calls renderApp() after loading this script.
 *
 * Thumbnails are inline SVG so we don't depend on external PNGs.
 * Themes can override --accent / --accent2 / --bg-card and the SVG inherits via currentColor.
 */

const PACKS = [
  { name: "VoxeLibre Reborn", base: "packerbase 0.91", hasArt: true,  art: "voxel" },
  { name: "Skyblock Mayhem",  base: "packerbase 0.91", hasArt: true,  art: "sky"   },
  { name: "Mesecons Lab",     base: "packerbase 0.91", hasArt: false },
  { name: "Tech World",       base: "packerbase 0.91", hasArt: false },
  { name: "Survival Hardcore",base: "packerbase 0.91", hasArt: false },
  { name: "Creative Sandbox", base: "packerbase 0.91", hasArt: false },
];

// Default thumbnail: pixel-art "T" (PackerMOD's current placeholder vibe).
function defaultThumb() {
  return `
    <svg viewBox="0 0 16 16" xmlns="http://www.w3.org/2000/svg" style="color:var(--accent)">
      <rect x="2"  y="3" width="12" height="2" fill="currentColor"/>
      <rect x="7"  y="3" width="2"  height="10" fill="currentColor"/>
    </svg>`;
}

// Themed art for packs that "have a thumbnail set".
function artThumb(kind) {
  if (kind === "voxel") {
    return `
      <svg viewBox="0 0 16 16" xmlns="http://www.w3.org/2000/svg" style="color:var(--accent)">
        <rect x="1"  y="9"  width="3" height="3" fill="currentColor"/>
        <rect x="4"  y="7"  width="3" height="5" fill="currentColor" opacity="0.7"/>
        <rect x="7"  y="5"  width="3" height="7" fill="currentColor"/>
        <rect x="10" y="8"  width="3" height="4" fill="currentColor" opacity="0.7"/>
        <rect x="13" y="10" width="2" height="2" fill="currentColor"/>
        <rect x="1"  y="12" width="14" height="2" fill="currentColor" opacity="0.4"/>
      </svg>`;
  }
  if (kind === "sky") {
    return `
      <svg viewBox="0 0 16 16" xmlns="http://www.w3.org/2000/svg" style="color:var(--accent2, var(--accent))">
        <circle cx="12" cy="4" r="2" fill="currentColor"/>
        <rect x="3"  y="9"  width="10" height="2" fill="currentColor"/>
        <rect x="5"  y="7"  width="6"  height="2" fill="currentColor" opacity="0.7"/>
        <rect x="2"  y="11" width="4"  height="2" fill="currentColor" opacity="0.5"/>
        <rect x="10" y="11" width="4"  height="2" fill="currentColor" opacity="0.5"/>
      </svg>`;
  }
  return defaultThumb();
}

const ICONS = {
  import: `<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M12 3v10m0 0l-4-4m4 4l4-4M4 17v3h16v-3" stroke="currentColor" stroke-width="2" fill="none"/></svg>`,
  create: `<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M12 4v16M4 12h16" stroke="currentColor" stroke-width="2.5" fill="none"/></svg>`,
  settings: `<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M5 7h10M5 12h14M5 17h7" stroke="currentColor" stroke-width="2" fill="none"/><circle cx="17" cy="7" r="2" fill="currentColor"/><circle cx="11" cy="17" r="2" fill="currentColor"/></svg>`,
};

function renderApp(opts) {
  const cfg = opts || {};
  const titleText = cfg.title || "PACKERMOD";
  const subtitleText = cfg.subtitle || "PACK LIBRARY";

  const root = document.getElementById("app") || document.body;

  const grid = PACKS.map(p => `
    <div class="pack-card">
      <div class="thumb">${p.hasArt ? artThumb(p.art) : defaultThumb()}</div>
      <div class="name">${p.name}</div>
      <div class="base">${p.base}</div>
    </div>`).join("");

  const actions = ["import", "create", "settings"].map(k => `
    <button class="icon-btn" data-action="${k}">
      <span class="ico" style="color:var(--accent)">${ICONS[k]}</span>
      <span class="lbl">${k}</span>
    </button>`).join("");

  root.innerHTML = `
    <div class="app">
      <div class="bg-fx"></div>
      <header class="app-header">
        <div class="title">${titleText}</div>
        <div class="subtitle">${subtitleText}</div>
      </header>
      <main class="pack-grid">${grid}</main>
      <footer class="actions">${actions}</footer>
    </div>`;
}
