import { Fragment, useEffect, useMemo, useRef, useState } from "react";
import { toast } from "sonner";
import { SOURCE_NAMES, type Install, type Page, type Skill } from "../types";
import { installsIn, useGroups, useUI, type Sort } from "../store";
import { Icon } from "../icons";
import { Thumb } from "../thumbs";
import { DriftPopover, RenameInline } from "./InstallBits";

/* The contents page. One row model for both Registers: the Mono register changes type, not behaviour.
   Sections (Installs) fold; entries (skills) carry page numbers; a keyboard cursor moves over both. */

type Row = { kind: "sec"; install: Install; open: boolean } | { kind: "ent"; install: Install; skill: Skill; page: number };
const SORT_LABEL: Record<Sort, string> = { book: "book", name: "name", date: "date", size: "size" };
const matches = (i: Install, q: string) => !q || i.name.toLowerCase().includes(q) || i.skills.some((s) => (s.name + " " + s.description).toLowerCase().includes(q));
const skillMatches = (i: Install, s: Skill, q: string) => !q || (s.name + " " + s.description + " " + i.name).toLowerCase().includes(q);

export function Contents({ installs, pages, page, onOpen, projectPath, mono }: { installs: Install[]; pages: Page[]; page: number; onOpen: (n: number) => void; projectPath: string; mono: boolean }) {
  const sort = useUI((u) => u.sort), setSort = useUI((u) => u.setSort);
  const dismiss = useGroups((g) => g.dismiss), restore = useGroups((g) => g.restore);
  const [open, setOpen] = useState<Record<string, boolean>>({});
  const [filter, setFilter] = useState("");
  const [cursor, setCursor] = useState<string | null>(null);
  const [kb, setKb] = useState(false); // the cursor ring shows only after keyboard use
  const [renaming, setRenaming] = useState<string | null>(null);
  const inp = useRef<HTMLInputElement>(null);
  const listRef = useRef<HTMLDivElement>(null);
  const q = filter.trim().toLowerCase();
  const cur = pages[page];

  useEffect(() => { if (cur && !open[cur.install.id]) setOpen((o) => ({ ...o, [cur.install.id]: true })); }, [cur?.install.id]);
  useEffect(() => { if (cur) setCursor("e:" + cur.install.id + "/" + cur.skill.id); }, [page]);

  const chapters = useMemo(() => (["project", "device"] as const).map((src) => ({ src, ins: installsIn(installs, src).filter((i) => matches(i, q)) })), [installs, q]);
  const rows = useMemo<Row[]>(() => {
    const out: Row[] = [];
    chapters.forEach((ch) => ch.ins.forEach((i) => {
      const isOpen = q ? true : !!open[i.id];
      out.push({ kind: "sec", install: i, open: isOpen });
      if (isOpen) i.skills.filter((s) => skillMatches(i, s, q)).forEach((s) => out.push({ kind: "ent", install: i, skill: s, page: pages.findIndex((p) => p.install === i && p.skill === s) }));
    }));
    return out;
  }, [chapters, open, q, pages]);
  const keyOf = (r: Row) => (r.kind === "sec" ? "s:" + r.install.id : "e:" + r.install.id + "/" + r.skill.id);
  const idx = rows.findIndex((r) => keyOf(r) === cursor);
  useEffect(() => { listRef.current?.querySelector(".is-cursor")?.scrollIntoView({ block: "nearest" }); }, [cursor]);

  function move(d: number) { if (!rows.length) return; const k = Math.max(0, Math.min(rows.length - 1, (idx < 0 ? -1 : idx) + d)); setCursor(keyOf(rows[k])); }
  function toggle(i: Install, force?: boolean) { setOpen((o) => ({ ...o, [i.id]: force ?? !o[i.id] })); }
  function dismissWithUndo(i: Install) { dismiss(i.id); toast.success("Not a group. " + i.skills.length + " skills are now Loose Skills.", { action: { label: "Undo", onClick: () => restore(i.id) } }); }
  useEffect(() => {
    function keys(e: KeyboardEvent) {
      const t = e.target as HTMLElement;
      if (t === inp.current) { if (e.key === "Escape") { setFilter(""); inp.current?.blur(); } if (e.key === "Enter" || e.key === "ArrowDown") { e.preventDefault(); inp.current?.blur(); if (rows[0]) setCursor(keyOf(rows[0])); } return; }
      if (t.closest("input, textarea, [contenteditable]") || e.metaKey || e.ctrlKey || e.altKey) return;
      const r = rows[idx];
      if (e.key === "j" || e.key === "ArrowDown") { e.preventDefault(); setKb(true); move(1); }
      else if (e.key === "k" || e.key === "ArrowUp") { e.preventDefault(); setKb(true); move(-1); }
      else if (e.key === "/") { e.preventDefault(); inp.current?.focus(); }
      else if (e.key === "z") { const any = Object.values(open).some(Boolean); setOpen(any ? {} : Object.fromEntries(installs.map((i) => [i.id, true]))); }
      else if (e.key === "s") { const order: Sort[] = ["book", "name", "date", "size"]; const n = order[(order.indexOf(sort) + 1) % order.length]; setSort(n); toast("Sorted by " + SORT_LABEL[n] + (n === "book" ? " order" : "") + ". Page numbers follow."); }
      else if (e.key === "r" && r?.kind === "sec" && r.install.kind === "inferred") { e.preventDefault(); setRenaming(r.install.id); }
      else if (e.key === "x" && r?.kind === "sec" && r.install.kind === "inferred") { e.preventDefault(); dismissWithUndo(r.install); }
      else if (e.key === "h") { if (r) { toggle(r.install, false); if (r.kind === "ent") setCursor("s:" + r.install.id); } }
      else if (e.key === "l") { if (r?.kind === "sec") toggle(r.install, true); }
      else if (e.key === "Enter" || e.key === " ") { if (!r) return; e.preventDefault(); if (r.kind === "sec") toggle(r.install); else onOpen(r.page); }
    }
    const mouse = () => setKb(false);
    document.addEventListener("keydown", keys); document.addEventListener("mousedown", mouse);
    return () => { document.removeEventListener("keydown", keys); document.removeEventListener("mousedown", mouse); };
  }, [rows, idx, open, installs, sort, onOpen]);

  return <>
    <div className="gr-run"><span>Spellbook</span><span className="rh">{projectPath}</span></div>
    <div className="ct" ref={listRef} role="tree" aria-label="Contents">
      <div className="ct-hd"><h2>Contents</h2><span className="cnt tnum">{installs.length} installs · {pages.length} skills{sort !== "book" && <> · by {SORT_LABEL[sort]}</>}</span></div>
      {chapters.map((ch) => <Fragment key={ch.src}>
        <div className="ct-ch" role="presentation"><span>{SOURCE_NAMES[ch.src]}</span><span className="n tnum">{ch.ins.length}</span></div>
        {!ch.ins.length && <div className="ct-empty">{q ? "No match in this chapter." : <>Nothing here yet. A folder with a <code>SKILL.md</code> under <code>.claude/skills/</code> becomes a section.</>}</div>}
        {ch.ins.map((i) => {
          const isOpen = q ? true : !!open[i.id], key = "s:" + i.id, isCur = cur?.install.id === i.id;
          return <Fragment key={i.id}>
            <div className={"ct-sec" + (isOpen ? " open" : "") + (isCur ? " is-current" : "") + (kb && cursor === key ? " is-cursor" : "") + (i.kind === "inferred" ? " guess" : "")} role="treeitem" aria-level={1} aria-expanded={isOpen} tabIndex={cursor === key ? 0 : -1}
              onClick={(e) => { if ((e.target as HTMLElement).closest(".ct-acts, .ren-in, [data-ann]")) return; setCursor(key); toggle(i); }} onFocus={() => setCursor(key)}>
              <Icon name="nav-arrow-right" size="sm" className="chev" />
              <Thumb install={i} size={mono ? 12 : 20} square />
              {renaming === i.id ? <RenameInline i={i} onDone={() => setRenaming(null)} /> : <span className="n">{i.name}</span>}
              <span className="meta">
                {i.kind === "inferred" && <span className="pill" title="Spellbook guessed this group because the skills arrived on the same day. Name it, or say it is not a group.">guessed</span>}
                {i.renamed && <span className="pill solid" title={"You named this group. It was “" + i.originalName + "”."}>named</span>}
                {i.kind === "recorded" && !i.drift && <span className="kind" title={"A manifest lists these skills as one install: " + (i.manifest || "")}>recorded</span>}
                {i.kind === "plugin" && <span className="kind" title="Installed as a plugin">plugin</span>}
                {i.drift && <DriftPopover i={i} className="drift">drift</DriftPopover>}
              </span>
              {i.kind === "inferred" && <span className="ct-acts" onClick={(e) => e.stopPropagation()}><button type="button" tabIndex={-1} onClick={() => setRenaming(i.id)}>name it</button><button type="button" tabIndex={-1} onClick={() => dismissWithUndo(i)}>not a group</button></span>}
              <span className="lead" /><span className="pg tnum">{i.skills.length}</span>
            </div>
            <div className={"ct-kids" + (isOpen ? " open" : "")} role="group" aria-hidden={!isOpen}><div className="ct-kids-in">{i.skills.filter((s) => skillMatches(i, s, q)).map((s) => {
              const n = pages.findIndex((p) => p.install === i && p.skill === s), ek = "e:" + i.id + "/" + s.id;
              return <div key={s.id} className={"ct-ent" + (n === page ? " is-selected" : "") + (kb && cursor === ek ? " is-cursor" : "")} role="treeitem" aria-level={2} aria-selected={n === page} tabIndex={isOpen && cursor === ek ? 0 : -1}
                onClick={() => { setCursor(ek); onOpen(n); }} onFocus={() => setCursor(ek)}>
                <span className="n">{s.name}</span>{mono && <span className="ln">{s.lines} lines</span>}<span className="lead" /><span className="pg tnum">{n + 1}</span>
              </div>;
            })}</div></div>
          </Fragment>;
        })}
      </Fragment>)}
    </div>
    <div className="ct-in"><span className="pr">/</span><input ref={inp} type="text" placeholder="filter" autoComplete="off" spellCheck={false} value={filter} onChange={(e) => setFilter(e.target.value)} aria-label="Filter the contents" />
      <span className="keys"><kbd>j</kbd><kbd>k</kbd> move <kbd>⏎</kbd> open · fold <kbd>←</kbd><kbd>→</kbd> page <span className="more">· more in Settings</span></span></div>
  </>;
}
