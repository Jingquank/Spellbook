import { Fragment } from "react";
import { Popover } from "@base-ui/react/popover";
import { AGENT_NAMES, type Install, type Mark, type Origin } from "../types";
import { useSurvey } from "../store";
import { reconcileBrief, sendAgentBrief } from "../brief";
import { Icon } from "../icons";

const MARK_SRC: Partial<Record<Mark, string>> = { "claude-code": "/design/icons/agents/claude-code.png", codex: "/design/icons/agents/codex.png", cursor: "/design/icons/agents/cursor-dark.png" };

export function Marks({ marks, size }: { marks: Mark[]; size?: "lg" }) {
  return <span className="marks">{marks.map((m) => MARK_SRC[m]
    ? <img key={m} className={"mark" + (size ? " " + size : "")} src={MARK_SRC[m]} alt={AGENT_NAMES[m]} title={AGENT_NAMES[m]} />
    : <span key={m} className={"mark gem" + (size ? " " + size : "")} title={AGENT_NAMES[m]}>{AGENT_NAMES[m].charAt(0)}</span>)}</span>;
}

export function kindLabel(i: Install): string {
  return i.origin.grade === "hinted" ? "probably " + (i.origin.slug || i.origin.name) : i.origin.kind;
}
export function OriginLine({ origin }: { origin: Origin }) {
  const detail = [origin.slug, origin.path, origin.ref, origin.version && "version " + origin.version].filter(Boolean);
  return <div className="rd-origin" aria-label="Origin">
    <div><b>{origin.kind} · {origin.name}</b><span> · {origin.grade === "hinted" ? "probably · Hinted Origin" : origin.grade.charAt(0).toUpperCase() + origin.grade.slice(1) + " Origin"}</span></div>
    {detail.length > 0 && <div className="detail">{detail.join(" · ")}</div>}
    {origin.url && <div className="detail">{origin.url}</div>}
    {origin.record && <div className="detail">Record: {origin.record}</div>}
    {origin.evidence.map((e) => <p key={e}>{e}</p>)}
  </div>;
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
  return <><span className="origin-word" title={i.origin.evidence[0]}>{kindLabel(i)}</span>{i.drift && <DriftPopover i={i} className="drift">drift</DriftPopover>}</>;
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
              {d.copies.map((c) => <Fragment key={c.root}><span key={c.root + "r"}>{c.root}</span><span key={c.root + "v"}>{c.lines} lines · {c.files} file{c.files === 1 ? "" : "s"}{c.updated && <span className="dt"> · {c.updated}</span>}</span></Fragment>)}
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

export function IconBtn({ name, title, onClick, className }: { name: Parameters<typeof Icon>[0]["name"]; title: string; onClick?: () => void; className?: string }) {
  return <button type="button" className={"btn quiet icon " + (className || "")} title={title} aria-label={title} onClick={onClick}><Icon name={name} size="sm" /></button>;
}
