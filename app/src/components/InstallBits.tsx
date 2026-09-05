import { useEffect, useRef, useState } from "react";
import { Popover } from "@base-ui/react/popover";
import { toast } from "sonner";
import { AGENT_NAMES, type Install, type Mark } from "../types";
import { useGroups, useSurvey } from "../store";
import { reconcileBrief, sendAgentBrief } from "../brief";
import { Icon } from "../icons";

const MARK_SRC: Partial<Record<Mark, string>> = { "claude-code": "/design/icons/agents/claude-code.png", codex: "/design/icons/agents/codex.png", cursor: "/design/icons/agents/cursor-dark.png" };

export function Marks({ marks, size }: { marks: Mark[]; size?: "lg" }) {
  return <span className="marks">{marks.map((m) => MARK_SRC[m]
    ? <img key={m} className={"mark" + (size ? " " + size : "")} src={MARK_SRC[m]} alt={AGENT_NAMES[m]} title={AGENT_NAMES[m]} />
    : <span key={m} className={"mark gem" + (size ? " " + size : "")} title={AGENT_NAMES[m]}>{AGENT_NAMES[m].charAt(0)}</span>)}</span>;
}

export function kindLabel(i: Install): string {
  if (i.kind === "recorded") return "Recorded";
  if (i.kind === "inferred") return "Guessed";
  if (i.kind === "plugin") return "Plugin";
  return i.skills.length === 1 ? "Loose skill" : "Loose";
}
export function describe(i: Install): string { return i.skills.length === 1 ? i.skills[0].description : i.skills.length + " skills: " + i.skills.map((s) => s.name).join(", ") + "."; }
export function totalLines(i: Install): number { return i.skills.reduce((a, s) => a + (s.lines || 0), 0); }
export function relDate(date: string, scanned: string): string {
  const days = Math.round((new Date(scanned.slice(0, 10)).getTime() - new Date(date).getTime()) / 86400000);
  if (days <= 0) return "today"; if (days === 1) return "1d ago"; if (days < 30) return days + "d ago";
  const mo = Math.round(days / 30); return mo < 12 ? mo + "mo ago" : Math.round(days / 365) + "y ago";
}
export function driftSkills(i: Install) { return i.skills.filter((s) => s.drift && s.driftDetail); }
export function driftSummary(i: Install): string {
  const ds = driftSkills(i); if (!ds.length) return "";
  const files = new Set<string>(); ds.forEach((s) => (s.driftDetail?.changed || []).forEach((f) => files.add(f)));
  const roots = new Set<string>(); ds.forEach((s) => s.driftDetail?.copies.forEach((c) => roots.add(c.root)));
  return ds.length + " of " + i.skills.length + " skill" + (i.skills.length === 1 ? "" : "s") + " differ between " + [...roots].join(" and ") + " (" + [...files].slice(0, 3).join(", ") + ")";
}

export function Badges({ i }: { i: Install }) {
  return <>
    {i.kind === "inferred" && <span className="badge guess" title="Spellbook guessed this group because the skills arrived on the same day. Name it, or say it is not a group.">Guessed</span>}
    {i.kind === "recorded" && <span className="badge" title={"A manifest lists these skills as one install: " + (i.manifest || "")}>Recorded</span>}
    {i.kind === "plugin" && <span className="badge" title="Installed as a plugin; its skills arrive and update together.">Plugin {i.version}</span>}
    {i.drift && <span className="badge drift" title={driftSummary(i)}><span className="drift-dot" />Drift</span>}
  </>;
}

/* The Drift popover: both copies of each drifted skill, and one request to the agent. */
export function DriftPopover({ i, children, className }: { i: Install; children: React.ReactNode; className?: string }) {
  const agentName = useSurvey((s) => s.agentName);
  const ds = driftSkills(i);
  return <Popover.Root>
    <Popover.Trigger className={className || "w"} data-ann="drift" title={driftSummary(i)}>{children}</Popover.Trigger>
    <Popover.Portal>
      <Popover.Positioner sideOffset={8} align="start" className="pop-popup">
        <Popover.Popup className="pop" role="dialog">
          <h4><span className="drift-dot" />Drift in {i.name}</h4>
          {ds.map((s) => {
            const d = s.driftDetail!;
            const extra = Object.keys(d.onlyIn || {}).filter((k) => d.onlyIn[k].length).map((k) => d.onlyIn[k].join(", ") + " only in " + k).join("; ");
            return <div className="row" key={s.id}><b>{s.name}</b>
              {d.copies.map((c) => <><span key={c.root + "r"}>{c.root}</span><span key={c.root + "v"}>{c.lines} lines · {c.files} file{c.files === 1 ? "" : "s"}{c.updated && <span className="dt"> · {c.updated}</span>}</span></>)}
              <span className="w">differs</span><span>{(d.changed || []).join(", ")}{extra ? "; " + extra : ""}</span>
            </div>;
          })}
          <div className="foot">The same skill differs between agent roots. Nothing here writes to disk; the Brief asks {agentName} to make the copies agree.<br />
            <Popover.Close className="btn" onClick={() => { const b = reconcileBrief(i, agentName); void sendAgentBrief({ installId: i.id, skillId: b.skill.id, file: "SKILL.md", path: b.skill.path + "/", text: b.text, summary: "reconcile " + ds.length + " drifted skill" + (ds.length === 1 ? "" : "s") + " in " + i.name }); }}>Ask {agentName} to reconcile</Popover.Close></div>
        </Popover.Popup>
      </Popover.Positioner>
    </Popover.Portal>
  </Popover.Root>;
}

/* Inline rename: swaps the name for an input until Enter or Escape. */
export function RenameInline({ i, onDone, className }: { i: Install; onDone: () => void; className?: string }) {
  const rename = useGroups((g) => g.rename);
  const ref = useRef<HTMLInputElement>(null);
  const [v, setV] = useState(i.name);
  useEffect(() => { ref.current?.focus(); ref.current?.select(); }, []);
  function finish(save: boolean) { if (save && v.trim() && v.trim() !== i.name) { rename(i.id, v.trim()); toast.success("Named the group “" + v.trim() + "”. Kept in this browser only."); } onDone(); }
  return <input ref={ref} className={"ren-in " + (className || "")} value={v} aria-label="Name this group" onChange={(e) => setV(e.target.value)}
    onKeyDown={(e) => { e.stopPropagation(); if (e.key === "Enter") finish(true); if (e.key === "Escape") finish(false); }} onBlur={() => finish(false)} onClick={(e) => e.stopPropagation()} />;
}

/* The annotation cluster shown beside an Install's name: kind, guessed actions, drift. */
export function Annotations({ i, onRename }: { i: Install; onRename: () => void }) {
  const dismiss = useGroups((g) => g.dismiss), restore = useGroups((g) => g.restore);
  const has = i.kind !== "loose" || i.renamed || i.drift;
  if (!has) return null;
  return <span className="ann" onClick={(e) => e.stopPropagation()}>
    {i.kind === "recorded" && <span>recorded</span>}
    {i.kind === "plugin" && <span>plugin</span>}
    {i.kind === "inferred" && <><span className="g">guessed</span><button type="button" onClick={onRename}>name it</button><button type="button" onClick={() => { dismiss(i.id); toast.success("Not a group. " + i.skills.length + " skills are now Loose Skills.", { action: { label: "Undo", onClick: () => restore(i.id) } }); }}>not a group</button></>}
    {i.renamed && <span>named by you</span>}
    {i.drift && <DriftPopover i={i}>drift</DriftPopover>}
  </span>;
}

export function IconBtn({ name, title, onClick, className }: { name: Parameters<typeof Icon>[0]["name"]; title: string; onClick?: () => void; className?: string }) {
  return <button type="button" className={"btn quiet icon " + (className || "")} title={title} aria-label={title} onClick={onClick}><Icon name={name} size="sm" /></button>;
}
