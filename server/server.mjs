// Spellbook local server. Serves the built app, the Survey, skill files, a Brief queue for the
// agent, and live events for the tab. Node 20+, no dependencies.
//
//   node server/server.mjs [--project DIR] [--port N] [--agent claude-code|codex|cursor] [--no-open]
import http from "node:http";
import fs from "node:fs";
import fsp from "node:fs/promises";
import path from "node:path";
import os from "node:os";
import crypto from "node:crypto";
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";
import { scan, locate, isTextFile, AGENTS } from "./scan.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const REPO = path.resolve(here, "..");
const DIST = path.join(REPO, "app", "dist");
const DESIGN = path.join(REPO, "design");
const HOME = os.homedir();

function arg(name, def) { const i = process.argv.indexOf(name); return i > -1 ? process.argv[i + 1] : def; }
const project = path.resolve(arg("--project", process.cwd()));
const agent = arg("--agent", process.env.CLAUDECODE ? "claude-code" : process.env.CODEX_HOME || process.env.CODEX_SANDBOX ? "codex" : "claude-code");
const wantPort = Number(arg("--port", 0));
const noOpen = process.argv.includes("--no-open");

export function stateFile(projectPath) {
  const dir = path.join(os.tmpdir(), "spellbook");
  fs.mkdirSync(dir, { recursive: true });
  return path.join(dir, crypto.createHash("sha1").update(path.resolve(projectPath)).digest("hex").slice(0, 10) + ".json");
}

const MIME = { ".html": "text/html; charset=utf-8", ".js": "text/javascript; charset=utf-8", ".mjs": "text/javascript; charset=utf-8", ".css": "text/css; charset=utf-8", ".json": "application/json; charset=utf-8", ".svg": "image/svg+xml", ".png": "image/png", ".ttf": "font/ttf", ".woff2": "font/woff2", ".woff": "font/woff", ".ico": "image/x-icon", ".map": "application/json", ".txt": "text/plain; charset=utf-8", ".md": "text/markdown; charset=utf-8" };

let survey = null;
const clients = new Set();          // SSE responses
const briefs = [];                  // { id, at, delivered, ... }
const waiters = [];                 // long-poll responses from wait-brief
let briefLog = null;

function send(res, code, body, type = "application/json; charset=utf-8", extra = {}) {
  const data = typeof body === "string" || Buffer.isBuffer(body) ? body : JSON.stringify(body);
  res.writeHead(code, { "content-type": type, "cache-control": "no-store", ...extra });
  res.end(data);
}
function broadcast(event, data) {
  const msg = "event: " + event + "\ndata: " + JSON.stringify(data) + "\n\n";
  for (const c of clients) { try { c.write(msg); } catch { clients.delete(c); } }
}
async function readBody(req) {
  return new Promise((resolve, reject) => { let s = ""; req.on("data", (c) => { s += c; if (s.length > 2e6) reject(new Error("too large")); }); req.on("end", () => resolve(s)); req.on("error", reject); });
}

async function rescan() {
  survey = await scan({ project, agent });
  survey.port = server.address() ? server.address().port : wantPort;
  watchRoots();
  broadcast("survey", { scanned: survey.scanned, installs: survey.installs.length });
  return survey;
}

// ---- file watching: a change inside a skill folder tells the tab to reload that file.
const watchers = new Map();
let pending = new Map();
function watchRoots() {
  const roots = new Set();
  for (const i of survey.installs) for (const s of i.skills) { roots.add(path.dirname(s.real)); }
  for (const r of roots) {
    if (watchers.has(r) || !fs.existsSync(r)) continue;
    try {
      const w = fs.watch(r, { recursive: true }, (ev, name) => {
        if (!name) return;
        const full = path.join(r, name.toString());
        pending.set(full, Date.now());
        clearTimeout(watchRoots.timer);
        watchRoots.timer = setTimeout(flushChanges, 250);
      });
      w.on("error", () => { watchers.delete(r); });
      watchers.set(r, w);
    } catch { /* recursive watch unsupported here; polling would go in a later pass */ }
  }
}
async function flushChanges() {
  const changed = [...pending.keys()]; pending = new Map();
  for (const full of changed) {
    const hit = locate(survey, full); if (!hit) continue;
    const rel = hit.rel === "." ? "SKILL.md" : hit.rel;
    if (rel === "SKILL.md") { try { hit.skill.md = await fsp.readFile(path.join(hit.skill.real, "SKILL.md"), "utf8"); hit.skill.lines = hit.skill.md.split(/\r?\n/).length; } catch { } }
    broadcast("changed", { installId: hit.install.id, skillId: hit.skill.id, file: rel, at: new Date().toISOString() });
  }
}

// ---- Briefs
function pushBrief(body) {
  const id = crypto.randomBytes(4).toString("hex");
  const brief = { id, at: new Date().toISOString(), delivered: false, ...body };
  briefs.push(brief);
  if (briefLog) fs.appendFileSync(briefLog, JSON.stringify(brief) + "\n");
  const w = waiters.shift();
  if (w) { brief.delivered = true; send(w, 200, brief); broadcast("brief-taken", { id, at: new Date().toISOString() }); }
  return brief;
}

async function handleApi(req, res, url) {
  const p = url.pathname;
  if (p === "/api/health") return send(res, 200, { ok: true, agent, project: survey.projectPath, port: survey.port, pid: process.pid });
  if (p === "/api/survey") return send(res, 200, survey);
  if (p === "/api/rescan" && req.method === "POST") { await rescan(); return send(res, 200, { scanned: survey.scanned }); }
  if (p === "/api/file") {
    const installId = url.searchParams.get("install"), skillId = url.searchParams.get("skill"), rel = url.searchParams.get("path") || "SKILL.md";
    const inst = survey.installs.find((i) => i.id === installId); const skill = inst && inst.skills.find((s) => s.id === skillId);
    if (!skill) return send(res, 404, { error: "unknown skill" });
    const base = skill.real, full = path.resolve(base, rel);
    if (!full.startsWith(base + path.sep) && full !== base) return send(res, 400, { error: "path escapes the skill folder" });
    if (!isTextFile(full)) return send(res, 415, { error: "not a text file" });
    try { const st = await fsp.stat(full); if (st.size > 2e6) return send(res, 413, { error: "too large" }); return send(res, 200, { path: rel, text: await fsp.readFile(full, "utf8"), size: st.size, mtime: st.mtime.toISOString() }); }
    catch { return send(res, 404, { error: "not found" }); }
  }
  if (p === "/api/briefs" && req.method === "POST") {
    let body; try { body = JSON.parse(await readBody(req)); } catch { return send(res, 400, { error: "bad json" }); }
    if (!body || typeof body.text !== "string") return send(res, 400, { error: "a Brief needs text" });
    const brief = pushBrief({ installId: body.installId, skillId: body.skillId, file: body.file, path: body.path, notes: body.notes || [], text: body.text });
    return send(res, 201, { id: brief.id, at: brief.at, delivered: brief.delivered });
  }
  if (p === "/api/briefs" && req.method === "GET") return send(res, 200, briefs.map((b) => ({ ...b, text: b.text.slice(0, 200) })));
  if (p === "/api/briefs/next") {
    const next = briefs.find((b) => !b.delivered);
    if (next) { next.delivered = true; broadcast("brief-taken", { id: next.id, at: new Date().toISOString() }); return send(res, 200, next); }
    if (url.searchParams.get("wait") !== "1") return send(res, 204, "");
    waiters.push(res);
    const t = setTimeout(() => { const k = waiters.indexOf(res); if (k > -1) { waiters.splice(k, 1); send(res, 204, ""); } }, 25000);
    req.on("close", () => { clearTimeout(t); const k = waiters.indexOf(res); if (k > -1) waiters.splice(k, 1); });
    return;
  }
  if (p === "/api/events") {
    res.writeHead(200, { "content-type": "text/event-stream", "cache-control": "no-store", connection: "keep-alive" });
    res.write("event: hello\ndata: " + JSON.stringify({ agent, agentName: AGENTS[agent] || agent, port: survey.port, scanned: survey.scanned }) + "\n\n");
    clients.add(res);
    const ping = setInterval(() => { try { res.write(": ping\n\n"); } catch { } }, 20000);
    req.on("close", () => { clearInterval(ping); clients.delete(res); });
    return;
  }
  if (p === "/api/shutdown" && req.method === "POST") { send(res, 200, { bye: true }); setTimeout(() => process.exit(0), 50); return; }
  return send(res, 404, { error: "no such route" });
}

async function serveStatic(res, root, rel) {
  const full = path.resolve(root, "." + rel);
  if (!full.startsWith(root)) return send(res, 400, "bad path", "text/plain");
  try {
    const st = await fsp.stat(full);
    if (st.isDirectory()) return serveStatic(res, root, path.posix.join(rel, "index.html"));
    const ext = path.extname(full).toLowerCase();
    res.writeHead(200, { "content-type": MIME[ext] || "application/octet-stream", "cache-control": ext === ".html" ? "no-store" : "public, max-age=3600" });
    fs.createReadStream(full).pipe(res);
  } catch { return null; }
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, "http://127.0.0.1");
  try {
    if (url.pathname.startsWith("/api/")) return await handleApi(req, res, url);
    if (url.pathname.startsWith("/design/")) { const r = await serveStatic(res, DESIGN, url.pathname.slice("/design".length)); if (r === null) send(res, 404, "not found", "text/plain"); return; }
    if (!fs.existsSync(path.join(DIST, "index.html"))) return send(res, 503, "<title>Spellbook</title><p style='font:14px system-ui;padding:24px'>The app is not built yet. Run <code>npm run build</code> in the Spellbook repo.</p>", "text/html; charset=utf-8");
    const r = await serveStatic(res, DIST, url.pathname);
    if (r === null) await serveStatic(res, DIST, "/index.html");
  } catch (e) { send(res, 500, { error: String(e && e.message || e) }); }
});

server.listen(wantPort, "127.0.0.1", async () => {
  const port = server.address().port;
  const url = "http://127.0.0.1:" + port + "/";
  const state = stateFile(project);
  briefLog = path.join(path.dirname(state), path.basename(state, ".json") + ".briefs.jsonl");
  await rescan();
  fs.writeFileSync(state, JSON.stringify({ url, port, pid: process.pid, project, agent, started: new Date().toISOString() }));
  const cleanup = () => { try { fs.unlinkSync(state); } catch { } };
  process.on("exit", cleanup); process.on("SIGINT", () => process.exit(0)); process.on("SIGTERM", () => process.exit(0));
  process.stdout.write(url + "\n");
  if (!noOpen) {
    const cmd = process.platform === "darwin" ? ["open", url] : process.platform === "win32" ? ["cmd", "/c", "start", "", url] : ["xdg-open", url];
    try { spawn(cmd[0], cmd.slice(1), { stdio: "ignore", detached: true }).unref(); } catch { }
  }
});
