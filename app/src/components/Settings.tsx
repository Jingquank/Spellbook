import { useEffect, useState } from "react";
import { useTheme } from "next-themes";
import { ToggleGroup } from "@base-ui/react/toggle-group";
import { Toggle } from "@base-ui/react/toggle";
import { toast } from "sonner";
import { rescan } from "../api";
import { usePrefs, useSurvey } from "../store";
import type { Survey } from "../types";
import { Icon } from "../icons";
import { Marks } from "./InstallBits";

function Seg<T extends string | number>({ label, value, options, onChange }: { label: string; value: T; options: { value: T; label: string }[]; onChange: (v: T) => void }) {
  return <ToggleGroup className="seg" aria-label={label} value={[String(value)]} onValueChange={(vals) => { const v = vals[0]; if (v != null) onChange(options.find((o) => String(o.value) === String(v))!.value); }}>
    {options.map((o) => <Toggle key={String(o.value)} value={String(o.value)}>{o.label}</Toggle>)}
  </ToggleGroup>;
}
function Row({ title, sub, children }: { title: React.ReactNode; sub?: React.ReactNode; children?: React.ReactNode }) {
  return <div className="set-row"><div className="lb"><div className="t">{title}</div>{sub && <div className="s">{sub}</div>}</div><div className="ct">{children}</div></div>;
}
function Section({ id, title, desc, children }: { id: string; title: string; desc: string; children: React.ReactNode }) {
  return <section className="set-sec" id={"set-" + id}><h3>{title}</h3><p className="d">{desc}</p><div className="set-rows">{children}</div></section>;
}

const SECTIONS: [string, string][] = [["appearance", "Appearance"], ["reader", "Reader"], ["connection", "Connection"], ["roots", "Roots"], ["records", "Records"], ["keys", "Keys"]];

export function SettingsNav({ survey, onBack }: { survey: Survey; onBack: () => void }) {
  const { theme } = useTheme();
  const prefs = usePrefs();
  const [current, setCurrent] = useState("appearance");
  useEffect(() => {
    const els = SECTIONS.map(([id]) => document.getElementById("set-" + id)).filter(Boolean) as HTMLElement[];
    const root = document.querySelector(".set-scroll");
    if (!els.length || !root) return;
    const io = new IntersectionObserver((ents) => { const vis = ents.filter((e) => e.isIntersecting).sort((a, b) => a.boundingClientRect.top - b.boundingClientRect.top); if (vis[0]) setCurrent(vis[0].target.id.replace("set-", "")); }, { root, rootMargin: "0px 0px -70% 0px", threshold: 0 });
    els.forEach((el) => io.observe(el)); return () => io.disconnect();
  }, []);
  const value = (id: string) => id === "appearance" ? theme || "system" : id === "reader" ? prefs.width + " · " + prefs.text + "px" : id === "records" ? String(survey.records.length) : "";
  return <>
    <div className="gr-run"><span>Spellbook · Settings</span><span className="rh">{survey.projectPath}</span></div>
    <div className="set-nav">
      <h2>Settings</h2>
      <p className="lede">Appearance and Reader choices stay in this browser. Roots and Records show what the Survey read.</p>
      {SECTIONS.map(([id, label]) => <button key={id} type="button" className={"lnk" + (current === id ? " is-current" : "")} onClick={() => document.getElementById("set-" + id)?.scrollIntoView({ block: "start" })}><span>{label}</span><span className="lead" /><span className="v">{value(id)}</span></button>)}
    </div>
    <div className="gr-ft"><button type="button" className="btn quiet" onClick={onBack}>‹ Back to reading</button><span /></div>
  </>;
}

export function SettingsPage({ survey, pageLabel }: { survey: Survey; pageLabel: string }) {
  const { theme, setTheme } = useTheme();
  const prefs = usePrefs();
  const connected = useSurvey((s) => s.connected);
  const agentName = survey.agentName;
  return <>
    <div className="gr-run"><span className="rh">Settings</span><span className="rh">{pageLabel}</span></div>
    <div className="set-scroll">
      <Section id="appearance" title="Appearance" desc="Light and dark come from the same tokens. System follows the operating system.">
        <Row title="Colour"><Seg label="Appearance" value={(theme || "system") as string} options={[{ value: "system", label: "System" }, { value: "light", label: "Light" }, { value: "dark", label: "Dark" }]} onChange={(v) => setTheme(v)} /></Row>
      </Section>
      <Section id="reader" title="Reader" desc="How the right page sets the skill you are reading.">
        <Row title="Width" sub="Focused keeps a 68-character measure. Wide lets the book and the measure grow on large screens."><Seg label="Width" value={prefs.width} options={[{ value: "focused" as const, label: "Focused" }, { value: "wide" as const, label: "Wide" }]} onChange={prefs.setWidth} /></Row>
        <Row title="Text size" sub="Reader prose only. Interface text does not change."><Seg label="Text size" value={prefs.text} options={[{ value: 14 as const, label: "14" }, { value: 15 as const, label: "15" }, { value: 16 as const, label: "16" }]} onChange={prefs.setText} /></Row>
      </Section>
      <Section id="connection" title="Connection" desc="Where Briefs go and how they get there.">
        <Row title="Opened by" sub="The agent that ran /spellbook. Briefs are addressed to it."><span className="st"><Marks marks={[survey.agent]} />{agentName}</span></Row>
        <Row title="Delivery" sub="A local server the skill started. The Reader reloads when the agent changes a file."><span className="st"><span className={"dot" + (connected ? "" : " off")} />{connected ? "127.0.0.1:" + (survey.port || location.port) : "not reachable"}</span></Row>
        <Row title="Fallback" sub="Copy Brief puts the same text on the clipboard, for agents without the server or when it is offline."><span className="st">clipboard, always available</span></Row>
      </Section>
      <Section id="roots" title="Roots" desc="Where the Survey's facts come from. Read-only; a rescan re-reads them.">
        {survey.roots.map((r) => <Row key={r.path} title={r.path} sub={r.note + (r.exists ? "" : " · not present")}><span className="n">{r.skills} skill{r.skills === 1 ? "" : "s"}</span></Row>)}
        <Row title="Last scan" sub={new Date(survey.scanned).toLocaleString(undefined, { hour: "2-digit", minute: "2-digit", day: "numeric", month: "short" })}><button type="button" className="btn" onClick={async () => { try { await rescan(); toast.success("Rescanned the roots."); } catch { toast.error("Could not reach the local server to rescan."); } }}><Icon name="refresh" size="sm" />Rescan</button></Row>
      </Section>
      <Section id="records" title="Records" desc="Lockfiles and manifests read to establish Origins. Entry counts include records for skills no longer on disk; those skills are not added to the Survey.">
        {survey.records.map((r) => <Row key={r.path} title={r.path} sub={r.kind + (r.read ? " · read" : " · could not read")}><span className="n">{r.entries} entr{r.entries === 1 ? "y" : "ies"}</span></Row>)}
        {!survey.records.length && <div className="set-empty">No lockfiles or manifests found.</div>}
      </Section>
      <section className="set-sec" id="set-keys"><h3>Keys</h3><p className="d">Move through the contents, turn pages and find a skill.</p>
        <table className="set-keys"><tbody>
          <tr><td><kbd>←</kbd><kbd>→</kbd></td><td>Turn a page</td></tr>
          <tr><td><kbd>Esc</kbd></td><td>Leave Settings; clear the filter</td></tr>
          <tr><td><kbd>j</kbd><kbd>k</kbd></td><td>Move the cursor</td></tr>
          <tr><td><kbd>⏎</kbd></td><td>Open a skill, or fold an Install</td></tr>
          <tr><td><kbd>h</kbd><kbd>l</kbd> <kbd>z</kbd></td><td>Fold, unfold, fold all</td></tr>
          <tr><td><kbd>/</kbd> <kbd>s</kbd></td><td>Filter; cycle sort by name, date, size</td></tr>
        </tbody></table>
      </section>
    </div>
  </>;
}
