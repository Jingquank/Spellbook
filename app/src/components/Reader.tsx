import { useEffect, useMemo, useRef, useState } from "react";
import Markdown from "react-markdown";
import remarkGfm from "remark-gfm";
import { Menu } from "@base-ui/react/menu";
import { useTheme } from "next-themes";
import { toast } from "sonner";
import { create } from "zustand";
import { getFile, postBrief } from "../api";
import { openInEditorBrief, sendAgentBrief } from "../brief";
import { noteKey, useNotes, useSurvey, useUI } from "../store";
import type { Install, Note, Skill } from "../types";
import { Icon } from "../icons";
import { Thumb } from "../thumbs";
import { Badges, Marks } from "./InstallBits";

/* Sibling files are fetched on demand and re-fetched when the server says they changed. */
interface Files { versions: Record<string, number>; bump: (key: string) => void }
export const useFiles = create<Files>()((set) => ({ versions: {}, bump: (key) => set((s) => ({ versions: { ...s.versions, [key]: (s.versions[key] || 0) + 1 } })) }));

const uid = () => Math.random().toString(36).slice(2, 9);
const hm = () => { const d = new Date(); return String(d.getHours()).padStart(2, "0") + ":" + String(d.getMinutes()).padStart(2, "0"); };
function splitFrontmatter(md: string) {
  const m = /^---\r?\n([\s\S]*?)\r?\n---\r?\n?/.exec(md || ""); if (!m) return { fm: {} as Record<string, string>, body: md || "" };
  const fm: Record<string, string> = {}; m[1].split(/\r?\n/).forEach((l) => { const mm = /^(\w[\w-]*):\s*(.*)$/.exec(l); if (mm) fm[mm[1]] = mm[2].replace(/^["']|["']$/g, ""); });
  return { fm, body: md.slice(m[0].length) };
}
function lineOf(src: string, quote: string): string | null {
  if (!src || !quote) return null;
  const flat = src.replace(/[ \t]+/g, " "); let probe = quote.replace(/\s+/g, " ").slice(0, 40).trim();
  let idx = flat.indexOf(probe); if (idx < 0) { probe = probe.slice(0, 16); idx = flat.indexOf(probe); } if (idx < 0) return null;
  const start = flat.slice(0, idx).split("\n").length; const tail = quote.replace(/\s+/g, " ").slice(-24).trim(); const e = flat.indexOf(tail, idx);
  const end = e > -1 ? flat.slice(0, e).split("\n").length : start; return end > start ? start + "–" + end : String(start);
}
const supportsHighlight = typeof CSS !== "undefined" && "highlights" in CSS && typeof (window as unknown as { Highlight?: unknown }).Highlight === "function";
function paintHighlights(notes: Note[], active: string | null) {
  if (!supportsHighlight) return;
  const H = (window as unknown as { Highlight: new (...r: Range[]) => unknown }).Highlight;
  const all = notes.filter((n) => n.range).map((n) => n.range!);
  const act = notes.filter((n) => n.range && n.id === active).map((n) => n.range!);
  (CSS as unknown as { highlights: Map<string, unknown> }).highlights.set("sb-notes", new H(...all));
  (CSS as unknown as { highlights: Map<string, unknown> }).highlights.set("sb-note-active", new H(...act));
}

/* Find a quote in the rendered body and return a Range over it, tolerating whitespace differences. */
function anchorByQuote(body: HTMLElement, quote: string): Range | null {
  const want = quote.replace(/\s+/g, " ").trim(); if (!want) return null;
  const walker = document.createTreeWalker(body, NodeFilter.SHOW_TEXT);
  const nodes: Text[] = []; let full = ""; const starts: number[] = [];
  let n: Node | null;
  while ((n = walker.nextNode())) { const t = n as Text; nodes.push(t); starts.push(full.length); full += t.data; }
  const flat = full.replace(/\s+/g, " ");
  // map flat index back to raw index
  const raw: number[] = []; let prevSpace = false;
  for (let i = 0; i < full.length; i++) { const ws = /\s/.test(full[i]); if (ws && prevSpace) continue; raw.push(i); prevSpace = ws; }
  const idx = flat.indexOf(want); if (idx < 0) return null;
  const a = raw[idx], b = raw[Math.min(idx + want.length - 1, raw.length - 1)] + 1;
  const locate = (pos: number, end: boolean) => { for (let k = nodes.length - 1; k >= 0; k--) { if (starts[k] <= pos - (end ? 1 : 0) || (k === 0)) return { node: nodes[k], offset: Math.max(0, Math.min(pos - starts[k], nodes[k].data.length)) }; } return { node: nodes[0], offset: 0 }; };
  try { const r = document.createRange(); const s = locate(a, false), e = locate(b, true); r.setStart(s.node, s.offset); r.setEnd(e.node, e.offset); return r; } catch { return null; }
}

function Code({ className, children, inline }: { className?: string; children?: React.ReactNode; inline?: boolean }) {
  const { resolvedTheme } = useTheme();
  const text = String(children ?? "").replace(/\n$/, "");
  const lang = /language-(\w+)/.exec(className || "")?.[1];
  const isBlock = !inline && (lang || text.includes("\n"));
  const [html, setHtml] = useState<string | null>(null);
  useEffect(() => {
    if (!isBlock || !lang) { setHtml(null); return; }
    let live = true;
    import("shiki").then(({ codeToHtml }) => codeToHtml(text, { lang, theme: resolvedTheme === "dark" ? "github-dark" : "github-light" })).then((h) => { if (live) setHtml(h); }).catch(() => { if (live) setHtml(null); });
    return () => { live = false; };
  }, [text, lang, isBlock, resolvedTheme]);
  if (!isBlock) return <code className={className}>{children}</code>;
  if (html) return <div className="shiki-wrap" dangerouslySetInnerHTML={{ __html: html }} />;
  return <pre><code className={className}>{text}</code></pre>;
}

export function Reader({ install, skill, mode }: { install: Install; skill: Skill; mode: "main" }) {
  const agentName = useSurvey((s) => s.agentName);
  const tab = useUI((u) => u.tab), setTab = useUI((u) => u.setTab);
  const version = useFiles((f) => f.versions[install.id + "/" + skill.id + "#" + tab] || 0);
  const notesStore = useNotes();
  const key = noteKey(install.id, skill.id, tab);
  const notes = notesStore.notes[key] || [], hist = notesStore.hist[key] || [], status = notesStore.status[key] || null, sending = !!notesStore.sending[key];
  const [sibling, setSibling] = useState<{ text: string } | null>(null);
  const [reloading, setReloading] = useState(false);
  const [returning, setReturning] = useState(false);
  const [showBrief, setShowBrief] = useState(false);
  const bodyRef = useRef<HTMLElement>(null);
  const [pill, setPill] = useState<{ x: number; y: number } | null>(null);
  const pendingRange = useRef<Range | null>(null);
  const siblings = skill.files.filter((f) => /\.md$/i.test(f) && f !== "SKILL.md");
  useEffect(() => { if (!["SKILL.md", "Files", ...siblings].includes(tab)) setTab("SKILL.md"); }, [skill.id]);
  useEffect(() => {
    if (tab === "SKILL.md" || tab === "Files") { setSibling(null); return; }
    let live = true; setSibling(null);
    getFile(install.id, skill.id, tab).then((r) => { if (live) setSibling({ text: r.text }); }).catch((e) => toast.error("Could not read " + tab + ": " + e.message));
    return () => { live = false; };
  }, [install.id, skill.id, tab, version]);
  useEffect(() => {
    if (version <= 0) return;
    setReloading(true);
    const t = setTimeout(() => { setReloading(false); setReturning(true); }, 420);
    const t2 = setTimeout(() => setReturning(false), 700);
    return () => { clearTimeout(t); clearTimeout(t2); };
  }, [version, skill.md]);
  useEffect(() => {
    const body = bodyRef.current; if (!body) { paintHighlights(notes, notesStore.active); return; }
    const detached = notes.filter((n) => n.quote && (!n.range || !body.contains(n.range.startContainer)));
    if (!detached.length) { paintHighlights(notes, notesStore.active); return; }
    const found: Range[] = [];
    detached.forEach((n) => { const r = anchorByQuote(body, n.quote); if (r) { notesStore.update(key, n.id, { range: r }); found.push(r); } });
    paintHighlights(notes, notesStore.active);
    if (found.length && supportsHighlight) {
      const H = (window as unknown as { Highlight: new (...r: Range[]) => unknown }).Highlight;
      (CSS as unknown as { highlights: Map<string, unknown> }).highlights.set("sb-note-flash", new H(...found));
      const t = setTimeout(() => (CSS as unknown as { highlights: Map<string, unknown> }).highlights.delete("sb-note-flash"), 2000);
      return () => clearTimeout(t);
    }
  }, [notes, notesStore.active, skill.md, sibling]);

  const source = tab === "SKILL.md" ? skill.md || "" : sibling?.text || "";
  const parts = useMemo(() => {
    const p = splitFrontmatter(source);
    // A body that opens with the same title as the frontmatter name would print it twice; the head already shows it.
    const m = /^\s*#\s+(.+?)\s*\n/.exec(p.body);
    if (m && tab === "SKILL.md" && m[1].replace(/^\/+/, "").trim().toLowerCase() === skill.name.trim().toLowerCase()) p.body = p.body.slice(m[0].length);
    return p;
  }, [source, skill.name, tab]);
  const fmKeys = Object.keys(parts.fm).filter((k) => k !== "name" && k !== "description");
  const drafts = notes.filter((n) => n.state === "draft" && !n.editing);

  function briefText() {
    let out = "Brief for " + agentName + " — from Spellbook\nFile: " + skill.path + "/" + tab + "\n";
    drafts.forEach((n, idx) => { out += "\n" + (idx + 1) + ". " + (n.line ? "Lines " + n.line : n.quote ? "Range" : "Whole skill") + "\n"; if (n.quote) out += "   > " + n.quote.slice(0, 160) + (n.quote.length > 160 ? "…" : "") + "\n"; out += "   Note: " + (n.text || "") + "\n"; });
    return out;
  }
  function onMouseUp() {
    setTimeout(() => {
      const sel = window.getSelection(); const body = bodyRef.current;
      if (!sel || sel.isCollapsed || !body || !sel.toString().trim() || !body.contains(sel.anchorNode) || !body.contains(sel.focusNode)) { setPill(null); return; }
      const r = sel.getRangeAt(0).getBoundingClientRect(); if (!r.width && !r.height) { setPill(null); return; }
      pendingRange.current = sel.getRangeAt(0).cloneRange(); setPill({ x: r.left + r.width / 2, y: r.top - 8 });
    }, 0);
  }
  function addFromSelection() {
    const range = pendingRange.current; if (!range) return;
    const quote = range.toString().replace(/\s+/g, " ").trim(); if (!quote) return;
    window.getSelection()?.removeAllRanges(); setPill(null);
    notesStore.add(key, { id: uid(), file: tab, quote: quote.slice(0, 300), line: lineOf(source, quote), text: "", state: "draft", editing: true, range });
  }
  async function send() {
    if (!drafts.length) return;
    const text = briefText(); const at = hm();
    notesStore.setSending(key, true);
    try {
      await postBrief({ installId: install.id, skillId: skill.id, file: tab, path: skill.path + "/", notes: drafts.map((n) => ({ quote: n.quote, line: n.line, text: n.text })), text });
      notesStore.markSent(key, at); notesStore.setStatus(key, { text: "Sent to " + agentName + " at " + at + ". Waiting for the edit.", ok: false });
      setTimeout(() => { const st = useNotes.getState().status[key]; if (st && !st.ok && /Waiting/.test(st.text)) useNotes.getState().setStatus(key, { text: "No change on disk in 10 minutes. " + agentName + " may still be working; Copy Brief resends it.", ok: false }); }, 10 * 60 * 1000);
    } catch (e) { notesStore.setStatus(key, { text: "Could not reach the server. Copy the Brief and paste it to " + agentName + ".", ok: false }); toast.error("The local server did not answer."); }
    finally { notesStore.setSending(key, false); }
  }
  async function copyBrief() { try { await navigator.clipboard.writeText(briefText()); toast.success("Brief copied. Paste it into " + agentName + "."); } catch { toast("Select the preview and copy it by hand."); } }

  useEffect(() => { const hide = () => setPill(null); document.addEventListener("scroll", hide, true); document.addEventListener("mousedown", hide); return () => { document.removeEventListener("scroll", hide, true); document.removeEventListener("mousedown", hide); }; }, []);

  return <div className="rd">
    <div className="rd-bar">
      <span className="rd-kind">Skill</span><span className="dim">·</span><span className="mono">{tab}</span><span className="sp" />
      <button type="button" className="btn quiet" title="Copy path" onClick={() => { navigator.clipboard?.writeText(skill.path + "/" + tab); toast.success("Copied " + skill.path + "/" + tab); }}><Icon name="copy" size="sm" />Path</button>
      <Menu.Root><Menu.Trigger className="btn quiet icon" title="More" aria-label="More"><Icon name="more-horiz" size="sm" /></Menu.Trigger>
        <Menu.Portal><Menu.Positioner sideOffset={6} align="end"><Menu.Popup className="menu-pop">
          <Menu.Item className="menu-item" onClick={copyBrief}><Icon name="copy" size="sm" />Copy Brief</Menu.Item>
          <Menu.Item className="menu-item" onClick={() => { navigator.clipboard?.writeText(skill.path); toast.success("Copied " + skill.path); }}><Icon name="folder" size="sm" />Copy folder path</Menu.Item>
          <Menu.Item className="menu-item" onClick={() => void sendAgentBrief({ installId: install.id, skillId: skill.id, file: "SKILL.md", path: skill.path + "/", text: openInEditorBrief(install, skill, agentName), summary: "open " + skill.name + " in the editor" })}><Icon name="page" size="sm" />Ask {agentName} to open it in the editor</Menu.Item>
        </Menu.Popup></Menu.Positioner></Menu.Portal></Menu.Root>
    </div>
    <div className="rd-scroll">
      <div className="rd-head">
        <div className="rd-crumb"><Thumb install={install} size={24} /><span>{install.name}</span><Badges i={install} /><Marks marks={install.marks} /></div>
        <h1 className="rd-title">{skill.name}</h1>
        {skill.description && <p className="rd-desc">{skill.description}</p>}
        <div className="rd-meta"><span><b>{skill.path}/{tab}</b></span><span>{skill.lines} lines</span><span>{skill.files.length} file{skill.files.length === 1 ? "" : "s"}</span><span>updated {skill.date}</span></div>
      </div>
      <div className="rd-tabs" role="tablist" onKeyDown={(e) => { const tabs = ["SKILL.md", ...siblings, "Files"]; const k = tabs.indexOf(tab); if (e.key === "ArrowRight") { e.preventDefault(); setTab(tabs[(k + 1) % tabs.length]); } if (e.key === "ArrowLeft") { e.preventDefault(); setTab(tabs[(k - 1 + tabs.length) % tabs.length]); } }}>
        {["SKILL.md", ...siblings, "Files"].map((t) => <button key={t} type="button" role="tab" id={"tab-" + t} aria-controls="rd-panel" className="rd-tab" aria-selected={t === tab} tabIndex={t === tab ? 0 : -1} onClick={() => setTab(t)}>{t}{t === "Files" && <span className="c">{skill.files.length}</span>}</button>)}
      </div>
      <div className="rd-split">
        {tab === "Files" ? <div className="rd-body rd-files" id="rd-panel" role="tabpanel">{skill.files.map((f) => {
          const md = /\.md$/i.test(f), kind = md ? "markdown" : /\.(js|mjs|ts|jsx|tsx|py|sh|css|json|ya?ml|toml)$/i.test(f) ? "code" : /\.(png|jpe?g|svg|gif|woff2?|ttf|otf)$/i.test(f) ? "asset" : "text";
          return <div key={f} className={"f" + (md ? " md" : "")}><Icon name={f.includes("/") ? "folder" : "page"} size="sm" /><span>{f}</span><span className="k">{kind}</span></div>;
        })}</div>
        : <article ref={bodyRef} id="rd-panel" role="tabpanel" className={"rd-body" + (reloading ? " is-reloading" : "") + (returning ? " returning" : "")} onMouseUp={onMouseUp} onClick={(e) => { const a = (e.target as HTMLElement).closest("a"); if (a) { e.preventDefault(); toast("Link: " + a.getAttribute("href")); } }}>
          {tab !== "SKILL.md" && !sibling && <div className="rd-loading">Reading {tab}…</div>}
          {tab === "SKILL.md" && fmKeys.length > 0 && <div className="rd-fm">{fmKeys.map((k) => <div key={k}><b>{k}:</b> {parts.fm[k]}</div>)}</div>}
          <Markdown remarkPlugins={[remarkGfm]} components={{ pre: ({ children }) => <>{children}</>, code: Code as never }}>{parts.body}</Markdown>
        </article>}
        <aside className="rd-notes">
          <div className="rd-notes-head"><span>Notes<span className="tnum cnt">{notes.length ? " · " + notes.length : ""}</span></span><button type="button" className="add" onClick={() => notesStore.add(key, { id: uid(), file: tab, quote: "", line: null, text: "", state: "draft", editing: true })}><Icon name="quote" size="xs" />Note on skill</button></div>
          {!notes.length && <div className="rd-notes-empty">Select text to add a note, or note the skill as a whole. Notes leave together as one Brief.</div>}
          {notes.map((n) => <NoteView key={n.id} n={n} noteKey={key} />)}
          <div className="rd-notes-foot">
            <button type="button" className="btn primary" disabled={!drafts.length || sending} onClick={send}><Icon name="submit-document" size="sm" />{sending ? "Sending…" : "Send Brief" + (drafts.length ? " · " + drafts.length : "")}</button>
            {drafts.length > 0 && <div className="rd-links"><button type="button" onClick={() => setShowBrief((v) => !v)}>{showBrief ? "Hide Brief" : "Preview Brief"}</button><span aria-hidden="true">·</span><button type="button" onClick={copyBrief}>Copy Brief</button></div>}
            {drafts.length > 0 && showBrief && <div className="rd-brief"><b>{briefText().split("\n")[0]}</b>{"\n" + briefText().split("\n").slice(1).join("\n")}</div>}
            <div className={"rd-status" + (status?.ok ? " ok" : "")} role="status" aria-live="polite">{status && <><Icon name={status.ok ? "check-circle" : "refresh"} size="sm" /><span>{status.text}</span></>}</div>
            {hist.length > 0 && <div className="rd-hist">{hist.map((x, k) => <div key={k}>{x.n} note{x.n === 1 ? "" : "s"} sent at {x.at} · {x.label}</div>)}</div>}
          </div>
        </aside>
      </div>
    </div>
    {pill && <button type="button" className="note-pill is-on" style={{ left: pill.x, top: pill.y }} onMouseDown={(e) => { e.preventDefault(); e.stopPropagation(); }} onClick={addFromSelection}><Icon name="edit-pencil" size="sm" />Add note</button>}
  </div>;
}

function NoteView({ n, noteKey: key }: { n: Note; noteKey: string }) {
  const st = useNotes();
  const ref = useRef<HTMLTextAreaElement>(null);
  useEffect(() => { if (n.editing) ref.current?.focus(); }, [n.editing]);
  function activate() { st.setActive(n.id); if (n.range) { const r = n.range.getBoundingClientRect(); if (r.height) n.range.startContainer.parentElement?.scrollIntoView({ block: "center", behavior: "smooth" }); } }
  return <div className={"rd-note " + n.state + (st.active === n.id ? " is-active" : "")} onClick={(e) => { if ((e.target as HTMLElement).closest("button, textarea")) return; activate(); }}>
    <div className="q">{n.quote ? <>{n.line && <span className="ln">L{n.line}</span>}{n.quote}</> : <><span className="ln">skill</span>whole skill</>}</div>
    {n.editing ? <><textarea ref={ref} placeholder="What should change?" rows={3} defaultValue={n.text}
      onKeyDown={(e) => { const v = (e.target as HTMLTextAreaElement).value.trim(); if (e.key === "Enter" && !e.shiftKey) { e.preventDefault(); if (!v) st.remove(key, n.id); else st.update(key, n.id, { text: v, editing: false }); } if (e.key === "Escape") { e.preventDefault(); st.remove(key, n.id); } }} /><div className="ta-hint">Enter to keep · Esc to discard</div></>
      : <div className="t">{n.text}</div>}
    {!n.editing && <div className="s"><span className="chip">{n.state === "sent" ? "Sent " + n.sentAt : "Draft"}</span>
      {n.state === "draft" && <><button type="button" onClick={() => st.update(key, n.id, { editing: true })}>Edit</button><button type="button" onClick={() => st.remove(key, n.id)}>Remove</button></>}</div>}
  </div>;
}
