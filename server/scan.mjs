// Spellbook scanner. Enumerates skill roots for a project and the device, resolves
// Installs by Origin evidence, Agent Marks and Drift, and returns the Survey.
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

// Keep the record inventory even when a present record cannot be decoded.
async function readRecord(file, kind, records, count, optional = false) {
  if (optional && !(await exists(file))) return null;
  let data;
  try { data = JSON.parse(await fsp.readFile(file, "utf8")); } catch {
    records.push({ path: tilde(file), kind, entries: 0, read: false });
    return null;
  }
  records.push({ path: tilde(file), kind, entries: count(data), read: true });
  return data;
}

function githubSlug(url = "") {
  return /github\.com[:/]([^/\s]+\/[^/#?\s]+?)(?:\.git)?(?:[/#?]|$)/i.exec(url)?.[1];
}
function dateFromRecord(skill, record) {
  for (const [key, display] of [["installedAt", "installedDay"], ["updatedAt", "date"]]) {
    if (record[key] && Number.isFinite(Date.parse(record[key]))) {
      skill[key] = record[key]; skill[display] = record[key].slice(0, 10);
    }
  }
}
async function pluginSkills(records) {
  const manifest = path.join(HOME, ".claude", "plugins", "installed_plugins.json");
  const data = await readRecord(manifest, "plugin manifest", records, (d) => Object.keys(d.plugins || {}).length);
  const marketplaces = await readRecord(path.join(HOME, ".claude", "plugins", "known_marketplaces.json"), "plugin marketplaces", records, (d) => Object.keys(d).length);
  const out = [];
  for (const [key, entries] of Object.entries(data?.plugins || {})) {
    const name = key.split("@")[0], marketplace = key.slice(name.length + 1);
    const slug = marketplaces?.[marketplace]?.source?.repo;
    for (const entry of Array.isArray(entries) ? entries : [entries]) {
      if (!entry?.installPath) continue;
      const origin = {
        kind: "plugin", grade: "recorded", name, slug,
        url: slug ? "https://github.com/" + slug : undefined,
        path: "plugins/" + name, ref: entry.gitCommitSha, version: entry.version,
        record: tilde(manifest), evidence: ["recorded by the plugin manifest: " + key]
      };
      async function find(dir, depth) {
        if (depth > 4) return;
        if (await exists(path.join(dir, "SKILL.md"))) {
          const skill = await readSkill(dir, { path: entry.installPath, marks: ["claude-code"] });
          if (skill) {
            dateFromRecord(skill, { installedAt: entry.installedAt, updatedAt: entry.lastUpdated });
            out.push({ ...skill, origin });
          }
          return;
        }
        for (const file of await fsp.readdir(dir, { withFileTypes: true }).catch(() => [])) {
          if (file.isDirectory() && !file.name.startsWith(".") && file.name !== "node_modules") await find(path.join(dir, file.name), depth + 1);
        }
      }
      await find(path.join(entry.installPath, "skills"), 0);
    }
  }
  return out;
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

function looseInstall(s, source) {
  return { id: "loose-" + s.id, name: s.name, kind: "loose", source, origin: s.origin,
    marks: s.marks, drift: !!s.drift, date: s.date, skills: [s] };
}
function union(skills) { const m = new Set(); skills.forEach((s) => s.marks.forEach((x) => m.add(x))); return [...m].sort(); }
const byName = (a, b) => a.name.localeCompare(b.name);
function originKey(origin) { return origin.kind + "|" + (origin.slug || origin.url || origin.name) + (origin.kind === "plugin" ? "|" + origin.path : ""); }
function groupOrigins(skills, source) {
  const groups = new Map(), installs = [];
  for (const skill of skills) {
    if (!["recorded", "matched"].includes(skill.origin.grade)) { installs.push(looseInstall(skill, source)); continue; }
    const key = originKey(skill.origin);
    const group = groups.get(key) || []; group.push(skill); groups.set(key, group);
  }
  for (const [key, skills] of groups) {
    skills.sort(byName);
    const representative = skills.find((s) => s.origin.grade === "recorded") || skills[0];
    const origin = { ...representative.origin, evidence: [...new Set(skills.flatMap((s) => s.origin.evidence))] };
    // A folder hash and skillPath describe one skill, not every member of its Install.
    for (const field of ["path", "ref"]) if (skills.some((s) => s.origin[field] !== origin[field])) delete origin[field];
    installs.push({ id: "orig-" + crypto.createHash("sha1").update(key).digest("hex").slice(0, 8),
      name: skills.length === 1 ? skills[0].name : origin.name, kind: "install", source, origin,
      marks: union(skills), drift: skills.some((s) => s.drift), date: skills.map((s) => s.installedDay || s.date).sort()[0],
      updated: skills.map((s) => s.date).sort().at(-1), version: origin.version,
      quiet: skills.every((s) => s.system), skills });
  }
  return installs.sort(byName);
}

async function collectSource(roots, source, records, lock) {
  const seen = new Map(), summaries = [];
  for (const root of roots) {
    const skills = await skillsInRoot(root);
    summaries.push({ path: tilde(root.path), exists: await exists(root.path), skills: skills.length, note: root.note });
    const manifest = path.join(root.path, ".bench-install.json");
    const bench = await readRecord(manifest, "pack manifest", records, (d) => Object.keys(d.skills || {}).length, true);
    for (const skill of skills) {
      // The CLI installs into several agent roots. Resolve only skills on disk;
      // plugin entries and a different project never inherit a device lock entry.
      const entry = source === "device" && !root.system ? lock?.skills?.[skill.id] : null;
      if (entry?.source) {
        skill.origin = { kind: "github", grade: "recorded", name: entry.source, slug: entry.source,
          url: entry.sourceUrl || "https://github.com/" + entry.source,
          path: entry.skillPath ? path.posix.dirname(entry.skillPath) : undefined, ref: entry.skillFolderHash,
          record: tilde(path.join(HOME, ".agents", ".skill-lock.json")), evidence: ["recorded by the Agent Skills CLI lockfile"] };
        dateFromRecord(skill, entry);
      } else if (bench?.skills && Object.hasOwn(bench.skills, skill.id)) {
        skill.origin = { kind: "pack", grade: "recorded", name: "Bench", version: bench.version,
          record: tilde(manifest), evidence: ["recorded by the Bench pack manifest " + tilde(manifest)] };
      } else if (root.system) {
        skill.system = true;
        skill.origin = { kind: "github", grade: "recorded", name: "Codex system skills", slug: "openai/skills",
          url: "https://github.com/openai/skills", path: "skills/.system/" + skill.id,
          evidence: ["recorded by the Codex system root " + tilde(root.path)] };
      }
      const copies = seen.get(skill.id) || [];
      copies.push({ ...skill, shared: !!root.shared }); seen.set(skill.id, copies);
    }
  }
  const skills = [...seen.values()].map((copies) => {
    const skill = mergeCopies(copies);
    // Resolver order wins even if mergeCopies prefers a different root for reading.
    const resolved = copies.filter((c) => c.origin).sort((a, b) =>
      ["github", "plugin", "pack"].indexOf(a.origin.kind) - ["github", "plugin", "pack"].indexOf(b.origin.kind))[0];
    if (resolved) {
      skill.origin = { ...resolved.origin, evidence: [...new Set(copies.filter((c) => c.origin && originKey(c.origin) === originKey(resolved.origin)).flatMap((c) => c.origin.evidence))] };
      dateFromRecord(skill, resolved);
    }
    return skill;
  });
  return { source, skills, roots: summaries };
}

// No subprocesses: support both .git directories and linked working copies.
async function readRepository(repo) {
  repo = await realpath(repo);
  let gitDir = path.join(repo, ".git");
  try {
    if (!(await fsp.stat(gitDir)).isDirectory()) {
      const gitFile = await fsp.readFile(gitDir, "utf8");
      const target = /^gitdir:\s*(.+)$/m.exec(gitFile)?.[1];
      if (!target) return null;
      gitDir = path.resolve(repo, target.trim());
    }
    const common = await fsp.readFile(path.join(gitDir, "commondir"), "utf8").catch(() => "");
    const config = await fsp.readFile(path.join(common ? path.resolve(gitDir, common.trim()) : gitDir, "config"), "utf8").catch(() => "");
    const remote = /\[remote\s+"origin"\]([^\[]*)/.exec(config)?.[1];
    const url = /^\s*url\s*=\s*(.+)$/m.exec(remote || "")?.[1]?.trim();
    return { dir: repo, name: path.basename(repo), remote: url, slug: githubSlug(url) };
  } catch { return null; }
}
async function enclosingRepository(dir, cache) {
  if (cache.has(dir)) return cache.get(dir);
  const repo = await readRepository(dir);
  const result = repo || (path.dirname(dir) !== dir ? await enclosingRepository(path.dirname(dir), cache) : null);
  cache.set(dir, result); return result;
}
const skillRootPath = /(?:^|[/\\])\.(?:agents|claude|codex|gemini|cursor)[/\\]skills(?:[/\\]|$)/;
async function repositoryMatches(repos, skills) {
  const matches = new Map(skills.map((s) => [s, []]));
  for (const repo of repos) {
    const pending = new Set(skills.filter((s) => s.description));
    async function walk(dir) {
      if (!pending.size || skillRootPath.test(dir)) return;
      for (const entry of await fsp.readdir(dir, { withFileTypes: true }).catch(() => [])) {
        if (["node_modules", ".git", "dist"].includes(entry.name)) continue;
        const file = path.join(dir, entry.name);
        if (skillRootPath.test(file)) continue;
        if (entry.isDirectory()) {
          // Nested working copies are separate candidates, never evidence for their parent.
          if (await exists(path.join(file, ".git"))) continue;
          await walk(file);
        } else if (entry.isFile() && isTextFile(entry.name)) {
          const stat = await fsp.stat(file).catch(() => null);
          if (!stat || stat.size > 2 * 1024 * 1024) continue;
          const text = await fsp.readFile(file, "utf8").catch(() => "");
          if (text.includes("\0")) continue;
          for (const skill of pending) if (text.includes(skill.description)) {
            matches.get(skill).push({ repo, file: path.relative(repo.dir, file) }); pending.delete(skill);
          }
        }
      }
    }
    await walk(repo.dir);
  }
  return matches;
}
function localOrigin(repo, evidence) {
  return { kind: "local", grade: "matched", name: repo.name, url: tilde(repo.dir), slug: repo.slug,
    evidence: [evidence, ...(repo.remote ? ["repository remote is " + repo.remote] : [])] };
}
async function packageInfo(file) {
  const match = /^(.*[/\\]lib[/\\]node_modules[/\\](?:@[^/\\]+[/\\])?[^/\\]+)(?:[/\\]|$)/.exec(file);
  if (!match) return null;
  const manifest = path.join(match[1], "package.json");
  try { const pkg = JSON.parse(await fsp.readFile(manifest, "utf8")); return { ...pkg, manifest }; } catch { return null; }
}
async function cliEvidence(skill, cache) {
  // Only commands actually named in the skill are considered; never execute them.
  const snippets = [...skill.md.matchAll(/`([^`]+)`/g)].map((m) => m[1]);
  const names = [...new Set(snippets.flatMap((snippet) => snippet.split(/\r?\n/).map((line) =>
    /^\s*(?:\$\s+)?([a-z][a-z0-9-]{1,60})(?:\s+|$)/.exec(line)?.[1]).filter(Boolean)))];
  // A command explicitly shipped under a skill path is not the unrelated PATH binary.
  const localCommands = new Set([...skill.md.matchAll(/[/\\]scripts[/\\]([a-z][a-z0-9-]*)/g)].map((m) => m[1]));
  const found = new Map();
  for (const name of names) {
    if (localCommands.has(name)) continue;
    if (!cache.has(name)) {
      let pkg = null;
      for (const bin of (process.env.PATH || "").split(path.delimiter).filter(Boolean)) {
        const file = path.join(bin, name);
        try {
          await fsp.access(file, fs.constants.X_OK);
          if (!(await fsp.stat(file)).isFile()) continue;
          pkg = await packageInfo(await realpath(file)); break;
        } catch { /* command is not in this PATH directory */ }
      }
      cache.set(name, pkg);
    }
    const pkg = cache.get(name);
    if (pkg?.repository) found.set(pkg.name, { ...pkg, command: name });
  }
  return [...found.values()];
}
async function packageCaches() {
  const found = new Map();
  const root = path.join(HOME, ".npm", "_npx");
  for (const cache of await fsp.readdir(root, { withFileTypes: true }).catch(() => [])) {
    if (!cache.isDirectory()) continue;
    const modules = path.join(root, cache.name, "node_modules");
    async function inspect(dir, scoped = false) {
      for (const entry of await fsp.readdir(dir, { withFileTypes: true }).catch(() => [])) {
        if (!entry.isDirectory() || entry.name.startsWith(".")) continue;
        const folder = path.join(dir, entry.name);
        if (!scoped && entry.name.startsWith("@")) { await inspect(folder, true); continue; }
        try {
          const pkg = JSON.parse(await fsp.readFile(path.join(folder, "package.json"), "utf8"));
          const items = found.get(pkg.name) || []; items.push(pkg); found.set(pkg.name, items);
        } catch { /* incomplete cache */ }
      }
    }
    await inspect(modules);
  }
  return found;
}
function packageUrl(pkg) { return typeof pkg.repository === "string" ? pkg.repository : pkg.repository?.url; }
async function resolveOrigins(skills) {
  const repoCache = new Map(), repositories = new Map();
  for (const skill of skills) {
    const repo = await enclosingRepository(skill.real, repoCache);
    if (repo) {
      repositories.set(repo.dir, repo);
      if (!skill.origin) skill.origin = localOrigin(repo, "matched " + tilde(skill.dir) + " to " + tilde(repo.dir) + (skill.dir !== skill.real ? " by symlink" : " by its repository location"));
    }
  }
  const parents = new Set([path.join(HOME, "Code"), path.join(HOME, "Developer"), ...[...repositories.keys()].map((dir) => path.dirname(dir))]);
  for (const parent of parents) for (const entry of await fsp.readdir(parent, { withFileTypes: true }).catch(() => [])) {
    if (!entry.isDirectory() || entry.name.startsWith(".")) continue;
    const dir = path.join(parent, entry.name), repo = await readRepository(dir);
    if (repo) repositories.set(repo.dir, repo);
  }
  // Bench keeps its Recorded grade; the text match adds the otherwise absent repository.
  const unresolved = skills.filter((s) => !s.origin || s.origin.kind === "pack");
  const matches = await repositoryMatches([...repositories.values()].sort((a, b) => a.dir.localeCompare(b.dir)), unresolved);
  const commands = new Map();
  let caches;
  for (const skill of skills) {
    const hits = (matches.get(skill) || []).filter((hit) => hit.repo.remote);
    // Ambiguous text matches never choose an arbitrary repository.
    const hit = hits.length === 1 ? hits[0] : null;
    if (hit) {
      const evidence = "matched " + tilde(hit.repo.dir) + ": description of " + skill.id + " found in " + hit.file;
      if (skill.origin?.kind === "pack") {
        skill.origin = { ...skill.origin, slug: hit.repo.slug, url: tilde(hit.repo.dir), evidence: [...skill.origin.evidence, evidence, "repository remote is " + hit.repo.remote] };
      } else skill.origin = localOrigin(hit.repo, evidence);
    }
    if (!skill.origin || skill.origin.grade === "matched") for (const pkg of await cliEvidence(skill, commands)) {
      const url = packageUrl(pkg), slug = githubSlug(url);
      if (!slug) continue;
      const evidence = "command " + pkg.command + " on PATH resolves to " + pkg.name + "@" + pkg.version + " (" + tilde(pkg.manifest) + ")";
      if (skill.origin) {
        if (skill.origin.slug === slug) skill.origin.evidence.push(evidence);
      } else {
        caches ||= await packageCaches();
        const corroboration = (caches.get(pkg.name) || []).find((cached) => githubSlug(packageUrl(cached)) === slug);
        skill.origin = { kind: "github", grade: corroboration ? "matched" : "hinted", name: slug, slug,
          url: "https://github.com/" + slug, version: pkg.version, evidence: [evidence,
            ...(corroboration ? ["npm package cache also records " + pkg.name + " with repository " + slug] : [])] };
      }
    }
    if (skill.origin && ["recorded", "matched"].includes(skill.origin.grade)) {
      if (!skill.origin.version && skill.frontmatter.version) skill.origin.version = skill.frontmatter.version;
      continue;
    }
    const readme = await fsp.readFile(path.join(skill.dir, "README.md"), "utf8").catch(() => "");
    const text = skill.md + "\n" + readme;
    const github = /https?:\/\/github\.com\/[^\s<>()\]`"']+/.exec(text)?.[0];
    const slug = githubSlug(github);
    if (slug) {
      const evidence = "skill text links to " + github;
      if (skill.origin) skill.origin.evidence.push(evidence);
      else skill.origin = { kind: "github", grade: "hinted", name: slug, slug, url: "https://github.com/" + slug, evidence: [evidence] };
    }
    const release = /https?:\/\/releases\.([^/\s]+)\/install\.sh/.exec(text);
    const appName = skill.id.replace(/-browser$/, "").replace(/-/g, " ");
    const app = (await fsp.readdir("/Applications").catch(() => [])).find((name) => name.replace(/\.app$/i, "").toLowerCase() === appName.toLowerCase());
    if (release || app) {
      const name = app ? app.replace(/\.app$/i, "") : release[1].split(".")[0].replace(/^./, (c) => c.toUpperCase());
      const evidence = [...(release ? ["skill text links to " + release[0]] : []), ...(app ? ["matching app exists at /Applications/" + app] : [])];
      if (skill.origin) skill.origin.evidence.push(...evidence);
      else skill.origin = { kind: "app", grade: "hinted", name, url: release?.[0], evidence };
    }
    skill.origin ||= { kind: "unknown", grade: "unknown", name: "unknown", evidence: ["no recorded or matched Origin found"] };
    if (skill.frontmatter.version) skill.origin.version = skill.frontmatter.version;
    if (skill.frontmatter.license) skill.origin.evidence.push("skill declares license " + skill.frontmatter.license);
  }
  // A corroborating repository belongs to the recorded pack, including members whose
  // descriptions have changed since installation. It must not split that pack.
  const packs = new Map();
  for (const skill of skills.filter((s) => s.origin.kind === "pack" && s.origin.url)) {
    const origins = packs.get(skill.origin.name) || new Map();
    origins.set(skill.origin.url, skill.origin); packs.set(skill.origin.name, origins);
  }
  for (const skill of skills.filter((s) => s.origin.kind === "pack" && !s.origin.url)) {
    const origins = packs.get(skill.origin.name);
    if (origins?.size === 1) {
      const matched = [...origins.values()][0];
      skill.origin = { ...skill.origin, slug: matched.slug, url: matched.url,
        evidence: [...new Set([...skill.origin.evidence, ...matched.evidence])] };
    }
  }
}

export async function scan({ project = process.cwd(), agent = "claude-code" } = {}) {
  const projectPath = path.resolve(project), records = [];
  const lock = await readRecord(path.join(HOME, ".agents", ".skill-lock.json"), "Agent Skills CLI lockfile", records, (d) => Object.keys(d.skills || {}).length);
  const proj = await collectSource(projectRoots(projectPath), "project", records, lock);
  const dev = await collectSource(deviceRoots(), "device", records, lock);
  const plugins = await pluginSkills(records);
  // Plugin identity is separate from ordinary roots; copies within a plugin still merge.
  const pluginCopies = new Map();
  for (const skill of plugins) { const key = originKey(skill.origin) + "|" + skill.id; const copies = pluginCopies.get(key) || []; copies.push(skill); pluginCopies.set(key, copies); }
  dev.skills.push(...[...pluginCopies.values()].map(mergeCopies));
  await resolveOrigins([...proj.skills, ...dev.skills]);
  const pluginRoot = { path: tilde(path.join(HOME, ".claude", "plugins")), exists: await exists(path.join(HOME, ".claude", "plugins")), skills: plugins.length, note: new Set(plugins.map((s) => originKey(s.origin))).size + " plugins with skills" };
  const installs = [...groupOrigins(proj.skills, "project"), ...groupOrigins(dev.skills, "device")];
  for (const install of installs) for (const skill of install.skills) {
    if (skill.dir) { skill.path = tilde(skill.dir); delete skill.dir; }
    delete skill.installedDay; delete skill.rootDir; delete skill.system;
  }
  return {
    project: path.basename(projectPath), projectPath: tilde(projectPath), realProjectPath: projectPath,
    scanned: new Date().toISOString(), agent, agentName: AGENTS[agent] || agent,
    installs, roots: [...proj.roots, ...dev.roots, pluginRoot], records
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
