#!/usr/bin/env node
// Spellbook skill launcher. Commands: start, wait-brief, status, rescan, stop.
// Finds the repo through this file's real path, so it works when the skill folder is a symlink.
import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import crypto from "node:crypto";
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";

const here = path.dirname(fs.realpathSync(fileURLToPath(import.meta.url)));
const REPO = path.resolve(here, "..", "..", "..");
const SERVER = path.join(REPO, "server", "server.mjs");
const cmd = process.argv[2] || "start";
function arg(name, def) { const i = process.argv.indexOf(name); return i > -1 ? process.argv[i + 1] : def; }
const project = path.resolve(arg("--project", process.cwd()));
function stateFile() { return path.join(os.tmpdir(), "spellbook", crypto.createHash("sha1").update(project).digest("hex").slice(0, 10) + ".json"); }
function readState() { try { return JSON.parse(fs.readFileSync(stateFile(), "utf8")); } catch { return null; } }
async function alive(st) { if (!st) return false; try { const r = await fetch(st.url + "api/health"); return r.ok; } catch { return false; } }
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

if (!fs.existsSync(SERVER)) { console.error("Spellbook server not found at " + SERVER + ". Install the skill as a symlink into the Spellbook repo, or pass --repo."); process.exit(2); }

if (cmd === "start") {
  let st = readState();
  if (!(await alive(st))) {
    const args = [SERVER, "--project", project];
    const agent = arg("--agent", null); if (agent) args.push("--agent", agent);
    if (process.argv.includes("--no-open")) args.push("--no-open");
    const child = spawn(process.execPath, args, { detached: true, stdio: "ignore", cwd: REPO });
    child.unref();
    for (let i = 0; i < 60; i++) { await sleep(150); st = readState(); if (await alive(st)) break; }
    if (!(await alive(st))) { console.error("Spellbook did not start. Run: node " + SERVER + " --project " + project); process.exit(1); }
    console.log("Spellbook is open at " + st.url + " (pid " + st.pid + ").");
  } else {
    console.log("Spellbook is already running at " + st.url + ".");
    if (!process.argv.includes("--no-open")) { const c = process.platform === "darwin" ? ["open", st.url] : process.platform === "win32" ? ["cmd", "/c", "start", "", st.url] : ["xdg-open", st.url]; try { spawn(c[0], c.slice(1), { stdio: "ignore", detached: true }).unref(); } catch { } }
  }
  console.log("Now wait for Briefs with: node " + path.relative(process.cwd(), fileURLToPath(import.meta.url)) + " wait-brief");
} else if (cmd === "wait-brief") {
  const st = readState(); if (!(await alive(st))) { console.error("Spellbook is not running for " + project + ". Run start first."); process.exit(2); }
  const timeoutS = Number(arg("--timeout", 600)); const until = Date.now() + timeoutS * 1000;
  while (Date.now() < until) {
    let r; try { r = await fetch(st.url + "api/briefs/next?wait=1"); } catch { console.error("Lost the server."); process.exit(2); }
    if (r.status === 200) {
      const b = await r.json();
      console.log("Brief " + b.id + " received at " + b.at + " for " + (b.path || "") + (b.file || "") + "\n");
      console.log(b.text);
      console.log("\nApply the change with your own tools, then tell the user what you did. The tab reloads the file when it changes on disk.");
      process.exit(0);
    }
  }
  console.log("No Brief within " + timeoutS + " seconds. The tab is still open; run wait-brief again when the user is ready, or stop.");
  process.exit(3);
} else if (cmd === "status") {
  const st = readState(); console.log((await alive(st)) ? "running at " + st.url + " (pid " + st.pid + ", agent " + st.agent + ")" : "not running for " + project);
} else if (cmd === "rescan") {
  const st = readState(); if (!(await alive(st))) { console.error("not running"); process.exit(2); }
  const r = await fetch(st.url + "api/rescan", { method: "POST" }); console.log(await r.text());
} else if (cmd === "stop") {
  const st = readState(); if (!(await alive(st))) { console.log("not running"); process.exit(0); }
  await fetch(st.url + "api/shutdown", { method: "POST" }).catch(() => { }); console.log("stopped");
} else { console.error("usage: spellbook.mjs start|wait-brief|status|rescan|stop [--project DIR] [--agent NAME] [--no-open] [--timeout S]"); process.exit(2); }
