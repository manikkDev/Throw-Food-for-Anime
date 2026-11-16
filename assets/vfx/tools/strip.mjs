// Headless strip renderer for the roblox-vfx sim (no browser pane, no extension).
//
//   python assets/vfx/tools/serve_tfa.py        (once, in the background; port 8766)
//   node assets/vfx/tools/strip.mjs assets/vfx/effects/Reveal_Epic.json [more.json ...]
//
// Starts Microsoft Edge headless with --remote-debugging-port, drives the sim page over the
// Chrome DevTools Protocol (Node 22 global WebSocket), loads each effect definition INLINE
// (app.load(def), so nothing is copied into the skill folder), renders:
//   - a numbered strip at def.strip (times, s) on a light floor (row 1) and a dark floor (row 2),
//     saved through serve.py's POST /save, then moved to assets/vfx/strips/<name>.jpg
//   - dense metrics every 1/60 s over def.duration (luma, sat, hot, particles) ->
//     assets/vfx/metrics/<name>.json  (list of {t, luma, sat, hot, n}) for critic_gate.py --metrics
// Prints one summary line per effect: luma peak + time, flash frames, hot peak, particle peak.
import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";

const EDGE = "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe";
const SIM = process.env.VFX_SIM_URL || "http://127.0.0.1:8766/";
const HERE = path.dirname(fileURLToPath(import.meta.url));
const VFX = path.resolve(HERE, "..");
const SKILL_OUT = path.join(VFX, "_out");
const PORT = 9300 + Math.floor(Math.random() * 400);

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function getJSON(url) {
  for (let i = 0; i < 80; i++) {
    try { const r = await fetch(url); if (r.ok) return await r.json(); } catch {}
    await sleep(150);
  }
  throw new Error("no answer from " + url);
}

class CDP {
  constructor(ws) { this.ws = ws; this.id = 0; this.wait = new Map(); ws.onmessage = (m) => { const d = JSON.parse(m.data); if (d.id && this.wait.has(d.id)) { this.wait.get(d.id)(d); this.wait.delete(d.id); } }; }
  send(method, params = {}) { const id = ++this.id; this.ws.send(JSON.stringify({ id, method, params })); return new Promise((r) => this.wait.set(id, r)); }
  async eval(expr) {
    const r = await this.send("Runtime.evaluate", { expression: expr, awaitPromise: true, returnByValue: true, timeout: 600000 });
    if (r.result && r.result.exceptionDetails) throw new Error(JSON.stringify(r.result.exceptionDetails).slice(0, 800));
    if (r.error) throw new Error(JSON.stringify(r.error));
    return r.result.result.value;
  }
}

// runs inside the page
const PAGE_FN = `async function (def, name, opts) {
  const TW = opts.tw || 360;
  const T = (def.strip && def.strip.length) ? def.strip : Array.from({length: 12}, (_, i) => +(i * (def.duration || 2) / 12).toFixed(3));
  app.playing = false; app.loop = false;
  app.load(def);
  const st = def.stage || {};
  // warm: touch every time so every texture / mesh is requested, then wait
  for (const t of T) { app.world.reset(); app.world.seek(t); app.R.draw(app.world); }
  await app.ready(); await new Promise(r => setTimeout(r, 150)); await app.ready();
  const rows = [];
  const grounds = opts.grounds || ["light", "dark"];
  for (const g of grounds) {
    app.setView({ ground: g, sky: g === "dark" ? "night" : (st.sky || "day") });
    rows.push(await app.strip(T, { cols: Math.min(T.length, opts.cols || 8), w: TW, h: TW * 9 / 16, label: g[0] }));
  }
  // extra rows: pale floor colours (def.stripFloors, hex) and a far camera (def.camera2)
  for (const hex of (def.stripFloors || [])) {
    app.setView({ ground: "light", sky: st.sky || "day" });
    app.R.groundMat.color.set(hex);
    rows.push(await app.strip(T, { cols: Math.min(T.length, opts.cols || 8), w: TW, h: TW * 9 / 16, label: hex }));
  }
  if (def.camera2) {
    app.setView({ ground: "light", sky: st.sky || "day" });
    const d2 = JSON.parse(JSON.stringify(def)); d2.camera = def.camera2; app.load(d2); app.playing = false;
    for (const t of T) { app.world.reset(); app.world.seek(t); app.R.draw(app.world); }
    await app.ready();
    rows.push(await app.strip(T, { cols: Math.min(T.length, opts.cols || 8), w: TW, h: TW * 9 / 16, label: "far " }));
    app.load(def); app.playing = false;
  }
  // stack rows into one jpeg
  const imgs = await Promise.all(rows.map(r => new Promise(res => { const im = new Image(); im.onload = () => res(im); im.src = r.png; })));
  const c = document.createElement("canvas"); c.width = imgs[0].width; c.height = imgs.reduce((a, b) => a + b.height, 0);
  const g2 = c.getContext("2d"); let y = 0; for (const im of imgs) { g2.drawImage(im, 0, y); y += im.height; }
  await fetch("/save?name=" + name + ".jpg", { method: "POST", body: c.toDataURL("image/jpeg", 0.9) });
  // dense metrics on the effect's own stage
  app.setView({ ground: st.ground || "light", sky: st.sky || "day" });
  const m = []; app.world.reset();
  const dur = def.duration || 2;
  for (let f = 0; f <= Math.round(dur * 60); f++) {
    const t = f / 60; app.world.seek(t); app.R.draw(app.world);
    const k = app.R.metrics(); m.push({ t: +t.toFixed(4), luma: +k.luma.toFixed(2), sat: +k.sat.toFixed(2), hot: +k.hot.toFixed(4), n: app.world.particleCount() });
  }
  return { metrics: m, strip: T, warn: (app.world.warnings || []).slice(0, 8).concat([...(app.R.warnings || [])].slice(0, 8)) };
}`;

async function main() {
  const files = process.argv.slice(2).filter((a) => !a.startsWith("--"));
  const grounds = (process.argv.find((a) => a.startsWith("--grounds=")) || "").split("=")[1];
  if (!files.length) { console.log("usage: node strip.mjs <effect.json> ..."); process.exit(2); }
  const prof = fs.mkdtempSync(path.join(os.tmpdir(), "vfxedge-"));
  const edge = spawn(EDGE, ["--headless=new", `--remote-debugging-port=${PORT}`, `--user-data-dir=${prof}`, "--no-first-run", "--disable-gpu-sandbox",
    "--enable-unsafe-swiftshader", "--use-angle=swiftshader", "--window-size=1600,900", "--hide-scrollbars", "about:blank"], { stdio: "ignore" });
  let code = 0;
  try {
    const tabs = await getJSON(`http://127.0.0.1:${PORT}/json/list`);
    const page = tabs.find((t) => t.type === "page");
    const ws = new WebSocket(page.webSocketDebuggerUrl);
    await new Promise((r, j) => { ws.onopen = r; ws.onerror = j; });
    const cdp = new CDP(ws);
    await cdp.send("Runtime.enable");
    await cdp.send("Page.navigate", { url: SIM });
    for (let i = 0; i < 100; i++) { await sleep(200); try { if (await cdp.eval("!!(window.app && app.world)")) break; } catch {} }
    await cdp.eval("app.ready()");
    fs.mkdirSync(path.join(VFX, "strips"), { recursive: true });
    fs.mkdirSync(path.join(VFX, "metrics"), { recursive: true });
    for (const f of files) {
      const def = JSON.parse(fs.readFileSync(f, "utf8"));
      const name = def.name || path.basename(f, ".json");
      const opts = { tw: +((process.argv.find((a) => a.startsWith("--tw=")) || "=360").split("=")[1]), grounds: grounds ? grounds.split(",") : (def.stripGrounds || ["light", "dark"]) };
      let r;
      try { r = await cdp.eval(`(${PAGE_FN})(${JSON.stringify(def)}, ${JSON.stringify(name)}, ${JSON.stringify(opts)})`); }
      catch (e) { console.log(`${name}: ERROR ${e.message}`); code = 1; continue; }
      const src = path.join(SKILL_OUT, name + ".jpg");
      const dst = path.join(VFX, "strips", name + ".jpg");
      fs.copyFileSync(src, dst); fs.unlinkSync(src);
      fs.writeFileSync(path.join(VFX, "metrics", name + ".json"), JSON.stringify(r.metrics));
      const m = r.metrics;
      const base = m[0].luma;
      let pk = m[0]; for (const x of m) if (x.luma > pk.luma) pk = x;
      const flash = m.filter((x) => x.luma - base > 25).length;
      const hot = Math.max(...m.map((x) => x.hot));
      const n = Math.max(...m.map((x) => x.n));
      console.log(`${name}: dur ${def.duration}s  luma base ${base.toFixed(0)} peak ${pk.luma.toFixed(0)} @${pk.t}s  flash>+25: ${flash}f  hot max ${(hot * 100).toFixed(1)}%  particles peak ${n}  ${r.warn.length ? "WARN " + r.warn.join(" | ") : ""}`);
    }
    ws.close();
  } finally {
    edge.kill();
    await sleep(300);
    try { fs.rmSync(prof, { recursive: true, force: true }); } catch {}
    try { if (fs.existsSync(SKILL_OUT) && !fs.readdirSync(SKILL_OUT).length) fs.rmdirSync(SKILL_OUT); } catch {}
  }
  process.exit(code);
}
main().catch((e) => { console.error(e); process.exit(1); });
