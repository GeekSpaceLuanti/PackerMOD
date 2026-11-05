return [[
:root { --bg: #151A1F; --surface: #1D2429; --border: #333E39; --text: #EDF4F0; --muted: #A7B9B0; --green: #A0DFBB; color: var(--text); font-size: 16px; line-height: 1.55; }
h1 { font-size: 32px; font-weight: bold; }
h2 { font-size: 22px; font-weight: bold; }
h3 { font-size: 18px; font-weight: bold; }
button { padding: 10px 16px; min-height: 44px; background: #29332E; border-radius: 8px; text-align: center; }
key-button, toggle { padding: 10px 16px; min-height: 44px; background: #29332E; border-radius: 8px; text-align: center; }
field, textarea, dropdown, slider { width: 100%; min-width: 120px; }
image { width: 72px; height: 72px; }
list { width: 100%; min-height: 112px; }
scroll { max-height: 360px; gap: 12px; }
status { font-size: 14px; color: var(--muted); }
.quiet { background: transparent; color: var(--muted); }
.ui-dialog { padding: 28px; gap: 20px; }
.ui-stack { gap: 16px; }
.ui-grid { flex-direction: row; flex-wrap: wrap; gap: 20px; }
.ui-tile { min-width: 240px; flex-grow: 1; align-items: center; gap: 12px; }
.ui-actions { flex-direction: row; flex-wrap: wrap; gap: 12px; justify-content: end; }
.ui-grow { flex-grow: 1; min-width: 140px; }
.ui-column { flex-grow: 1; min-width: 240px; gap: 16px; }
.ui-row-panel { padding: 12px; background: var(--surface); border-radius: 12px; }
@media (max-width: 760px) { scroll { max-height: 280px; } .ui-dialog { padding: 20px; } }
.primary { background: var(--green); color: #102A1D; }
.danger { background: #3A292E; color: #F7B4BD; }
.app { background: var(--bg); border-radius: 24px; border-width: 1px; border-color: var(--border); }
.panel { padding: 24px; background: var(--surface); border-radius: 16px; border-width: 1px; border-color: var(--border); gap: 16px; }
.row { flex-direction: row; flex-wrap: wrap; align-items: center; gap: 12px; }
.column { gap: 16px; }
.grow { flex-grow: 1; min-width: 160px; }
.muted { font-size: 14px; color: var(--muted); }
.center { text-align: center; }
.icon { width: 20px; icon-size: 20px; }
.tabs { gap: 20px; border-bottom-width: 1px; border-bottom-color: var(--border); }
.tab-group { gap: 4px; padding: 4px 0; }
.tab { background: transparent; color: var(--muted); padding: 8px 0; }
.active { color: var(--green); font-weight: bold; }
.selected { border-bottom-width: 2px; border-bottom-color: var(--green); }
.count { font-size: 12px; padding: 1px 6px; background: var(--surface); border-radius: 8px; color: var(--muted); }
.empty { min-height: 260px; padding: 24px; gap: 14px; align-items: center; justify-content: center; }
.empty-icon { padding: 16px; background: #263D31; border-radius: 16px; color: var(--green); }
.empty-title { font-size: 20px; font-weight: bold; text-align: center; }
]]
