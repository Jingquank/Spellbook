// Spellbook scanner. Enumerates skill roots for a project and the device, resolves
// Installs (Recorded, Inferred, Loose), Agent Marks and Drift, and returns the Survey.
// Node 20+, no dependencies. Run directly to print JSON:  node server/scan.mjs [--project DIR]
import fs from "node:fs";
import fsp from "node:fs/promises";
import path from "node:path";
import os from "node:os";
import crypto from "node:crypto";

const HOME = os.homedir();
const TEXT_EXT = /\.(md|markdown|txt|json|ya?ml|toml|css|js|mjs|cjs|ts|tsx|jsx|py|sh|rb|go|rs|swift|html|svg|csv|xml|ini|cfg|conf|env|lock)$/i;

export const AGENTS = { "claude-code": "Claude Code", codex: "Codex", gemini: "Gemini", cursor: "Cursor" };

// A root is a directory that holds skill folders, each with a SKILL.md.
function deviceRoots() {
  return [
    { path: path.join(HOME, ".agents", "skills"), marks: ["codex"], note: "shared root · read by Codex; Claude Code reaches it through symlinks", shared: true },
    { path: path.join(HOME, ".claude", "skills"), marks: ["claude-code"], note: "Claude Code" },
    { path: path.join(HOME, ".codex", "skills"), marks: ["codex"], note: "Codex" },
    { path: path.join(HOME, ".codex", "skills", ".system"), marks: ["codex"], note: "Codex system skills", system: true },
    { path: path.join(HOME, ".gemini", "skills"), marks: ["gemini"], note: "Gemini" },
    { path: path.join(HOME, ".cursor", "skills"), marks: ["cursor"], note: "Cursor" }
  ];
}
function projectRoots(project) {
  return [
    { path: path.join(project, ".claude", "skills"), marks: ["claude-code"], note: "this project" },
    { path: path.join(project, ".agents", "skills"), marks: ["codex"], note: "this project · shared root", shared: true },
    { path: path.join(project, ".codex", "skills"), marks: ["codex"], note: "this project" }
  ];
}

async function exists(p) { try { await fsp.access(p); return true; } catch { return false; } }
async function realpath(p) { try { return await fsp.realpath(p); } catch { return p; } }
function tilde(p) { return p.startsWith(HOME) ? "~" + p.slice(HOME.length) : p; }
function localDay(ms) { const d = new Date(ms); const z = (n) => String(n).padStart(2, "0"); return d.getFullYear() + "-" + z(d.getMonth() + 1) + "-" + z(d.getDate()); }

export function parseFrontmatter(text) {
  const m = /^---\r?\n([\s\S]*?)\r?\n---\r?\n?/.exec(text);
  if (!m) return { fm: {}, body: text };
  const fm = {};
  let key = null;
  for (const line of m[1].split(/\r?\n/)) {
    const kv = /^([A-Za-z_][\w-]*):\s*(.*)$/.exec(line);
    if (kv) { key = kv[1]; fm[key] = kv[2].trim().replace(/^["']|["']$/g, ""); }
    else if (key && /^\s+\S/.test(line)) fm[key] = (fm[key] ? fm[key] + " " : "") + line.trim();
  }
  return { fm, body: text.slice(m[0].length) };
}

async function listFiles(dir, limit = 400) {
  const out = [];
  async function walk(d, rel) {
    let ents; try { ents = await fsp.readdir(d, { withFileTypes: true }); } catch { return; }
    for (const e of ents) {
      if (e.name.startsWith(".") || e.name === "node_modules") continue;
      const r = rel ? rel + "/" + e.name : e.name;
      if (e.isDirectory()) await walk(path.join(d, e.name), r);
      else out.push(r);
      if (out.length >= limit) return;
    }
  }
  await walk(dir, "");
  return out.sort();
}

async function readSkill(dir, root) {
  const skillPath = path.join(dir, "SKILL.md");
  let text; try { text = await fsp.readFile(skillPath, "utf8"); } catch { return null; }
  const { fm } = parseFrontmatter(text);
  const st = await fsp.stat(dir).catch(() => null);
  const files = await listFiles(dir);
  const real = await realpath(dir);
  const id = path.basename(dir);
  const birth = st && st.birthtimeMs && st.birthtimeMs > 0 ? st.birthtimeMs : (st ? st.mtimeMs : Date.now());
  return {
    id, name: fm.name || id, description: fm.description || "", frontmatter: fm,
    lines: text.split(/\r?\n/).length, bytes: text.length, files,
    date: localDay(st ? st.mtimeMs : Date.now()),
    installedDay: localDay(birth),
    md: text, hash: crypto.createHash("sha1").update(text).digest("hex").slice(0, 12),
    dir, real, root: root.path, marks: root.marks.slice()
  };
}

async function skillsInRoot(root) {
  if (!(await exists(root.path))) return [];
  let ents; try { ents = await fsp.readdir(root.path, { withFileTypes: true }); } catch { return []; }
  const out = [];
  for (const e of ents) {
    if (e.name.startsWith(".")) continue;
    const dir = path.join(root.path, e.name);
    let isDir = e.isDirectory();
    if (e.isSymbolicLink()) { try { isDir = (await fsp.stat(dir)).isDirectory(); } catch { isDir = false; } }
    if (!isDir) continue;
    const s = await readSkill(dir, root);
    if (s) out.push(s);
  }
  return out;
}

async function pluginInstalls() {
  const manifest = path.join(HOME, ".claude", "plugins", "installed_plugins.json");
  let data; try { data = JSON.parse(await fsp.readFile(manifest, "utf8")); } catch { return []; }
  const out = [];
  for (const [key, entries] of Object.entries(data.plugins || {})) {
    const e = Array.isArray(entries) ? entries[0] : entries; if (!e || !e.installPath) continue;
    const name = key.split("@")[0];
    const skills = [];
    async function find(d, depth) {
      if (depth > 4) return;
      let ents; try { ents = await fsp.readdir(d, { withFileTypes: true }); } catch { return; }
      for (const x of ents) {
        if (x.name.startsWith(".") || x.name === "node_modules") continue;
        const p = path.join(d, x.name);
        if (x.isDirectory()) { if (await exists(path.join(p, "SKILL.md"))) { const s = await readSkill(p, { path: e.installPath, marks: ["claude-code"] }); if (s) skills.push(s); } else await find(p, depth + 1); }
      }
    }
    await find(path.join(e.installPath, "skills"), 0);
    if (!skills.length) continue;
    out.push({
      id: "plugin-" + name, name, kind: "plugin", source: "device", marks: ["claude-code"], drift: false,
      date: (e.installedAt || "").slice(0, 10) || skills[0].date, updated: (e.lastUpdated || "").slice(0, 10) || undefined,
      version: String(e.version || "").slice(0, 12), manifest: tilde(manifest), skills
    });
  }
  return out;
}

async function benchManifest(rootPath) {
  try { const j = JSON.parse(await fsp.readFile(path.join(rootPath, ".bench-install.json"), "utf8")); return j && j.skills ? { skills: Object.keys(j.skills), version: j.version } : null; } catch { return null; }
}

// Same skill id seen from several roots: collapse identical copies, record Drift otherwise.
function mergeCopies(copies) {
  const primary = copies.find((c) => c.shared) || copies[0];
  const marks = new Set(); copies.forEach((c) => c.marks.forEach((m) => marks.add(m)));
  const realGroups = new Map(); copies.forEach((c) => { const g = realGroups.get(c.real) || []; g.push(c); realGroups.set(c.real, g); });
  const distinct = [...realGroups.values()].map((g) => g[0]);
  let drift = false, driftDetail = null;
  if (distinct.length > 1) {
    const base = distinct[0];
    const differing = distinct.slice(1).filter((c) => c.hash !== base.hash || c.files.join("|") !== base.files.join("|"));
    if (differing.length) {
      drift = true;
      const changed = new Set();
      const onlyIn = {};
      for (const c of differing) {
        if (c.hash !== base.hash) changed.add("SKILL.md");
        const a = new Set(base.files), b = new Set(c.files);
        onlyIn[tilde(path.dirname(base.dir))] = [...a].filter((f) => !b.has(f)).slice(0, 8);
        onlyIn[tilde(path.dirname(c.dir))] = [...b].filter((f) => !a.has(f)).slice(0, 8);
      }
      driftDetail = { copies: distinct.map((c) => ({ root: tilde(path.dirname(c.dir)), lines: c.lines, files: c.files.length, updated: c.date })), changed: [...changed], onlyIn };
    }
  }
  const s = { ...primary, marks: [...marks].sort(), drift, driftDetail, copies: distinct.map((c) => tilde(c.dir)), rootDir: tilde(path.dirname(primary.dir)) };
  delete s.root; delete s.hash;
  return s;
}

function clusterInferred(skills, source) {
  // One install action writes into one root on one day; cluster by both.
  const byKey = new Map();
  for (const s of skills) { const k = (s.rootDir || "") + "|" + s.installedDay; const g = byKey.get(k) || []; g.push(s); byKey.set(k, g); }
  const installs = [];
  for (const [key, group] of byKey) {
    const day = key.split("|")[1];
    if (group.length >= 2) {
      const d = new Date(day + "T12:00:00");
      const label = "Installed together, " + d.getDate() + " " + d.toLocaleString("en", { month: "short" });
      installs.push({ id: "inf-" + day + "-" + crypto.createHash("sha1").update(key).digest("hex").slice(0, 4), name: label, kind: "inferred", source, marks: union(group), drift: group.some((s) => s.drift), date: day, skills: group.sort(byName) });
    } else for (const s of group) installs.push(looseInstall(s, source));
  }
  return installs;
}
function looseInstall(s, source) { return { id: "loose-" + s.id, name: s.name, kind: "loose", source, marks: s.marks, drift: !!s.drift, date: s.date, skills: [s] }; }
function union(skills) { const m = new Set(); skills.forEach((s) => s.marks.forEach((x) => m.add(x))); return [...m].sort(); }
const byName = (a, b) => a.name.localeCompare(b.name);
const byInstall = (a, b) => a.name.localeCompare(b.name);

async function resolveSource(roots, source) {
  const seen = new Map(); // skill id -> copies
  const recorded = [];
  const rootSummaries = [];
  for (const root of roots) {
    if (root.system) {
      const sys = await skillsInRoot(root);
      rootSummaries.push({ path: tilde(root.path), exists: sys.length > 0, skills: sys.length, note: root.note });
      if (sys.length) recorded.push({ id: "codex-system", name: "Codex system skills", kind: "recorded", source, marks: ["codex"], drift: false, date: sys[0].date, manifest: tilde(root.path), quiet: true, skills: sys.map((s) => mergeCopies([{ ...s, shared: false }])).sort(byName) });
      continue;
    }
    const skills = await skillsInRoot(root);
    rootSummaries.push({ path: tilde(root.path), exists: await exists(root.path), skills: skills.length, note: root.note });
    for (const s of skills) { const g = seen.get(s.id) || []; g.push({ ...s, shared: !!root.shared }); seen.set(s.id, g); }
    const bench = await benchManifest(root.path);
    if (bench) recorded.push({ manifestRoot: root.path, bench });
  }
  const merged = new Map(); for (const [id, copies] of seen) merged.set(id, mergeCopies(copies));
  const installs = [];
  const taken = new Set();
  // Several roots may carry the same Bench manifest (a shared root and a per-agent root).
  // One manifest set of skills is one Install; later manifests only add skills not yet taken.
  for (const r of recorded) {
    if (r.bench) {
      const skills = r.bench.skills.map((id) => merged.get(id)).filter((s) => s && !taken.has(s.id));
      if (!skills.length) { const prior = installs.find((i) => i.kind === "recorded" && i.name === "Bench install"); if (prior) prior.manifests = [...(prior.manifests || [prior.manifest]), tilde(path.join(r.manifestRoot, ".bench-install.json"))]; continue; }
      skills.forEach((s) => taken.add(s.id));
      installs.push({ id: "bench-" + crypto.createHash("sha1").update(skills.map((s) => s.id).join()).digest("hex").slice(0, 6), name: "Bench install", kind: "recorded", source, marks: union(skills), drift: skills.some((s) => s.drift), date: skills.map((s) => s.date).sort()[0], manifest: tilde(path.join(r.manifestRoot, ".bench-install.json")), version: r.bench.version, skills: skills.sort(byName) });
    } else installs.push(r);
  }
  const rest = [...merged.values()].filter((s) => !taken.has(s.id));
  installs.push(...clusterInferred(rest, source));
  return { installs: installs.sort(byInstall), roots: rootSummaries };
}

export async function scan({ project = process.cwd(), agent = "claude-code" } = {}) {
  const projectPath = path.resolve(project);
  const proj = await resolveSource(projectRoots(projectPath), "project");
  const dev = await resolveSource(deviceRoots(), "device");
  const plugins = await pluginInstalls();
  const pluginRoot = { path: tilde(path.join(HOME, ".claude", "plugins")), exists: plugins.length > 0, skills: plugins.reduce((a, p) => a + p.skills.length, 0), note: plugins.length + " plugin" + (plugins.length === 1 ? "" : "s") + " with skills" };
  const installs = [...proj.installs, ...dev.installs, ...plugins.sort(byInstall)];
  for (const i of installs) for (const s of i.skills) { if (s.dir) { s.path = tilde(s.dir); delete s.dir; } delete s.installedDay; delete s.rootDir; }
  return {
    project: path.basename(projectPath), projectPath: tilde(projectPath), realProjectPath: projectPath,
    scanned: new Date().toISOString(), agent, agentName: AGENTS[agent] || agent,
    installs, roots: [...proj.roots, ...dev.roots, pluginRoot]
  };
}

// Locate the skill a changed file belongs to. Returns { install, skill, rel } or null.
export function locate(survey, changedPath) {
  const real = fs.existsSync(changedPath) ? fs.realpathSync(changedPath) : changedPath;
  for (const i of survey.installs) for (const s of i.skills) {
    for (const base of [s.real, ...(s.copies || []).map((c) => c.replace(/^~/, HOME))]) {
      if (base && (real === base || real.startsWith(base + path.sep))) return { install: i, skill: s, rel: path.relative(base, real) || "SKILL.md" };
    }
  }
  return null;
}

export function isTextFile(name) { return TEXT_EXT.test(name) || /^[^.]+$/.test(path.basename(name)); }

if (import.meta.url === "file://" + process.argv[1]) {
  const i = process.argv.indexOf("--project");
  const survey = await scan({ project: i > -1 ? process.argv[i + 1] : process.cwd() });
  const compact = process.argv.includes("--compact");
  if (compact) for (const inst of survey.installs) for (const s of inst.skills) { delete s.md; delete s.frontmatter; }
  process.stdout.write(JSON.stringify(survey, null, compact ? 1 : 0) + "\n");
}
